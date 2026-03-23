---
paths:
  - "apps/mobile/**"
---

# Mobile (Flutter) 규칙

## 빌드
- iOS 빌드 시 반드시 `--dart-define-from-file=.env` 포함
- 실기기 device ID: `00008150-000A20881E88401C` (Kun Woo's iPhone)
- 시뮬레이터: `iPhone 17 Pro` (ID: `16FEF8B7-DC41-49D8-9EC6-E9911468E875`)
- Release: `flutter build ios --release --dart-define-from-file=.env`
- 실기기 설치: `flutter install --release -d 00008150-000A20881E88401C`
- Debug: `flutter run -d 00008150-000A20881E88401C --dart-define-from-file=.env`
- 시뮬레이터: `flutter run -d 16FEF8B7-DC41-49D8-9EC6-E9911468E875 --dart-define-from-file=.env`

## 시트 안정화 규칙 (핵심)
- BottomSheet/Modal은 결과만 반환 (`Navigator.pop(result)`)
- API 호출/상태 변경(`ref.invalidate` 포함)은 `await showModalBottomSheet(...)` 이후 부모에서 처리
- TextField + 키보드 시트: `useRootNavigator: true` + 시트 내부 `StatefulWidget` 분리 + `MediaQuery.viewInsetsOf(context)`

## Lint
- 커밋 전: `dart format --set-exit-if-changed lib/ test/ && flutter analyze`
- 에러 시 커밋 차단
