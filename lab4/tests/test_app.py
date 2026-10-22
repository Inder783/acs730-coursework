from app import app


def test_homepage():
    client = app.test_client()
    response = client.get("/")
    assert response.status_code == 200
    assert b"ACS730 Lab 4" in response.data


def test_healthz_status():
    client = app.test_client()
    response = client.get("/healthz")
    assert response.status_code == 200
    assert response.json["status"] == "ok"


def test_healthz_version():
    client = app.test_client()
    response = client.get("/healthz")
    assert response.json["version"] == "dev"
