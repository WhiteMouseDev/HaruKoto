from app.services.chat_history import (
    append_chat_exchange,
    conversation_messages,
    count_conversation_messages,
    extract_conversation_history,
    message_list,
)


def test_message_list_filters_non_dict_messages():
    assert message_list(None) == []
    assert message_list([{"role": "system"}, "bad", 1, {"role": "user"}]) == [
        {"role": "system"},
        {"role": "user"},
    ]


def test_extract_conversation_history_keeps_system_prompt_and_chat_turns():
    history = extract_conversation_history(
        [
            {"role": "system", "content": "system"},
            {"role": "assistant", "content": "こんにちは"},
            {"role": "tool", "content": "ignored"},
            {"role": "user", "content": 123},
        ]
    )

    assert history.system_prompt == "system"
    assert history.history == [
        {"role": "assistant", "content": "こんにちは"},
        {"role": "user", "content": "123"},
    ]


def test_append_chat_exchange_and_count_conversation_messages():
    messages = append_chat_exchange(
        [{"role": "system", "content": "system"}],
        user_message="안녕",
        assistant_message="こんにちは",
    )

    assert messages == [
        {"role": "system", "content": "system"},
        {"role": "user", "content": "안녕"},
        {"role": "assistant", "content": "こんにちは"},
    ]
    assert conversation_messages(messages) == messages[1:]
    assert count_conversation_messages(messages) == 2
