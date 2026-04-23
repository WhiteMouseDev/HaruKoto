#!/usr/bin/env python3
"""Validate mobile (Flutter) API contracts against the OpenAPI snapshot.

Two checks, ordered by the cost of a miss:

1. **Orphaned endpoints** — Dart repository / service files call HTTP paths
   that no longer exist in OpenAPI. This catches endpoint renames, deletions,
   and typos — the highest-pain drift class because it fails at runtime.

2. **Field drift** — Dart classes annotated `// OPENAPI_SCHEMA: <name>` whose
   fromJson field accesses don't match the current OpenAPI schema properties.
   Annotation is opt-in so bootstrapping is painless; unannotated models are
   reported as info so you can progressively tag high-risk ones.

Exit code 1 on any orphaned endpoint or field error. Warnings (info-level
field drift, unannotated models) never block CI.

Run:
    cd apps/api && uv run python scripts/validate_mobile_contracts.py
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[3]
OPENAPI_PATH = REPO_ROOT / "apps" / "api" / "openapi" / "openapi.json"
MOBILE_LIB = REPO_ROOT / "apps" / "mobile" / "lib"

# Dio base URL in mobile prepends /api/v1 (see apps/mobile/lib/core/network/network_base.dart).
# Every Dio call like `_dio.get('/quiz/incomplete')` actually hits `/api/v1/quiz/incomplete`.
MOBILE_BASE_PREFIX = "/api/v1"

# Match _dio.<method>(...args..., 'path', ...). Handles:
# - _dio.get('/path')                         (same line)
# - _dio.get<Map<String, dynamic>>('/path')   (typed generic, nested brackets)
# - _dio.get<T>(                              (multi-line — path on next line)
#       '/path',
#   )
# The [^(]*? (non-greedy, no open-paren) skips generic type params without
# caring about nested angle brackets.
_DIO_CALL_RE = re.compile(
    r"""_dio\.(?P<method>get|post|put|patch|delete)[^(]*?
        \(\s*['"](?P<path>/[^'"${}]*)['"]
    """,
    re.IGNORECASE | re.VERBOSE | re.DOTALL,
)

# Match `// OPENAPI_SCHEMA: SchemaName` followed by `class ClassName`.
_ANNOT_RE = re.compile(
    r"""//\s*OPENAPI_SCHEMA:\s*(?P<schema>\w+)\s*\n\s*class\s+(?P<cls>\w+)""",
    re.MULTILINE,
)

# Extract field names from fromJson bodies: json['fieldName'].
_FIELD_RE = re.compile(r"""json\[['"](?P<name>[^'"]+)['"]\]""")


def _rel(path: Path) -> str:
    try:
        return str(path.relative_to(REPO_ROOT))
    except ValueError:
        return str(path)


def _load_openapi() -> dict:
    return json.loads(OPENAPI_PATH.read_text())


def _extract_mobile_calls() -> list[tuple[str, str, Path, int]]:
    calls: list[tuple[str, str, Path, int]] = []
    for dart_file in MOBILE_LIB.rglob("*.dart"):
        text = dart_file.read_text(errors="ignore")
        for match in _DIO_CALL_RE.finditer(text):
            method = match.group("method").upper()
            path = MOBILE_BASE_PREFIX + match.group("path")
            line = text.count("\n", 0, match.start()) + 1
            calls.append((method, path, dart_file, line))
    return calls


def _normalize(path: str) -> str:
    """Normalize trailing slash for comparison. FastAPI treats `/x` and `/x/` as
    the same endpoint via 307 redirect, so we consider them equivalent here."""
    return path.rstrip("/") or "/"


def _paths_match(concrete: str, template: str) -> bool:
    """Return True if concrete path matches OpenAPI path template."""
    lhs = _normalize(concrete).split("/")
    rhs = _normalize(template).split("/")
    if len(lhs) != len(rhs):
        return False
    for part_c, part_t in zip(lhs, rhs, strict=True):
        if part_t.startswith("{") and part_t.endswith("}"):
            continue
        if part_c != part_t:
            return False
    return True


def _endpoint_exists(method: str, path: str, openapi: dict) -> bool:
    method_lc = method.lower()
    paths = openapi.get("paths", {}) or {}
    normalized_path = _normalize(path)
    # Fast path (with trailing-slash normalization)
    for candidate in (path, normalized_path, normalized_path + "/"):
        entry = paths.get(candidate)
        if entry and method_lc in entry:
            return True
    # Templated match
    return any(_paths_match(path, template) and method_lc in ops for template, ops in paths.items())


def _extract_annotated_models() -> list[tuple[Path, str, str, set[str]]]:
    """Return [(file, schema_name, class_name, field_names)]."""
    out: list[tuple[Path, str, str, set[str]]] = []
    for dart_file in MOBILE_LIB.rglob("*.dart"):
        text = dart_file.read_text(errors="ignore")
        for match in _ANNOT_RE.finditer(text):
            schema_name = match.group("schema")
            class_name = match.group("cls")
            # Capture up to the next class declaration or end of file (simple heuristic).
            start = match.end()
            next_class = re.search(r"\nclass\s+\w+", text[start:])
            end = start + next_class.start() if next_class else len(text)
            body = text[start:end]
            fields = set(_FIELD_RE.findall(body))
            out.append((dart_file, schema_name, class_name, fields))
    return out


def _compare_fields(schema_name: str, dart_fields: set[str], openapi: dict) -> list[tuple[str, str]]:
    """Return list of (level, message). level in {'error','warn','info'}."""
    schemas = (openapi.get("components") or {}).get("schemas") or {}
    schema = schemas.get(schema_name)
    if schema is None:
        return [("error", f"schema '{schema_name}' not found in OpenAPI (rename? deletion?)")]
    props = (schema.get("properties") or {}).keys()
    required = set(schema.get("required") or [])
    openapi_fields = set(props)
    messages: list[tuple[str, str]] = []
    for field in sorted(openapi_fields - dart_fields):
        level = "error" if field in required else "info"
        messages.append((level, f"dart model missing field: {field}"))
    for field in sorted(dart_fields - openapi_fields):
        messages.append(("warn", f"dart model has extra field not in OpenAPI: {field}"))
    return messages


def _collect(openapi: dict) -> tuple[list[dict], list[dict]]:
    """Return (orphaned_endpoints, field_issues) as plain dicts for JSON output."""
    orphaned: list[dict] = []
    for method, path, file, line in _extract_mobile_calls():
        if not _endpoint_exists(method, path, openapi):
            orphaned.append({"method": method, "path": path, "file": _rel(file), "line": line})

    field_issues: list[dict] = []
    for file, schema_name, class_name, dart_fields in _extract_annotated_models():
        for level, msg in _compare_fields(schema_name, dart_fields, openapi):
            field_issues.append(
                {
                    "level": level,
                    "schema": schema_name,
                    "class": class_name,
                    "file": _rel(file),
                    "message": msg,
                }
            )
    return orphaned, field_issues


def main() -> int:
    emit_json = "--json" in sys.argv[1:]

    if not OPENAPI_PATH.exists():
        print(f"ERROR: {OPENAPI_PATH} not found. Run export_openapi.py first.", file=sys.stderr)
        return 2
    if not MOBILE_LIB.exists():
        print(f"ERROR: {MOBILE_LIB} not found.", file=sys.stderr)
        return 2

    openapi = _load_openapi()
    orphaned, field_issues = _collect(openapi)
    error_field_issues = [i for i in field_issues if i["level"] == "error"]
    has_error = bool(orphaned) or bool(error_field_issues)

    if emit_json:
        json.dump(
            {
                "orphaned_endpoints": orphaned,
                "field_issues": field_issues,
                "has_error": has_error,
            },
            sys.stdout,
            indent=2,
        )
        sys.stdout.write("\n")
        return 1 if has_error else 0

    # Human-readable output
    print("=" * 72)
    print("Mobile ↔ OpenAPI Contract Drift Report")
    print("=" * 72)

    calls_total = len(_extract_mobile_calls())
    print(f"\n## Endpoint existence — scanned {calls_total} Dio call(s)")
    if orphaned:
        print(f"❌ {len(orphaned)} orphaned call(s):")
        for item in orphaned:
            print(f"   {item['method']} {item['path']}  ({item['file']}:{item['line']})")
        print("\n   Likely causes: endpoint renamed, deleted, or typo. Fix options:")
        print("   • If endpoint was renamed/moved: update the Dart call")
        print("   • If endpoint should still exist: backend-agent must restore it")
        print("\n   → file an escalation at .planning/escalations/ so the next session")
        print("     can triage this without re-discovering it.")
    else:
        print("✓ every Dio path matches an OpenAPI route")

    models = _extract_annotated_models()
    print(f"\n## Field drift — scanned {len(models)} annotated model(s)")
    if not models:
        print("ⓘ  no `// OPENAPI_SCHEMA: <Name>` annotations found")
        print("   enable field drift detection by adding the annotation above high-risk Dart classes")
    elif field_issues:
        grouped: dict[tuple[str, str, str], list[dict]] = {}
        for issue in field_issues:
            grouped.setdefault((issue["class"], issue["schema"], issue["file"]), []).append(issue)
        for (cls, schema_name, file), items in grouped.items():
            print(f"\n   {cls}  ←→  {schema_name}  ({file})")
            for issue in items:
                marker = {"error": "❌", "warn": "⚠️ ", "info": "ⓘ "}[issue["level"]]
                print(f"     {marker} [{issue['level']:<5}] {issue['message']}")
        if error_field_issues:
            print(f"\n   ❌ {len(error_field_issues)} error-level field drift(s) across annotated models")
    else:
        print("✓ all annotated models match their OpenAPI schema")

    print()
    return 1 if has_error else 0


if __name__ == "__main__":
    sys.exit(main())
