---
status: ready
scope: admin-production-smoke
release: v1.1-stabilization
created: 2026-04-28T06:53:19.000Z
source:
  - docs/operations/release/v1.1-manual-uat-2026-04-23.md
---

# Admin Production Smoke Runbook

This runbook converts the remaining H4 UAT item into an executable checklist for
the production admin app. It does not close H4 by itself; a credentialed reviewer
must execute the checklist and record evidence in the manual UAT tracker.

## Scope

Target:

- Admin URL: `https://harukoto-admin.vercel.app`
- UAT item: H4, credentialed production admin smoke
- Evidence tracker: `docs/operations/release/v1.1-manual-uat-2026-04-23.md`

Out of scope:

- Mobile voice-call validation.
- API fault injection unless a safe, approved mechanism already exists.
- Production content mutation without a pre-approved disposable review item.

## Safety Rules

- Do not paste reviewer credentials, cookies, tokens, or dashboard secrets into
  this repo or screenshots.
- Prefer read-only checks first. Only approve, reject, save, or regenerate TTS on
  a disposable smoke item that was selected before the run.
- Do not use bulk approve or bulk reject in production UAT.
- If no disposable item exists for a mutating step, mark that step
  `deferred - no safe production fixture` instead of forcing the action.
- If the UI or API returns an unexpected error, preserve the item ID, timestamp,
  route, browser console excerpt, and network status, but omit secrets.

## Preconditions

| Check | How to verify | Required result |
| --- | --- | --- |
| Production login page | Open `/login` or run `curl -sS -o /dev/null -w '%{http_code}' https://harukoto-admin.vercel.app/login` | `200` or visible login form |
| Reviewer credentials | Sign in through the admin login form | Reviewer reaches the protected dashboard |
| Disposable item | Confirm with the content owner before mutation | Item ID and allowed action are known |
| Evidence location | Prepare the UAT tracker before the run | Result can be recorded without credentials |

## Execution Checklist

Record each row as `pass`, `fail`, `blocked`, or `deferred`.

| # | Area | Steps | Pass condition | Evidence to record |
| --- | --- | --- | --- | --- |
| A1 | Login | Sign in with reviewer credentials and open `/dashboard`. | Dashboard loads without redirecting back to login. | Timestamp, reviewer email domain only, screenshot with secrets hidden. |
| A2 | Dashboard | Confirm stats cards and sidebar navigation render. | Dashboard content is visible and main navigation is usable. | Screenshot or short note. |
| A3 | Vocabulary list/detail | Open `/vocabulary`, apply an N5 or status filter, open one detail page. | List loads, URL preserves filter state, detail fields and audit history render. | Route, item ID, filter used. |
| A4 | Grammar list/detail | Open `/grammar`, search or filter, open one detail page. | List and detail render without API or shape errors. | Route, item ID, filter used. |
| A5 | Quiz list/detail | Open `/quiz`, verify both quiz type links when available, open one cloze or sentence-arrange detail page. | Detail route preserves the quiz type and renders the correct editor. | Route, item ID, quiz type. |
| A6 | Conversation list/detail | Open `/conversation`, search or filter, open one detail page. | Scenario detail renders with editable fields and audit history. | Route and item ID. |
| A7 | Review queue | Start review from one filtered list. Navigate next/previous if more than one item is queued, then exit the queue. | Queue opens, index state is visible, navigation works, exit returns to the list. | Content type, filter, queued count if visible. |
| A8 | Review action | On the pre-approved disposable item only, perform the approved action: approve or reject with a reason. | Success toast appears and queue/list state updates as expected. | Item ID, action, timestamp. |
| A9 | TTS playback | On a detail page with existing audio, play one available field. | Audio control starts playback and does not show an error toast. | Item ID and field. |
| A10 | TTS regenerate | On the disposable item only, open the regenerate confirmation for one missing or allowed field. Confirm only if the item owner approved mutation. | Confirmation dialog renders; if confirmed, success toast or backend `{ detail }` error is surfaced. | Item ID, field, dialog/result screenshot. |
| A11 | Error detail toast | If a safe error trigger occurs during A8/A10, confirm the toast surfaces the backend reason instead of a generic or blank error. | Backend `{ detail }` text is visible to the reviewer in the localized toast. | Error text, route, network status. |
| A12 | Logout | Use the admin logout control. | Session clears and the login page is reachable again. | Timestamp. |

## Closeout Rule

H4 can be marked `pass` only when A1-A7, A9, and A12 pass, and either:

- A8/A10 execute on a pre-approved disposable item without P0/P1 failure, or
- the release owner explicitly accepts the mutating checks as deferred because
  automated admin E2E already covers review actions and TTS confirmation paths.

A11 is conditional. If no safe backend error occurs and no approved fault trigger
exists, record it as `deferred - no safe error trigger` rather than fabricating
coverage.

If any reviewer-critical route is inaccessible, if the dashboard cannot load
after sign-in, or if safe TTS playback/regenerate breaks on the chosen item,
keep `gate_status` open and classify the issue before release closeout.

## Evidence Template

Paste this into the manual UAT tracker after execution.

```text
### Admin production smoke - YYYY-MM-DD

runtime: production admin
tester:
account: reviewer credential, no secrets recorded
browser:
result:
evidence:
- A1:
- A2:
- A3:
- A4:
- A5:
- A6:
- A7:
- A8:
- A9:
- A10:
- A11:
- A12:
notes:
```
