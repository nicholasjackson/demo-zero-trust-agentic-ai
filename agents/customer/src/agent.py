import logging

from langchain.agents import create_agent as langchain_create_agent
from langchain_ollama import ChatOllama
from langchain_mcp_adapters.client import MultiServerMCPClient
from vault import get_session_token

logger = logging.getLogger(__name__)


async def create_agent(config, user_token: str, system_prompt: str):
    """Create an agent instance with the given configuration and user token.

    Args:
        config: Application configuration.
        user_token: User's JWT access token.
        system_prompt: The system prompt for the agent.
    """
    # Attempt to create a token for the session using the user's token
    # Raises an error on failure
    session_token = get_session_token(config, user_token)

    # Create MCP client with config
    mcp_client = MultiServerMCPClient(
        {
            "weather": {
                "transport": "streamable_http",
                "url": config.weather_mcp_uri,
                "headers": {
                    "Authorization": f"Bearer {session_token}",
                },
            },
            "customer": {
                "transport": "streamable_http",
                "url": config.customer_mcp_uri,
                "headers": {
                    "Authorization": f"Bearer {session_token}",
                },
            },
        }
    )

    # Define the model to use
    llm = ChatOllama(
        model="llama3.2",
        temperature=0,
        base_url=config.ollama_host,
    )

    try:
        tools = await mcp_client.get_tools()
    except Exception as e:
        logger.warning(f"Failed to get tools from MCP server: {e}")
        tools = None

    return langchain_create_agent(
        llm,
        system_prompt=system_prompt,
        tools=tools,
    )
