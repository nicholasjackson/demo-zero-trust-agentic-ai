"""Simple FastAPI server to run the LangGraph agent.

This is a minimal open-source alternative to the LangSmith Agent Server.
For production use with persistence, you would add:
- PostgreSQL checkpointing
- Redis for state management
- Thread/conversation management
"""

import os
import traceback
import logging
from typing import Optional
from fastapi import FastAPI, Header
from fastapi.responses import JSONResponse
import uvicorn
from config import Config
from agent import create_agent

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(title="Customer Agent API")

# Load configuration from environment variables
config = Config.from_env()


@app.get("/")
async def root():
    """Root endpoint."""
    return {"message": "Customer Agent API", "status": "running"}


@app.get("/health")
@app.get("/ok")
async def health():
    """Health check endpoint."""
    return {"status": "ok"}


def serialize_message(msg):
    """Convert LangChain message to dict."""
    if hasattr(msg, "model_dump"):
        return msg.model_dump()
    elif hasattr(msg, "content"):
        return {"role": getattr(msg, "type", "unknown"), "content": msg.content}
    return str(msg)


@app.post("/invoke")
async def invoke(request: dict, authorization: Optional[str] = Header(None)):
    """Invoke the agent with input.

    Request body:
    {
        "input": {
            "messages": [{"role": "user", "content": "What's the weather?"}]
        }
    }

    Headers:
        Authorization: Bearer <token> (optional)
    """
    try:
        logger.info(f"Received request: {request}")
        if authorization:
            # Extract token from "Bearer <token>" format
            token = (
                authorization.replace("Bearer ", "")
                if authorization.startswith("Bearer ")
                else authorization
            )
            logger.info(f"Authorization header present (token length: {len(token)})")
        else:
            token = None
            logger.error("No authorization header provided")
            return JSONResponse(
                status_code=403, content={"error": "user is not authenticated"}
            )

        # Get the agent
        logger.info("Creating agent instance...")
        agent_instance = await create_agent(config, token)
        logger.info("Agent instance created")

        # Invoke the agent with the input
        logger.info("Invoking agent...")
        result = await agent_instance.ainvoke(request.get("input", {}))
        logger.info("Agent invoked successfully")

        # Serialize the result to make it JSON-friendly
        serialized_result = {}
        for key, value in result.items():
            if isinstance(value, list):
                serialized_result[key] = [serialize_message(item) for item in value]
            else:
                serialized_result[key] = value

        return JSONResponse(content={"result": serialized_result})
    except Exception as e:
        logger.error(f"Error invoking agent: {str(e)}")
        logger.error(traceback.format_exc())
        return JSONResponse(
            status_code=500,
            content={
                "error": str(e),
                "type": type(e).__name__,
                "traceback": traceback.format_exc(),
            },
        )


if __name__ == "__main__":
    host = os.getenv("HOST", "0.0.0.0")
    port = int(os.getenv("PORT", "8124"))

    # Note: Redis and Postgres URIs are available in env vars if needed
    # For now, running stateless - each request is independent
    # To add persistence, configure checkpointing in agent.py

    uvicorn.run(app, host=host, port=port, log_level="info")
