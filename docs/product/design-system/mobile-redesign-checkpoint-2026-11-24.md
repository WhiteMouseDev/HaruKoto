# 하루코토 모바일 리디자인 검증과 후속 작업

**기록일 2026-11-24 (한국 시간)**

[리디자인 기준선](mobile-redesign-baseline-2026-11-23.md)에 이어 홈·통계 검증 결과, 학습 탭 구현, 가입 화면 논의안을 기록한다. 화면 구조와 색상은 [하루코토 피그마](https://www.figma.com/design/y0vVcOVXYyJDDmF6VovDdG/Design?node-id=0-1)를 기준으로 삼는다.

## 홈과 학습 통계

[PR #246](https://github.com/WhiteMouseDev/HaruKoto/pull/246)에 운영 API에 연결한 iOS 시뮬레이터의 검증 결과를 기록하고 리뷰 준비 상태로 전환했다. 당시 PR 헤드는 `13491cf1`이었고 [GitHub CI](https://github.com/WhiteMouseDev/HaruKoto/actions/runs/45302884684)의 모바일 검사와 API 호환성 검사가 통과했다.

실전회화 PR #247까지 반영한 홈·통계 PR 헤드는 `66859668`이다. 이 헤드의 정적 분석, Flutter 테스트, Android 디버그 APK 빌드와 API 호환성 검사도 통과했다. [최신 CI 기록](https://github.com/WhiteMouseDev/HaruKoto/actions/runs/45321857706)

- 단어 5개, 문법 15개, 문장배열 20개의 목표를 따로 저장하고, 홈에서 유형을 바꿔 각 목표를 확인했다.
- 첫 답안이 저장되면 한국 시간 기준 학습일이 표시됐다. 퀴즈를 나갔다가 이어 풀면 두 번째 문제로 복원됐고, 단어 5문제에 답한 뒤 단어 목표 100%와 그날의 트로피가 표시됐다.
- 통계의 기간별과 학습별 화면에 풀이 5문제가 반영됐다. JLPT 진도는 현재 학습 급수 N4로 열렸고, N2 진도를 본 뒤에도 앱의 학습 급수는 N4였다.

### 주간 학습 카드

- 한국 시간 기준 월~일의 단어·문법·문장배열 풀이 수를 누적 막대로 표시한다. 같은 주의 일별 최댓값을 높이의 기준으로 삼는다. 하루 목표에서 막대를 자르거나 목표선을 그리지 않는다.
- 날짜를 눌렀을 때 해당 일자의 합계와 유형별 수치를 표시한다. 오늘, 지난날의 0문제, 미래 날짜를 구분한다.
- 풀이 기록이 없으면 옅은 예시 막대와 안내를 표시한다. 학습일도 없는 주와 풀이 없이 다른 학습 기록만 있는 주의 안내 문구를 구분한다. 로딩·오류 상태에서도 그래프 영역을 유지한다.
- 카드에는 주간 풀이 수와 학습일을 요약하고, ‘학습 통계 자세히 보기’는 통계 화면으로 연결한다. [주간 학습 시안](https://www.figma.com/design/y0vVcOVXYyJDDmF6VovDdG/Design?node-id=108-930)

## 학습 탭

`codex/mobile-redesign-study`의 로컬 커밋 `e1e11887`에서 [학습 탭 시안](https://www.figma.com/design/y0vVcOVXYyJDDmF6VovDdG/Design?node-id=60-1790)에 맞춰 복습, 추천 레슨, 이 기기에 저장된 레슨, 학습 노선 순으로 구성했다. 복습 아이콘은 피그마 원본을 사용했다.

- 복습할 유형이 하나면 ‘복습 시작’을 표시한다. 단어와 문법 모두 분량이 있으면 유형별 버튼을 표시해 각 복습으로 들어갈 수 있게 한다.
- 추천 레슨이 진행 중이면 ‘이어하기’로 복원한다. 저장된 레슨 목록은 펼쳐서 열고, 노선은 역마다 레슨과 진행률을 보여준다.
- Flutter 전체 테스트 1,538개와 정적 분석을 통과했다. 375pt iOS 시뮬레이터의 테스트 데이터로 상단과 2번 역을 펼친 화면을 확인했다. 로컬 캡처는 작업 폴더의 `harukoto-simulator-screenshots/30-study-redesign-top.png`, `31-study-redesign-route.png`에서 찾을 수 있다.

## 가입과 온보딩에서 검토할 부분

현재 경로를 스플래시, 계정 진입, 이메일 로그인·가입, 이메일 확인 안내, 닉네임, 급수, 조건부 가나 선택, 학습 목적, 알림 권한, 첫 홈 순으로 캡처했다. 비밀번호 재설정은 별도 경로로 기록했다. 캡처는 로컬 작업 폴더의 `harukoto-signup-flow-2026-11-24/`에 있다.

| 논의할 화면 | 현재 확인한 내용 | 제안 |
| --- | --- | --- |
| 계정 진입 · 이메일 가입 | 가입 폼과 세 소셜 로그인 버튼이 같은 화면에 있고 로그인 전환 링크는 폼 아래에 있다. `03-email-signup.png` | 소셜 로그인과 이메일 경로의 우선순위를 정하고, 이메일 가입·로그인의 제목과 전환 링크를 쉽게 찾을 수 있게 한다. |
| 가입 직후 | 이메일 안내가 가입 버튼 위 한 줄로 표시된다. `04-email-confirmation.png`는 확인 안내를 보여주는 프리뷰다. | 이메일을 확인한 뒤 앱으로 돌아와 로그인하는 순서를 명확히 안내한다. 실제 메일 수신과 링크 복귀는 별도 실기기 확인 항목이다. |
| 급수 선택 이후 | ‘첫걸음’에서만 가나 선택이 추가될 수 있다. 캡처의 가나 선택은 첫걸음 경로이고, 학습 목적은 N4 경로로 찍었다. 가나 제목 끝의 ‘요?’가 줄바꿈된다. `06-onboarding-level.png`–`08-onboarding-goal.png` | 경로별 단계 수를 어떻게 보여줄지 정하고, 가나 제목은 ‘가나부터 배워볼까요?’처럼 짧게 정리한다. |

가입 화면의 변경 범위는 황윤영님과 위 항목을 검토한 뒤 확정한다.

## 퀴즈 탭과 자유퀴즈 설정

`codex/mobile-redesign-quiz`에서 [퀴즈 탭](https://www.figma.com/design/y0vVcOVXYyJDDmF6VovDdG/Design?node-id=120-1070)과 [자유퀴즈 설정 시트](https://www.figma.com/design/y0vVcOVXYyJDDmF6VovDdG/Design?node-id=127-1993)를 적용했다.

- 퀴즈 탭에는 단어·문법·한자·리스닝·문장배열을 표시한다. ‘퀴즈 풀기’에서 단어·문법은 해당 유형으로 설정 시트를 열고 4지선다를 기본으로 선택한다. 문장배열은 바로 시작한다.
- ‘오늘의 기록’은 한국 시간 기준으로 오늘 완료한 퀴즈 전체의 문제 수와 정오답 수다. 탭을 바꿔도 같은 합계를 보여주며, 미완료 퀴즈의 답안은 이 카드의 집계에 포함되지 않는다. 홈의 학습일은 첫 답안부터 표시한다.
- 저장 퀴즈 카드는 원래 세션과 답안을 복원한다. 빈 목록에서는 카드를 숨기고, 불러오기 실패는 다시 시도할 수 있게 표시한다.
- 퀴즈 탭과 기록 메뉴는 피그마 원본 아이콘을 사용했다. 설정 시트의 문제 형식 아이콘은 앱의 기존 아이콘 세트를 사용했다.
- Flutter 전체 테스트 1,548개와 정적 분석을 통과했다. 테스트에는 저장 세션 복원, 퀴즈 완료 후 오늘의 기록 갱신, 320dp 화면과 2배 글자 크기가 포함된다.
- 375pt iOS 시뮬레이터에서 테스트 데이터로 확인했다. 로컬 캡처는 작업 폴더의 `harukoto-simulator-screenshots/32-quiz-redesign-top.png`와 `33-quiz-redesign-free-quiz-sheet.png`에 있다.

## 퀴즈 풀이와 결과

- [4지선다 풀이](https://www.figma.com/design/y0vVcOVXYyJDDmF6VovDdG/Design?node-id=242-4337)의 진행 바, 문제 번호, 선택지, 정오답 표시를 적용했다. 선택과 동시에 채점하고, 정오답과 해설을 다음 버튼 위에 보여준다. 매칭·빈칸·문장배열·직접 입력은 각 형식의 기존 풀이 방식으로 동작한다.
- [종료 확인](https://www.figma.com/design/y0vVcOVXYyJDDmF6VovDdG/Design?node-id=243-7939)은 왼쪽 ‘종료’, 오른쪽 ‘취소’ 순서다. 종료를 확인한 뒤 대기 중인 답안을 저장한다. 저장에 실패하면 풀이 화면에 남아 재시도할 수 있고, 취소하면 현재 문제로 돌아온다.
- [퀴즈 결과](https://www.figma.com/design/y0vVcOVXYyJDDmF6VovDdG/Design?node-id=244-8485)는 제출 결과의 정답률·정오답 수·경험치와 세션의 오답 목록을 보여준다. 오답을 펼쳐 발음을 듣거나 단어장에 저장할 수 있고, ‘오답 복습하기’는 해당 퀴즈의 오답으로 시작한다.
- Flutter 전체 테스트 1,551개와 정적 분석을 통과했다. 375pt iOS 시뮬레이터에서 테스트 답안 10개를 제출해 정답 8개, 오답 2개, 80 XP와 오답 목록을 확인했다. 로컬 캡처는 작업 폴더의 `harukoto-simulator-screenshots/`에서 `35-quiz-question.png`부터 `40-quiz-result-details.png`까지다.

## 마이페이지와 가나차트

- [마이페이지](https://www.figma.com/design/y0vVcOVXYyJDDmF6VovDdG/Design?node-id=154-1973)는 프로필·레벨 경험치, 학습 요약, ‘나의 학습 통계’, 학습 설정, 앱 설정, 고객센터, 계정 순으로 구성한다. 학습일·단어·누적 XP·최장 연속일은 기존 프로필 데이터에 연결한다. 설정은 기존 저장 경로를 사용하며, ‘나의 학습 통계’는 `/my/stats`로 이동한다.
- ‘앱 버전’은 iOS 번들과 Android 설치 패키지에서 버전·빌드 번호를 읽어 `1.0.0 (1)`처럼 표시한다. 설치 정보를 읽을 수 없는 환경은 `—`로 표시한다.
- [가나차트](https://www.figma.com/design/y0vVcOVXYyJDDmF6VovDdG/Design?node-id=232-3688)는 히라가나와 가타카나의 행·열 머리글에 일본어와 한글 읽기를 함께 표시한다. 글자 칸을 누르면 기존 상세·발음을 사용할 수 있다. `ん`과 `ン`은 모음 열 밖에 별도 행으로 표시한다. 한쪽 목록의 실패는 다른 탭에 영향을 주지 않는다.
- Flutter 테스트 1,558개를 통과했다. 375pt iOS 시뮬레이터에서 테스트 프로필로 JLPT 설정 시트 열기, 마이페이지에서 학습 통계로 이동한 뒤 돌아오기, 기본 글자 46개씩 있는 히라가나·가타카나 탭 전환을 확인했다. 로컬 캡처는 `harukoto-simulator-screenshots/`의 41~46번이다.

## 업데이트와 최신 main 통합 검증

- 로컬 테스트 서버에 연결한 iOS 시뮬레이터와 Android 에뮬레이터에서 기준 앱 `1.0.0 (1)`에 로그인한 뒤 통합 빌드 `15d36f81`의 테스트 버전 `1.0.7 (73)`을 덮어 설치했다. 두 기기에서 재로그인 없이 홈이 열렸다. iOS 첫 시도는 로그인 화면이 열렸고, 기준 앱을 다시 열어 세션 복원을 확인한 뒤 재실행한 검증은 통과했다. 첫 결과의 원인은 확인하지 못했다.
- 두 기기에서 단어 4/20·문법 3/10·문장배열 1/5, 달력의 학습일과 목표 달성 트로피, 저장한 2/5 문제를 3번부터 이어 풀기, 앱 설정의 `1.0.7 (73)` 표시를 확인했다. 캡처는 로컬 작업 폴더의 `harukoto-simulator-screenshots/upgrade-1.0.7-73/`에 있다.
- 이후 [실전회화 PR #247](https://github.com/WhiteMouseDev/HaruKoto/pull/247)이 병합된 `main`을 홈·통계 PR에 반영했다. 회화 소스와 리디자인의 변경 파일은 겹치지 않았다. 최신 `main`과 로컬 리디자인을 합친 `fc3ab2bf`의 정적 분석과 Flutter 테스트 1,572개가 통과했다. 회화 진입·준비·통화 도움·저장·계정별 진도·Live 전사 테스트를 포함한다. 실기기 발화 인식과 오디오 경로 전환은 확인이 남아 있다.
- `fc3ab2bf`를 양쪽 테스트 기기에 덮어 설치한 뒤에도 합성 로그인 세션이 복원됐다. Android에서는 실제 하단 탭으로 회화 허브를 열었고, iOS에서는 로컬 카탈로그의 지정 시나리오 세 개로 ‘도쿄 첫날’ 추천 카드를 띄웠다. 캡처는 `harukoto-simulator-screenshots/latest-main-conversation/`에 있다.

## 남은 리디자인 순서

가입·온보딩은 논의에서 결정한 순서로 진행한다.

## 피그마 재대조 후속 작업

- 4지선다 375×812 시안의 진행 바는 좌우 20dp, 상단 110dp, 높이 8dp다. ‘다음 문제’는 상단 730dp, 높이 48dp로 하단 안전 영역 바로 위에 배치한다. 답안을 선택하기 전에는 버튼의 비활성 상태를 유지한다. [4지선다 풀이 시안](https://www.figma.com/design/y0vVcOVXYyJDDmF6VovDdG/Design?node-id=242-4337)
- 기존 학습 탭에서 진입하는 레슨에 공통 헤더와 단계 표시를 적용했다. 개요의 급수·역·예상 시간·단어·문법은 레슨 데이터에 연결한다. 단어·문법 화면의 카드 안에서 항목을 이동하고, 마지막 항목에서 하단 다음 단계 버튼을 활성화한다. 레슨에서 하단 탭을 누르면 진행을 저장한 뒤 이동한다. [레슨 개요](https://www.figma.com/design/y0vVcOVXYyJDDmF6VovDdG/Design?node-id=278-5625) · [단어](https://www.figma.com/design/y0vVcOVXYyJDDmF6VovDdG/Design?node-id=319-5363) · [문법](https://www.figma.com/design/y0vVcOVXYyJDDmF6VovDdG/Design?node-id=325-7064)
- 대화 단계의 작업 중 시안에서 상황 안내, 실제 문장 개수, 화자와 듣기 버튼이 있는 문장 카드를 반영했다. 전체 듣기·번역·이해 체크로 이어지는 기존 기능도 사용할 수 있다. 이후 레슨 단계의 독립 프레임은 이 파일에서 확인되지 않았다. [대화 단계 작업 중 시안](https://www.figma.com/design/y0vVcOVXYyJDDmF6VovDdG/Design?node-id=325-7532)
- ‘학습한 단어’와 알림은 퀴즈의 메뉴 또는 마이페이지 설정 항목으로 확인됐다. 독립 화면 시안은 찾지 못했다. 회화는 퀴즈 예시 내용이 들어간 보류 프레임이다. [회화 보류 시안](https://www.figma.com/design/y0vVcOVXYyJDDmF6VovDdG/Design?node-id=127-2066)
- 375×812 iPhone 시뮬레이터에서 진행 바와 ‘다음 문제’의 좌표를 실측했다. 테스트 데이터로 기존 레슨 경로를 열어 학습 시작, 단어 5개 이동, 문법 단계 전환을 확인했다. 캡처는 작업 폴더의 `outputs/harukoto-figma-coverage-2026-11-24/`에 있다.

### 레슨 4단계 번역 ON·OFF

- 대화 전체에 공통 번역 스위치 하나를 사용한다. 기본값은 OFF다. ON이면 각 문장의 번역을 말풍선 안 구분선 아래에 표시한다. [번역 ON 시안](https://www.figma.com/design/y0vVcOVXYyJDDmF6VovDdG/Design?node-id=325-7532) · [번역 OFF 시안](https://www.figma.com/design/y0vVcOVXYyJDDmF6VovDdG/Design?node-id=333-8045)
- 상황 안내는 테두리형 카드로 표시한다. 화자에 따라 말풍선을 왼쪽·오른쪽에 놓고 각 문장의 발음 버튼을 말풍선 아래에 둔다. 전체 듣기는 상단에서 사용할 수 있다.
- 하단에 ‘이전’·‘다음학습’을 둔다. 문법이 없는 레슨에서는 ‘이전’에서 단어 단계로 돌아간다. 다음 단계를 준비하는 중에는 양쪽 버튼을 잠근다. 화면을 벗어나면 현재 레슨의 재생을 중지한다.

### 2026-11-27 피그마 재대조

최신 `main`의 `fe0e102a`와 Design의 Page 1을 대조했다. 아래는 `codex/mobile-lesson-practice-figma` 작업 상태다.

| 순서 | 피그마 화면 | 상태 |
| --- | --- | --- |
| 1 | [레슨 6단계 단어 매칭](https://www.figma.com/design/y0vVcOVXYyJDDmF6VovDdG/Design?node-id=349-6656) | 실제 단어·뜻으로 2열 카드를 구성했다. 선택·정답·오답을 구분하고, 모든 짝을 맞춘 뒤 ‘다음 학습’을 활성화한다. |
| 2 | [레슨 7단계 문장 배열](https://www.figma.com/design/y0vVcOVXYyJDDmF6VovDdG/Design?node-id=356-7427) | 지문, 답안 영역, 토큰 배치와 하단 버튼을 적용했다. 기존 해설은 ‘힌트 보기’로 열 수 있다. [정답](https://www.figma.com/design/y0vVcOVXYyJDDmF6VovDdG/Design?node-id=376-8133)과 [오답](https://www.figma.com/design/y0vVcOVXYyJDDmF6VovDdG/Design?node-id=376-8616) 시안의 토큰별 색상은 제출 전 채점 결과를 제공하는 서버 경로가 필요하다. |
| 3 | [레슨 결과](https://www.figma.com/design/y0vVcOVXYyJDDmF6VovDdG/Design?node-id=376-9192) | 피그마에서 ‘작업중’으로 표시된다. 앱의 기존 결과로 채점을 확인할 수 있다. |
| 4 | [이용약관](https://www.figma.com/design/y0vVcOVXYyJDDmF6VovDdG/Design?node-id=412-8548)·마이페이지 리마인더 | 약관 프레임과 리마인더 시간 컴포넌트를 앱에 반영했다. 세부 내용은 아래에 기록했다. |

레슨 진행 바는 피그마처럼 7단계까지 센다. 레슨 제출과 결과는 기존 서버 경로를 사용한다. 실전회화의 상황 선택·준비·통화, 가입·온보딩, 학습한 단어와 알림함은 Page 1에서 구현에 사용할 독립 화면을 확인하지 못했다. 가나 실습과 4지선다 이외 퀴즈 풀이도 기존 화면을 사용한다.

#### 리마인더 시간·이용약관·단어 매칭 보정

- 리마인더 시간은 가로 335pt, 기본 높이 308pt인 다이얼로그에서 오전·오후, 시, 분을 고른다. 선택된 숫자는 Pretendard 36/500, 나머지는 36/300이다. 저장 시 기존 기기 설정과 알림 예약을 갱신하고 취소하면 이전 시간을 유지한다. [리마인더 시간 시안](https://www.figma.com/design/y0vVcOVXYyJDDmF6VovDdG/Design?node-id=405-7330)
- 이용약관은 시행일, 조항 제목·본문·번호 목록, 마이페이지와 같은 사업자 정보 푸터, 하단 탭을 적용한다. 본문은 기존 전체 조항을 사용한다. [이용약관 시안](https://www.figma.com/design/y0vVcOVXYyJDDmF6VovDdG/Design?node-id=412-8548)
- 단어 매칭은 ‘대화 다시 보기’가 들어 있는 진행 바 영역의 높이를 고려해 이 단계의 상단 여백을 조정했다. 일본어는 Pretendard JP 15/600, 읽기는 12/400, 한국어 뜻은 Pretendard 14/500이다. 모두 자간 -2.5%를 사용한다. 라이트 테마의 맞춘 카드는 카드 전체에 시안의 50% 불투명도를 적용한다. [선택 시안](https://www.figma.com/design/y0vVcOVXYyJDDmF6VovDdG/Design?node-id=349-6656) · [완료 버튼 상태 시안](https://www.figma.com/design/y0vVcOVXYyJDDmF6VovDdG/Design?node-id=356-7245)
- 라이트 테마의 하단 내비게이션은 검정 4%, Y -4, blur 8, spread 0인 피그마 그림자를 사용한다. 리마인더의 ‘취소’와 ‘저장’은 48pt 버튼 안에서 Pretendard 글자 픽셀을 기준으로 1pt 위로 보정했다. [하단 내비게이션 컴포넌트](https://www.figma.com/design/y0vVcOVXYyJDDmF6VovDdG/Design?node-id=60-1317)

#### 학습 카드 여백

피그마의 학습 프레임에 달린 여백 코멘트 3개를 기준으로, 복습 설명에서 버튼까지 16pt, 추천 레슨 제목에서 표현 박스까지 12pt, 표현 박스에서 버튼까지 16pt를 적용했다. 버튼은 시안의 42pt 외형과 앱의 48pt 이상 터치 영역을 함께 유지한다. [학습 탭 시안](https://www.figma.com/design/y0vVcOVXYyJDDmF6VovDdG/Design?node-id=60-1790)
