# Feature Landscape: HaruKoto Admin — Learning Data Review Tool

**Domain:** Content management/review admin for language learning data (vocabulary, grammar, quizzes, conversation scenarios)
**Target users:** 1-3 non-developer Japanese native speakers (reviewers) + Korean developer (admin)
**Researched:** 2026-03-26
**Overall confidence:** HIGH (core patterns well-established; specific TTS workflow patterns extrapolated from adjacent domains)

---

## Table Stakes

Features users expect. Missing = product feels broken or unusable.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Data list view with search | Reviewers need to locate specific items fast; no search = impossible to navigate 100s of entries | Low | Server-side search on Japanese text fields (word, reading, meaning). Must handle hiragana/katakana/kanji input. |
| Column filter by status | Reviewers focus their session on "needs review" or "pending" items; without filter they wade through everything | Low | Filter by: status, content type, chapter/lesson, JLPT level |
| Sortable columns | Natural mental model from spreadsheets; reviewers are non-developers used to spreadsheet tools | Low | Sort by: created_at, updated_at, status, chapter order |
| Pagination (or virtual scroll) | Lists of 500+ vocabulary entries are unusable without it | Low | 20-50 rows/page default; rows-per-page selector. Server-side pagination. |
| Inline edit for short fields | Reading, meaning, example sentence — reviewers expect to click and fix, not open a modal for every small correction | Medium | Optimistic update + explicit save confirmation. Not for all fields. |
| Full edit form (modal or page) | Complex fields (quiz options, conversation turns) need dedicated forms, not inline cells | Medium | React Hook Form + Zod validation matching existing schema constraints |
| Status workflow (needs_review / approved / rejected) | Core review loop: reviewer marks each item — without explicit status the tool has no output | Low | 3-state minimum: `needs_review` → `approved` / `rejected`. DB column addition via Alembic. |
| TTS audio playback | Reviewers listen to audio quality before approving; without playback the review is incomplete | Low | HTML `<audio>` with pre-signed GCS URL or streamed proxy. Must work without download. |
| TTS regeneration trigger | Audio may be wrong pronunciation or wrong voice; reviewers need to request re-generation | Medium | Calls existing FastAPI TTS endpoint. Show spinner, replace audio on success. One item at a time initially. |
| Role-based access (reviewer only) | Reviewers must not see user accounts, billing, or other admin-only areas | Medium | Supabase Auth + `reviewer` role claim. Middleware-protected routes in Next.js. New role requires Alembic migration or Supabase function. |
| Multilingual UI (Japanese primary, Korean secondary) | Japanese native speakers are the primary users; English-only UI creates friction and errors | Medium | next-intl with `ja` / `ko` / `en` locales. Locale switcher in header. Persist choice in localStorage. |
| Toast / inline feedback on save | Non-developers cannot interpret HTTP errors; they need "Saved" or "Failed — try again" in plain language | Low | sonner (already in web stack). |
| Unsaved-changes guard | Non-developers accidentally close tabs; losing edits erodes trust immediately | Low | `beforeunload` event + router leave guard in Next.js App Router. |

---

## Differentiators

Features that set this tool apart from a generic CMS. Not expected, but significantly increase reviewer velocity.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Review queue (next/previous navigation) | Reviewers work through a batch sequentially; individual list navigation is slow. A "review mode" with next/prev arrows and keyboard shortcuts cuts session time in half. | Medium | URL-based queue state (`?queue=needs_review&index=3`). Keyboard: `→` next, `←` prev, `a` approve, `r` reject. |
| Bulk status change | Approving 50 correct items one-by-one is the #1 productivity killer. Checkbox multi-select + bulk approve/reject saves hours per session. | Medium | Checkbox column, floating action bar on selection, confirmation dialog for bulk reject. PatternFly bulk-selection pattern. |
| Review comment / annotation | When rejecting, reviewers need to leave a note explaining what's wrong (for the developer to fix). Without this, rejection means nothing. | Medium | Optional text field on reject/flag action. Stored in `review_note` column. Not a full commenting thread — single latest note per item is sufficient. |
| Change history (field-level) | Reviewers will accidentally overwrite correct data. A simple "last changed by / when / from → to" log for key fields restores trust. | Medium | PostgreSQL trigger or application-level audit log table. Show last 5 changes per item in a collapsible panel. Do NOT build full Git-style diff — overkill for 1-3 users. |
| Content-type dashboard summary | A single overview screen showing "Vocabulary: 450 approved / 32 needs review / 8 rejected" gives reviewers clarity on session progress and priority. | Low | Aggregate query on status counts per content type. Static refresh (no real-time push needed at 1-3 users). |
| TTS batch regeneration (filtered set) | After a voice model update, all items in a chapter need re-generation. Triggering 80 items one-by-one is unusable. | High | Scoped batch: select all in current filter → queue regeneration jobs. Requires job queue awareness (show progress). Defer to Phase 2. |
| Keyboard shortcut help overlay | Reviewers who become power users (even non-developers) dramatically speed up with shortcuts. A `?` overlay removes the learning barrier. | Low | Modal listing all shortcuts. `?` key trigger. |
| Audio waveform visual indicator | Reviewers can see at a glance whether audio has been generated (vs missing) without pressing play on every item. | Low | Show generated/missing badge on audio cell, not an actual waveform (waveform = overkill). |

---

## Anti-Features

Features to explicitly NOT build in this milestone.

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| CSV / Excel import | PROJECT.md explicitly out-of-scope. High complexity (schema mapping, validation errors, partial failures). 1-3 users do not need it. | Individual edit forms are sufficient. Add as a separate milestone if demand emerges. |
| User / account management | PROJECT.md out-of-scope. Belongs to main app. Cross-cutting concern that adds auth complexity. | Link to main app admin area in a sidebar note. |
| Learning analytics / progress dashboard | PROJECT.md out-of-scope. No relevance to reviewer role. Adds backend query complexity. | Main app handles this. |
| Real-time collaborative editing | 1-3 users will not edit the same record simultaneously. WebSocket infrastructure for this is pure overhead. | Last-write-wins with optimistic locking (DB updated_at check) is sufficient. |
| Full version control / content history (Git-style) | Enormous complexity. Reviewers do not need diff trees. | Simple "last changed" audit log (5 entries) covers the use case. |
| AI-assisted content suggestions | Out of stated scope. Introduces latency and cost for a tool meant to verify human-quality data, not generate new content. | Separate milestone if AI validation of Japanese correctness is wanted. |
| Rich text / WYSIWYG editor | Learning data fields are plain text or structured JSON. Rich text adds sanitization complexity for no benefit. | Plain textarea with character count for long fields. |
| Email notification workflow | 1-3 users coordinate directly. Building notification infrastructure for this team size is over-engineering. | Shared status dashboard covers coordination needs. |
| Complex permission tiers (editor / reviewer / super-reviewer) | PROJECT.md specifies reviewer role only + admin. Adding tiers now front-loads auth complexity. | Two roles: `reviewer` and `admin`. Expand only if user count grows. |
| Mobile-first or native mobile admin | Reviewers work at a desk reviewing audio and text. Mobile admin for this use case is a distraction. | Desktop-optimized responsive layout (min-width 1024px target). |

---

## Feature Dependencies

```
Supabase Auth (existing)
  └── reviewer role (new, Alembic migration)
        └── all protected routes

Content list view (search + filter + sort + pagination)  ← foundational, build first
  └── inline edit
  └── full edit form
        └── status workflow (needs_review / approved / rejected)
              └── review comment on reject
              └── review queue (next/prev navigation)
              └── bulk status change
              └── change history

TTS audio playback  ← independent, low complexity
  └── TTS regeneration (single item)
        └── TTS batch regeneration (deferred to Phase 2)

Multilingual UI (next-intl setup)  ← cross-cutting, set up at project init
  └── all UI strings in ja/ko/en

Content-type dashboard summary  ← depends on status workflow having data
```

---

## MVP Recommendation

Build in this order, phase by phase:

**Phase 1 — Foundation (auth + shell + list)**
1. apps/admin scaffold in monorepo (Next.js, shadcn, next-intl ja/ko/en)
2. Supabase Auth + reviewer role middleware
3. Content list views: Vocabulary, Grammar, Quiz, ConversationScenario
4. Search, filter by status, sort, pagination

**Phase 2 — Edit + Review Workflow**
5. Full edit forms per content type (React Hook Form + Zod)
6. Inline edit for short text fields
7. Status workflow (needs_review / approved / rejected) with comment on reject
8. Toast feedback + unsaved-changes guard

**Phase 3 — Audio + Productivity**
9. TTS audio playback (pre-signed GCS URL)
10. TTS single-item regeneration
11. Review queue (next/prev + keyboard shortcuts)
12. Bulk status change (checkbox + floating action bar)

**Defer to later milestone:**
- Change history / audit log (Medium complexity, non-blocking)
- Content-type dashboard summary (Low complexity but not day-1 critical)
- TTS batch regeneration (High complexity, use single-item first)
- Keyboard shortcut overlay (Low, polish item)

---

## Data Model Implications for Features

| Feature | DB Change Required | Mechanism |
|---------|-------------------|-----------|
| Review status | Add `review_status` enum + `reviewed_at` + `reviewer_id` columns to Vocabulary, Grammar, Quiz, ConversationScenario | Alembic migration (DDL authority) |
| Review comment | Add `review_note text` column to same tables | Alembic migration |
| Reviewer role | Add `role` claim to Supabase user metadata OR add `user_roles` table | Supabase Auth metadata or Alembic |
| Change history | Add `content_audit_log` table (table, record_id, field, old_value, new_value, changed_by, changed_at) | Alembic migration + DB trigger or app-level logging |
| TTS regeneration | No new schema — calls existing FastAPI endpoint, updates existing `TtsAudio` record | API call only |

---

## Sources

- [Content Workflow Management Guide 2026 — Activepieces](https://www.activepieces.com/blog/content-workflow-management)
- [Bulk Actions UX: 8 design guidelines — Eleken](https://www.eleken.co/blog-posts/bulk-actions-ux)
- [PatternFly Bulk Selection pattern](https://www.patternfly.org/patterns/bulk-selection/)
- [Drupal Content Moderation workflow states](https://www.drupal.org/docs/8/core/modules/content-moderation/overview)
- [Filter UX Design Patterns — Pencil & Paper](https://www.pencilandpaper.io/articles/ux-pattern-analysis-enterprise-filtering)
- [Data Table UX: 5 Rules of Thumb](https://mannhowie.com/data-table-ux)
- [next-intl official docs](https://next-intl.dev/docs/getting-started)
- [Content Review and Approval Best Practices — zipBoard](https://zipboard.co/blog/collaboration/content-review-and-approval-best-practices-tools-automation/)
- [Text-to-Speech for Language Apps comparison 2026 — DEV Community](https://dev.to/pocket_linguist/text-to-speech-in-2026-comparing-5-tts-apis-for-language-apps-606)
- PROJECT.md constraints and out-of-scope definitions (primary authority for anti-features)
