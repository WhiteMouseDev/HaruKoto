import json
import sys
import unittest
from copy import deepcopy
from io import BytesIO
from pathlib import Path
from unittest.mock import Mock, call, patch
from urllib.error import HTTPError
from urllib.parse import parse_qs, urlsplit

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
import rollout_cloud_run as rollout

PROJECT = "test-project"
REGION = "asia-northeast3"
SERVICE = "harukoto-api"
SERVICE_NAME = f"projects/{PROJECT}/locations/{REGION}/services/{SERVICE}"
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


def service(generation, requested, *, candidate_created=False, statuses=None, etag=None):
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
        "etag": etag if etag is not None else f"etag-{generation}",
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
        self.assertEqual(current["etag"], self.active["etag"])
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
        self.assertEqual(current["etag"], "etag-6")
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

    def test_missing_or_changed_etag_never_authorizes_promotion(self):
        for etag in (None, "changed-etag"):
            with self.subTest(etag=etag):
                changed = deepcopy(self.active)
                if etag is None:
                    del changed["etag"]
                else:
                    changed["etag"] = etag
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

    def test_promotion_patch_conflict_or_unknown_outcome_is_never_retried(self):
        for failure in (
            RuntimeError("etag conflict"),
            TimeoutError("PATCH response lost"),
        ):
            with self.subTest(failure=failure):
                self.cloud.set_traffic.reset_mock(side_effect=True)
                self.cloud.set_traffic.side_effect = failure
                with self.assertRaisesRegex(type(failure), str(failure)):
                    self.run_rollout()
                self.assertEqual(self.cloud.set_traffic.call_count, 1)

    def test_rolls_back_to_concrete_previous_revision_and_preserves_existing_tag(self):
        self.before = service(5, [{"type": LATEST, "percent": 100}, self.debug])

        def smoke(url, _schema):
            if url == PUBLIC_URL:
                raise rollout.OpenAPIMismatchError("stale public")

        self.smoke.side_effect = smoke
        with self.assertRaisesRegex(rollout.OpenAPIMismatchError, "stale public"):
            self.run_rollout()
        promotion, rollback = [item.args for item in self.cloud.set_traffic.call_args_list]
        self.assertEqual(promotion[0]["etag"], "etag-6")
        self.assertEqual(rollback[0]["etag"], "etag-7")
        self.assert_traffic(rollback[1], PREVIOUS)

    def test_does_not_rollback_when_operator_changed_generation_or_etag(self):
        for changed_field, field_value in (
            ("generation", "8"),
            ("etag", "operator-etag"),
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

    def test_rollback_patch_conflict_does_not_reapply_or_overwrite_foreign_state(self):
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
        raise RuntimeError("etag conflict")

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


class CloudRunTransportTests(unittest.TestCase):
    def setUp(self):
        self.cloud = rollout.CloudRun(PROJECT, REGION, SERVICE)
        self.before = service(6, [target(PREVIOUS, 100)], candidate_created=True)
        self.promoted = [target(CANDIDATE, 100)]
        self.applied = service(7, self.promoted, candidate_created=True)
        self.operation = f"projects/{PROJECT}/locations/{REGION}/operations/test-operation"

    def test_apply_sends_only_traffic_identity_and_etag_and_waits_for_done(self):
        self.before["template"] = {"contains": "not-part-of-the-patch"}
        responses = [
            {"name": self.operation},
            {"name": self.operation, "done": True, "response": self.applied},
        ]
        with (
            patch.object(self.cloud, "request", side_effect=responses) as request,
            patch.object(rollout.time, "sleep") as sleep,
        ):
            self.assertEqual(self.cloud.set_traffic(self.before, self.promoted), self.applied)

        self.assertEqual(
            request.call_args_list,
            [
                call(
                    SERVICE_NAME,
                    query={"updateMask": "traffic"},
                    body={
                        "name": SERVICE_NAME,
                        "etag": "etag-6",
                        "traffic": self.promoted,
                    },
                ),
                call(self.operation),
            ],
        )
        sleep.assert_called_once()

    def test_done_operation_error_reports_code_without_logging_error_body(self):
        result = {
            "name": self.operation,
            "done": True,
            "error": {"code": 10, "message": "private upstream detail"},
        }
        with (
            patch.object(self.cloud, "request", return_value=result) as request,
            self.assertRaisesRegex(RuntimeError, "code 10") as error,
        ):
            self.cloud.set_traffic(self.before, self.promoted)
        self.assertNotIn("private upstream detail", str(error.exception))
        request.assert_called_once()

    def test_timeout_is_uncertain_and_never_sends_a_second_write(self):
        with (
            patch.object(self.cloud, "request", return_value={"name": self.operation}) as request,
            patch.object(rollout.time, "monotonic", side_effect=[0, 999]),
            self.assertRaisesRegex(RuntimeError, "did not finish"),
        ):
            self.cloud.set_traffic(self.before, self.promoted)
        request.assert_called_once()

    def test_missing_precondition_is_rejected_before_any_request(self):
        del self.before["etag"]
        with (
            patch.object(self.cloud, "request") as request,
            self.assertRaisesRegex(RuntimeError, "precondition"),
        ):
            self.cloud.set_traffic(self.before, self.promoted)
        request.assert_not_called()

    def test_untrusted_operation_name_is_never_polled(self):
        for operation in (
            "https://example.invalid/operations/test",
            self.operation.replace(PROJECT, "other-project"),
        ):
            with (
                self.subTest(operation=operation),
                patch.object(self.cloud, "request", return_value={"name": operation}) as request,
                self.assertRaisesRegex(RuntimeError, "operation name"),
            ):
                self.cloud.set_traffic(self.before, self.promoted)
            request.assert_called_once()

    def test_stale_http_etag_is_not_retried_or_logged(self):
        self.cloud.token = "fixture-only-token"
        for status in (409, 412):
            with self.subTest(status=status):
                error = HTTPError(
                    "https://run.googleapis.com",
                    status,
                    "private upstream detail",
                    None,
                    BytesIO(),
                )
                with (
                    patch.object(self.cloud.opener, "open", side_effect=error) as opening,
                    self.assertRaisesRegex(RuntimeError, "conditional update") as raised,
                ):
                    self.cloud.set_traffic(self.before, self.promoted)
                self.assertNotIn("private upstream detail", str(raised.exception))
                self.assertNotIn(self.cloud.token, str(raised.exception))
                opening.assert_called_once()
                actual = opening.call_args.args[0]
                url = urlsplit(actual.full_url)
                self.assertEqual(
                    (url.scheme, url.netloc, url.path),
                    ("https", "run.googleapis.com", f"/v2/{SERVICE_NAME}"),
                )
                self.assertEqual(parse_qs(url.query), {"updateMask": ["traffic"]})
                self.assertEqual(actual.get_method(), "PATCH")
                self.assertEqual(
                    json.loads(actual.data),
                    {"name": SERVICE_NAME, "etag": "etag-6", "traffic": self.promoted},
                )

    def test_snapshot_requests_only_routing_and_identity_fields(self):
        with patch.object(self.cloud, "request", return_value=self.before) as request:
            self.assertEqual(rollout.snapshot(self.cloud), self.before)
        request.assert_called_once()
        args, kwargs = request.call_args
        self.assertEqual(args, (SERVICE_NAME,))
        self.assertEqual(set(kwargs), {"query"})
        fields = set(kwargs["query"]["fields"].split(","))
        self.assertTrue(
            {
                "name",
                "uid",
                "etag",
                "traffic",
                "trafficStatuses",
                "generation",
                "observedGeneration",
            }
            <= fields
        )
        self.assertTrue({"template", "annotations", "labels", "env"}.isdisjoint(fields))


if __name__ == "__main__":
    unittest.main()
