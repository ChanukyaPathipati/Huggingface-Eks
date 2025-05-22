import pytest
from fastapi.testclient import TestClient
from serving.main import app

client = TestClient(app)

def test_status_initial():
    """Should return NOT_DEPLOYED when no model is loaded."""
    res = client.get("/status")
    assert res.status_code == 200
    assert res.json()["status"] == "NOT_DEPLOYED"

def test_get_model_initial():
    """Should return None or empty model_id when nothing is loaded."""
    res = client.get("/model")
    assert res.status_code == 200
    assert res.json()["model_id"] is None

def test_invalid_model_deploy():
    """Should return error status for invalid model."""
    res = client.post("/model", json={"model_id": "invalid_model_name"})
    assert res.status_code == 200
    assert res.json()["status"] == "error"

@pytest.mark.skip(reason="Only works after valid model deployment")
def test_completion():
    """Test inference after valid model deployment (requires gpt2)."""
    client.post("/model", json={"model_id": "gpt2"})
    res = client.post("/completion", json={"messages": [{"role": "user", "content": "Hello"}]})
    assert res.status_code == 200
    assert res.json()["status"] == "success"
    assert "response" in res.json()
