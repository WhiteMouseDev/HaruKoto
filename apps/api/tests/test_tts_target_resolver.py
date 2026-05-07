from __future__ import annotations

import uuid
from types import SimpleNamespace

import pytest

from app.services.tts_target_resolver import (
    TtsTargetResolverError,
    resolve_content_tts_text,
    resolve_kana_tts_text,
    resolve_vocabulary_reading_tts_target,
)


def test_resolve_vocabulary_reading_target_uses_server_reading() -> None:
    vocab = SimpleNamespace(id=uuid.uuid4(), word="学生", reading="がくせい")

    target = resolve_vocabulary_reading_tts_target(vocab)

    assert target.target_type == "vocabulary"
    assert target.target_id == str(vocab.id)
    assert target.field == "reading"
    assert target.text == "がくせい"


def test_resolve_vocabulary_reading_target_falls_back_to_word() -> None:
    vocab = SimpleNamespace(id=uuid.uuid4(), word="カメラ", reading="カメラ")

    assert resolve_vocabulary_reading_tts_target(vocab).text == "カメラ"


def test_resolve_content_tts_text_uses_first_grammar_example_sentence() -> None:
    grammar = SimpleNamespace(
        example_sentences=[{"japanese": "日本語の例文", "sentence": "fallback"}],
        pattern="文法パターン",
    )

    assert resolve_content_tts_text("grammar", "example_sentences", grammar) == "日本語の例文"


def test_resolve_kana_tts_text_rejects_kanji_vocabulary_word() -> None:
    with pytest.raises(TtsTargetResolverError) as exc_info:
        resolve_kana_tts_text("学生")

    assert exc_info.value.status_code == 422
    assert "히라가나/가타카나" in exc_info.value.detail


def test_resolve_kana_tts_text_rejects_fullwidth_latin() -> None:
    with pytest.raises(TtsTargetResolverError):
        resolve_kana_tts_text("Ａ")


def test_resolve_kana_tts_text_accepts_kana_text() -> None:
    assert resolve_kana_tts_text(" はじめまして ") == "はじめまして"
