from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from starlette_exporter import PrometheusMiddleware, handle_metrics
from transformers import pipeline, Pipeline
import asyncio

app = FastAPI()

app.add_middleware(PrometheusMiddleware)

@app.get("/metrics")
async def metrics():
    return await handle_metrics()

deployment_status = "NOT_DEPLOYED"
current_model_id = None
model_pipeline: Pipeline | None = None

class Message(BaseModel):
    role: str
    content: str

class CompletionRequest(BaseModel):
    messages: list[Message]

class ModelRequest(BaseModel):
    model_id: str

@app.post("/completion")
async def completion(request: CompletionRequest):
    global model_pipeline
    if not model_pipeline:
        raise HTTPException(status_code=503, detail="Model not deployed")

    try:
        input_text = request.messages[-1].content
        result = model_pipeline(input_text)[0]["generated_text"]
        return {
            "status": "success",
            "response": [{"role": "assistant", "message": result}]
        }
    except Exception as e:
        return {"status": "error", "message": str(e)}

@app.get("/status")
async def get_status():
    return {"status": deployment_status}

@app.get("/model")
async def get_model():
    return {"model_id": current_model_id}

@app.post("/model")
async def deploy_model(request: ModelRequest):
    global deployment_status, current_model_id, model_pipeline

    try:
        model_id = request.model_id
        deployment_status = "PENDING"

        await asyncio.sleep(1)
        deployment_status = "DEPLOYING"

        model_pipeline = pipeline("text-generation", model=model_id)
        current_model_id = model_id

        deployment_status = "RUNNING"
        return {"status": "success", "model_id": model_id}
    except Exception as e:
        deployment_status = "NOT_DEPLOYED"
        model_pipeline = None
        return {"status": "error", "message": str(e)}
