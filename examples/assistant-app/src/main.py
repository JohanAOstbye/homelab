from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from typing import Optional
import logging
import time
import random

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(
    title="AI Assistant API",
    description="A simple AI assistant for homelab demonstration",
    version="1.0.0"
)

# Request/Response models
class QuestionRequest(BaseModel):
    question: str
    context: Optional[str] = None

class AssistantResponse(BaseModel):
    answer: str
    confidence: float
    processing_time: float

# Simple responses for demo
RESPONSES = [
    "That's an interesting question! Let me think about it.",
    "Based on my knowledge, I would say...",
    "Great question! Here's what I think:",
    "I'd be happy to help with that!",
    "Let me provide some insights on that topic.",
]

@app.get("/health")
async def health_check():
    """Health check endpoint for Kubernetes probes"""
    return {
        "status": "healthy",
        "timestamp": time.time(),
        "version": "1.0.0"
    }

@app.get("/")
async def root():
    """Root endpoint with API information"""
    return {
        "message": "AI Assistant API",
        "version": "1.0.0",
        "endpoints": {
            "health": "/health",
            "ask": "/ask (POST)",
            "metrics": "/metrics"
        }
    }

@app.post("/ask", response_model=AssistantResponse)
async def ask_assistant(request: QuestionRequest):
    """Ask the assistant a question"""
    start_time = time.time()
    
    try:
        logger.info(f"Received question: {request.question}")
        
        # Simulate processing time
        processing_delay = random.uniform(0.1, 0.5)
        time.sleep(processing_delay)
        
        # Generate a response (in a real app, this would use an AI model)
        answer = f"{random.choice(RESPONSES)} Regarding '{request.question}', " \
                f"this is a demo response from the homelab assistant."
        
        confidence = random.uniform(0.7, 0.95)
        processing_time = time.time() - start_time
        
        logger.info(f"Generated response with confidence: {confidence:.2f}")
        
        return AssistantResponse(
            answer=answer,
            confidence=confidence,
            processing_time=processing_time
        )
        
    except Exception as e:
        logger.error(f"Error processing question: {str(e)}")
        raise HTTPException(status_code=500, detail="Internal server error")

@app.get("/metrics")
async def get_metrics():
    """Simple metrics endpoint (in production, use Prometheus metrics)"""
    return {
        "requests_total": "counter_would_go_here",
        "response_time_avg": "histogram_would_go_here",
        "health_status": "healthy"
    }

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)