"""Customer Agent API server."""

import os
import logging
import uvicorn
from langchain_agent_server import create_app, BearerAuth
from config import Config
from agent import create_agent

logging.basicConfig(level=logging.INFO)

# Load the system prompt from a file
prompt_path = os.path.join(os.path.dirname(__file__), "prompt.md")
with open(prompt_path) as f:
    system_prompt = f.read()

config = Config.from_env()


async def agent_factory(user_token: str):
    return await create_agent(config, user_token, system_prompt)


app = create_app(
    title="Customer Agent API",
    agent_factory=agent_factory,
    auth=BearerAuth(),
)

if __name__ == "__main__":
    host = os.getenv("HOST", "0.0.0.0")
    port = int(os.getenv("PORT", "8124"))

    uvicorn.run(app, host=host, port=port, log_level="info")
