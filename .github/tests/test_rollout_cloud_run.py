import json
import sys
import unittest
from io import BytesIO
from pathlib import Path
from unittest.mock import Mock, call, patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
import rollout_cloud_run as rollout

OLD_TRAFFIC = {"old-primary": 75, "old-canary": 25}
PROMOTED = {"verified-revision": 100}
TAG = "verify-123-1"
TAG_URL = "https://verify-123-1---api.run.app"
PUBLIC_URL = "https://api.run.app"
SHA = "commit"
IMAGE = "api@sha256:digest"
SCHEMA = {"openapi": "3.1.0"}


def service(generation=5, traffic=OLD_TRAFFIC):
    entries = [{"revisionName": name, "percent": percent} for name, percent in traffic.items()]
    return {
        "metadata": {"generation": generation},
        "spec": {"traffic": entries},
        "status": {
            "url": PUBLIC_URL,
            "traffic": [*entries, {"revisionName": "verified-revision", "tag": TAG, "url": TAG_URL}],
        },
    }


def revision(image=IMAGE, healthy=True):
    return {
        "metadata": {"labels": {"commit-sha": SHA}},
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
        self.cloud = Mock(spec=rollout.CloudRun)
        self.cloud.service = "api"

    def run_rollout(self):
        rollout.rollout(self.cloud, TAG, IMAGE, SHA, OLD_TRAFFIC, SCHEMA)

    def test_candidate_is_smoked_before_promotion_and_public_url_is_checked_after(self):
        self.cloud.describe.side_effect = [service(), revision(), service(), service(6, PROMOTED)]
        with patch.object(rollout, "smoke") as smoke:
            sequence = Mock()
            sequence.attach_mock(smoke, "smoke")
            sequence.attach_mock(self.cloud.set_traffic, "set_traffic")
            self.run_rollout()
        self.assertEqual(sequence.mock_calls, [call.smoke(TAG_URL, SCHEMA), call.set_traffic(PROMOTED), call.smoke(PUBLIC_URL, SCHEMA)])

    def test_unverified_candidate_or_traffic_drift_does_not_promote(self):
        cases = [
            ("traffic changed during deploy", [service(6, PROMOTED)], None),
            ("digest mismatch", [service(), revision("other-image")], None),
            ("candidate is unhealthy", [service(), *[revision(healthy=False)] * 5], None),
            ("candidate schema mismatch", [service(), revision()], rollout.OpenAPIMismatchError("stale schema")),
            ("service changed after smoke", [service(), revision(), service(6)], None),
        ]
        for label, describe_results, smoke_error in cases:
            with (
                self.subTest(label=label),
                patch.object(rollout.time, "sleep"),
                patch.object(rollout, "smoke", side_effect=smoke_error),
                self.assertRaises(RuntimeError),
            ):
                self.cloud.describe.side_effect = describe_results
                self.run_rollout()
        self.cloud.set_traffic.assert_not_called()

    def test_cold_candidate_is_warmed_and_retried_before_promotion(self):
        self.cloud.describe.side_effect = [service(), revision(healthy=False), revision(), service(), service(6, PROMOTED)]
        with patch.object(rollout.time, "sleep") as sleep, patch.object(rollout, "smoke") as smoke:
            self.run_rollout()
        self.assertEqual(smoke.call_args_list, [call(TAG_URL, SCHEMA), call(TAG_URL, SCHEMA), call(PUBLIC_URL, SCHEMA)])
        sleep.assert_called_once()
        self.cloud.set_traffic.assert_called_once_with(PROMOTED)

    def test_failed_public_verification_restores_the_prior_split(self):
        promoted_service = service(6, PROMOTED)
        self.cloud.describe.side_effect = [service(), revision(), service(), promoted_service, service(7)]
        with (
            patch.object(rollout, "smoke"),
            patch.object(rollout, "verify_serving", side_effect=RuntimeError("stale public schema")),
            self.assertRaisesRegex(RuntimeError, "stale public schema"),
        ):
            self.run_rollout()
        self.assertEqual(self.cloud.set_traffic.call_args_list, [call(PROMOTED), call(OLD_TRAFFIC)])

    def test_failed_public_verification_does_not_revert_a_later_change(self):
        self.cloud.describe.side_effect = [service(), revision(), service(), service(7, {"operator-revision": 100})]
        with (
            patch.object(rollout, "smoke"),
            patch.object(rollout, "verify_serving", side_effect=RuntimeError("traffic changed")),
            self.assertRaisesRegex(RuntimeError, "traffic changed"),
        ):
            self.run_rollout()
        self.cloud.set_traffic.assert_called_once_with(PROMOTED)

    def test_public_check_retries_while_traffic_has_not_converged(self):
        self.cloud.describe.side_effect = [service(), service(6, PROMOTED)]
        with patch.object(rollout.time, "sleep") as sleep, patch.object(rollout, "smoke") as smoke:
            rollout.verify_serving(self.cloud, PROMOTED, SCHEMA)
        sleep.assert_called_once()
        smoke.assert_called_once_with(PUBLIC_URL, SCHEMA)

    def test_smoke_rejects_a_healthy_service_with_the_wrong_contract(self):
        responses = [BytesIO(b'{"status":"ok"}'), BytesIO(json.dumps({"openapi": "3.0.0"}).encode())]
        with patch.object(rollout, "urlopen", side_effect=responses), self.assertRaisesRegex(RuntimeError, "OpenAPI"):
            rollout.smoke(TAG_URL, SCHEMA)


if __name__ == "__main__":
    unittest.main()
