# N4 Chapter 5 Physical-Device Smoke Attempt

> Date: 2026-05-27
> Scope: HN4-017 physical iPhone install/launch precheck for the N4 CH05
> controlled-pilot wave
> Status: BLOCKED by physical iPhone lock state before install/launch
> Boundary: device-availability evidence only; not release-device smoke PASS

## Boundary

This attempt checks whether the physical iPhone path is available for CH05
release-device claims after the simulator target-runtime UAT passed.

It does not include user emails, auth material, raw DB URLs, API tokens, or
per-user identifiers. It does not replace simulator UAT, aggregate pilot
feedback monitoring, native-speaker curriculum review, or native-speaker audio
review.

ASSUMPTION: A physical-device release smoke claim requires at least physical
device install/launch evidence, and ideally direct human-observed screen
behavior. Device visibility alone is not sufficient.

## Device Evidence

| Check | Result |
|---|---|
| Flutter device discovery | PASS: `Kun Woo's iPhone (wireless)` detected as `00008150-000A20881E88401C`, iOS 26.5 |
| CoreDevice discovery | PASS: `Kun Woo's iPhone`, identifier `8C4FE734-227C-5F99-AE4C-BB6EDCFBBD55`, state `available (paired)`, model `iPhone 17 Pro (iPhone18,1)` |
| Lock-state query | PARTIAL: `passcodeRequired: true`, `unlockedSinceBoot: true`; later developer-disk-image calls still reported device locked |
| Installed app lookup | BLOCK: Developer Disk Image mount failed because the device was locked |
| Process listing | BLOCK: Developer Disk Image mount failed because the device was locked |
| HN4-017 profile install/launch | NOT RUN: preflight was blocked before a meaningful install/launch attempt |
| HN4-017 physical screen flow | NOT RUN: no physical screen observation was available |

## Commands

```bash
cd apps/mobile
flutter devices
xcrun devicectl list devices
xcrun devicectl device info lockState \
  --device 8C4FE734-227C-5F99-AE4C-BB6EDCFBBD55
xcrun devicectl device info apps \
  --device 8C4FE734-227C-5F99-AE4C-BB6EDCFBBD55 \
  --bundle-id com.harukoto.app
xcrun devicectl device info processes \
  --device 8C4FE734-227C-5F99-AE4C-BB6EDCFBBD55
```

## Error Evidence

The app lookup and process listing attempts failed before app-level evidence
could be collected:

```text
ERROR: The developer disk image could not be mounted on this device.
DeviceIdentifier = 8C4FE734-227C-5F99-AE4C-BB6EDCFBBD55
Error mounting image: 0xe80000e2
kAMDMobileImageMounterDeviceLocked: The device is locked.
```

## Result

Physical-device smoke remains blocked. CH05 still has simulator target-runtime
UAT and aggregate feedback baseline evidence, but it does not have
release-device install/launch or human-observed physical screen proof.

## Unblock Path

1. Unlock `Kun Woo's iPhone` and keep it awake near the Mac.
2. Re-run the device preflight:
   `flutter devices`, `xcrun devicectl list devices`, and lock-state check.
3. Run a profile physical launch for HN4-017 with `.env` dart defines.
4. Record install/launch result, target API log evidence if available, and
   human-observed screen behavior separately.
