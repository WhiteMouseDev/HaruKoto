"""Verify a staged HaruKoto API revision before routing production traffic."""

import json
import os
import subprocess
import sys
import time
from collections.abc import Callable
from pathlib import Path
from urllib.error import HTTPError
from urllib.parse import urlencode
from urllib.request import HTTPRedirectHandler, Request, build_opener, urlopen

REVISION = "TRAFFIC_TARGET_ALLOCATION_TYPE_REVISION"
LATEST = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
SERVICE_FIELDS = (
    "name,uid,etag,generation,observedGeneration,reconciling,traffic,trafficStatuses,uri,latestCreatedRevision,terminalCondition(state)"
)


class PendingVerificationError(RuntimeError):
    """Cloud Run has not finished applying the requested change."""


class OpenAPIMismatchError(RuntimeError):
    """The endpoint did not serve the release contract."""


class RejectRedirects(HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


class CloudRun:
    def __init__(self, project: str, region: str, service: str) -> None:
        self.name = f"projects/{project}/locations/{region}/services/{service}"
        self.operation_prefix = f"projects/{project}/locations/{region}/operations/"
        self.options = [f"--project={project}", f"--region={region}", "--quiet"]
        self.opener = build_opener(RejectRedirects())
        self.token: str | None = None

    def request(self, path: str, *, query: dict | None = None, body: dict | None = None) -> dict:
        if self.token is None:
            self.token = subprocess.check_output(["gcloud", "auth", "print-access-token", "--quiet"], text=True, timeout=30).strip()
        query_string = f"?{urlencode(query)}" if query else ""
        request = Request(
            f"https://run.googleapis.com/v2/{path}{query_string}",
            data=json.dumps(body).encode() if body is not None else None,
            headers={"Authorization": f"Bearer {self.token}", "Content-Type": "application/json"},
            method="PATCH" if body is not None else "GET",
        )
        try:
            with self.opener.open(request, timeout=20) as result:
                return json.load(result)
        except HTTPError as error:
            if body is not None and error.code in (409, 412):
                raise RuntimeError("Cloud Run traffic changed before the conditional update") from None
            raise RuntimeError(f"Cloud Run Admin API returned HTTP {error.code}") from None

    def describe_service(self) -> dict:
        return self.request(self.name, query={"fields": SERVICE_FIELDS})

    def describe_revision(self, name: str) -> dict:
        response = subprocess.check_output(
            [
                "gcloud",
                "run",
                "revisions",
                "describe",
                name,
                *self.options,
                "--format=json(metadata.labels,status.conditions,status.imageDigest)",
            ],
            text=True,
            timeout=30,
        )
        return json.loads(response)

    def set_traffic(self, current: dict, traffic: list[dict]) -> dict:
        if current["name"] != self.name or not current.get("etag"):
            raise RuntimeError("Cloud Run service identity or update precondition is missing")
        operation = self.request(
            self.name,
            query={"updateMask": "traffic"},
            body={"name": self.name, "etag": current["etag"], "traffic": traffic},
        )
        name = operation.get("name", "")
        if name.rpartition("/")[0] + "/" != self.operation_prefix or not name.rpartition("/")[2]:
            raise RuntimeError("Cloud Run returned an unexpected operation name")
        deadline = time.monotonic() + 240
        while not operation.get("done"):
            if time.monotonic() >= deadline:
                raise RuntimeError("Cloud Run traffic operation did not finish. Check the live allocation.")
            time.sleep(3)
            operation = self.request(name)
        if "error" in operation:
            code = operation["error"].get("code")
            raise RuntimeError(f"Cloud Run traffic operation failed (code {code}). Check the live allocation.")
        result = operation.get("response", {})
        if result.get("name") != self.name or not result.get("etag") or not result.get("generation"):
            raise RuntimeError("Cloud Run operation did not return the updated service. Check the live allocation.")
        return result


def traffic_key(targets: list[dict]) -> list[tuple[str, str, int, str]]:
    return sorted((entry["type"], entry.get("revision", ""), entry.get("percent", 0), entry.get("tag", "")) for entry in targets)


def serving_targets(service: dict) -> list[dict]:
    # The status carries the concrete revision even when the request used LATEST.
    targets = [
        {"type": REVISION, "revision": entry["revision"], "percent": entry.get("percent", 0)}
        | ({"tag": entry["tag"]} if entry.get("tag") else {})
        for entry in service["trafficStatuses"]
    ]
    if sum(target.get("percent", 0) > 0 for target in targets) != 1 or sum(target["percent"] for target in targets) != 100:
        raise RuntimeError("Automatic promotion requires one revision serving 100% of traffic")
    return targets


def require_ready(service: dict, *, allow_failed: bool = False) -> None:
    if (
        service.get("reconciling")
        or service.get("generation") != service.get("observedGeneration")
        or (not allow_failed and service["terminalCondition"]["state"] != "CONDITION_SUCCEEDED")
    ):
        raise PendingVerificationError("Cloud Run service has not reconciled")
    if not service.get("etag") or not service.get("generation"):
        raise RuntimeError("Cloud Run service generation or etag is missing")


def snapshot(cloud: CloudRun) -> dict:
    service = cloud.describe_service()
    require_ready(service)
    serving_targets(service)
    if any(entry["type"] == LATEST and entry.get("tag") for entry in service["traffic"]):
        raise RuntimeError("Automatic promotion cannot preserve a tag configured to follow LATEST")
    return service


def smoke(url: str, expected_schema: dict) -> None:
    if not url.startswith("https://"):
        raise RuntimeError("Cloud Run did not return an HTTPS URL")
    for path, expected in (("/health", {"status": "ok"}), ("/openapi.json", expected_schema)):
        with urlopen(f"{url}{path}", timeout=15) as response:
            if json.load(response) != expected:
                if path == "/openapi.json":
                    raise OpenAPIMismatchError("OpenAPI does not match the release")
                raise PendingVerificationError("Health check did not return the expected response")


def wait_for_verification(check: Callable[[], None], *, allow_stale_schema: bool = False) -> None:
    for attempt in range(5):
        try:
            check()
            return
        except (OSError, PendingVerificationError, OpenAPIMismatchError, subprocess.SubprocessError) as error:
            if attempt == 4 or (isinstance(error, OpenAPIMismatchError) and not allow_stale_schema):
                raise
            time.sleep(3)


def verify_candidate(cloud: CloudRun, candidate: dict, expected_image: str, expected_sha: str, expected_schema: dict) -> None:
    revision_name = candidate["revision"]

    def check() -> None:
        revision = cloud.describe_revision(revision_name)
        status = revision["status"]
        image = status.get("imageDigest")
        if revision["metadata"]["labels"].get("commit-sha") != expected_sha or (image and image != expected_image):
            raise RuntimeError("Cloud Run candidate does not match the verified image and commit")
        if not image:
            raise PendingVerificationError("Cloud Run has not resolved the candidate image")
        smoke(candidate["uri"], expected_schema)
        conditions = {entry["type"]: entry["status"] for entry in status.get("conditions", [])}
        if conditions.get("Ready") != "True" or conditions.get("ContainerHealthy") != "True":
            raise PendingVerificationError("Cloud Run candidate is not ready and healthy")

    wait_for_verification(check)


def verify_serving(cloud: CloudRun, traffic: list[dict], expected_schema: dict | None) -> None:
    def check() -> None:
        service = cloud.describe_service()
        require_ready(service)
        expected = traffic_key(traffic)
        if traffic_key(service["traffic"]) != expected or traffic_key(serving_targets(service)) != expected:
            raise PendingVerificationError("Cloud Run requested or serving traffic differs from the verified allocation")
        if expected_schema is not None:
            smoke(service["uri"], expected_schema)

    # The public endpoint may briefly return the previous schema during propagation.
    wait_for_verification(check, allow_stale_schema=True)


def rollout(
    cloud: CloudRun,
    tag: str,
    expected_image: str,
    expected_sha: str,
    before: dict,
    expected_schema: dict,
) -> None:
    service = cloud.describe_service()
    require_ready(service)
    previous = serving_targets(before)
    candidates = [entry for entry in service["trafficStatuses"] if entry.get("tag") == tag]
    if len(candidates) != 1 or candidates[0].get("percent"):
        raise RuntimeError("Expected one tagged candidate with 0% serving traffic")
    candidate = candidates[0]
    revision = candidate["revision"]
    if service["latestCreatedRevision"] != f"{service['name']}/revisions/{revision}":
        raise RuntimeError("Cloud Run created a newer candidate")
    prior_routes = [entry for entry in service["traffic"] if entry.get("tag") != tag]
    if (
        service["uid"] != before["uid"]
        or int(service["generation"]) != int(before["generation"]) + 1
        or traffic_key(prior_routes) != traffic_key(previous)
        or traffic_key([entry for entry in serving_targets(service) if entry.get("tag") != tag]) != traffic_key(previous)
    ):
        raise RuntimeError("Cloud Run configuration or traffic changed while deploying the candidate")

    verify_candidate(cloud, candidate, expected_image, expected_sha, expected_schema)
    current = cloud.describe_service()
    require_ready(current)
    if (current["uid"], current["etag"]) != (service["uid"], service["etag"]):
        raise RuntimeError("Cloud Run configuration changed during candidate verification")

    # Keep the previous named endpoints, even though they receive no normal traffic.
    promoted = [{"type": REVISION, "revision": revision, "percent": 100}]
    promoted.extend(entry | {"percent": 0} for entry in previous if entry.get("tag"))
    applied = cloud.set_traffic(current, promoted)
    try:
        verify_serving(cloud, promoted, expected_schema)
    except Exception:
        try:
            failed = cloud.describe_service()
            if (
                failed["uid"] != current["uid"]
                or failed["generation"] != applied["generation"]
                or failed["etag"] != applied["etag"]
                or traffic_key(failed["traffic"]) != traffic_key(promoted)
            ):
                raise RuntimeError("Cloud Run allocation changed after promotion. Check the current traffic.")
            cloud.set_traffic(failed, previous)
            verify_serving(cloud, previous, None)
            print("Restored and verified previous Cloud Run traffic.", file=sys.stderr)
        except Exception as rollback_error:
            print(f"Cloud Run traffic restoration could not be verified: {rollback_error}", file=sys.stderr)
        raise
    print(f"Cloud Run is serving {revision} at 100% with the expected OpenAPI.")


def remove_candidate_tag(cloud: CloudRun, tag: str) -> None:
    service = cloud.describe_service()
    traffic = service["traffic"]
    if any(entry.get("tag") == tag for entry in traffic):
        require_ready(service, allow_failed=True)
        if any(entry.get("tag") == tag and entry.get("percent") for entry in traffic):
            raise RuntimeError("The candidate tag now receives traffic. Check the current allocation.")
        remaining = [entry for entry in traffic if entry.get("tag") != tag]
        cloud.set_traffic(service, remaining)


def main() -> None:
    cloud = CloudRun(os.environ["GCP_PROJECT_ID"], os.environ["CLOUD_RUN_REGION"], os.environ["CLOUD_RUN_SERVICE"])
    command = sys.argv[1]
    if command == "snapshot":
        Path(sys.argv[2]).write_text(json.dumps(snapshot(cloud)))
    elif command == "cleanup":
        remove_candidate_tag(cloud, os.environ["CANDIDATE_TAG"])
    elif command == "promote":
        rollout(
            cloud,
            os.environ["CANDIDATE_TAG"],
            os.environ["CANDIDATE_IMAGE"],
            os.environ["GITHUB_SHA"],
            json.loads(Path(sys.argv[2]).read_text()),
            json.loads(Path("apps/api/openapi/openapi.json").read_text()),
        )
    else:
        raise ValueError(f"Unknown rollout command: {command}")


if __name__ == "__main__":
    main()
