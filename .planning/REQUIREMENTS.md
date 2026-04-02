# Requirements: HaruKoto Admin v1.1

**Defined:** 2026-03-30
**Core Value:** 원어민이 학습 데이터를 쉽고 빠르게 검증·수정할 수 있어야 한다

## v1.1 Requirements

### TTS Per-Field Audio

- [x] **TTS-03**: 단어 편집 화면에서 읽기/단어/예문 필드별로 개별 TTS 오디오를 생성할 수 있다
- [x] **TTS-04**: 필드별 오디오가 독립적으로 재생/재생성된다 (다른 필드에 영향 없음)
- [x] **TTS-05**: 기존 아이템당 1개 오디오 데이터가 마이그레이션 후에도 정상 동작한다

### Internationalization Completion

- [ ] **I18N-04**: 모든 UI 문자열이 i18n 키를 통해 번역된다 (하드코딩 일본어 없음)
- [ ] **I18N-05**: locale 전환 시 모든 텍스트가 선택된 언어로 표시된다

### Accessibility

- [x] **A11Y-01**: 사이드바 활성 항목에 aria-current="page"가 설정된다
- [x] **A11Y-02**: 메인 콘텐츠로 건너뛰는 skip link가 있다
- [x] **A11Y-03**: nav, aside, main에 의미 있는 aria-label이 있다
- [x] **A11Y-04**: 검색 입력에 명시적 label이 있다

## Future Requirements

- **BATCH-01**: TTS 일괄 재생성 (여러 항목 동시 재생성)
- **BATCH-02**: CSV/Excel 일괄 가져오기
- **AUX-01**: 키보드 단축키로 리뷰 큐 탐색 (J/K, A/R)
- **AUX-02**: 수정 전/후 비교(diff) 뷰

## Out of Scope

| Feature | Reason |
|---------|--------|
| 다크 모드 | 사용자 요청 없음, 작업량 대비 효과 낮음 |
| Admin content API 테스트 | 인프라 작업, 별도 처리 |
| 사용자 계정 관리 | 메인 앱 관할 |
| 결제/구독 관리 | 메인 앱 관할 |
| 모바일 반응형 | 데스크톱 전용 도구 |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| TTS-03 | Phase 6 | Not started |
| TTS-04 | Phase 6 | Not started |
| TTS-05 | Phase 6 | Not started |
| I18N-04 | Phase 8 (gap closure) | Pending |
| I18N-05 | Phase 8 (gap closure) | Pending |
| A11Y-01 | Phase 7 | Not started |
| A11Y-02 | Phase 7 | Not started |
| A11Y-03 | Phase 7 | Not started |
| A11Y-04 | Phase 7 | Not started |

**Coverage:**
- v1.1 requirements: 9 total
- Mapped to phases: 9
- Unmapped: 0

---
*Requirements defined: 2026-03-30 | Traceability updated: 2026-03-30*
