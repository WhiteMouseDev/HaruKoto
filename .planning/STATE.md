---
gsd_state_version: 1.0
milestone: v1.0
milestone_name: milestone
status: executing
stopped_at: Phase 999.3 UI-SPEC approved
last_updated: "2026-03-30T01:58:04.143Z"
last_activity: 2026-03-30
progress:
  total_phases: 9
  completed_phases: 6
  total_plans: 17
  completed_plans: 17
  percent: 0
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-03-26)

**Core value:** 원어민이 학습 데이터를 쉽고 빠르게 검증·수정할 수 있어야 한다
**Current focus:** Phase 999.1 — tts-field-ui-improvement

## Current Position

Phase: 999.2
Plan: Not started
Status: Ready to execute
Last activity: 2026-03-30

Progress: [░░░░░░░░░░] 0%

## Performance Metrics

**Velocity:**

- Total plans completed: 0
- Average duration: —
- Total execution time: 0 hours

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| - | - | - | - |

**Recent Trend:**

- Last 5 plans: —
- Trend: —

*Updated after each plan completion*
| Phase 01-foundation P01 | 5m | 2 tasks | 34 files |
| Phase 01-foundation P03 | 5 | 2 tasks | 8 files |
| Phase 01-foundation P02 | 2m | 2 tasks | 7 files |
| Phase 01-foundation P04 | 15m | 1 tasks | 2 files |
| Phase 02-content-list-views P02 | 10m | 2 tasks | 11 files |
| Phase 02-content-list-views P01 | 10 | 2 tasks | 9 files |
| Phase 02-content-list-views P03 | 5m | 2 tasks | 14 files |
| Phase 03-content-editing-review-workflow P01 | 3m | 2 tasks | 8 files |
| Phase 03-content-editing-review-workflow P02 | 15m | 2 tasks | 2 files |
| Phase 03-content-editing-review-workflow P03 | 6m | 2 tasks | 18 files |
| Phase 04-tts-audio P01 | 5m | 2 tasks | 3 files |
| Phase 04-tts-audio P02 | 4m | 3 tasks | 13 files |
| Phase 05-reviewer-productivity P01 | 2m | 2 tasks | 4 files |
| Phase 05 P02 | 3m | 2 tasks | 10 files |
| Phase 05-reviewer-productivity P03 | 4m | 2 tasks | 13 files |
| Phase 999.1 P01 | 3m | 3 tasks | 3 files |

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.
Recent decisions affecting current work:

- [Pre-Phase 1]: next-intl without-routing mode (cookie-based locale, flat app/ dir) — Japanese primary, no URL segments
- [Pre-Phase 1]: Supabase app_metadata.reviewer claim for role gate — no Custom Access Token Hook needed at 1-3 user scale
- [Pre-Phase 1]: FastAPI TTS endpoint reused — new POST /api/v1/admin/tts/regenerate with require_admin_role dependency
- [Phase 01-foundation]: requireReviewer() uses getUser() not getSession() for live DB auth validation (AUTH-03)
- [Phase 01-foundation]: next-intl without-routing mode with NEXT_LOCALE cookie; ja default; no URL locale segments
- [Phase 01-foundation]: ja.json as IntlMessages TypeScript type source; missing translations surface as compile errors
- [Phase 01-foundation]: Header is async Server Component using getTranslations(); locale string passed from layout via getLocale()
- [Phase 01-foundation]: Native language labels hardcoded (日本語/한국어/English) in LocaleSwitcher — shown in own language regardless of UI locale
- [Phase 01-foundation]: middleware.ts removed: Next.js 16 forbids both middleware.ts and proxy.ts; proxy.ts is canonical per CLAUDE.md
- [Phase 01-foundation]: proxy.ts uses getUser() not getSession() for live DB auth validation — role revocation effective immediately on next request (AUTH-03)
- [Phase 01-foundation]: Non-reviewer authenticated users redirected to /login?error=access_denied — distinct error path from unauthenticated redirect
- [Phase 01-foundation]: Login form validates on submit only (no real-time validation) per D-03 UX decision
- [Phase 01-foundation]: Deploy from monorepo root (not apps/admin cwd) with rootDirectory=apps/admin via Vercel REST API — ensures workspace packages are included in upload
- [Phase 02-content-list-views]: FilterBar uses native <select> for dropdowns — simpler than DropdownMenu for non-interactive admin UI
- [Phase 02-content-list-views]: Sidebar bottom reuses existing LocaleSwitcher + LogoutButton — no duplication needed
- [Phase 02-content-list-views]: require_reviewer reads app_metadata.reviewer from JWT without DB role table — lightweight, matches pre-phase decision
- [Phase 02-content-list-views]: ConversationAdminItem.jlpt_level is always None — ConversationScenario has no jlpt_level column
- [Phase 02-content-list-views]: fetchAdminContent uses browser Supabase client getSession() for JWT — consistent with 'use client' pages
- [Phase 02-content-list-views]: useContentList maps URL params to API params in hook (not in page) — single source of truth
- [Phase 03-content-editing-review-workflow]: Manual Alembic migration (i9j0k1l2m3n4) used — autogenerate blocked by duplicate revision ID a1b2c3d4e5f6 cycle in existing migrations
- [Phase 03-content-editing-review-workflow]: by_alias=False in model_dump() ensures snake_case field names for ORM setattr(); real AuditLog instances used in test mocks for Pydantic model_validate compatibility
- [Phase 03-content-editing-review-workflow]: Quiz edit page uses searchParams type param to branch between cloze and sentence_arrange forms and API content type paths
- [Phase 03-content-editing-review-workflow]: ContentTable checkbox state is local useState — resets on page navigation; no global selection state needed at 1-3 user scale
- [Phase 04-tts-audio]: POST /tts/regenerate registered before wildcard GET /{content_type}/{item_id}/tts to prevent FastAPI treating 'tts' as content_type param
- [Phase 04-tts-audio]: CamelModel base used for AdminTtsResponse/AdminTtsRegenerateRequest — consistent with all existing admin schemas
- [Phase 04-tts-audio]: Lazy state initialization used for localStorage cooldown read — avoids react-hooks/set-state-in-effect lint error
- [Phase 04-tts-audio]: Snake_case TtsAudioResponse type matches FastAPI Pydantic JSON; hook remaps audio_url to audioUrl camelCase for components
- [Phase 05-reviewer-productivity]: GET /{content_type}/review-queue placed before /stats — prevents wildcard path conflict with FastAPI top-down matching
- [Phase 05-reviewer-productivity]: Quiz review-queue merges cloze + sentence_arrange in memory sorted by created_at ASC — avoids complex UNION SQL at 1-3 user scale
- [Phase 05]: NavBadge is a separate file (sidebar-badge.tsx) — importable without pulling in SidebarNavItem
- [Phase 05]: getBadgeCount and getStatsForKey both merge cloze+sentence_arrange for quiz key — same pattern in sidebar and dashboard
- [Phase 05-reviewer-productivity]: Queue state stored in URL params (queue=id1,id2,id3&qi=0) — no global state needed, survives page reload
- [Phase 05-reviewer-productivity]: Auto-advance uses setTimeout 800ms — gives reviewer time to read success toast before navigation
- [Phase 999.1]: playingField/confirmField as string|null instead of boolean flags enables per-row state tracking in TtsPlayer

### Pending Todos

None yet.

### Blockers/Concerns

- [Phase 3 risk]: Confirm review_status, review_note, reviewer_id columns do NOT already exist in schema before writing Alembic migration
- [Phase 4 risk]: Verify GCS harukoto-tts bucket CORS config before building audio playback
- [Phase 4 risk]: Check existing rate_limit.py pattern before designing TTS cooldown
- [Phase 1 risk]: Document reviewer provisioning flow (Supabase Dashboard vs. script) before first deploy

## Session Continuity

Last session: 2026-03-30T01:58:04.139Z
Stopped at: Phase 999.3 UI-SPEC approved
Resume file: .planning/phases/999.3-admin-ui-polish/999.3-UI-SPEC.md
