import os
from pathlib import Path

from scripts.report_n4_rollout_preflight import (
    AudioVerdictSummary,
    TtsCoverageSummary,
    _audio_verdict_coverage_blockers,
    _subprocess_env,
    _summarize_audio_verdicts,
    parse_args,
)


def test_summarize_audio_verdicts_reads_top_level_invalid_count() -> None:
    summary = _summarize_audio_verdicts(
        {
            "total_targets": 2,
            "pass_count": 1,
            "pending_count": 0,
            "flag_count": 0,
            "fail_count": 0,
            "waived_count": 0,
            "invalid_count": 1,
            "blockers": ["INVALID_VERDICTS: 1 target(s) have unsupported verdict values"],
        }
    )

    assert summary.invalid_count == 1
    assert not summary.passed


def test_audio_verdict_coverage_blocks_when_packet_targets_lag_tts_records() -> None:
    blockers = _audio_verdict_coverage_blockers(
        tts_coverage=TtsCoverageSummary(
            lesson_count=26,
            expected_total_records=234,
            generated_total_records=234,
            audio_urls_checked=234,
            audio_urls_failed=0,
            blockers=[],
            signals=[],
        ),
        audio_verdicts=AudioVerdictSummary(
            targets=189,
            pass_count=189,
            pending_count=0,
            flag_count=0,
            fail_count=0,
            waived_count=0,
            invalid_count=0,
            blockers=[],
        ),
    )

    assert blockers == ["AUDIO_QA_TARGET_MISMATCH: 189 verdict target(s) for 234 expected learner-facing TTS record(s)"]


def test_audio_verdict_coverage_passes_when_counts_match() -> None:
    blockers = _audio_verdict_coverage_blockers(
        tts_coverage=TtsCoverageSummary(
            lesson_count=21,
            expected_total_records=189,
            generated_total_records=189,
            audio_urls_checked=189,
            audio_urls_failed=0,
            blockers=[],
            signals=[],
        ),
        audio_verdicts=AudioVerdictSummary(
            targets=189,
            pass_count=189,
            pending_count=0,
            flag_count=0,
            fail_count=0,
            waived_count=0,
            invalid_count=0,
            blockers=[],
        ),
    )

    assert blockers == []


def test_subprocess_env_prepends_pnpm_bin_for_package_manager_commands(monkeypatch, tmp_path: Path) -> None:
    pnpm_bin = tmp_path / "node-bin"
    pnpm_bin.mkdir()
    pnpm_path = pnpm_bin / "pnpm"
    monkeypatch.setattr("scripts.report_n4_rollout_preflight.shutil.which", lambda name: str(pnpm_path) if name == "pnpm" else None)
    monkeypatch.setenv("PATH", os.pathsep.join(["/usr/local/bin", str(pnpm_bin)]))

    env = _subprocess_env(["pnpm", "--filter", "@harukoto/database", "curriculum:validate"])

    assert env is not None
    assert Path(env["PATH"].split(os.pathsep)[0]) == Path(pnpm_path).parent


def test_subprocess_env_leaves_non_pnpm_commands_unchanged() -> None:
    assert _subprocess_env(["python", "-m", "app.seeds.lessons"]) is None


def test_parse_args_accepts_explicit_audio_url_check_alias(monkeypatch) -> None:
    monkeypatch.setattr("sys.argv", ["report_n4_rollout_preflight.py", "--check-audio-urls"])

    args = parse_args()

    assert args.skip_audio_urls is False
