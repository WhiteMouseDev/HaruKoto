# N5/N4 PDF Curriculum Expansion Coverage Report - 2026-05-26

## Scope

This report connects the paid local PDF reference set to HaruKoto-owned
curriculum contracts and official lesson seeds. It stores only coverage
metadata. Source explanations, examples, and question text from the PDFs must
not be copied into HaruKoto lesson content.

ASSUMPTION: The PDF files are coverage anchors only. New lessons must use
newly authored dialogues, examples, prompts, and explanations.

ASSUMPTION: The target expansion size is a planning baseline, not a launch
commitment: N5 around 80 lessons and N4 around 90 lessons before claiming
broad N5/N4 course coverage.

## Source Check

| Metric | Value |
| --- | --- |
| PDF directory | `/Users/kimkunwoo/Downloads/japanese` |
| Inventory refs | 98 |
| PDF files found | 98 |
| Total pages | 124 |
| Missing inventory PDFs | 0 |
| Extra PDF files | 0 |

Page count distribution from the local PDF files:

| Pages | PDF files |
| --- | --- |
| 1 | 92 |
| 2 | 4 |
| 3 | 1 |
| 21 | 1 |

Inventory level tags:

| Level tag | PDF refs |
| --- | --- |
| ABSOLUTE_ZERO | 2 |
| BUSINESS | 2 |
| CONVERSATION | 17 |
| N2 | 1 |
| N3 | 25 |
| N4 | 54 |
| N5 | 49 |

A PDF can carry multiple level tags, so N5 and N4 counts are coverage tags
rather than mutually exclusive file counts.

## Current Official Lesson Footprint

| Level | Current chapters | Current lessons | Target chapters | Target lessons | Additional lessons | Primary grammar coverage | Vocabulary coverage |
| --- | --- | --- | --- | --- | --- | --- | --- |
| N5 | 9 | 50 | 12-15 | 80 | 30 | 39/60 (65%) | 184/609 (30.2%) |
| N4 | 4 | 16 | 14-18 | 90 | 74 | 15/49 (30.6%) | 65/944 (6.9%) |

## PDF-to-Lesson Coverage

Official seed coverage means a topic already maps to a current lesson or to
a grammar order used by current official lesson seeds. It does not replace
human curriculum review, audio QA, or target-app playback gates.

| Level | PDF refs | Official seed | Partial official | Seed candidate only | Blueprint only | Backlog only | High-priority gaps |
| --- | --- | --- | --- | --- | --- | --- | --- |
| N5 | 49 | 26 | 0 | 0 | 10 | 13 | 10 |
| N4 | 54 | 28 | 0 | 0 | 14 | 12 | 9 |

## Existing Expansion Contracts

| Contract | Rows |
| --- | --- |
| curriculum-topics.json | 98 |
| coverage-priorities.json | 40 |
| lesson-draft-blueprints.json | 54 |
| lesson-seed-candidates.json | 36 |

Priority queue summary:

| Priority / wave / status | Count |
| --- | --- |
| P0 / WAVE_1_N5_PATCH / missing | 11 |
| P0 / WAVE_1_N5_PATCH / partial | 11 |
| P1 / WAVE_2_N4_FOUNDATION / partial | 7 |
| P2 / WAVE_2_N4_FOUNDATION / missing | 1 |
| P2 / WAVE_4_REGISTER_BUSINESS / missing | 7 |
| P3 / WAVE_3_N3_PLUS / missing | 1 |
| P3 / WAVE_4_REGISTER_BUSINESS / missing | 2 |

## First High-Priority Gap Slice

| Level | PDF ref | Topic | State | Priority | Wave |
| --- | --- | --- | --- | --- | --- |
| N5 | 006 | 인칭대명사 | blueprint_only | P0 | WAVE_1_N5_PATCH |
| N5 | 011 | 인사말 | blueprint_only | P0 | WAVE_1_N5_PATCH |
| N5 | 012 | 숫자・조수사 | blueprint_only | P0 | WAVE_1_N5_PATCH |
| N5 | 013 | 시간・요일 | blueprint_only | P0 | WAVE_1_N5_PATCH |
| N5 | 014 | おねがいします | blueprint_only | P0 | WAVE_1_N5_PATCH |
| N5 | 017 | 한자 읽는 법 | blueprint_only | P0 | WAVE_1_N5_PATCH |
| N5 | 044 | 알다 | blueprint_only | P0 | WAVE_1_N5_PATCH |
| N5 | 045 | ほしい | blueprint_only | P0 | WAVE_1_N5_PATCH |
| N5 | 084 | と | blueprint_only | P1 | WAVE_2_N4_FOUNDATION |
| N5 | 087 | と | blueprint_only | P1 | WAVE_2_N4_FOUNDATION |
| N4 | 035 | の | blueprint_only | P0 | WAVE_1_N5_PATCH |
| N4 | 043 | 진행과 상태 | blueprint_only | P0 | WAVE_1_N5_PATCH |
| N4 | 044 | 알다 | blueprint_only | P0 | WAVE_1_N5_PATCH |
| N4 | 045 | ほしい | blueprint_only | P0 | WAVE_1_N5_PATCH |
| N4 | 058 | くなる・になる | blueprint_only | P0 | WAVE_1_N5_PATCH |
| N4 | 062 | な | blueprint_only | P1 | WAVE_2_N4_FOUNDATION |
| N4 | 077 | にする | blueprint_only | P0 | WAVE_1_N5_PATCH |
| N4 | 085 | という | blueprint_only | P0 | WAVE_1_N5_PATCH |
| N4 | 099 | もの | blueprint_only | P1 | WAVE_2_N4_FOUNDATION |

## Recommended Parallel Workstreams

1. Source inventory refresh: verify every `pdfRef` still maps to one local PDF
   and update only topic metadata, never copied examples.
2. Coverage matrix closeout: split high-priority N5 gaps into official lesson
   slots and decide which existing seed candidates can be promoted.
3. N4 expansion architecture: grow N4 from pilot coverage into a full foundation
   sequence before marketing it as covered.
4. Candidate authoring: generate chapter-sized seed candidates in disjoint
   files, then run candidate review and TTS readiness gates.
5. Human review closeout: keep `lesson-human-review` and audio QA verdicts as
   rollout gates, not as optional polish.

## Reproduction

```bash
pnpm --filter @harukoto/database curriculum:lesson-expansion:report -- \
  --pdf-dir ~/Downloads/japanese \
  --markdown-output docs/operations/plans/n5-n4-pdf-curriculum-expansion-2026-05-26.md
```
