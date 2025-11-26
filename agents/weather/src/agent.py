import os
import logging
from langchain.agents import create_agent
from langchain_ollama import ChatOllama
from langchain_mcp_adapters.client import MultiServerMCPClient

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

weather_mcp_uri = os.getenv("WEATHER_MCP_URI", "http://localhost:8000/mcp")

# Load the system prompt from a file
prompt_path = os.path.join(os.path.dirname(__file__), "prompt.md")
with open(prompt_path) as f:
    system_prompt = f.read()

# Define the model to use
llm = ChatOllama(
    model="llama3.2",
    temperature=0,
)


# Create an async agent
async def agent(token: str):
    mcpclient = MultiServerMCPClient(
        {
            "weather": {
                "transport": "streamable_http",  # HTTP transport
                "url": weather_mcp_uri,
                "headers": {
                    "Authorization": f"Bearer {token}",
                },
            }
        },
    )
    tools = await mcpclient.get_tools()

    logger.info("🤖 Creating agent with tools and context schema...")
    agent_instance = create_agent(
        llm,
        system_prompt=system_prompt,
        tools=tools,
    )

    return agent_instance
