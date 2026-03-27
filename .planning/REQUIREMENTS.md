# Requirements: HaruKoto Admin

**Defined:** 2026-03-26
**Core Value:** 원어민이 학습 데이터를 쉽고 빠르게 검증·수정할 수 있어야 한다

## v1 Requirements

### Authentication & Authorization

- [x] **AUTH-01**: Reviewer가 ID/PW로 어드민에 로그인할 수 있다
- [x] **AUTH-02**: Reviewer가 아닌 사용자는 어드민 페이지 접근이 차단된다
- [x] **AUTH-03**: Reviewer 역할이 폐기되면 즉시 접근이 차단된다 (DB 레벨 확인)

### Content Listing

- [x] **LIST-01**: Reviewer가 단어/어휘 목록을 페이지네이션으로 조회할 수 있다
- [x] **LIST-02**: Reviewer가 문법/문장 목록을 페이지네이션으로 조회할 수 있다
- [x] **LIST-03**: Reviewer가 퀴즈/문제 목록을 페이지네이션으로 조회할 수 있다
- [x] **LIST-04**: Reviewer가 회화 시나리오 목록을 페이지네이션으로 조회할 수 있다
- [x] **LIST-05**: Reviewer가 JLPT 레벨, 카테고리, 검증 상태로 데이터를 필터링할 수 있다
- [x] **LIST-06**: Reviewer가 텍스트 검색으로 특정 데이터를 찾을 수 있다
- [x] **LIST-07**: 각 항목에 검증 상태 뱃지(needs_review/approved/rejected)가 표시된다

### Content Editing

- [x] **EDIT-01**: Reviewer가 단어/어휘 데이터를 개별 수정할 수 있다 (일본어, 읽기, 뜻, 예문)
- [x] **EDIT-02**: Reviewer가 문법/문장 데이터를 개별 수정할 수 있다
- [x] **EDIT-03**: Reviewer가 퀴즈/문제 데이터를 개별 수정할 수 있다 (문제, 선택지, 정답, 해설)
- [x] **EDIT-04**: Reviewer가 회화 시나리오 데이터를 개별 수정할 수 있다

### Review Workflow

- [x] **REVW-01**: Reviewer가 개별 항목을 승인(approved) 또는 반려(rejected)할 수 있다
- [x] **REVW-02**: Reviewer가 여러 항목을 선택하여 일괄 승인/반려할 수 있다
- [x] **REVW-03**: 반려 시 사유를 입력할 수 있다
- [x] **REVW-04**: 모든 수정/승인/반려에 대한 이력(audit log)이 기록된다

### TTS Audio

- [x] **TTS-01**: Reviewer가 편집 화면에서 기존 TTS 오디오를 재생할 수 있다
- [x] **TTS-02**: Reviewer가 개별 항목의 TTS를 재생성 요청할 수 있다 (확인 다이얼로그 포함)

### Reviewer UX

- [x] **UX-01**: needs_review 항목을 순서대로 탐색하는 리뷰 큐(다음/이전)가 있다
- [x] **UX-02**: 대시보드에서 검증 진행률과 카테고리별 현황을 확인할 수 있다
- [x] **UX-03**: 새로 추가되거나 변경된 데이터에 대한 알림이 표시된다

### Internationalization

- [x] **I18N-01**: UI가 일본어를 기본 언어로 제공한다
- [x] **I18N-02**: UI 언어를 한국어로 전환할 수 있다
- [x] **I18N-03**: UI 언어를 영어로 전환할 수 있다

## v2 Requirements

### Batch Operations

- **BATCH-01**: TTS 일괄 재생성 (여러 항목 동시 재생성)
- **BATCH-02**: CSV/Excel 일괄 가져오기

### Advanced UX

- **AUX-01**: 키보드 단축키로 리뷰 큐 탐색 (J/K, A/R)
- **AUX-02**: 수정 전/후 비교(diff) 뷰
- **AUX-03**: 리뷰어 간 코멘트/토론 기능

## Out of Scope

| Feature | Reason |
|---------|--------|
| 사용자 계정 관리 | 메인 앱 관할 |
| 결제/구독 관리 | 메인 앱 관할 |
| AI 대화 실시간 테스트 | 복잡도 높음, 별도 마일스톤 |
| 학습 진도/통계 대시보드 | 메인 앱 기능 |
| 데이터 생성 (새 단어/문법 추가) | 초기에는 seed/migration으로 투입, 추후 고려 |
| 모바일 반응형 | 데스크톱 전용 도구, 1-3명 사용 |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| AUTH-01 | Phase 1 | Complete |
| AUTH-02 | Phase 1 | Complete |
| AUTH-03 | Phase 1 | Complete |
| I18N-01 | Phase 1 | Complete |
| I18N-02 | Phase 1 | Complete |
| I18N-03 | Phase 1 | Complete |
| LIST-01 | Phase 2 | Complete |
| LIST-02 | Phase 2 | Complete |
| LIST-03 | Phase 2 | Complete |
| LIST-04 | Phase 2 | Complete |
| LIST-05 | Phase 2 | Complete |
| LIST-06 | Phase 2 | Complete |
| LIST-07 | Phase 2 | Complete |
| EDIT-01 | Phase 3 | Complete |
| EDIT-02 | Phase 3 | Complete |
| EDIT-03 | Phase 3 | Complete |
| EDIT-04 | Phase 3 | Complete |
| REVW-01 | Phase 3 | Complete |
| REVW-02 | Phase 3 | Complete |
| REVW-03 | Phase 3 | Complete |
| REVW-04 | Phase 3 | Complete |
| TTS-01 | Phase 4 | Complete |
| TTS-02 | Phase 4 | Complete |
| UX-01 | Phase 5 | Complete |
| UX-02 | Phase 5 | Complete |
| UX-03 | Phase 5 | Complete |

**Coverage:**
- v1 requirements: 24 total
- Mapped to phases: 24
- Unmapped: 0 ✓

---
*Requirements defined: 2026-03-26*
*Last updated: 2026-03-26 — Traceability populated after roadmap creation*
