# 하루코토 모바일 리디자인 기준선과 디자인 시스템 분석

**기록일 2026-11-23 (한국 시간) · 범위 Flutter iOS·Android · 단계 코드와 시안 대조**

홈과 학습·퀴즈·마이페이지를 리디자인하기 전에 공용 테마와 컴포넌트를 먼저 정리한다. 버튼과 탭의 표현을 화면마다 다시 구현하는 일을 줄이고, 목표·학습 기록·이어하기처럼 이미 쓰고 있는 동작은 같은 데이터와 경로로 검증하기 위한 순서다.

## 1. 변경 전 기준점

| 대상 | 다시 찾는 방법 |
| --- | --- |
| Flutter 코드 | 2026-11-23 작업을 시작할 때 확인한 `origin/main`의 [고정 커밋](https://github.com/WhiteMouseDev/HaruKoto/commit/b3854e9503ca52227a8cb8762f2a3c71a4ac4544) `b3854e9503ca52227a8cb8762f2a3c71a4ac4544` (#243 병합). |
| 작업 브랜치와 태그 | `codex/mobile-redesign-design-system`을 별도 체크아웃에 만들고, `pre-redesign-2026-11-23` 태그를 위 커밋에 달았다. 기존 로컬의 미커밋 작업은 별도 체크아웃의 기준에 포함되지 않는다. 태그가 없는 체크아웃에서도 위 커밋으로 기준 코드를 조회할 수 있다. |
| 디자인 | [Figma Design / Page 1](https://www.figma.com/design/y0vVcOVXYyJDDmF6VovDdG/Design?node-id=0-1)을 2026-11-23에 열어 확인했다. 이 문서의 노드 링크는 현재 파일을 연다. 당시 상태는 아래에 기록한 속성과 화면 설명으로 확인할 수 있다. 이름을 붙인 Figma 버전은 이번 작업에서 생성하지 않았다. |
| 제품 결정 | [디스코드 업무-공유](https://discord.com/channels/1561555495347691611/1564080318506598481)의 11월 검토 내용. [주간 학습 요구사항](https://discord.com/channels/1561555495347691611/1564080318506598481/1567358068696809474)과 [연속 학습 피드백 스레드](https://discord.com/channels/1561555495347691611/1566747063247568906), 11월 20일·23일 학습 통계 피드백을 참조한다. |

변경 전 코드를 열어볼 때는 새 폴더에 읽기용 체크아웃을 만든다. 작업 중인 브랜치나 파일을 되돌릴 필요가 없다.

```sh
git worktree add --detach ../harukoto-before-redesign b3854e9503ca52227a8cb8762f2a3c71a4ac4544
```

## 2. Flutter 테마와 피그마 속성

| 항목 | 기준 커밋의 Flutter | 피그마에서 확인한 값과 구현 기준 |
| --- | --- | --- |
| 브랜드와 화면 색상 | [AppColors](../../../apps/mobile/lib/core/constants/colors.dart)의 주색 `#FF6B86`, 눌림 `#E04A6A`, 연한 강조면 `#FFD8E1`. 라이트 배경 `#FBFAF8`·카드 `#FFFFFF`, 다크 배경 `#1A1A2E`·카드 `#242442`. | [Main 프레임](https://www.figma.com/design/y0vVcOVXYyJDDmF6VovDdG/Design?node-id=1-2)의 배경은 `#FFFFFF`. [홈 학습 버튼](https://www.figma.com/design/y0vVcOVXYyJDDmF6VovDdG/Design?node-id=93-723)의 기본 배경은 `#FF6A87`, 글자는 `#FFFFFF`. 주색을 일괄 치환하기 전에 버튼 배경·강조 글자·차트·상태 색을 [HaruSemanticColors](../../../apps/mobile/lib/core/theme/haru_semantic_colors.dart)에 역할별로 매핑한다. |
| 글꼴 | [appTextTheme](../../../apps/mobile/lib/core/theme/text_theme.dart)는 Noto Sans KR과 Noto Sans JP 폴백을 사용한다. | 홈 학습 버튼은 Pretendard SemiBold 600, 14px, 행간 140%, 자간 −2.5%. 한글 UI와 일본어 문제문·가나의 글꼴과 행간은 각각 실제 문구로 검증한 뒤 공용 스타일에 반영한다. |
| 버튼과 간격 | [AppSizes](../../../apps/mobile/lib/core/constants/sizes.dart)는 4·8·12·16·24·32·48 간격, 페이지 좌우 20, 카드 반경 24·패딩 20, 버튼 높이 48·반경 16을 정의한다. | 홈의 `Button / BG_Brand / default / round`는 높이 48px, 가로 패딩 20px, 내부 간격 6px, 반경 500px(캡슐형). 확인한 한 변형의 값이다. 기존 공용 [AppTheme](../../../apps/mobile/lib/core/theme/app_theme.dart)의 기본·눌림·비활성 상태를 활용하고, 홈 카드의 직접 구현 버튼도 함께 점검한다. |
| 시트 | `AppSizes`의 시트 상단 반경 20, 핸들 40×4. | [캘린더 바텀시트](https://www.figma.com/design/y0vVcOVXYyJDDmF6VovDdG/Design?node-id=110-1375)는 흰 배경, 상단 반경 20px, 상단 패딩 20px·하단 40px, 내부 간격 16px. 375px 예시 프레임의 값이다. 앱에서는 화면과 안전 영역에 맞춰 배치한다. |
| 하단 메뉴 | [BottomNav](../../../apps/mobile/lib/shared/widgets/bottom_nav.dart)는 [MainShell](../../../apps/mobile/lib/shared/widgets/main_shell.dart)에서 사용하는 커스텀 위젯이다. | 피그마는 홈·학습·퀴즈·실전회화·마이페이지 5개에 채워진 아이콘과 현재 탭 표시를 둔다. 공용 위젯에서 외형을 바꾸고 기존 탭 이동과 상태 보존을 확인한다. |

피그마에서 읽은 수치는 위 프레임과 변형의 라이트 시안 기준이다. 다크 팔레트, 글자색 대비, 나머지 버튼 상태와 크기는 구현 전에 별도로 확인한다. 기존 [컬러 문서](color-system.md)의 주색 `#F6A5B3`과 [초기 디자이너 브리프](designer-brief.md)의 WebView 설명은 과거 기록이다. 변경 전 모바일 값은 위 기준 커밋의 Flutter 소스를 따른다.

## 3. 화면별 기준과 남은 확인

| 화면 | 합의한 기준 | 확인한 시안과 구현 메모 |
| --- | --- | --- |
| 홈 학습 | 단어·문법·문장배열 각각 하루 목표를 저장하고, 선택한 유형의 오늘 풀이 수와 목표를 표시·수정한다. 홈과 퀴즈 탭 모두에서 학습에 진입할 수 있게 한다. 홈의 단어·문법은 시작 전 새 문제·복습·재도전 구성을 보여준다. 누적 숙련도는 홈에서 제외한다. | [홈](https://www.figma.com/design/y0vVcOVXYyJDDmF6VovDdG/Design?node-id=93-657)에 가로 유형 탭, 진행률, 시작 버튼과 단어 시작 시트가 보인다. 시안의 분량과 퍼센트는 예시다. [목표 계산](../../../apps/mobile/lib/features/home/domain/daily_goal_progress.dart)과 [시작 카드](../../../apps/mobile/lib/features/home/presentation/widgets/quick_start_card.dart)의 계정별 데이터와 실제 추천량을 사용한다. |
| 연속 학습 | 좁은 한 줄에 둥근 벚꽃으로 요일을 표시한다. 한국 시간 기준으로 한 문제의 답이 기록되면 학습일로 인정한다. 유형별 목표 중 하나 이상을 달성한 날에는 트로피를 하나 표시한다. | 카드 전체에서 월간 기록을 연다. 하단 시트로 여는 형태가 제안됐고 [별도 시트 시안](https://www.figma.com/design/y0vVcOVXYyJDDmF6VovDdG/Design?node-id=110-1375)도 확인했다. [기존 달력 위젯](../../../apps/mobile/lib/features/home/presentation/widgets/streak_daily_card.dart)의 학습일·목표 달성·오늘 표시와 [서버의 달성 판정](../../../apps/api/app/services/category_goals.py)을 연결한다. |
| 주간 학습 | 한국 시간 기준 월~일. 단어·문법·문장배열을 누적 막대로 표시한다. 한 주의 총 풀이 수 최댓값에 맞춰 높이를 비례 조정하고 목표선은 넣지 않는다. 날짜를 누르면 총합과 유형별 수치를 보여준다. 상세 보기에서 통계로 이동한다. | [그래프 상세 예시](https://www.figma.com/design/y0vVcOVXYyJDDmF6VovDdG/Design?node-id=108-930). 과거 0문제, 미래 날짜, 빈 기록, 로딩, 오류를 구분하고 카드 높이를 유지한다. 가나·회화 학습이 학습일로 인정된 날에는 풀이량 0과 학습일이 함께 표시될 수 있다. 기존 [홈 집계](../../../apps/api/app/services/stats_dashboard.py)는 오늘 포함 최근 7일이며 날짜별 단어 답변 수만 제공한다. 월~일과 세 유형을 지원할 데이터 계약을 확인한 뒤 연결한다. |
| 학습·퀴즈 | 학습의 급수 선택을 복습과 추천 레슨에 적용하고 저장 레슨은 펼쳐서 이어간다. 퀴즈 CTA는 **퀴즈 풀기**. 자유퀴즈는 진입 유형을 유지하고 4지선다를 기본 선택으로 둔다. | [학습](https://www.figma.com/design/y0vVcOVXYyJDDmF6VovDdG/Design?node-id=60-1790) · [퀴즈](https://www.figma.com/design/y0vVcOVXYyJDDmF6VovDdG/Design?node-id=120-1070) · [자유퀴즈 설정](https://www.figma.com/design/y0vVcOVXYyJDDmF6VovDdG/Design?node-id=127-1993) · [퀴즈 결과](https://www.figma.com/design/y0vVcOVXYyJDDmF6VovDdG/Design?node-id=244-8485). 문제·정오답·종료 확인·결과 화면은 저장과 이어하기 흐름에 연결하고, 결과의 정오답 수와 정답률은 같은 제출 결과에서 표시한다. |
| 마이페이지·가나차트 | 마이페이지는 프로필·학습 요약·통계·설정의 구획을 잡는다. 가나차트는 히라가나·가타카나의 행과 단 제목에 일본어와 한글 읽기를 함께 표시한다. | [마이페이지](https://www.figma.com/design/y0vVcOVXYyJDDmF6VovDdG/Design?node-id=154-1973) · [가나차트](https://www.figma.com/design/y0vVcOVXYyJDDmF6VovDdG/Design?node-id=232-3688). 검토한 히라가나 예시는 행·단에 병기하고 본문 셀에는 가나만 표시한다. 가타카나에도 같은 규칙을 확인한다. |
| 통계 기간별·학습별 | 오늘·이번 주 풀이 수와 유형별 풀이량을 중심으로 구성한다. 학습 시간과 대화 시간은 화면에서 제외한다. 문장배열은 풀이량에 포함한다. | [기간별](https://www.figma.com/design/y0vVcOVXYyJDDmF6VovDdG/Design?node-id=186-1678)에는 시간 표시가 없고 [학습별](https://www.figma.com/design/y0vVcOVXYyJDDmF6VovDdG/Design?node-id=205-4555)에는 ‘총 학습’과 ‘대화 시간’이 남아 있다. 구현 기준은 11월 23일 공유한 항목 제외다. |
| JLPT 진도 | N5~N1 탭을 진도 카드 위에 둔다. 현재 학습 급수를 기본 선택하고, 선택한 급수에 대해 통합 마스터율·단어 진도·문법 진도·남은 수를 한 번만 표시한다. 통계 탭 선택으로 학습 급수가 바뀌지 않는다. | [JLPT 진도](https://www.figma.com/design/y0vVcOVXYyJDDmF6VovDdG/Design?node-id=205-6287)에는 상단 요약과 ‘전체 레벨 진도’, 문장배열 항목이 함께 남아 있다. 11월 23일 기준은 단어·문법만 담은 카드 하나다. [기존 API](../../../apps/api/app/services/stats_jlpt_progress.py)는 자료가 없거나 현재 급수 외에 진도 기록이 없는 급수를 생략한다. 탭을 연결할 때 자료 없음과 진도 0을 구별한다. |

## 4. 구현 순서와 확인 방법

1. **공용 테마와 컴포넌트** · 색의 역할, 한글·일본어 타이포그래피, 버튼·카드·탭·시트·하단 메뉴를 기존 위젯에 매핑한다. [Widgetbook](../../../apps/mobile/lib/widgetbook.dart)의 기존 라이트·다크 설정에 선택·비활성·로딩·오류 예시를 추가해 화면 적용 전에 확인한다.
2. **홈에서 먼저 연결** · 유형별 목표 카드, 학습 시작 시트와 연속 학습을 검증한다. 주간 학습은 날짜 범위와 유형별 집계 계약을 정리한 뒤 적용한다. 홈의 학습 시작, 퀴즈 탭 시작, 이어하기에서 기존 저장 동작을 함께 확인한다.
3. **학습·퀴즈·마이페이지와 통계로 확장** · 공용 위젯을 적용하고 화면별 데이터 갱신, 뒤로가기, 접근성 라벨을 확인한다. 작은 화면과 큰 글씨, 다크 모드, 로딩·빈 상태·실패도 검증한다.

화면 적용 시 [유형별 목표 카드 테스트](../../../apps/mobile/test/features/home/presentation/widgets/quick_start_card_test.dart), [학습 기록 달력 테스트](../../../apps/mobile/test/features/home/presentation/widgets/streak_daily_card_test.dart), [홈 집계 API 테스트](../../../apps/api/tests/test_stats_dashboard_service.py)를 회귀 확인의 출발점으로 삼는다. 이 기록은 기준 커밋 소스와 피그마의 속성을 비교한 문서다. 앱 빌드와 기기 검증은 화면 적용 단계에서 수행한다.
