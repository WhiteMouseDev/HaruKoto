import json
import sys
import unittest
from copy import deepcopy
from io import BytesIO
from pathlib import Path
from unittest.mock import Mock, call, patch
from urllib.error import HTTPError
from urllib.parse import urlsplit

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
import rollout_cloud_run as rollout

PROJECT = "test-project"
REGION = "asia-northeast3"
SERVICE = "harukoto-api"
SERVICE_NAME = f"projects/{PROJECT}/locations/{REGION}/services/{SERVICE}"
SERVICE_PATH = f"namespaces/{PROJECT}/services/{SERVICE}"
API_HOST = f"{REGION}-run.googleapis.com"
API_PATH = f"/apis/serving.knative.dev/v1/{SERVICE_PATH}"
TAG = "verify-123-1"
TAG_URL = f"https://{TAG}---{SERVICE}-test.a.run.app"
PUBLIC_URL = f"https://{SERVICE}-test.a.run.app"
CANDIDATE = f"{SERVICE}-{TAG}"
PREVIOUS = f"{SERVICE}-00001-old"
FOREIGN = f"{SERVICE}-00002-other"
DEBUG_TAG = "debug"
REVISION = "TRAFFIC_TARGET_ALLOCATION_TYPE_REVISION"
LATEST = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
SHA = "a" * 40
IMAGE = f"{REGION}-docker.pkg.dev/{PROJECT}/harukoto/api@sha256:{'b' * 64}"
SCHEMA = {"openapi": "3.1.0"}


def target(revision, percent, *, tag=None):
    value = {"type": REVISION, "revision": revision, "percent": percent}
    if tag is not None:
        value["tag"] = tag
    return value


def service(generation, requested, *, candidate_created=False, statuses=None, resource_version=None):
    statuses = deepcopy(statuses if statuses is not None else requested)
    for entry in statuses:
        if entry["type"] == LATEST:
            entry["revision"] = PREVIOUS
        if tag := entry.get("tag"):
            entry["uri"] = TAG_URL if tag == TAG else f"https://{tag}---{SERVICE}-test.a.run.app"
    return {
        "name": SERVICE_NAME,
        "uid": "test-service-uid",
        "generation": str(generation),
        "observedGeneration": str(generation),
        "resourceVersion": resource_version if resource_version is not None else f"rv-{generation}",
        "reconciling": False,
        "terminalCondition": {"type": "Ready", "state": "CONDITION_SUCCEEDED"},
        "traffic": deepcopy(requested),
        "trafficStatuses": statuses,
        "uri": PUBLIC_URL,
        "latestCreatedRevision": f"{SERVICE_NAME}/revisions/{CANDIDATE if candidate_created else PREVIOUS}",
        "latestReadyRevision": f"{SERVICE_NAME}/revisions/{PREVIOUS}",
    }


def revision(image=IMAGE, *, healthy=True, sha=SHA):
    return {
        "metadata": {"labels": {"commit-sha": sha}},
        "status": {
            "imageDigest": image,
            "conditions": [
                {"type": "Ready", "status": "True"},
                {"type": "ContainerHealthy", "status": "True" if healthy else "False"},
            ],
        },
    }


class RolloutTests(unittest.TestCase):
    def setUp(self):
        self.old = target(PREVIOUS, 100)
        self.debug = target(FOREIGN, 0, tag=DEBUG_TAG)
        self.candidate = target(CANDIDATE, 0, tag=TAG)
        self.before = service(5, [self.old, self.debug])
        self.active = service(6, [self.old, self.debug, self.candidate], candidate_created=True)
        self.cloud = Mock(spec=rollout.CloudRun)
        self.cloud.service = SERVICE
        self.cloud.describe_service.side_effect = self.describe_service
        self.cloud.describe_revision.return_value = revision()
        self.cloud.set_traffic.side_effect = self.set_traffic
        self.smoke = self.enterContext(patch.object(rollout, "smoke"))
        self.sleep = self.enterContext(patch.object(rollout.time, "sleep"))

    def describe_service(self):
        return deepcopy(self.active)

    def set_traffic(self, current, traffic):
        self.assertEqual(current["resourceVersion"], self.active["resourceVersion"])
        self.active = service(int(current["generation"]) + 1, traffic, candidate_created=True)
        return deepcopy(self.active)

    def run_rollout(self):
        rollout.rollout(self.cloud, TAG, IMAGE, SHA, self.before, SCHEMA)

    def assert_traffic(self, traffic, revision_name):
        positive = [item for item in traffic if item.get("percent", 0)]
        self.assertEqual(len(positive), 1)
        self.assertEqual(positive[0]["type"], REVISION)
        self.assertEqual(positive[0]["revision"], revision_name)
        self.assertEqual(positive[0]["percent"], 100)
        self.assertEqual([item for item in traffic if item.get("tag") == DEBUG_TAG], [self.debug])
        self.assertTrue(all("uri" not in item for item in traffic))

    def test_smokes_tag_before_promotion_and_checks_public_after_promotion(self):
        sequence = Mock()
        sequence.attach_mock(self.smoke, "smoke")
        sequence.attach_mock(self.cloud.set_traffic, "set_traffic")
        self.run_rollout()
        self.cloud.describe_revision.assert_called_with(CANDIDATE)
        current, traffic = self.cloud.set_traffic.call_args.args
        self.assertEqual(current["resourceVersion"], "rv-6")
        self.assert_traffic(traffic, CANDIDATE)
        self.assertEqual(
            sequence.mock_calls,
            [
                call.smoke(TAG_URL, SCHEMA),
                call.set_traffic(current, traffic),
                call.smoke(PUBLIC_URL, SCHEMA),
            ],
        )

    def test_rejects_an_intentional_traffic_split(self):
        split = [target(PREVIOUS, 90), target(FOREIGN, 10)]
        self.before = service(5, split)
        self.active = service(6, [*split, self.candidate], candidate_created=True)
        with self.assertRaises(RuntimeError):
            self.run_rollout()
        self.cloud.set_traffic.assert_not_called()

    def test_rejects_candidate_other_than_latest_created(self):
        self.active["latestCreatedRevision"] = f"{SERVICE_NAME}/revisions/{FOREIGN}"
        with self.assertRaises(RuntimeError):
            self.run_rollout()
        self.cloud.set_traffic.assert_not_called()

    def test_detects_operator_change_to_an_unrelated_tag_while_staging(self):
        changed_debug = target(PREVIOUS, 0, tag=DEBUG_TAG)
        self.active = service(6, [self.old, changed_debug, self.candidate], candidate_created=True)
        with self.assertRaises(RuntimeError):
            self.run_rollout()
        self.cloud.set_traffic.assert_not_called()

    def test_missing_resource_version_or_changed_generation_blocks_promotion(self):
        for field, value in (("resourceVersion", None), ("generation", "7")):
            with self.subTest(field=field):
                changed = deepcopy(self.active)
                if value is None:
                    del changed[field]
                else:
                    changed[field] = value
                    changed["observedGeneration"] = value
                self.cloud.describe_service.side_effect = [
                    deepcopy(self.active),
                    changed,
                ]
                with self.assertRaises(RuntimeError):
                    self.run_rollout()
                self.cloud.set_traffic.assert_not_called()

    def test_incorrect_platform_digest_or_commit_does_not_promote(self):
        cases = [
            revision(image=IMAGE.replace("b" * 64, "c" * 64)),
            revision(sha="d" * 40),
        ]
        for bad_revision in cases:
            with self.subTest(revision=bad_revision):
                self.cloud.describe_revision.return_value = bad_revision
                with self.assertRaises(RuntimeError):
                    self.run_rollout()
                self.cloud.set_traffic.assert_not_called()
                self.smoke.assert_not_called()

    def test_unhealthy_candidate_can_warm_before_promotion(self):
        self.cloud.describe_revision.side_effect = [revision(healthy=False), revision()]
        self.run_rollout()
        self.assertEqual(self.cloud.describe_revision.call_count, 2)
        self.assertIn(call(TAG_URL, SCHEMA), self.smoke.call_args_list)
        self.assertEqual(self.smoke.call_args, call(PUBLIC_URL, SCHEMA))
        self.sleep.assert_called()

    def test_stale_candidate_openapi_blocks_promotion(self):
        self.smoke.side_effect = rollout.OpenAPIMismatchError("stale candidate")
        with self.assertRaises(rollout.OpenAPIMismatchError):
            self.run_rollout()
        self.cloud.set_traffic.assert_not_called()
        self.assertTrue(all(item == call(TAG_URL, SCHEMA) for item in self.smoke.call_args_list))

    def test_promotion_conflict_or_unknown_outcome_is_never_retried(self):
        for failure in (
            RuntimeError("resource version conflict"),
            TimeoutError("PUT response lost"),
        ):
            with self.subTest(failure=failure):
                self.cloud.set_traffic.reset_mock(side_effect=True)
                self.cloud.set_traffic.side_effect = failure
                with self.assertRaisesRegex(type(failure), str(failure)):
                    self.run_rollout()
                self.assertEqual(self.cloud.set_traffic.call_count, 1)

    def test_status_only_version_changes_allow_promotion_and_rollback_with_a_fresh_version(self):
        self.before = service(5, [{"type": LATEST, "percent": 100}, self.debug])

        def smoke(url, _schema):
            if url == TAG_URL:
                self.active["resourceVersion"] = "rv-6-after-tag"
            elif url == PUBLIC_URL:
                self.active["resourceVersion"] = "rv-7-after-public"
                raise rollout.OpenAPIMismatchError("stale public")

        self.smoke.side_effect = smoke
        with self.assertRaisesRegex(rollout.OpenAPIMismatchError, "stale public"):
            self.run_rollout()
        promotion, rollback = [item.args for item in self.cloud.set_traffic.call_args_list]
        self.assertEqual(promotion[0]["resourceVersion"], "rv-6-after-tag")
        self.assertEqual(rollback[0]["resourceVersion"], "rv-7-after-public")
        self.assert_traffic(rollback[1], PREVIOUS)

    def test_does_not_rollback_when_operator_changed_generation_uid_or_traffic(self):
        for changed_field, field_value in (
            ("generation", "8"),
            ("uid", "operator-uid"),
            ("traffic", [target(FOREIGN, 100)]),
        ):
            with self.subTest(changed_field=changed_field):
                self.active = service(6, [self.old, self.debug, self.candidate], candidate_created=True)
                self.cloud.set_traffic.reset_mock()

                def smoke(url, _schema, *, key=changed_field, value=field_value):
                    if url == PUBLIC_URL:
                        self.active[key] = value
                        raise RuntimeError("public verification failed")

                self.smoke.side_effect = smoke
                with self.assertRaisesRegex(RuntimeError, "public verification failed"):
                    self.run_rollout()
                self.assertEqual(self.cloud.set_traffic.call_count, 1)

    def test_rollback_conflict_does_not_reapply_or_overwrite_foreign_state(self):
        self.smoke.side_effect = [None, RuntimeError("public verification failed")]
        self.cloud.set_traffic.side_effect = lambda current, traffic: self._conflict_on_rollback(current, traffic)
        with self.assertRaisesRegex(RuntimeError, "public verification failed"):
            self.run_rollout()
        self.assertEqual(self.cloud.set_traffic.call_count, 2)
        self.assert_traffic(self.active["traffic"], FOREIGN)

    def _conflict_on_rollback(self, current, traffic):
        if self.cloud.set_traffic.call_count == 1:
            return self.set_traffic(current, traffic)
        self.active = service(8, [target(FOREIGN, 100), self.debug], candidate_created=True)
        raise RuntimeError("resource version conflict")

    def test_public_checks_wait_for_serving_generation_and_status_to_converge(self):
        def transient_then_current():
            current = self.describe_service()
            if current["generation"] == "7" and not self.sleep.called:
                current["observedGeneration"] = "6"
                current["reconciling"] = True
                current["trafficStatuses"] = deepcopy(self.before["trafficStatuses"])
            return current

        self.cloud.describe_service.side_effect = transient_then_current
        self.run_rollout()
        self.sleep.assert_called_once()
        self.assertEqual(self.smoke.call_args_list, [call(TAG_URL, SCHEMA), call(PUBLIC_URL, SCHEMA)])


class SmokeTests(unittest.TestCase):
    def test_smoke_rejects_a_healthy_service_with_the_wrong_contract(self):
        responses = [
            BytesIO(b'{"status":"ok"}'),
            BytesIO(json.dumps({"openapi": "3.0.0"}).encode()),
        ]
        with (
            patch.object(rollout, "urlopen", side_effect=responses),
            self.assertRaisesRegex(RuntimeError, "OpenAPI"),
        ):
            rollout.smoke(TAG_URL, SCHEMA)


def v1_target(revision_name, percent, *, tag=None, latest=False, url=None):
    entry = {"percent": percent}
    if revision_name is not None:
        entry["revisionName"] = revision_name
    if latest:
        entry["latestRevision"] = True
    if tag is not None:
        entry["tag"] = tag
    if url is not None:
        entry["url"] = url
    return entry


def raw_service(generation, *, resource_version=None, requested=None, statuses=None, ready="True"):
    requested = [v1_target(PREVIOUS, 100)] if requested is None else requested
    return {
        "apiVersion": "serving.knative.dev/v1",
        "kind": "Service",
        "metadata": {
            "name": SERVICE,
            "namespace": "123456789012",
            "uid": "test-service-uid",
            "resourceVersion": resource_version if resource_version is not None else f"rv-{generation}",
            "generation": generation,
            "labels": {"keep": "label"},
            "annotations": {"keep": "annotation"},
        },
        "spec": {
            "template": {
                "metadata": {"annotations": {"keep-template": "value"}},
                "spec": {
                    "containers": [{"image": IMAGE, "env": [{"name": "FIXTURE", "value": "private fixture config"}]}],
                    "timeoutSeconds": 42,
                },
            },
            "traffic": deepcopy(requested),
        },
        "status": {
            "observedGeneration": generation,
            "conditions": [{"type": "Ready", "status": ready}],
            "latestCreatedRevisionName": CANDIDATE,
            "latestReadyRevisionName": PREVIOUS,
            "url": PUBLIC_URL,
            "traffic": deepcopy(statuses if statuses is not None else requested),
        },
    }


class CloudRunTransportTests(unittest.TestCase):
    def setUp(self):
        self.cloud = rollout.CloudRun(PROJECT, REGION, SERVICE)
        self.before = service(6, [target(PREVIOUS, 100)], candidate_created=True)
        self.raw_before = raw_service(6)
        self.promoted = [target(CANDIDATE, 100)]
        self.raw_promoted = [v1_target(CANDIDATE, 100)]

    def test_replaces_traffic_using_the_full_spec_and_original_resource_version(self):
        returned = raw_service(7, requested=self.raw_promoted, statuses=[v1_target(PREVIOUS, 100)], ready="Unknown")
        with patch.object(self.cloud, "request", side_effect=[deepcopy(self.raw_before), returned]) as request:
            result = self.cloud.set_traffic(self.before, self.promoted)

        self.assertEqual(request.call_count, 2)
        request_args, request_kwargs = request.call_args_list[0]
        self.assertEqual(request_args, (SERVICE_PATH,))
        self.assertIsNone(request_kwargs.get("body"))
        request_args, request_kwargs = request.call_args_list[1]
        self.assertEqual(request_args, (SERVICE_PATH,))
        self.assertIsNone(request_kwargs.get("query"))
        body = request_kwargs["body"]
        self.assertEqual(body["metadata"]["resourceVersion"], "rv-6")
        self.assertEqual(body["metadata"]["name"], SERVICE)
        for key in ("labels", "annotations"):
            self.assertEqual(body["metadata"][key], self.raw_before["metadata"][key])
        self.assertEqual(body["spec"], self.raw_before["spec"] | {"traffic": self.raw_promoted})
        self.assertNotIn("status", body)
        self.assertEqual((result["generation"], result["resourceVersion"], result["uid"]), ("7", "rv-7", self.before["uid"]))

    def test_an_inconsistent_replacement_response_fails_without_another_write(self):
        for field in ("uid", "generation", "traffic"):
            with self.subTest(field=field):
                returned = raw_service(7, requested=self.raw_promoted)
                if field == "uid":
                    returned["metadata"]["uid"] = "unexpected-service-uid"
                elif field == "generation":
                    returned["metadata"]["generation"] = 8
                else:
                    returned["spec"]["traffic"] = [v1_target(FOREIGN, 100)]
                with (
                    patch.object(self.cloud, "request", side_effect=[deepcopy(self.raw_before), returned]) as request,
                    self.assertRaisesRegex(RuntimeError, "did not confirm"),
                ):
                    self.cloud.set_traffic(self.before, self.promoted)
                self.assertEqual(request.call_count, 2)

    def test_traffic_replacement_keeps_named_endpoints_and_zero_percent(self):
        desired = [target(CANDIDATE, 100), target(FOREIGN, 0, tag=DEBUG_TAG)]
        returned = raw_service(7, requested=[*self.raw_promoted, v1_target(FOREIGN, 0, tag=DEBUG_TAG)])
        with patch.object(self.cloud, "request", side_effect=[self.raw_before, returned]) as request:
            self.cloud.set_traffic(self.before, desired)
        raw_targets = request.call_args.kwargs["body"]["spec"]["traffic"]
        self.assertEqual(raw_targets, returned["spec"]["traffic"])
        self.assertTrue(all("url" not in item for item in raw_targets))

    def test_missing_precondition_is_rejected_before_any_request(self):
        del self.before["resourceVersion"]
        with patch.object(self.cloud, "request") as request, self.assertRaises(RuntimeError):
            self.cloud.set_traffic(self.before, self.promoted)
        request.assert_not_called()

    def test_change_before_full_get_prevents_writing(self):
        operator = raw_service(6, resource_version="rv-operator")
        with patch.object(self.cloud, "request", return_value=operator) as request, self.assertRaises(RuntimeError):
            self.cloud.set_traffic(self.before, self.promoted)
        self.assertEqual(request.call_count, 1)
        self.assertIsNone(request.call_args.kwargs.get("body"))

    def test_timeout_is_uncertain_and_uses_one_put(self):
        with (
            patch.object(self.cloud, "request", side_effect=[self.raw_before, TimeoutError("PUT response lost")]) as request,
            self.assertRaisesRegex(TimeoutError, "PUT response lost"),
        ):
            self.cloud.set_traffic(self.before, self.promoted)
        self.assertEqual(request.call_count, 2)
        self.assertEqual(request.call_args.kwargs["body"]["metadata"]["resourceVersion"], "rv-6")

    def test_change_after_full_get_is_rejected_on_wire_without_another_write(self):
        self.cloud.token = "fixture-only-token"
        for status in (409, 412):
            with self.subTest(status=status):
                before = BytesIO(json.dumps(self.raw_before).encode())
                conflict = HTTPError(f"https://{API_HOST}", status, "private upstream detail", None, BytesIO())
                with (
                    patch.object(self.cloud.opener, "open", side_effect=[before, conflict]) as opening,
                    self.assertRaisesRegex(RuntimeError, "conditional update") as caught,
                ):
                    self.cloud.set_traffic(self.before, self.promoted)
                self.assertNotIn("private upstream detail", str(caught.exception))
                self.assertNotIn("private fixture config", str(caught.exception))
                self.assertNotIn(self.cloud.token, str(caught.exception))
                self.assertEqual(opening.call_count, 2)
                read, write = [entry.args[0] for entry in opening.call_args_list]
                self.assertEqual((read.get_method(), write.get_method()), ("GET", "PUT"))
                url = urlsplit(write.full_url)
                self.assertEqual((url.scheme, url.netloc, url.path, url.query), ("https", API_HOST, API_PATH, ""))
                self.assertEqual(json.loads(write.data)["metadata"]["resourceVersion"], "rv-6")

    def test_snapshot_normalizes_v1_identity_traffic_and_tag_uri_without_template(self):
        requested = [v1_target(None, 100, latest=True), v1_target(FOREIGN, 0, tag=DEBUG_TAG)]
        tag_uri = f"https://{DEBUG_TAG}---{SERVICE}-test.a.run.app"
        statuses = [v1_target(PREVIOUS, 100, latest=True), v1_target(FOREIGN, 0, tag=DEBUG_TAG, url=tag_uri)]
        raw = raw_service(6, requested=requested, statuses=statuses)
        with patch.object(self.cloud, "request", return_value=raw) as request:
            result = rollout.snapshot(self.cloud)
        request.assert_called_once()
        self.assertEqual(request.call_args.args, (SERVICE_PATH,))
        self.assertIsNone(request.call_args.kwargs.get("body"))
        self.assertEqual(result["name"], SERVICE_NAME)
        self.assertEqual(result["uid"], self.before["uid"])
        self.assertEqual((result["generation"], result["observedGeneration"], result["resourceVersion"]), ("6", "6", "rv-6"))
        self.assertEqual(result["latestCreatedRevision"], f"{SERVICE_NAME}/revisions/{CANDIDATE}")
        self.assertEqual(result["traffic"], [{"type": LATEST, "percent": 100}, target(FOREIGN, 0, tag=DEBUG_TAG)])
        self.assertEqual(rollout.serving_targets(result), [target(PREVIOUS, 100), target(FOREIGN, 0, tag=DEBUG_TAG)])
        self.assertEqual(result["trafficStatuses"][1]["uri"], tag_uri)
        self.assertNotIn("private fixture config", json.dumps(result))
        self.assertNotIn("template", result)


if __name__ == "__main__":
    unittest.main()
