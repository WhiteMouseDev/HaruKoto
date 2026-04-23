#!/usr/bin/env python3
"""Validate admin (Next.js reviewer app) API contracts against the OpenAPI snapshot.

Two checks, ordered by the cost of a miss:

1. **Orphaned endpoints** — TypeScript files call HTTP paths (via fetch/URL with
   template literals referencing ``${API_URL}``) that no longer exist in OpenAPI.
   Catches endpoint renames, deletions, and typos like the quiz audit-logs
   segment-count drift uncovered in the 2026-04-23 admin audit.

2. **Enum value drift** — a hardcoded string array or Record annotated
   ``// OPENAPI_ENUM: <SchemaName>`` whose keys/members diverge from the
   OpenAPI enum. Catches the ScenarioCategory 8-vs-4 style drift.

Exit code 1 on any orphaned endpoint or enum drift. Unannotated enums are
reported as info and never block CI.

Run:
    cd apps/api && uv run python scripts/validate_admin_contracts.py
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[3]
OPENAPI_PATH = REPO_ROOT / "apps" / "api" / "openapi" / "openapi.json"
ADMIN_SRC = REPO_ROOT / "apps" / "admin" / "src"

# Match a TypeScript template literal referencing API_URL that points into the
# FastAPI backend, e.g. `${API_URL}/api/v1/admin/content/${type}`. Everything up
# to the closing backtick is captured as the raw path (still contains ${var}
# placeholders which the normalization step converts to OpenAPI-style {var}).
_ADMIN_CALL_RE = re.compile(
    r"`\$\{API_URL\}(?P<path>/api/v1[^`]*?)`",
    re.MULTILINE,
)

# Match explicit method override in a fetch/axios options object, e.g.
# fetch(url, { method: 'PATCH', ... }). Default is GET when unseen.
_METHOD_RE = re.compile(r"""method:\s*['"](?P<method>GET|POST|PUT|PATCH|DELETE)['"]""")

# Annotation pattern for enum-value checks. The object/array directly after the
# annotation line provides the enum values that must mirror OpenAPI. Capture up
# to the first statement terminator ``;`` — covers both ``Record<X, true>`` style
# (ends in ``};``) and ``['A','B'] as const;`` style, while skipping TS generics
# (``components['schemas']['X']``) that contain ``]`` but no ``;``.
_ENUM_ANNOT_RE = re.compile(
    r"""//\s*OPENAPI_ENUM:\s*(?P<schema>\w+)\n
        (?P<body>(?:[^;]|\n){0,3000}?;)""",
    re.MULTILINE | re.VERBOSE,
)
# Capture enum values written either as quoted strings (``['TRAVEL', 'DAILY']``)
# or as bare Record keys (``TRAVEL: true,``). Both forms are idiomatic TS.
_ENUM_STRING_RE = re.compile(r"""['"](?P<value>[A-Z][A-Z0-9_]+)['"]""")
_ENUM_KEY_RE = re.compile(r"""^\s*(?P<value>[A-Z][A-Z0-9_]+)\s*:""", re.MULTILINE)


def _rel(path: Path) -> str:
    try:
        return str(path.relative_to(REPO_ROOT))
    except ValueError:
        return str(path)


def _load_openapi() -> dict:
    return json.loads(OPENAPI_PATH.read_text())


def _normalize_template(path: str) -> str:
    """Convert TS ${var} placeholders into OpenAPI-style {var}."""
    return re.sub(r"\$\{([^}]+)\}", r"{\1}", path)


def _guess_method(text: str, match_end: int) -> str:
    """Scan forward from the path literal for a ``method:`` key.

    Defaults to GET when no explicit method is specified (fetch default). To
    prevent method bleed across functions, we stop at the next ``function``
    declaration: if a method literal only appears past the boundary, the
    current call has no method and is GET.
    """
    window = text[match_end : match_end + 800]
    fn_boundary = re.search(r"\n(?:export\s+)?(?:async\s+)?function\s+\w+", window)
    method_match = _METHOD_RE.search(window)
    if method_match and (fn_boundary is None or method_match.start() < fn_boundary.start()):
        return method_match.group("method")
    return "GET"


def _extract_admin_calls() -> list[tuple[str, str, Path, int]]:
    calls: list[tuple[str, str, Path, int]] = []
    for ts_file in ADMIN_SRC.rglob("*.ts"):
        if "__tests__" in ts_file.parts or "node_modules" in ts_file.parts:
            continue
        text = ts_file.read_text(errors="ignore")
        for match in _ADMIN_CALL_RE.finditer(text):
            raw_path = match.group("path")
            path = _normalize_template(raw_path)
            method = _guess_method(text, match.end())
            line = text.count("\n", 0, match.start()) + 1
            calls.append((method, path, ts_file, line))
    return calls


def _path_segments_match(concrete: str, template: str) -> bool:
    """Segment-aware match. Either side may contain {placeholder}: admin paths
    have ``${var}``-derived placeholders (unknown at static-analysis time), and
    OpenAPI routes have route-parameter placeholders. A placeholder on either
    side matches the opposite segment so long as segment counts align."""
    lhs = concrete.rstrip("/").split("/")
    rhs = template.rstrip("/").split("/")
    if len(lhs) != len(rhs):
        return False
    for part_c, part_t in zip(lhs, rhs, strict=True):
        c_is_placeholder = part_c.startswith("{") and part_c.endswith("}")
        t_is_placeholder = part_t.startswith("{") and part_t.endswith("}")
        if c_is_placeholder or t_is_placeholder:
            continue
        if part_c != part_t:
            return False
    return True


def _endpoint_exists(method: str, path: str, openapi: dict) -> bool:
    method_lc = method.lower()
    paths = openapi.get("paths", {}) or {}
    # Exact match (handles trailing-slash variants)
    for candidate in (path, path.rstrip("/"), path.rstrip("/") + "/"):
        entry = paths.get(candidate)
        if entry and method_lc in entry:
            return True
    # Templated match — both sides may have {placeholder} segments since the admin
    # path has been normalized to OpenAPI-style braces.
    return any(_path_segments_match(path, template) and method_lc in ops for template, ops in paths.items())


def _extract_annotated_enums() -> list[tuple[Path, str, set[str], int]]:
    """Return [(file, schema_name, values, line)]."""
    out: list[tuple[Path, str, set[str], int]] = []
    for ts_file in ADMIN_SRC.rglob("*.ts*"):
        if "__tests__" in ts_file.parts or "node_modules" in ts_file.parts:
            continue
        text = ts_file.read_text(errors="ignore")
        for match in _ENUM_ANNOT_RE.finditer(text):
            schema = match.group("schema")
            body = match.group("body")
            values = {m.group("value") for m in _ENUM_STRING_RE.finditer(body)}
            values |= {m.group("value") for m in _ENUM_KEY_RE.finditer(body)}
            line = text.count("\n", 0, match.start()) + 1
            out.append((ts_file, schema, values, line))
    return out


def _compare_enum(schema_name: str, admin_values: set[str], openapi: dict) -> list[tuple[str, str]]:
    schemas = (openapi.get("components") or {}).get("schemas") or {}
    schema = schemas.get(schema_name)
    if schema is None:
        return [("error", f"enum schema '{schema_name}' not found in OpenAPI")]
    api_values = set(schema.get("enum") or [])
    if not api_values:
        return [("error", f"schema '{schema_name}' has no enum values in OpenAPI")]
    messages: list[tuple[str, str]] = []
    for value in sorted(admin_values - api_values):
        messages.append(("error", f"admin has value '{value}' not in OpenAPI enum"))
    for value in sorted(api_values - admin_values):
        messages.append(("error", f"admin missing OpenAPI enum value '{value}'"))
    return messages


def _collect(openapi: dict) -> tuple[list[dict], list[dict]]:
    orphaned: list[dict] = []
    for method, path, file, line in _extract_admin_calls():
        if not _endpoint_exists(method, path, openapi):
            orphaned.append({"method": method, "path": path, "file": _rel(file), "line": line})

    enum_issues: list[dict] = []
    for file, schema, values, line in _extract_annotated_enums():
        for level, msg in _compare_enum(schema, values, openapi):
            enum_issues.append(
                {
                    "level": level,
                    "schema": schema,
                    "file": _rel(file),
                    "line": line,
                    "message": msg,
                }
            )
    return orphaned, enum_issues


def main() -> int:
    emit_json = "--json" in sys.argv[1:]

    if not OPENAPI_PATH.exists():
        print(f"ERROR: {OPENAPI_PATH} not found. Run export_openapi.py first.", file=sys.stderr)
        return 2
    if not ADMIN_SRC.exists():
        print(f"ERROR: {ADMIN_SRC} not found.", file=sys.stderr)
        return 2

    openapi = _load_openapi()
    orphaned, enum_issues = _collect(openapi)
    error_enum_issues = [i for i in enum_issues if i["level"] == "error"]
    has_error = bool(orphaned) or bool(error_enum_issues)

    if emit_json:
        json.dump(
            {
                "orphaned_endpoints": orphaned,
                "enum_issues": enum_issues,
                "has_error": has_error,
            },
            sys.stdout,
            indent=2,
        )
        sys.stdout.write("\n")
        return 1 if has_error else 0

    # Human-readable output
    print("=" * 72)
    print("Admin ↔ OpenAPI Contract Drift Report")
    print("=" * 72)

    calls_total = len(_extract_admin_calls())
    print(f"\n## Endpoint existence — scanned {calls_total} admin call(s)")
    if orphaned:
        print(f"❌ {len(orphaned)} orphaned call(s):")
        for item in orphaned:
            print(f"   {item['method']} {item['path']}  ({item['file']}:{item['line']})")
        print("\n   Likely causes: endpoint renamed, deleted, or typo. Fix options:")
        print("   • If endpoint was renamed/moved: update the TS call")
        print("   • If endpoint should still exist: backend-agent must restore it")
        print("\n   → file an escalation at .planning/escalations/ so the next session")
        print("     can triage this without re-discovering it.")
    else:
        print("✓ every admin path matches an OpenAPI route")

    annots = _extract_annotated_enums()
    print(f"\n## Enum value drift — scanned {len(annots)} annotated enum(s)")
    if not annots:
        print("ⓘ  no `// OPENAPI_ENUM: <Name>` annotations found")
        print("   enable enum drift detection by adding the annotation above high-risk arrays/Records")
    elif enum_issues:
        grouped: dict[tuple[str, str, int], list[dict]] = {}
        for issue in enum_issues:
            grouped.setdefault((issue["schema"], issue["file"], issue["line"]), []).append(issue)
        for (schema, file, line), items in grouped.items():
            print(f"\n   {schema}  ({file}:{line})")
            for issue in items:
                marker = {"error": "❌", "warn": "⚠️ ", "info": "ⓘ "}[issue["level"]]
                print(f"     {marker} [{issue['level']:<5}] {issue['message']}")
        if error_enum_issues:
            print(f"\n   ❌ {len(error_enum_issues)} enum drift(s) across annotated enums")
    else:
        print("✓ all annotated enums match their OpenAPI schema")

    print()
    return 1 if has_error else 0


if __name__ == "__main__":
    sys.exit(main())
