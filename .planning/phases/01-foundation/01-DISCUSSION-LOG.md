# Phase 1: Foundation - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-03-26
**Phase:** 01-foundation
**Areas discussed:** Login page experience, Post-login dashboard, Language switcher UX, Auth error handling

---

## Login Page Experience

### Login style

| Option | Description | Selected |
|--------|-------------|----------|
| Minimal centered card (Recommended) | Clean white card on neutral background. Logo + email/password fields + submit button. | ✓ |
| Split layout | Left side: branding/illustration. Right side: login form. | |
| Full-page form | No card — just centered form fields directly on the page. | |

**User's choice:** Minimal centered card
**Notes:** None

### Login branding

| Option | Description | Selected |
|--------|-------------|----------|
| App name only (Recommended) | "HaruKoto Admin" text with subtitle. No logo image. | |
| Logo + app name | HaruKoto logo image above the form with app name. | ✓ |
| Bare — no branding | Just email/password fields and submit. | |

**User's choice:** Logo + app name — "로고는 지금 /web에 에셋에 있을거야. 이걸 쓰면 되지 않을까?"
**Notes:** User identified apps/web/public/images/logo-symbol.svg as the logo to reuse. Also asked about tone/manner alignment with main app.

### Validation timing

| Option | Description | Selected |
|--------|-------------|----------|
| On submit only (Recommended) | Validate when user clicks "ログイン". Error shows as inline message. | ✓ |
| Real-time + on submit | Show validation as user types. | |

**User's choice:** On submit only
**Notes:** None

---

## Post-login Dashboard

### Dashboard content

| Option | Description | Selected |
|--------|-------------|----------|
| Welcome + placeholder cards (Recommended) | Greeting + empty cards showing where stats will appear. | ✓ |
| Simple welcome only | Just a welcome message and Phase 2 notice. | |
| Navigation-focused shell | Sidebar with grayed-out nav items + welcome. | |

**User's choice:** Welcome + placeholder cards
**Notes:** None

### App shell layout

| Option | Description | Selected |
|--------|-------------|----------|
| Header-only layout (Recommended) | Top header bar. No sidebar yet. | ✓ |
| Sidebar from the start | Left sidebar with disabled nav items. | |

**User's choice:** Header-only — decided via Codex cross-review
**Notes:** User requested Codex MCP discussion. Codex recommended header-only for Phase 1 (sidebar with disabled items = "unfinished product" feel). User agreed.

### Tone and manner

| Option | Description | Selected |
|--------|-------------|----------|
| Match main app cherry-pink theme | Full cherry-pink spring theme. | |
| Neutral/gray + accent only | Current UI-SPEC plan. | |
| Hybrid warm-admin | Neutral base + warm tones + generous cherry-pink. | ✓ |

**User's choice:** Hybrid warm-admin — decided via Codex cross-review
**Notes:** User initially questioned "아무리 내부용이라도 톤앤매너는 우리 프로젝트 웹이나 앱과 맞추는게 좋지 않을까?" Codex recommended hybrid. User agreed.

---

## Language Switcher UX

### Placement

| Option | Description | Selected |
|--------|-------------|----------|
| Header right side (Recommended) | Dropdown in the header bar, always accessible. | ✓ |
| Footer | Small language links at page bottom. | |
| User menu inside | Nested inside user profile dropdown. | |

**User's choice:** Header right side
**Notes:** None

### Display style

| Option | Description | Selected |
|--------|-------------|----------|
| Dropdown with native names (Recommended) | "日本語 / 한국어 / English" in dropdown. | ✓ |
| Segmented control / pills | Three buttons side-by-side: JA | KO | EN. | |
| Globe icon + dropdown | Globe icon that opens a dropdown. | |

**User's choice:** Dropdown with native names
**Notes:** None

---

## Auth Error Handling

### Login error display

| Option | Description | Selected |
|--------|-------------|----------|
| Inline under form (Recommended) | Red error message below login form. | ✓ |
| Toast notification | Toast popup in corner (sonner). | |
| Full-page error for role denial | Inline for credentials, dedicated page for access denied. | |

**User's choice:** Inline under form
**Notes:** None

### Session expiry behavior

| Option | Description | Selected |
|--------|-------------|----------|
| Redirect to login with message (Recommended) | Auto-redirect + "セッションが無効になりました" inline message. | ✓ |
| Show modal on current page | Modal dialog on current page. | |
| Silent redirect | Redirect without message. | |

**User's choice:** Redirect to login with message
**Notes:** None

---

## Claude's Discretion

- Turborepo apps/admin scaffolding details (tsconfig, eslint, tailwind config)
- Supabase server/client client structure
- next-intl message file structure and translation key naming
- Vercel deployment configuration
- proxy.ts implementation details

## Deferred Ideas

None — discussion stayed within phase scope
