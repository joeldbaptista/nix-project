from fastapi.testclient import TestClient

from fortune import __version__, cookies
from fortune.main import app

client = TestClient(app)


def test_health_reports_ok():
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json() == {"status": "ok"}


def test_root_reports_version():
    response = client.get("/")
    assert response.status_code == 200
    assert response.json()["version"] == __version__


def test_root_reports_a_commit():
    """The commit is 'unknown' outside the pipeline, but the key must always be present."""
    response = client.get("/")
    assert "commit" in response.json()


def test_root_reports_a_saying_from_the_database():
    response = client.get("/")
    saying = response.json()["saying"]
    assert saying in cookies.SAYINGS


def test_repeated_calls_eventually_differ():
    """The saying is drawn at random, so twenty calls must not all return the same one."""
    seen = {client.get("/").json()["saying"] for _ in range(20)}
    assert len(seen) > 1
