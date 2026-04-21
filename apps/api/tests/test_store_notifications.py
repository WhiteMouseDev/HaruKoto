from app.services.store_notifications import acknowledge_store_notification


def test_acknowledge_store_notification_returns_apple_ack():
    ack = acknowledge_store_notification("apple", "signed-apple-payload")

    assert ack.ok is True
    assert ack.accepted is True
    assert ack.source == "apple"


def test_acknowledge_store_notification_returns_google_ack():
    ack = acknowledge_store_notification("google", "signed-google-payload")

    assert ack.ok is True
    assert ack.accepted is True
    assert ack.source == "google"
