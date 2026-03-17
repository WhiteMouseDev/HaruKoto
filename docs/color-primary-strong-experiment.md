# primaryStrong 색상 실험

## 상태: 실험 중 (피드백 수집 필요)

## 배경

기존 `primary` (#F6A5B3)는 파스텔 톤(명도 80%)으로 브랜드 무드에는 적합하지만,
CTA 버튼이나 프로그레스 바처럼 시선을 끌어야 하는 요소에서 힘이 부족했음.

정답/오답 피드백 색(success #2DB08A, error #E8577D)이 primary보다 강렬해서
**시각적 위계가 뒤집히는 문제**가 있었음.

## 결정

Duolingo 방식 참고: 브랜드색(파스텔)과 CTA색(강조)을 분리.

| 변수 | 색상 | 용도 |
|------|------|------|
| `primary` | `#F6A5B3` (기존 유지) | 배경 틴트, 아이콘, 선택 상태 border, 네비 활성색 |
| `primaryStrong` | `#E8708A` (신규) | FilledButton, ElevatedButton, 프로그레스 바 |

### primaryStrong (#E8708A) 선정 이유

- 같은 핑크 계열(H:347°)로 브랜드 연속성 유지
- 채도 72%, 명도 67% → primary(80%)보다 확실한 강조
- 흰 텍스트 대비 WCAG AA 충족
- `#FA7B95`(명도 73%, 채도 93%)도 후보였으나, 팀 피드백으로 #E8708A 채택

## 변경 파일

1. `lib/core/constants/colors.dart` — `primaryStrong` 추가
2. `lib/core/theme/app_theme.dart` — FilledButton, ElevatedButton, ProgressIndicator 테마에 `primaryStrong` 적용

## 영향 범위

- FilledButton (퀴즈 피드백 바, 결과 페이지, 다이얼로그 확인 버튼 등)
- ElevatedButton (로그인, 온보딩 등)
- LinearProgressIndicator / CircularProgressIndicator (퀴즈 진행, 학습 진행률 등)
- `theme.colorScheme.primary`를 직접 참조하는 아이콘/배경은 **영향 없음** (파스텔 유지)

## 롤백 방법

`app_theme.dart`에서 3곳의 `AppColors.primaryStrong`을 `AppColors.primary`로 변경하면 끝.

```dart
// filledButtonTheme → backgroundColor: AppColors.primary
// elevatedButtonTheme → backgroundColor: AppColors.primary
// progressIndicatorTheme → color: AppColors.primary
```

## 피드백 수집 계획

- [ ] 내부 테스트 (시뮬레이터/실기기)
- [ ] 사용자 피드백 수집
- [ ] 피드백 결과에 따라 유지/롤백 결정
