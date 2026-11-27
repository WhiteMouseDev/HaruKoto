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
    "metadata(name,uid,generation,resourceVersion),spec(traffic),"
    "status(traffic,url,observedGeneration,latestCreatedRevisionName,conditions(type,status))"
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
        self.service = service
        self.service_path = f"namespaces/{project}/services/{service}"
        self.endpoint = f"https://{region}-run.googleapis.com/apis/serving.knative.dev/v1"
        self.options = [f"--project={project}", f"--region={region}", "--quiet"]
        self.opener = build_opener(RejectRedirects())
        self.token: str | None = None

    def request(self, path: str, *, query: dict | None = None, body: dict | None = None) -> dict:
        if self.token is None:
            self.token = subprocess.check_output(["gcloud", "auth", "print-access-token", "--quiet"], text=True, timeout=30).strip()
        query_string = f"?{urlencode(query)}" if query else ""
        request = Request(
            f"{self.endpoint}/{path}{query_string}",
            data=json.dumps(body).encode() if body is not None else None,
            headers={"Authorization": f"Bearer {self.token}", "Content-Type": "application/json"},
            method="PUT" if body is not None else "GET",
        )
        try:
            with self.opener.open(request, timeout=20) as result:
                return json.load(result)
        except HTTPError as error:
            if body is not None and error.code in (409, 412):
                raise RuntimeError("Cloud Run traffic changed before the conditional update") from None
            raise RuntimeError(f"Cloud Run Admin API returned HTTP {error.code}") from None

    def describe_service(self) -> dict:
        resource = self.request(self.service_path, query={"fields": SERVICE_FIELDS})
        return self.service_state(resource)

    def service_state(self, resource: dict) -> dict:
        metadata = resource["metadata"]
        if metadata["name"] != self.service:
            raise RuntimeError("Cloud Run returned the wrong service")
        status = resource.get("status", {})
        conditions = {entry["type"]: entry["status"] for entry in status.get("conditions", [])}
        ready = conditions.get("Ready")
        created = status.get("latestCreatedRevisionName")
        return {
            "name": self.name,
            "uid": metadata["uid"],
            "generation": str(metadata["generation"]),
            "observedGeneration": str(status.get("observedGeneration", "")),
            "resourceVersion": metadata.get("resourceVersion"),
            "reconciling": ready not in ("True", "False"),
            "terminalCondition": {"state": "CONDITION_SUCCEEDED" if ready == "True" else "CONDITION_FAILED"},
            "latestCreatedRevision": f"{self.name}/revisions/{created}" if created else None,
            "uri": status.get("url"),
            "traffic": [from_cloud_run_target(entry) for entry in resource["spec"].get("traffic", [])],
            "trafficStatuses": [from_cloud_run_target(entry) for entry in status.get("traffic", [])],
        }

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
        if current["name"] != self.name or not current.get("resourceVersion"):
            raise RuntimeError("Cloud Run service identity or update precondition is missing")

        # v1 ReplaceService honors resourceVersion. Read the full service only
        # here to preserve its template and metadata. Never print or save it.
        raw = self.request(self.service_path)
        metadata = raw["metadata"]
        if (
            metadata["name"] != self.service
            or metadata["uid"] != current["uid"]
            or metadata["resourceVersion"] != current["resourceVersion"]
        ):
            raise RuntimeError("Cloud Run traffic changed before the conditional update")
        raw.pop("status", None)
        raw["spec"]["traffic"] = [to_cloud_run_target(entry) for entry in traffic]
        applied = self.service_state(self.request(self.service_path, body=raw))
        if (
            applied["uid"] != current["uid"]
            or int(applied["generation"]) != int(current["generation"]) + 1
            or traffic_key(applied["traffic"]) != traffic_key(traffic)
        ):
            raise RuntimeError("Cloud Run did not confirm the requested allocation. Check the live traffic.")
        return applied


def from_cloud_run_target(entry: dict) -> dict:
    target = {"type": LATEST if entry.get("latestRevision") else REVISION, "percent": entry.get("percent", 0)}
    for source, destination in (("revisionName", "revision"), ("tag", "tag"), ("url", "uri")):
        if entry.get(source):
            target[destination] = entry[source]
    return target


def to_cloud_run_target(entry: dict) -> dict:
    target = {"percent": entry.get("percent", 0)}
    if entry["type"] == LATEST:
        target["latestRevision"] = True
    else:
        target["revisionName"] = entry["revision"]
    if entry.get("tag"):
        target["tag"] = entry["tag"]
    return target


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
    if not service.get("resourceVersion") or not service.get("generation"):
        raise RuntimeError("Cloud Run service generation or resourceVersion is missing")


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


def wait_for_verification(check: Callable[[], None], *, allow_stale_schema: bool = False, attempts: int = 5) -> None:
    for attempt in range(attempts):
        try:
            check()
            return
        except (OSError, PendingVerificationError, OpenAPIMismatchError, subprocess.SubprocessError) as error:
            if attempt == attempts - 1 or (isinstance(error, OpenAPIMismatchError) and not allow_stale_schema):
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
    wait_for_verification(check, allow_stale_schema=True, attempts=12)


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
    if (
        current["uid"] != service["uid"]
        or current["generation"] != service["generation"]
        or traffic_key(current["traffic"]) != traffic_key(service["traffic"])
    ):
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
