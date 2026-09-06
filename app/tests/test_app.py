from app import app


def test_health():
    client = app.test_client()
    assert client.get("/health").status_code == 200


def test_echo_truncates():
    client = app.test_client()
    resp = client.get("/echo?message=" + "a" * 500)
    assert len(resp.get_json()["message"]) == 200
