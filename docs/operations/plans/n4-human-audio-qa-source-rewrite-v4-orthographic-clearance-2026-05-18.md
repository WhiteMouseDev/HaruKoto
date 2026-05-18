# N4 Source Rewrite v4 Orthographic Clearance

> Status: APPLY-READY
> Scope: HN4-006 script:1 final residual FLAG
> Boundary: delegated AI/STT audio QA only; not native-speaker review

ASSUMPTION: The project owner delegated this final audio QA judgment because no human/native-speaker reviewer is currently available.

## Decision

HN4-006 script:1 can be cleared to `PASS`.

- Source text: `この川の浅さがわかります。`
- STT transcript: `この川の浅さが分かります。`
- Audio URL: `https://storage.googleapis.com/harukoto-storage/tts/lesson/94d8d321-17c6-4fa1-8c50-af29c08e9c22/script-line-1-regen-20260518T080500Z.mp3`
- Rationale: `わかります` and `分かります` are kana/kanji orthographic variants of the same spoken word. The MP3 probe passed, and the transcript preserves the full sentence, grammar target, and meaning.

## Apply Command

```bash
uv run python scripts/apply_n4_audio_qa_verdicts.py --csv-input ../../docs/operations/plans/n4-human-audio-qa-source-rewrite-v4-orthographic-clearance-2026-05-18.csv --write
```
