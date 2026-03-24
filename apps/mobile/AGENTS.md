# AGENTS.md

## Scope

Instructions in this file apply to `apps/mobile/**`.

## Mobile Defaults

- Always pass environment variables through `.env` dart defines. Prefer the `Makefile` targets because they already include the required flag.
- Prefer `make run` or `make run-web` over ad hoc raw `flutter` commands during development.
- Avoid reinstall-heavy flows when `flutter run` is enough, because reinstalling can wipe local login state.
- For bottom sheets and modals, return a result from the sheet and apply side effects after the await in the parent flow.
- Keep keyboard and inset handling stable when editing modal or form-heavy screens.

## Validation

- `cd apps/mobile && make format`
- `cd apps/mobile && make analyze`
- `cd apps/mobile && make test`

## Change Risk

- Changes to auth, parser assumptions, push notifications, or API response handling need explicit backend compatibility review.
