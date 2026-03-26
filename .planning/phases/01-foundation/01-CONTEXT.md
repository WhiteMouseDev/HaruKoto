# Phase 1: Foundation - Context

**Gathered:** 2026-03-26
**Status:** Ready for planning

<domain>
## Phase Boundary

apps/admin Next.js 앱 스캐폴딩, Supabase Auth 기반 reviewer 인증 게이트, next-intl i18n(ja/ko/en), Vercel 배포. 로그인 + 대시보드 stub + 언어 전환까지 동작하는 최소 배포 가능 앱.

</domain>

<decisions>
## Implementation Decisions

### Login Page
- **D-01:** Minimal centered card 레이아웃 — neutral 배경 위 흰색 카드, logo-symbol.svg + "HaruKoto 管理者" 텍스트
- **D-02:** 로고 에셋은 apps/web/public/images/logo-symbol.svg를 재사용 (admin에 복사 또는 공유)
- **D-03:** 이메일/비밀번호 필드 — submit 시에만 검증 (실시간 검증 없음)

### App Shell & Tone
- **D-04:** Phase 1은 Header-only 레이아웃 — 사이드바 없음. Phase 2에서 사이드바 추가
- **D-05:** 헤더 구조: 좌측 로고/앱 이름, 우측 locale switcher + user info
- **D-06:** 톤앤매너: Hybrid warm-admin — neutral 구조 기반이지만 따뜻한 off-white/blush 톤, cherry-pink를 accent 3곳 제한이 아닌 좀 더 넓게 활용 (선택 상태, 주요 액션, empty state 등). UI-SPEC의 neutral-dominant 팔레트를 warm 방향으로 조정 필요
- **D-07:** 메인 콘텐츠 영역은 Phase 2 two-column(sidebar) 전환에 호환되도록 설계

### Post-login Dashboard
- **D-08:** Welcome 메시지 + placeholder cards — vocabulary/grammar/quiz/conversation 영역 표시 (Phase 2 콘텐츠 미리보기 구조)
- **D-09:** "こんにちは, [name]さん" 인사 + empty state cards ("コンテンツ一覧はフェーズ2で追加されます")

### Language Switcher
- **D-10:** 헤더 우측에 dropdown 배치 — 항상 접근 가능
- **D-11:** 네이티브 언어명으로 표시: "日本語 / 한국어 / English"
- **D-12:** next-intl without-routing mode (cookie-based locale, flat app/ dir) — 이미 결정됨

### Auth Error Handling
- **D-13:** 로그인 에러 (잘못된 자격증명, reviewer 역할 없음): 폼 아래 inline 에러 메시지
- **D-14:** 세션 만료/역할 폐기: 로그인 페이지로 리다이렉트 + "セッションが無効になりました" inline 메시지
- **D-15:** Supabase app_metadata.reviewer claim으로 역할 확인 — 이미 결정됨

### Claude's Discretion
- Turborepo apps/admin 스캐폴딩 세부 설정 (tsconfig, eslint, tailwind config 등)
- Supabase server/client 클라이언트 구조 (apps/web 패턴 참조)
- next-intl 메시지 파일 구조 및 번역 키 네이밍
- Vercel 배포 설정 (환경 변수, 도메인 등)
- proxy.ts (middleware 대체) 구현 세부사항

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Authentication
- `apps/web/src/lib/supabase/auth.ts` — getUser(), requireUser() 패턴 (admin에서 재사용)
- `apps/web/src/lib/supabase/server.ts` — Server-side Supabase 클라이언트 생성 패턴
- `apps/web/src/lib/supabase/client.ts` — Client-side Supabase 클라이언트 패턴
- `apps/web/src/lib/supabase/admin.ts` — Admin Supabase 클라이언트

### UI Design
- `.planning/phases/01-foundation/01-UI-SPEC.md` — Phase 1 UI 디자인 계약 (spacing, typography, color, copywriting). 단, D-06 톤앤매너 결정에 따라 color 팔레트는 warm-admin hybrid로 조정 필요
- `apps/web/public/images/logo-symbol.svg` — 로그인 페이지 로고 에셋

### Research
- `.planning/phases/01-foundation/01-RESEARCH.md` — Phase 1 기술 리서치 (auth, i18n, scaffold, deploy)

### Project
- `.planning/ROADMAP.md` — 전체 5 phase 로드맵
- `.planning/REQUIREMENTS.md` — v1 요구사항 24개 (Phase 1: AUTH-01~03, I18N-01~03)
- `CLAUDE.md` — 프로젝트 컨벤션 및 기술 스택

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `apps/web/src/lib/supabase/*` — Supabase 클라이언트 패턴 4파일 (server, client, auth, admin) → admin 앱에서 동일 구조 재사용
- `apps/web/src/components/ui/` — shadcn/ui 컴포넌트 (button, card, input, label, badge, dialog, dropdown-menu 등) → admin에서 별도 shadcn init 후 동일 컴포넌트 설치
- `apps/web/public/images/logo-symbol.svg` — 로고 에셋 → 로그인 페이지에 사용

### Established Patterns
- shadcn/ui new-york style + Radix UI 기반 → admin도 동일
- `@supabase/ssr` 서버사이드 인증 → admin에서도 동일 패키지 사용
- Tailwind CSS v4 + CSS variables → admin도 동일
- Noto Sans JP 폰트 → admin도 동일 (Next.js font optimization)

### Integration Points
- Turborepo `pnpm-workspace.yaml` — apps/admin 추가 필요
- `turbo.json` — admin 앱 빌드/dev 태스크 추가
- Supabase 프로젝트 — 동일 프로젝트 공유 (같은 DB, Auth)
- Vercel — 별도 프로젝트로 배포 (apps/admin)

</code_context>

<specifics>
## Specific Ideas

- 로고는 apps/web에 있는 logo-symbol.svg 재사용
- 톤앤매너는 Codex와 논의 후 hybrid warm-admin으로 결정 — 내부 도구이지만 친구들이 사용하므로 enterprise 느낌보다 따뜻하게
- Phase 1 헤더를 Phase 2 sidebar 추가 시 자연스럽게 확장 가능하도록 설계

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 01-foundation*
*Context gathered: 2026-03-26*
