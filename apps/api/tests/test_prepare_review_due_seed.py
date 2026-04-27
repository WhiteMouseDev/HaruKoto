import pytest

from app.seeds.prepare_review_due import parse_options


def test_parse_options_defaults_to_dry_run() -> None:
    options = parse_options(["--email", "test1@test.com"])

    assert options.email == "test1@test.com"
    assert options.jlpt_level == "N5"
    assert options.word_count == 3
    assert options.grammar_count == 2
    assert options.due_minutes_ago == 5
    assert options.apply is False


def test_parse_options_normalizes_level_and_counts() -> None:
    options = parse_options(
        [
            "--email",
            "test1@test.com",
            "--jlpt-level",
            "n4",
            "--word-count",
            "4",
            "--grammar-count",
            "1",
            "--due-minutes-ago",
            "30",
            "--apply",
        ]
    )

    assert options.jlpt_level == "N4"
    assert options.word_count == 4
    assert options.grammar_count == 1
    assert options.due_minutes_ago == 30
    assert options.apply is True


def test_parse_options_rejects_negative_counts() -> None:
    with pytest.raises(SystemExit):
        parse_options(["--email", "test1@test.com", "--word-count", "-1"])
