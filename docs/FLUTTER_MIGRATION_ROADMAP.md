# Flutter 네이티브 앱 전환 로드맵

> 현재 Next.js 웹앱 → Flutter 네이티브 앱으로의 전환 전략 및 타이밍 가이드.
> 지금 당장 실행하는 문서가 아니라, 시점별 의사결정을 위한 참조 문서.

---

## 1. 전환 전략: 업계는 어떻게 하는가?

### Big Bang (전체 재작성)

한번에 Flutter로 전부 새로 만들고, 완성되면 기존 앱을 교체하는 방식.

| 사례 | 설명 |
|------|------|
| **BMW** | 45개국 앱 변형을 Flutter 단일 코드베이스로 전면 재작성. 수백 명의 엔지니어 투입. |

**장점:** 깔끔한 아키텍처, 레거시 부채 없음
**단점:** 수개월 기능 개발 중단, 실패 리스크 높음, 대규모 팀/예산 필요

→ **소규모 팀에는 비현실적.** BMW처럼 대기업 수준의 인력/예산이 있어야 가능.

### Incremental (점진적 전환) — 업계 표준

기존 앱을 유지하면서, 새 기능이나 핵심 화면부터 Flutter로 하나씩 교체.

| 사례 | 설명 |
|------|------|
| **알리바바 (Xianyu)** | 5억+ 유저. Flutter Boost 오픈소스를 만들어 기존 네이티브 앱에 Flutter 화면을 WebView처럼 삽입. 고우선순위 화면부터 점진 교체. |
| **Nubank** | 1억+ 유저. 신규 기능은 전부 Flutter, 기존 React Native 기능은 여력 될 때 마이그레이션. 12~18개월 예상 → 수년째 진행 중. |
| **Google Pay** | 결제 플로우를 Flutter로 먼저 전환, 부가 화면은 이후 순차 교체. |

**장점:** 제품 개발 멈추지 않음, 리스크 분산, 팀이 Flutter를 실전에서 학습 가능
**단점:** 2~3개 기술 스택 동시 유지, 네비게이션 복잡도 증가, 완전 전환까지 오래 걸림

→ **하루코토에 적합한 전략.** 아래 상세 설명.

---

## 2. 전환 패턴 3가지

### 패턴 A: WebView 하이브리드 (가장 빠름)

Flutter 앱 껍데기 안에 기존 Next.js 웹앱을 `webview_flutter`로 감싸는 방식.

```
Flutter Shell (bottom nav, push 알림, 앱스토어)
  └── WebView → 기존 Next.js 웹앱
       └── 점진적으로 WebView 화면을 Flutter 네이티브 화면으로 교체
```

- **장점:** 앱스토어 출시까지 1~2주, 기능 손실 없음
- **단점:** 성능 떨어짐 (애니메이션, 스크롤), 유저가 "웹뷰"임을 느낌, 앱스토어 리젝 위험
- **판단:** 학습 앱은 부드러운 인터랙션이 중요하므로 **장기 전략으로는 부적합.** 단, 앱스토어 빠른 진입이 필요할 때 브릿지 전략으로는 유효.

### 패턴 B: 별도 Flutter 앱 + 공유 백엔드 (추천)

Flutter 앱을 완전히 별도 프로젝트로 만들되, 백엔드(Supabase)를 공유.

```
[Next.js 웹앱] ──┐
                  ├── Supabase (동일 프로젝트, 동일 테이블, 동일 RLS)
[Flutter 앱]   ──┘    └── API Routes (Next.js) — Flutter에서 HTTP 호출
```

- **장점:** 아키텍처가 깔끔, 양쪽 독립적으로 개발/배포 가능
- **단점:** UI 코드는 100% 새로 작성, 기능 패리티 달성까지 시간 소요
- **판단:** **하루코토에 가장 적합.** Supabase가 Flutter를 1등 시민으로 지원하므로 백엔드 변경 불필요.

### 패턴 C: Add-to-App (알리바바 방식)

기존 네이티브 앱 안에 Flutter 모듈을 하나씩 삽입. → 우리는 네이티브 앱이 없으므로 해당 없음.

---

## 3. 언제 전환해야 하는가?

"바텀 네비부터 Flutter로 옮기고, 그 다음 로그인..." 이런 식의 점진 교체는 **웹 → Flutter에서는 불가능**하다. (Flutter를 Next.js 페이지 안에 삽입할 수 없음.) 따라서 Flutter 앱은 별도로 만들고, 기능 패리티가 충분해지면 유저를 이동시키는 방식.

### 유저 규모별 전략

| 단계 | 유저 수 | 전략 |
|------|---------|------|
| **PMF 검증** | 0 ~ 1K | 웹앱에 집중. Flutter 시작하지 않음. |
| **초기 성장** | 1K ~ 10K | PWA 강화 (오프라인 캐시, 홈화면 추가). Flutter 프로토타이핑/학습 시작. |
| **성장 궤도** | 10K ~ 50K | Flutter MVP 착수 (인증 + 핵심 학습 플로우). 앱스토어 출시. |
| **스케일업** | 50K ~ 100K | Flutter 기능 패리티 확보. 웹은 SEO/유입용으로 유지. |
| **안정기** | 100K+ | 네이티브 앱이 메인. 웹은 랜딩/SEO 전용. |

### 전환 시점을 알려주는 신호

- 유저가 "앱 없나요?" 질문을 반복
- 모바일 웹 세션이 전체의 50% 이상
- PWA 설치율이 5% 이상
- 경쟁 앱이 네이티브이고, UX에서 밀리고 있음
- 푸시 알림이 리텐션에 결정적 영향을 줄 것으로 예상
- 웹 모바일 성능 최적화에 시간을 과도하게 쓰고 있음

---

## 4. 기술 매핑: Next.js → Flutter

### 그대로 재사용 가능 (변경 없음)

| 항목 | 설명 |
|------|------|
| **Supabase** | `supabase_flutter` 패키지로 동일 프로젝트 연결. Auth, DB, RLS, Realtime 전부 동일. |
| **Next.js API Routes** | Flutter에서 `dio`/`http` 패키지로 동일 엔드포인트 호출. |
| **DB 스키마/RLS** | 변경 불필요. |

### 새로 구현해야 하는 것

| Next.js (Web) | Flutter 대응 | 비고 |
|---------------|-------------|------|
| React 컴포넌트 (JSX) | Flutter Widget (Dart) | UI 전체 재작성 |
| Tailwind CSS | Flutter ThemeData + 커스텀 스타일 | 멘탈 모델은 유사 |
| shadcn/ui | Flutter 패키지 or 커스텀 위젯 | 직접 대응 없음 |
| Zustand | **Riverpod 3** (추천) | 가장 유사한 철학 |
| TanStack Query | Riverpod AsyncNotifier | 캐싱/로딩/에러 패턴 유사 |
| React Hook Form + Zod | `flutter_form_builder` + `formz` | 패러다임 다르지만 동등 |
| next-themes | Flutter ThemeMode | Flutter에서 더 간단 |
| Framer Motion | Flutter AnimationController / `flutter_animate` | Flutter 애니메이션이 더 강력 |
| App Router | `go_router` | Flutter 표준 라우팅 |

### 상태 관리 매핑: Zustand → Riverpod

```typescript
// Zustand (현재)
const useUserStore = create((set) => ({
  user: null,
  setUser: (user) => set({ user }),
}));

// 컴포넌트에서
const user = useUserStore((s) => s.user);
```

```dart
// Riverpod (Flutter)
@riverpod
class UserNotifier extends _$UserNotifier {
  @override
  User? build() => null;

  void setUser(User user) => state = user;
}

// 위젯에서
final user = ref.watch(userNotifierProvider);
```

### Flutter에서 어려운 것

- **SEO:** Flutter Web은 SEO가 약함 → 웹(Next.js)은 SEO/유입용으로 계속 유지
- **SSR/Server Components:** Flutter에는 없음 → 전부 클라이언트 렌더링
- **리치 텍스트/마크다운:** Flutter 지원이 웹보다 미성숙

---

## 5. 마이그레이션 로드맵 (하루코토 기준)

### Phase 0: 준비 (2~4주)

- [ ] Flutter 프로젝트 셋업 (모노레포 내 `apps/mobile/` 또는 별도 레포)
- [ ] Supabase Flutter 클라이언트 연동 (동일 프로젝트)
- [ ] CI/CD 파이프라인 구축 (GitHub Actions → App Store/Play Store)
- [ ] 디자인 토큰 정의 (현재 Tailwind 테마를 Flutter ThemeData로 변환)
- [ ] 상태 관리 결정 (Riverpod 3 추천)
- [ ] `go_router` 라우팅 구조 설계

### Phase 1: 인증 + 네비게이션 쉘 (2~4주)

- [ ] 로그인/회원가입 (Supabase Auth → 카카오, 구글 OAuth)
- [ ] 온보딩 플로우
- [ ] 바텀 네비게이션 쉘
- [ ] 기본 라우팅 (홈, 학습, 회화, 마이)
- [ ] 라이트/다크 테마

→ 앱이 설치 가능하지만 실제 기능은 없는 "뼈대" 상태.

### Phase 2: 핵심 학습 플로우 (4~8주)

- [ ] 퀴즈 (4지선다, 매칭, 빈칸, 어순, 쓰기)
- [ ] 가나 학습
- [ ] 학습 결과 화면
- [ ] 데일리 프로그래스

→ **유저가 Flutter 앱에서 핵심 가치(학습)를 경험할 수 있는 최소 단위.** 이 단계에서 앱스토어 출시.

### Phase 3: 부가 기능 (4~12주)

- [ ] 홈 대시보드 (스트릭, 주간 차트, 퀵스타트)
- [ ] AI 회화 (채팅 + 음성통화)
- [ ] 마이페이지 (프로필, 설정, 업적)
- [ ] 푸시 알림 (네이티브 — 웹보다 훨씬 강력)
- [ ] 단어장

### Phase 4: 네이티브 고유 기능 (지속)

- [ ] 오프라인 모드 (SQLite via `drift` 패키지)
- [ ] 햅틱 피드백
- [ ] 홈 화면 위젯 (오늘의 단어 등)
- [ ] App Store Optimization (ASO)
- [ ] 딥링크

### Phase 5: 안정화 + 역할 분리

- 웹 (Next.js): SEO, 랜딩, 신규 유저 유입 채널
- 앱 (Flutter): 리텐션, 핵심 학습 경험, 푸시 알림

---

## 6. 예상 소요 기간

| 범위 | 1인 개발 | 2~3인 팀 |
|------|----------|----------|
| Phase 0~1 (뼈대) | 4~6주 | 2~4주 |
| Phase 2 (핵심 플로우) | 6~10주 | 4~6주 |
| Phase 3 (부가 기능) | 8~16주 | 4~8주 |
| 전체 기능 패리티 | 6~9개월 | 3~5개월 |

> **Nubank의 교훈:** 12~18개월로 예상했으나 수년째 진행 중. "꼬리가 긴 작은 기능들"이 예상보다 많다. 100% 패리티보다는 80% 패리티에서 출시하고 나머지는 점진적으로.

---

## 7. 하루코토 현재 상황 기준 권장 사항

1. **지금은 Flutter 전환하지 않는다.** PMF 검증과 유저 확보에 집중.
2. **PWA를 먼저 강화한다.** `manifest.json`, 서비스 워커, 오프라인 단어 캐시 — 1~2주 투자로 앱 수준 경험 제공 가능.
3. **Flutter 학습은 지금부터 시작해도 좋다.** Dart 문법, Riverpod, Widget 시스템 익히기.
4. **전환 트리거:** 모바일 웹 세션 50%+ & 유저 5K~10K & "앱 어디서 다운받아요?" 질문 반복 시.
5. **전환 시 Supabase가 최대 자산.** 백엔드 변경 없이 Flutter 클라이언트만 추가하면 됨.

---

## 참고 자료

- [BMW Flutter 사례](https://flutter.dev/showcase/bmw)
- [Nubank Flutter 전환 블로그](https://building.nubank.com/scaling-with-flutter/)
- [알리바바 Flutter Boost](https://github.com/alibaba/flutter_boost)
- [Flutter Add-to-App 공식 문서](https://docs.flutter.dev/add-to-app)
- [Supabase Flutter 클라이언트](https://supabase.com/docs/guides/getting-started/quickstarts/flutter)
- [Riverpod 공식 문서](https://riverpod.dev/)
