# 하루코토 모바일 StyleGuide 적용 기준

2026-11-25 한국 시간 기준으로 Figma의 스타일 가이드와 앱 화면을 대조했다. [StyleGuide의 게시 버전 `2425633608157904115`](https://www.figma.com/design/qRyEjwHdi9e2C6jmZXaMIX/Design?version-id=2425633608157904115&node-id=0-1)을 확인했고, 아래 원본 노드 링크는 해당 버전으로 연다. [리디자인 시작 기준점](mobile-redesign-baseline-2026-11-23.md)은 변경 이력으로 보관한다.

## 버튼과 유형 탭

| 화면에서 쓰는 구성 | Figma 출처와 값 | Flutter 적용 |
| --- | --- | --- |
| 퀴즈 풀기, 복습 시작, 추천 레슨 | [42 / default / BG_Brand / round](https://www.figma.com/design/qRyEjwHdi9e2C6jmZXaMIX/Design?version-id=2425633608157904115&node-id=86-3158). 높이 42, 좌우 패딩 20, 반경 500, 브랜드 배경 `#FF6A87`, 흰 글자. Pretendard 14·500, 행간 140%, 자간 −2.5%. [퀴즈 화면에서 이 컴포넌트를 참조한다.](https://www.figma.com/design/y0vVcOVXYyJDDmF6VovDdG/Design?node-id=137-1985) | `HaruButtonStyles.primary`의 `compact`. 카드 너비를 채우고 48pt 터치 영역을 확보한다. |
| 홈 학습 시작 | [48 / default / BG_Brand / round의 글자](https://www.figma.com/design/qRyEjwHdi9e2C6jmZXaMIX/Design?version-id=2425633608157904115&node-id=86-3150). 높이 48, 좌우 패딩 20, 반경 500, 브랜드 배경과 흰 글자. Pretendard 14·600, 행간 140%, 자간 −2.5%. | `HaruButtonStyles.primary`의 `regular`. 홈 목표 카드의 학습 시작과 이어하기에 사용한다. |
| 42·48 버튼 비활성 | 배경 `#F1F1F5`, [글자 `#999999`](https://www.figma.com/design/qRyEjwHdi9e2C6jmZXaMIX/Design?version-id=2425633608157904115&node-id=86-3165). | 라이트 모드에서 실행할 수 없는 버튼이 이 색을 사용한다. |
| 퀴즈 유형 32pt 탭 | [선택은 BG_Black / default](https://www.figma.com/design/qRyEjwHdi9e2C6jmZXaMIX/Design?version-id=2425633608157904115&node-id=104-677). [미선택은 BG_Black / disabled 외형](https://www.figma.com/design/qRyEjwHdi9e2C6jmZXaMIX/Design?version-id=2425633608157904115&node-id=104-683). 선택 배경 `#2A2A37`, 미선택 배경 `#F1F1F5`. 글자는 Pretendard 13·500, 행간 140%, 자간 −2.5%. | `HaruButtonStyles.pillTab`에서 `selected`에 외형을 연결한다. 두 상태 모두 선택할 수 있다. 32pt 캡슐의 터치 영역은 48pt다. 실제 라벨과 폭은 퀴즈 탭이 정하고, 글자 위치는 네이티브 대조 결과를 공용 패딩에 반영했다. |

라이트 모드의 42·48pt 브랜드 기본 버튼은 황윤영님의 StyleGuide에 따라 배경 `#FF6A87`과 흰 글자 `#FFFFFF`를 사용하기로 했다. 두 크기에 같은 색상을 [공용 버튼 스타일](../../../apps/mobile/lib/shared/widgets/haru_button_styles.dart)에서 적용한다.

Figma의 `hover` 변형은 `#FF5173`이다. 모바일에서 손가락으로 누르고 있는 상태의 색과 다크 팔레트는 해당 시안을 대조할 때 정한다. 현재 구현은 Flutter의 눌림 효과와 앱 다크 테마를 사용한다.

## 한글과 일본어 서체

| Figma 스타일 | 글꼴 · 크기 · 굵기 | 행간 · 자간 | Flutter |
| --- | --- | --- | --- |
| [KR / Title / Title 2](https://www.figma.com/design/qRyEjwHdi9e2C6jmZXaMIX/Design?version-id=2425633608157904115&node-id=4-681) | Pretendard 20 · 600 | 140% · −2.5% | `krTitle2`, 학습·퀴즈 화면 제목 |
| [KR / Title / Title 3](https://www.figma.com/design/qRyEjwHdi9e2C6jmZXaMIX/Design?version-id=2425633608157904115&node-id=2-60) | Pretendard 18 · 600 | 140% · −2.5% | `krTitle3`, 복습·추천 레슨·퀴즈 카드 제목 |
| [KR / Body / Body 3](https://www.figma.com/design/qRyEjwHdi9e2C6jmZXaMIX/Design?version-id=2425633608157904115&node-id=4-925) | Pretendard 13 · 400 | 150% · −2.5% | `krBody3`, 설명과 메타데이터 |
| [JP / Body / Body 3](https://www.figma.com/design/qRyEjwHdi9e2C6jmZXaMIX/Design?version-id=2425633608157904115&node-id=4-1116) | Pretendard JP 13 · 400 | 150% · −2.5% | `jpBody3`, Widgetbook에서 검증. 화면별 일본어 스타일은 해당 Figma 노드를 대조하며 연결한다. |

[공용 타이포그래피](../../../apps/mobile/lib/core/theme/haru_typography.dart)는 Figma의 자간 백분율을 Flutter의 논리 픽셀로 환산한다. 화면에서 글자의 색 역할을 정한다.

## 복습·퀴즈 카드

[학습 복습 카드](https://www.figma.com/design/y0vVcOVXYyJDDmF6VovDdG/Design?node-id=60-1790)와 [퀴즈 시작 카드](https://www.figma.com/design/y0vVcOVXYyJDDmF6VovDdG/Design?node-id=120-1070)는 [`AppCard.compactSurface`](../../../apps/mobile/lib/shared/widgets/app_card.dart)를 사용한다. 두 화면 시안의 공통 배경 `#F7F7FB`, 반경 12pt, 기본 안쪽 여백 16pt를 맞췄다. 다크 배경은 각 화면의 역할을 따르고, 복습 상태별 정보와 퀴즈 시작 동작은 각 화면에서 정의한다. 42pt 버튼의 아래쪽 터치 여백 3pt를 고려해 화면에 보이는 카드 여백을 맞춘다.

Widgetbook의 AppCard에서 기본 카드와 복습·퀴즈의 채움 스타일을 라이트·다크 모드로 확인할 수 있다.

## 홈 학습 바텀시트

홈에서 여는 오늘 학습 시트와 학습 진입 흐름의 이어하기 선택 시트는 공용 20pt 상단 반경을 쓴다. 이어하기 선택 시트도 공용 40×4pt 핸들을 사용한다. 같은 데이터의 375pt iOS 캡처에서 두 시트의 라이트·다크 화면을 전후 비교했고 앱 영역의 픽셀은 일치했다. 자유퀴즈 설정의 24pt 반경은 시안에 맞춘 별도 값이다. [공용 핸들](../../../apps/mobile/lib/shared/widgets/app_sheet_handle.dart) · [학습 진입](../../../apps/mobile/lib/features/study/presentation/study_entry_flow.dart)

## 화면 적용과 검증

1. 화면의 Figma 인스턴스를 선택하고 연결된 가이드 컴포넌트, 버전과 변형을 확인한다. 화면에서 별도로 지정한 값도 함께 기록한다.
2. 같은 구성은 공용 스타일과 연결한다. 화면의 실제 텍스트, 동작, 접근성 이름을 사용하고 터치 영역과 글자 확대를 검증한다.
3. [Widgetbook](../../../apps/mobile/lib/widgetbook.dart)에서 버튼 42·48, 정규·비활성, 퀴즈 유형 선택·미선택과 한·일 서체를 확인한다. 같은 예시 데이터와 글자 배율의 375pt iOS 캡처에서 글자의 위치, 배경과 카드 경계를 대조한다.
4. 후속 화면은 적용하려는 카드·입력·시트의 Figma 컴포넌트와 상태가 확인되는 순서로 진행한다.

첫 적용에서 Flutter 테스트 1,615개와 정적 분석이 통과했다. [공용 버튼 테스트](../../../apps/mobile/test/shared/widgets/haru_button_styles_test.dart)에서 시각 높이와 터치 영역, 비활성 색, 미선택 탭 클릭을 확인했다. 375pt iOS 시뮬레이터에서 같은 예시 데이터로 전후를 비교한 홈 학습 카드, 학습 화면 상단, 퀴즈 화면 상단의 픽셀은 일치했다. 라이트·다크 공용 버튼과 탭을 직접 눌러 동작도 확인했다.

## 오늘 학습 시트 핸들

오늘 학습 시트는 공용 `AppSheetHandle.todayStudy()`의 36×3pt 캡슐형 핸들을 사용한다. 위쪽 여백은 20pt다. 라이트 색은 시안의 `#C9C9CF`를 적용했고, 다크 색은 기존 앱 테마의 표면 위 글자색을 불투명도 20%로 사용한다. [피그마 핸들 인스턴스](https://www.figma.com/design/y0vVcOVXYyJDDmF6VovDdG/Design?node-id=179-4457&sublayer-id=I179-4457%3B179-4454)
