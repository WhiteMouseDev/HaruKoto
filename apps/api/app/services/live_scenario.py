from __future__ import annotations

from app.models import ConversationScenario


def scenario_feedback_context(scenario: ConversationScenario) -> str:
    return "\n".join(
        [
            f"タイトル: {scenario.title}",
            f"状況: {scenario.situation}",
            f"学習者の役割: {scenario.your_role}",
            f"会話相手の役割: {scenario.ai_role}",
            f"練習する表現: {', '.join(scenario.key_expressions or [])}",
        ]
    )


def build_live_scenario_instruction(scenario: ConversationScenario, jlpt_level: str) -> str:
    level_guidance = {
        "ABSOLUTE_ZERO": "入門者です。短い挨拶と基本表現を一文ずつ使い、困ったら短い韓国語のヒントを出してください。",
        "N5": "基本語彙とです・ます形を使い、一文ずつゆっくり話してください。",
        "N4": "基本的な日常表現を使い、一〜二文で話してください。",
        "N3": "自然な日常会話の表現を使い、二〜三文以内で話してください。",
        "N2": "状況に合う敬語と自然な表現を使ってください。",
        "N1": "自然な語彙と細かなニュアンスを含む会話にしてください。",
    }.get(jlpt_level, "基本的な表現を使い、一文ずつ話してください。")
    return "\n\n".join(
        [
            "あなたは韓国人の日本語学習者のロールプレイ相手です。選択された状況と役割に沿って日本語で会話してください。",
            scenario_feedback_context(scenario),
            scenario.system_prompt or "",
            f"学習者のJLPTレベル: {jlpt_level}\n{level_guidance}",
            "アプリのニックネームは、この場面で確認済みの本名や予約名ではありません。\n"
            "初対面の受付・店員などの役では、本人が名乗るまでは名前で呼ばず、必要なら名前を尋ねてください。\n"
            "会話中に本人が伝えた名前を優先し、アプリのニックネームで置き換えないでください。\n"
            "友人など既に知り合いという設定では、その関係に合う呼び方を使ってください。",
            "音声の会話だけを返し、JSONや説明文は読み上げないでください。質問は一度に一つにしてください。\n"
            "学習者の返答を待ち、ユーザーの役割を代わりに話さないでください。会話中の訂正は自然な言い換えに留めてください。\n"
            "[学習サポートのリクエスト] で意味や返答例を求められたときだけ、短い韓国語の説明を添えてください。\n"
            "最初はこの場面に合う挨拶から始めてください。電話の場面でなければ「もしもし」から始めないでください。",
        ]
    )


def build_live_scenario_greeting(scenario: ConversationScenario) -> str:
    return (
        f"[システム] ロールプレイを始めてください。あなたは「{scenario.ai_role}」です。"
        f"「{scenario.situation}」に合う最初の一言を話してください。"
    )
