# Mobile My Page Release Smoke Gate

> Date: 2026-05-12
> Scope: Mobile `MY` tab launch-readiness smoke after account/settings hardening
> Code checkpoint: `b2262b465a9efce64102f93be780171b58066a00`
> Status: automated gate and physical-device install/launch precheck passed; on-screen smoke pending

## Summary

The mobile `MY` tab follow-up fixes are implemented and covered by focused
widget tests. The current code removes two launch-facing copy mismatches,
fixes the initial profile error state, and hardens the account deletion dialog
controller lifecycle.

ASSUMPTION: The release smoke should use a disposable or reviewer-safe account
for any destructive account test. Do not execute real account deletion on a
primary account.

## Automated Evidence

| Check | Command | Result |
|---|---|---|
| My page widget flows | `cd apps/mobile && flutter test test/features/my/presentation/my_page_test.dart` | PASS, 4 tests |
| My/settings targeted suite | `cd apps/mobile && flutter test test/features/my test/core/settings/device_settings_repository_test.dart test/core/settings/user_preferences_repository_test.dart` | PASS, 35 tests |
| Mobile analyzer | `cd apps/mobile && make analyze` | PASS, no issues |
| Full mobile tests | `cd apps/mobile && make test` | PASS, 525 tests |
| Device availability | `cd apps/mobile && flutter devices` | PASS, iPhone 17 Pro simulator and `Kun Woo's iPhone` wireless detected |

## Physical-Device Pre-Smoke Evidence

| Check | Command | Result |
|---|---|---|
| Current checkpoint | `git status --short --branch && git log --oneline --decorate -4` | PASS, `main...origin/main` clean at `7c1b760` |
| Device availability | `cd apps/mobile && flutter devices` | PASS, `Kun Woo's iPhone` wireless detected as `00008150-000A20881E88401C` |
| Profile install and launch | `cd apps/mobile && flutter run --profile -d 00008150-000A20881E88401C --dart-define-from-file=.env --no-resident` | PASS, Xcode build completed and install/launch command exited 0 |
| Installed app lookup | `xcrun devicectl device info apps --device 8C4FE734-227C-5F99-AE4C-BB6EDCFBBD55 --bundle-id com.harukoto.app` | PASS, `하루코토 / com.harukoto.app / 1.0.0 / 1` listed |
| Foreground launch | `xcrun devicectl device process launch --device 8C4FE734-227C-5F99-AE4C-BB6EDCFBBD55 --terminate-existing com.harukoto.app` | PASS, application launched by bundle identifier |
| Lock state | `xcrun devicectl device info lockState --device 8C4FE734-227C-5F99-AE4C-BB6EDCFBBD55` | PASS, `unlockedSinceBoot: true` |
| Process listing | `xcrun devicectl device info processes --device 8C4FE734-227C-5F99-AE4C-BB6EDCFBBD55` | PASS, `/Runner.app/Runner` observed in process list |

Note: wireless profile launch reported that the Dart VM Service was not
discovered within 75 seconds. This is a debug attach limitation on the wireless
device path, not a failed install. The installed app lookup, foreground launch,
and process listing above are the release-smoke precheck evidence.

## Fixed Before Smoke

| Area | File | Result |
|---|---|---|
| Terms copy | `apps/mobile/lib/features/legal/presentation/terms_page.dart` | Replaced hidden `MY > 구독 관리` instruction with email-based cancellation request path |
| Streak alert copy | `apps/mobile/lib/features/my/presentation/widgets/app_settings_section.dart` | Changed unproven conditional copy to actual daily 22:00 reminder behavior |
| Profile error state | `apps/mobile/lib/features/my/presentation/my_page.dart` | Initial load errors now show retry UI instead of staying in skeleton |
| Account deletion dialog | `apps/mobile/lib/features/my/presentation/widgets/account_section.dart` | Dialog owns and disposes its `TextEditingController` safely |
| Test coverage | `apps/mobile/test/features/my/presentation/my_page_test.dart` | Covers loaded content, error retry state, nickname trim/PATCH, and delete confirmation gate |

## GSD UAT Audit Notes

`$gsd-audit-uat` was attempted through the documented CLI path, but
`gsd-sdk query audit-uat --raw` was unavailable in the current shell
(`command not found`). Manual fallback inspection of `.planning` found:

| Category | Finding |
|---|---|
| Current GSD state | `.planning/STATE.md` says v1.1 stabilization UAT is closed with accepted P2 follow-ups; v1.2/N4 learner-rollout decision remains open |
| Current mobile release gate | No `*-UAT.md` files are present under `.planning/phases`; current mobile evidence is maintained under `docs/operations/plans` and `docs/operations/release` |
| Historical human-needed items | Remaining `human_needed` verification files are admin/TTS/browser-runtime oriented, not this `MY` tab release slice |

## Physical-Device Smoke Plan

Run on `Kun Woo's iPhone` wireless or a connected physical iPhone. Record
`Pass`, `Flag`, or `Block` for each scenario.

Precondition status: app is installed and launched on the physical iPhone.
The remaining checks require reading and interacting with the device screen.

### Scenario A. My Tab Load And Error-Free Profile

1. Launch the app from a signed-in account.
2. Navigate to `MY`.
3. Confirm the profile hero, level badge, learning stats tile, app settings,
   info section, and account section render without loading hang.

Expected: the page leaves skeleton state and shows user profile content. Any
profile fetch failure should show `데이터를 불러올 수 없습니다` and `다시 시도`.

Result:

- Status:
- Notes:

### Scenario B. Nickname Update

1. Tap the pencil icon beside the nickname.
2. Enter a nickname with surrounding spaces.
3. Tap `저장`.
4. Pull-to-refresh or leave and return to `MY`.

Expected: the saved nickname is trimmed and persists after refresh/re-entry.

Result:

- Status:
- Notes:

### Scenario C. Settings Toggles

1. Change JLPT level from the settings sheet, then return it to the intended
   reviewer value.
2. Toggle `가나 학습 표시`.
3. Toggle `읽기(후리가나) 표시`.
4. Change theme, sound, and haptic settings.

Expected: each UI control responds immediately, no snackbar error is shown, and
settings remain coherent after navigating away and back.

Result:

- Status:
- Notes:

### Scenario D. Notification Settings

1. Toggle `학습 리마인더`.
2. Grant notification permission if prompted.
3. Set a reminder time.
4. Toggle `스트릭 방어 알림`.

Expected: permission prompt and time picker work on-device. The copy describes
daily 22:00 reminder behavior and does not promise an unverified conditional
cancel path.

Result:

- Status:
- Notes:

### Scenario E. Info And Legal Links

1. Open `이용약관`.
2. Confirm the cancellation instruction is email-based, not `MY > 구독 관리`.
3. Open `개인정보처리방침`.
4. Tap `문의하기`.

Expected: legal pages open normally; `문의하기` opens the device mail flow or
fails in an understandable OS-level way if no mail account is configured.

Result:

- Status:
- Notes:

### Scenario F. Logout

1. Tap `로그아웃`.
2. Confirm the app leaves the authenticated shell and reaches login/onboarding
   as expected.
3. Sign back in with the test account.

Expected: no stuck loading state; re-login restores app access.

Result:

- Status:
- Notes:

### Scenario G. Account Deletion Gate

Use only a disposable account.

1. Open `회원 탈퇴`.
2. Confirm the final action is disabled before typing `탈퇴`.
3. Type any non-matching text and confirm it stays disabled.
4. Type exact `탈퇴` and confirm the final action becomes enabled.
5. Cancel unless this is a disposable account approved for deletion.

Expected: destructive action is gated by exact confirmation text. If executed
on a disposable account, the account is deleted and the app signs out.

Result:

- Status:
- Notes:

## Exit Criteria

- No `Block` in scenarios A, B, C, E, or F.
- Scenario D may be `Flag` only for OS permission/configuration limits; app UI
  must not crash or hang.
- Scenario G must prove the exact-text gate before any deletion is allowed.
- Any `Block` requires a fix and rerun of `make analyze`, targeted My tests,
  and `make test`.

## Remaining Release Notes

- `/payments` and subscription management remain hidden for the free launch.
  Before re-enabling them, add a focused mobile payment model/repository
  contract test and align the API `response_model` boundary.
- This smoke gate is narrower than the v1.2 N4 learner-rollout decision. N4
  content rollout still needs the separate learner-rollout approval path
  recorded in `.planning/STATE.md`.
