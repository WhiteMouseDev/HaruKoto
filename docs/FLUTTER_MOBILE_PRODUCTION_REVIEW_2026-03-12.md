# Flutter 모바일 실무 배포 기준 리뷰 (v2, 피드백 반영)
- 대상: `/apps/mobile`
- 리뷰 일시: 2026-03-12
- 실행 검증: `flutter analyze` 통과, `flutter test` 136개 통과

## 1. 프로젝트 한줄 총평
Feature-first + Riverpod + Repository 조합은 현재 규모에 적합하며, 핵심 결함(미정의 라우트/통계 하드코딩/침묵 예외)만 정리하면 실무 배포 신뢰도를 충분히 끌어올릴 수 있는 코드베이스입니다.

## 2. 강점
- 구조 방향성은 명확합니다.  
  `lib/features/{feature}/{data,providers,presentation}` 패턴이 대부분 유지됩니다.
- 공통 디자인 시스템 기반이 있습니다.  
  `lib/core/constants/colors.dart`, `lib/core/constants/sizes.dart`, `lib/core/theme/app_theme.dart`로 일관성 확보가 되어 있습니다.
- 인프라 레이어가 최소한 분리되어 있습니다.  
  `lib/core/network/dio_client.dart`, `lib/core/network/auth_interceptor.dart`, `lib/core/router/app_router.dart`
- 자원 해제 습관이 비교적 잘 잡혀 있습니다.  
  예: `AnimationController`, `TabController`, `ScrollController` 등을 `dispose`에서 정리.
- 모델 파싱 테스트는 잘 갖췄습니다.  
  테스트가 모델 중심이긴 하지만, JSON 파싱 안정성 자체는 신뢰할 수 있습니다.

## 3. 구조적 문제점
- `domain` 레이어 부재 자체는 결함이 아니라 선택입니다.  
  다만 현재는 `quiz_page.dart`, `kana_stage_page.dart`, `conversation_page.dart`처럼 화면에 로직이 몰려 있어 기능 확장 시 변경 전파가 커질 수 있습니다.
- 화면(StatefulWidget) 안에 유스케이스가 과도하게 들어가 있습니다.  
  예: [quiz_page.dart](/Users/kimkunwoo/WhiteMouseDev/japanese/apps/mobile/lib/features/study/presentation/quiz_page.dart), [kana_stage_page.dart](/Users/kimkunwoo/WhiteMouseDev/japanese/apps/mobile/lib/features/kana/presentation/kana_stage_page.dart), [conversation_page.dart](/Users/kimkunwoo/WhiteMouseDev/japanese/apps/mobile/lib/features/chat/presentation/conversation_page.dart)
- 라우터 단일 파일 구성은 Flutter 실무에서 흔한 패턴입니다.  
  다만 [app_router.dart](/Users/kimkunwoo/WhiteMouseDev/japanese/apps/mobile/lib/core/router/app_router.dart)에 라우트가 집중되어 있어 파일 성장 시 충돌 관리 규칙이 필요합니다.
- 라우팅 방식 혼용은 의도된 설계지만 운영 규칙이 필요합니다.  
  `GoRouter` + `Navigator.push` 혼용(`study_page.dart:32`, `recommend_tab.dart`, `resume_banner.dart`, `quiz_result_page.dart`)은 허용 가능하나, 딥링크/백스택 기준을 문서화하지 않으면 유지보수 비용이 증가합니다.
- 미사용/죽은 코드가 누적되고 있습니다.  
  `SecureStorageService`, `AppDurations`, `AppUser`가 실제 사용되지 않습니다.

## 4. 코드 품질 문제점
- 즉시 장애성 결함: 정의되지 않은 라우트 이동  
  [kana_quiz_page.dart:159](/Users/kimkunwoo/WhiteMouseDev/japanese/apps/mobile/lib/features/kana/presentation/kana_quiz_page.dart:159)에서 `context.go('/study/result?...')` 호출하지만, [app_router.dart](/Users/kimkunwoo/WhiteMouseDev/japanese/apps/mobile/lib/core/router/app_router.dart)에는 `/study/result` 라우트가 없습니다.
- 하드코딩된 더미 데이터가 실제 기능을 무력화합니다.  
  [stats_page.dart:74](/Users/kimkunwoo/WhiteMouseDev/japanese/apps/mobile/lib/features/stats/presentation/stats_page.dart:74)에서 `levelProgress`를 상수 0값으로 고정.
- `dynamic` 사용이 타입 안전성을 떨어뜨립니다.  
  [resume_banner.dart:8](/Users/kimkunwoo/WhiteMouseDev/japanese/apps/mobile/lib/features/study/presentation/widgets/resume_banner.dart:8), [payments_page.dart:18](/Users/kimkunwoo/WhiteMouseDev/japanese/apps/mobile/lib/features/my/presentation/payments_page.dart:18), [settings_menu.dart:9](/Users/kimkunwoo/WhiteMouseDev/japanese/apps/mobile/lib/features/my/presentation/widgets/settings_menu.dart:9)
- 예외를 삼키는 패턴이 많아 장애 분석이 어려워집니다.  
  예: [stats_repository.dart:28](/Users/kimkunwoo/WhiteMouseDev/japanese/apps/mobile/lib/features/stats/data/stats_repository.dart:28), [wordbook_page.dart:169](/Users/kimkunwoo/WhiteMouseDev/japanese/apps/mobile/lib/features/study/presentation/wordbook_page.dart:169), [quiz_result_page.dart:69](/Users/kimkunwoo/WhiteMouseDev/japanese/apps/mobile/lib/features/study/presentation/quiz_result_page.dart:69)
- 컨트롤러 라이프사이클 누수가 있습니다.  
  [wordbook_page.dart:99](/Users/kimkunwoo/WhiteMouseDev/japanese/apps/mobile/lib/features/study/presentation/wordbook_page.dart:99) 다이얼로그 컨트롤러 4개가 dispose되지 않음, [my_page.dart:191](/Users/kimkunwoo/WhiteMouseDev/japanese/apps/mobile/lib/features/my/presentation/my_page.dart:191) 컨트롤러가 저장 시에만 dispose됨.

## 5. 성능/안정성 이슈
- 월별 통계 API를 직렬 12회 호출합니다.  
  [stats_repository.dart:16](/Users/kimkunwoo/WhiteMouseDev/japanese/apps/mobile/lib/features/stats/data/stats_repository.dart:16)~31  
  네트워크 지연/실패 확률이 커지고, 일부 월 실패 시 조용히 누락됩니다.
- 대화 메시지 렌더링이 `ListView(children: [...map])` 방식입니다.  
  [conversation_page.dart:231](/Users/kimkunwoo/WhiteMouseDev/japanese/apps/mobile/lib/features/chat/presentation/conversation_page.dart:231)  
  메시지가 늘면 재빌드 비용이 급증합니다(`ListView.builder` 권장).
- 히트맵 계산이 매 build마다 중첩 탐색됩니다.  
  [heatmap_widget.dart:113](/Users/kimkunwoo/WhiteMouseDev/japanese/apps/mobile/lib/features/stats/presentation/widgets/heatmap_widget.dart:113)~123, 214~251  
  연산량이 커지고 hover/tap 시 불필요 연산이 반복됩니다.
- 2초 고정 스플래시 지연이 앱 시작 시간을 인위적으로 증가시킵니다.  
  [app_router.dart:346](/Users/kimkunwoo/WhiteMouseDev/japanese/apps/mobile/lib/core/router/app_router.dart:346)
  브랜딩/초기화 목적일 수 있으므로 제거 단정이 아니라 측정 기반(A/B) 최적화가 적절합니다.
- `await` 이후 `mounted` 체크 없는 `setState`가 다수 존재합니다.  
  예: [wordbook_page.dart:67](/Users/kimkunwoo/WhiteMouseDev/japanese/apps/mobile/lib/features/study/presentation/wordbook_page.dart:67), [learned_words_page.dart:75](/Users/kimkunwoo/WhiteMouseDev/japanese/apps/mobile/lib/features/study/presentation/learned_words_page.dart:75), [payments_page.dart:31](/Users/kimkunwoo/WhiteMouseDev/japanese/apps/mobile/lib/features/my/presentation/payments_page.dart:31)  
  빠른 뒤로가기/탭 전환 시 `setState() called after dispose()` 위험.
- 보안/안정성 관점에서는 입력 검증과 환경 유연성이 더 중요합니다.  
  Google OAuth client id([app_config.dart:8](/Users/kimkunwoo/WhiteMouseDev/japanese/apps/mobile/lib/core/constants/app_config.dart:8))는 비밀값이라기보다 공개 식별자이며, 실제 개선 포인트는 [login_page.dart:81](/Users/kimkunwoo/WhiteMouseDev/japanese/apps/mobile/lib/features/auth/presentation/login_page.dart:81), [wordbook_page.dart:154](/Users/kimkunwoo/WhiteMouseDev/japanese/apps/mobile/lib/features/study/presentation/wordbook_page.dart:154)의 입력 검증 보강입니다.

## 6. 테스트/유지보수성 평가
- 테스트는 모델 파싱에 편중되어 있습니다.  
  `test/features/**/data/models/*`는 풍부하지만,
  - Repository 테스트 없음
  - Provider/Notifier 테스트 없음
  - 실질 Widget 테스트 없음 (`widget_test.dart`는 렌더 smoke 수준)
- DI 구조는 부분적으로 가능하나(Provider override), 실제 비즈니스가 StatefulWidget에 몰려 테스트 진입점이 약합니다.
- 유지보수 관점에서 “기능 추가 시 기존 화면 대형 파일 수정”이 빈번해질 구조입니다.

## 7. 실무 협업 관점 평가
- 긍정적 요소
  - 파일명/클래스명 규칙은 대체로 일관적(snake_case, PascalCase)
  - Feature 단위 분리가 되어 신규 인력 온보딩은 빠른 편
- 리스크 요소
  - 핵심 라우터 단일 파일 집중 관리([app_router.dart](/Users/kimkunwoo/WhiteMouseDev/japanese/apps/mobile/lib/core/router/app_router.dart))
  - 페이지 비대화로 PR 단위가 커지고 리뷰 난이도 상승
  - 침묵 예외 처리 때문에 운영 장애시 원인 추적 시간 증가

## 8. 우선순위별 개선 과제
### 즉시 수정
- [app_router.dart](/Users/kimkunwoo/WhiteMouseDev/japanese/apps/mobile/lib/core/router/app_router.dart)에 `/study/result` 경로 추가 또는 [kana_quiz_page.dart](/Users/kimkunwoo/WhiteMouseDev/japanese/apps/mobile/lib/features/kana/presentation/kana_quiz_page.dart)에서 기존 `QuizResultPage`로 직접 이동하도록 수정
- [stats_page.dart](/Users/kimkunwoo/WhiteMouseDev/japanese/apps/mobile/lib/features/stats/presentation/stats_page.dart)의 하드코딩 `levelProgress` 제거, 실제 API/provider 연동
- `await` 이후 `setState` 구간에 `if (!mounted) return;` 적용(학습/결제/퀴즈 결과 페이지 우선)
- `catch (_) {}` 제거하고 공통 에러 핸들러로 사용자/로그 분리 처리
- 다이얼로그 TextEditingController 누수 수정(Wordbook/My)

### 단기 개선 (1~2 스프린트)
- 학습 리스트 3종(learned/wordbook/wrong) + 결제 내역에 공통 Pagination Controller 도입
- `StatsRepository.fetchHistory` 월별 직렬 호출 개선(서버 집계 API 또는 병렬/배치)
- `GoRouter`/`Navigator` 혼용 규칙 문서화(언제 무엇을 쓸지 명확화)
- `dynamic` 제거 및 타입 명시 모델 도입(`PaymentRecord`, `ResumeSession`)
- 기본 lint 강화(`unawaited_futures`, `avoid_dynamic_calls`, `strict-inference` 등)

### 중장기 개선
- 필요 시점(기능/팀 규모 증가)에 `application/domain/data/presentation` 단계적 도입
- 대형 페이지(Quiz/KanaStage/Conversation)를 `Controller(Notifier)` + View 조합으로 분리
- 통합 테스트(로그인-학습-결과-결제 흐름) 구축
- 네트워크 응답 표준화(`Result<T>`, 에러 코드 매핑, 재시도 정책)

## 9. 리팩토링 제안
### 폴더 구조 개선안
```text
lib/
  core/
    network/
    error/
    di/
  features/
    study/
      presentation/
      application/      # AsyncNotifier/Controller (필요 화면부터)
      domain/           # 팀/규모 증가 시 점진 도입
      data/             # DTO, RemoteDataSource, RepositoryImpl
```

### 상태관리 개선안
- 현재: StatefulWidget 내부에 API 호출/상태머신 집중
- 개선: 서버 상태(비동기/재시도/페이지네이션)는 `AsyncNotifier`로, 강한 로컬 UI 인터랙션은 StatefulWidget 유지
- 기대효과: 테스트 용이성, race condition 감소, 코드 재사용 증가

### 공통 컴포넌트 분리 제안
- `PaginatedFilterListScaffold` (검색/정렬/필터/페이지네이션 공통)
- `AppAsyncStateView` (loading/error/empty 공통 렌더)
- `AppFormDialog` (컨트롤러 생성/해제 포함)

### 네트워크/데이터 레이어 개선안
- `Result<T, AppFailure>` 형태로 에러를 명시화
- Repository에서 `response.data!` 직접 신뢰 제거(널/스키마 검증)
- Timeout/Retry 정책 중앙화(중요 API만 제한적 재시도)
- 응답 DTO와 UI 모델 분리(백엔드 변경 내성 확보)

## 10. 점수 평가
- 아키텍처: 76/100
- 코드 품질: 72/100
- 성능: 68/100
- 유지보수성: 74/100
- 테스트 가능성: 55/100
- 협업 적합성: 75/100
- 총점: 70/100

## 11. 결론
- 지금 당장 배포 가능한지  
  - 심각 결함(`/study/result`)과 통계 하드코딩/침묵 예외만 정리하면 배포 가능한 수준입니다. 현 상태는 “보완 후 배포”가 안전합니다.
- 어느 수준의 개발자가 작성한 코드처럼 보이는지  
  - UI/구조 일관성을 보면 “중급 후반~중상급”에 가깝습니다.
- 포트폴리오용으로 경쟁력이 있는지  
  - 충분히 경쟁력 있습니다. 다만 실무 신뢰도를 높이려면 라우팅 정합성, 예외 처리, 테스트 레이어 확장이 필요합니다.

---

## Before / After 예시 1: 라우트 불일치 수정
### Before
```dart
// kana_quiz_page.dart
context.go('/study/result?...');
```

### After (현 구조 최소 변경)
```dart
Navigator.of(context).pushReplacement(
  MaterialPageRoute(
    builder: (_) => QuizResultPage(
      result: QuizResultModel(
        accuracy: res.accuracy,
        correctCount: correct,
        totalQuestions: total,
        xpEarned: res.xpEarned,
        currentXp: res.currentXp,
        xpForNext: res.xpForNext,
      ),
      quizType: 'KANA',
      jlptLevel: 'N5',
      sessionId: _sessionId!,
    ),
  ),
);
```

## Before / After 예시 2: 반복 fetch 패턴 정리
### Before
```dart
Future<void> _fetchData() async {
  setState(() => _loading = true);
  final data = await repo.fetchWordbook(...);
  setState(() {
    _entries = data.entries;
    _loading = false;
  });
}
```

### After (AsyncNotifier)
```dart
@riverpod
class WordbookController extends _$WordbookController {
  @override
  Future<WordbookState> build(WordbookQuery q) async {
    final repo = ref.read(studyRepositoryProvider);
    final res = await repo.fetchWordbook(
      page: q.page,
      sort: q.sort,
      search: q.search,
      filter: q.filter,
    );
    return WordbookState.fromResponse(res);
  }
}
```

## Before / After 예시 3: 대화 목록 렌더 최적화
### Before
```dart
ListView(
  children: [
    ..._messages.map((m) => ChatBubble(...)),
  ],
)
```

### After
```dart
ListView.builder(
  controller: _scrollController,
  itemCount: _messages.length,
  itemBuilder: (context, index) {
    final m = _messages[index];
    return ChatBubble(
      role: m.role,
      messageJa: m.messageJa,
      messageKo: m.messageKo,
      feedback: m.feedback,
      showTranslation: _showTranslation,
    );
  },
)
```
