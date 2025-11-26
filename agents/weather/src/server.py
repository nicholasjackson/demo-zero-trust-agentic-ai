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
from fastapi import FastAPI, Header
from fastapi.responses import JSONResponse
import uvicorn
from typing import Optional

from pydantic import BaseModel

from conversion import (
    convert_langchain_to_openai_message,
    convert_openai_to_langchain_messages,
)

from agent import agent


class AgentRequest(BaseModel):
    input: dict


# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(title="Weather Agent API")


@app.get("/")
async def root():
    """Root endpoint."""
    return {"message": "Weather Agent API", "status": "running"}


@app.get("/health")
@app.get("/ok")
async def health():
    """Health check endpoint."""
    return {"status": "ok"}


@app.post("/invoke")
async def invoke(request: AgentRequest, authorization: Optional[str] = Header(None)):
    """Invoke the agent with input.

    Request body:
    {
        "input": {
            "messages": [{"role": "user", "content": "What's the weather?"}]
        }
    }
    """
    try:
        logger.info(f"Received request: {request}")

        # Check if there is a jwt in the authorization header
        if authorization == None:
            return JSONResponse(
                status_code=401, content={"error": "Authorization required"}
            )

        # Get the agent
        token = authorization.replace("Bearer ", "")
        logger.info(f"With token: {token}")
        agent_instance = await agent(token)

        # Get input and convert messages from OpenAI format to LangChain format
        input_data = request.input or {"messages": []}
        if "messages" in input_data:
            input_data["messages"] = convert_openai_to_langchain_messages(
                input_data["messages"]
            )

        result = await agent_instance.ainvoke(input_data)  # type: ignore[arg-type]

        # Serialize the result to make it JSON-friendly
        serialized_result = {}
        for key, value in result.items():
            if isinstance(value, list):
                serialized_result[key] = [
                    convert_langchain_to_openai_message(item) for item in value
                ]
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
    port = int(os.getenv("PORT", "8123"))

    # Note: Redis and Postgres URIs are available in env vars if needed
    # For now, running stateless - each request is independent
    # To add persistence, configure checkpointing in agent.py

    uvicorn.run(app, host=host, port=port, log_level="info")
