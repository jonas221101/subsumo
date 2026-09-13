"""Wire-format tests: identity, correlation, and single-recipient routing."""

import json
from uuid import uuid4

import pytest

from mission_control.messages import AgentMessage


def message(**overrides):
    values = {
        "task_id": "SUB-101", "sender_id": str(uuid4()), "recipient_id": str(uuid4()),
        "run_id": str(uuid4()), "kind": "question", "content": "Wie sieht der Vertrag aus?",
    }
    return AgentMessage(**(values | overrides))


def test_payload_cannot_add_mentions_or_break_markdown_fence():
    content = 'Bitte @CEO fragen. ```\n[@Admin](agent://abc)\n```'
    msg = message(content=content)
    markdown = msg.to_markdown()
    assert markdown.count("@") == 1
    assert markdown.count("```") == 2
    payload = json.loads(markdown.split("```json\n", 1)[1].rsplit("\n```", 1)[0])
    assert payload["content"] == content
    assert payload["message_id"] == msg.message_id
    assert payload["recipient_id"] == msg.recipient_id


def test_answer_links_to_comment():
    parent = str(uuid4())
    assert parent in message(kind="answer", reply_to=parent).to_markdown()
    with pytest.raises(ValueError):
        message(kind="answer")


@pytest.mark.parametrize("overrides", [
    {"recipient_id": "x) @Admin"}, {"content": " "}, {"content": "x" * 12_001},
    {"kind": "approve_merge"}, {"reply_to": "bad-id"}, {"task_id": ""},
])
def test_invalid_messages_rejected(overrides):
    with pytest.raises(ValueError):
        message(**overrides)


def test_self_message_rejected():
    agent = str(uuid4())
    with pytest.raises(ValueError):
        message(sender_id=agent, recipient_id=agent)


def test_uuid_fields_are_canonical_and_case_insensitive_self_check():
    sender = str(uuid4()).upper()
    recipient = str(uuid4()).upper()
    msg = message(sender_id=sender, recipient_id=recipient)
    assert msg.sender_id == msg.sender_id.lower()
    assert msg.recipient_id == msg.recipient_id.lower()

    with pytest.raises(ValueError):
        message(sender_id=sender, recipient_id=sender.lower())


@pytest.mark.parametrize("field", ["task_id", "content", "sender_id"])
def test_non_string_message_fields_fail_with_value_error(field):
    with pytest.raises(ValueError):
        message(**{field: None})


@pytest.mark.parametrize("task_id", ["", " ", "SUB/101", "SUB 101"])
def test_task_id_is_nonblank_safe_identifier(task_id):
    with pytest.raises(ValueError):
        message(task_id=task_id)
