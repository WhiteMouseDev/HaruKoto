# Mobile Learn List Redesign

Date: 2026-05-07

## Context

Claude Code produced a learning-list redesign in
`/Users/kimkunwoo/Downloads/HaruKoto_Mobile/HaruKoto Learn Screen Redesign.html`.
The useful direction is the `Path of Stones` concept: the lesson list should
make the learner's current position and next action obvious, instead of showing
chapters as separate flat cards.

## Decision

Adopt the direction as an incremental mobile UI change, not as a full app
theme rewrite.

- Add a top continue banner for the recommended lesson.
- Make the chapter list feel like a vertical path.
- Restyle lesson rows as compact stateful "stones".
- Keep the existing Sakura, mint, purple, and neutral color system.
- Keep the current lesson data model, telemetry, and routing contracts.

ASSUMPTION: The first implementation does not introduce chapter locking.
The Claude design proposed locked chapters when previous chapters are
incomplete, but that changes the learning policy. For now, not-started
chapters remain available and are only visually quieter.

## Scope

Affected mobile files:

- `apps/mobile/lib/features/study/presentation/lesson_list_page.dart`
- `apps/mobile/lib/features/study/presentation/study_page.dart`
- `apps/mobile/lib/features/study/presentation/widgets/lesson_continue_banner.dart`
- `apps/mobile/lib/features/study/presentation/widgets/lesson_chapter_list.dart`
- `apps/mobile/lib/features/study/presentation/widgets/lesson_chapter_card.dart`
- `apps/mobile/lib/features/study/presentation/widgets/lesson_tile.dart`
- Related widget tests for study and lesson-list screens.

Out of scope:

- Chapter lock gating.
- API or database changes.
- New production dependencies.
- App-wide typography or color-token migration.
- Bonus-track or milestone node types.

## Rollout

1. Replace the standalone lesson-list intro with a header plus continue banner.
2. Reuse the same continue banner on the study home recommendation card.
3. Restyle chapter cards with a left path node and clearer active/done/idle
   states.
4. Restyle lesson rows with icon-first states and a single next-action pill.
5. Validate by widget tests, formatter, analyzer, and mobile tests.

## Acceptance Criteria

- The recommended lesson is visible once as the main entry point at the top.
- The same recommended lesson can still appear inside the chapter list, but as
  location/context rather than a second large CTA.
- Completed, perfect, in-progress/recommended, and not-started lessons differ
  by icon shape before color.
- Existing telemetry events keep the same names and properties.
- Existing lesson tap routing remains `/study/lessons/:id`.
