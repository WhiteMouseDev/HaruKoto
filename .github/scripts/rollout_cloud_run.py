"""Verify a staged HaruKoto API revision before routing production traffic."""

import json
import os
import subprocess
import sys
import time
from collections.abc import Callable
from pathlib import Path
from urllib.error import HTTPError
from urllib.request import urlopen


class PendingVerificationError(RuntimeError):
    """The staged or serving revision has not converged."""


class OpenAPIMismatchError(RuntimeError):
    """The endpoint did not serve the release contract."""


class CloudRun:
    def __init__(self, project: str, region: str, service: str) -> None:
        self.service = service
        self.options = [f"--project={project}", f"--region={region}", "--quiet"]

    def describe(self, resource: str, name: str) -> dict:
        response = subprocess.check_output(
            ["gcloud", "run", resource, "describe", name, *self.options, "--format=json"],
            text=True,
            timeout=30,
        )
        return json.loads(response)

    def set_traffic(self, traffic: dict[str, int]) -> None:
        assignments = ",".join(f"{revision}={percent}" for revision, percent in traffic.items())
        subprocess.run(
            [
                "gcloud",
                "run",
                "services",
                "update-traffic",
                self.service,
                *self.options,
                f"--to-revisions={assignments}",
                "--format=value(status.url)",
            ],
            check=True,
        )


def serving_traffic(service: dict) -> dict[str, int]:
    traffic: dict[str, int] = {}
    for entry in service["status"]["traffic"]:
        percent = entry.get("percent") or 0
        if percent > 0:
            revision = entry["revisionName"]
            traffic[revision] = traffic.get(revision, 0) + percent
    if sum(traffic.values()) != 100:
        raise RuntimeError("Cloud Run serving traffic does not add up to 100%")
    return traffic


def smoke(url: str, expected_schema: dict) -> None:
    if not url.startswith("https://"):
        raise RuntimeError("Cloud Run did not return an HTTPS URL")
    try:
        with urlopen(f"{url}/health", timeout=15) as response:
            if json.load(response) != {"status": "ok"}:
                raise RuntimeError(f"Health check failed at {url}")
        with urlopen(f"{url}/openapi.json", timeout=15) as response:
            if json.load(response) != expected_schema:
                raise OpenAPIMismatchError(f"OpenAPI does not match the release at {url}")
    except HTTPError as error:
        if error.code not in (404, 429) and error.code < 500:
            raise RuntimeError(f"Smoke request at {url} returned HTTP {error.code}") from error
        raise


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
    revision_name = candidate["revisionName"]

    def check() -> None:
        revision = cloud.describe("revisions", revision_name)
        status = revision.get("status", {})
        image = status.get("imageDigest")
        if revision["metadata"]["labels"].get("commit-sha") != expected_sha or (image and image != expected_image):
            raise RuntimeError(f"Cloud Run revision {revision_name} does not match the release image and commit")
        if not image:
            raise PendingVerificationError(f"Cloud Run has not resolved the image for {revision_name}")
        # Calling the tagged URL can start a cold candidate without changing serving traffic.
        smoke(candidate["url"], expected_schema)
        conditions = {entry["type"]: entry["status"] for entry in status.get("conditions", [])}
        if conditions.get("Ready") != "True" or conditions.get("ContainerHealthy") != "True":
            raise PendingVerificationError(f"Cloud Run revision {revision_name} is not ready and healthy")

    wait_for_verification(check)


def verify_serving(cloud: CloudRun, expected_traffic: dict[str, int], expected_schema: dict) -> None:
    def check() -> None:
        service = cloud.describe("services", cloud.service)
        if serving_traffic(service) != expected_traffic:
            raise PendingVerificationError("Cloud Run status does not show the verified revision at 100%")
        smoke(service["status"]["url"], expected_schema)

    # The service URL can briefly return the previous OpenAPI while traffic converges.
    wait_for_verification(check, allow_stale_schema=True)


def rollout(
    cloud: CloudRun,
    tag: str,
    expected_image: str,
    expected_sha: str,
    previous_traffic: dict[str, int],
    expected_schema: dict,
) -> None:
    service = cloud.describe("services", cloud.service)
    if serving_traffic(service) != previous_traffic:
        raise RuntimeError("Serving traffic changed while the candidate was deployed")
    candidates = [entry for entry in service["status"]["traffic"] if entry.get("tag") == tag]
    if len(candidates) != 1 or candidates[0].get("percent"):
        raise RuntimeError("Expected one tagged candidate with 0% serving traffic")
    candidate = candidates[0]
    revision_name = candidate["revisionName"]
    if revision_name in previous_traffic:
        raise RuntimeError("The candidate is already receiving serving traffic")

    verify_candidate(cloud, candidate, expected_image, expected_sha, expected_schema)

    current = cloud.describe("services", cloud.service)
    generation = current["metadata"]["generation"]
    if generation != service["metadata"]["generation"] or serving_traffic(current) != previous_traffic:
        raise RuntimeError("Cloud Run configuration changed during candidate verification")
    promoted_traffic = {revision_name: 100}
    try:
        cloud.set_traffic(promoted_traffic)
        verify_serving(cloud, promoted_traffic, expected_schema)
    except Exception:
        # Restore the old allocations only when this promotion is still the latest service change.
        try:
            failed = cloud.describe("services", cloud.service)
            requested = {
                entry.get("revisionName"): entry["percent"] for entry in failed["spec"]["traffic"] if (entry.get("percent") or 0) > 0
            }
            if failed["metadata"]["generation"] == generation + 1 and requested == promoted_traffic:
                cloud.set_traffic(previous_traffic)
                if serving_traffic(cloud.describe("services", cloud.service)) != previous_traffic:
                    raise RuntimeError("Could not verify restored traffic")
                print(f"Restored previous Cloud Run traffic: {previous_traffic}", file=sys.stderr)
            else:
                print("Cloud Run traffic was not restored automatically. Check current allocations.", file=sys.stderr)
        except Exception as rollback_error:
            print(f"Cloud Run traffic restoration could not be verified: {rollback_error}", file=sys.stderr)
        raise
    print(f"Cloud Run is serving {revision_name} at 100% with the expected OpenAPI.")


if __name__ == "__main__":
    cloud_run = CloudRun(os.environ["GCP_PROJECT_ID"], os.environ["CLOUD_RUN_REGION"], os.environ["CLOUD_RUN_SERVICE"])
    snapshot = json.loads(Path(sys.argv[1]).read_text())
    schema = json.loads(Path("apps/api/openapi/openapi.json").read_text())
    rollout(
        cloud_run,
        os.environ["CANDIDATE_TAG"],
        os.environ["CANDIDATE_IMAGE"],
        os.environ["GITHUB_SHA"],
        serving_traffic(snapshot),
        schema,
    )
