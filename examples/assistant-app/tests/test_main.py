import pytest
from fastapi.testclient import TestClient
from src.main import app

client = TestClient(app)

def test_health_check():
    """Test the health check endpoint"""
    response = client.get("/health")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "healthy"
    assert "timestamp" in data
    assert "version" in data

def test_root_endpoint():
    """Test the root endpoint"""
    response = client.get("/")
    assert response.status_code == 200
    data = response.json()
    assert "message" in data
    assert "version" in data
    assert "endpoints" in data

def test_ask_assistant():
    """Test the assistant question endpoint"""
    question_data = {
        "question": "What is the meaning of life?",
        "context": "philosophical"
    }
    
    response = client.post("/ask", json=question_data)
    assert response.status_code == 200
    
    data = response.json()
    assert "answer" in data
    assert "confidence" in data
    assert "processing_time" in data
    assert isinstance(data["confidence"], float)
    assert 0 <= data["confidence"] <= 1

def test_ask_assistant_required_field():
    """Test that question field is required"""
    response = client.post("/ask", json={})
    assert response.status_code == 422  # Validation error

def test_metrics_endpoint():
    """Test the metrics endpoint"""
    response = client.get("/metrics")
    assert response.status_code == 200
    data = response.json()
    assert "health_status" in data