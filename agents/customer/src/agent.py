import os
import logging
from langchain.agents import create_agent as langchain_create_agent
from langchain_ollama import ChatOllama
from langchain_mcp_adapters.client import MultiServerMCPClient
from vault_agent import VaultAgentClient
from config import Config

# Load the system prompt from a file
prompt_path = os.path.join(os.path.dirname(__file__), "prompt.md")
with open(prompt_path) as f:
    system_prompt = f.read()

# Global Vault client (lazily initialized)
_vault_client = None

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


def get_vault_client(config: Config) -> VaultAgentClient:
    """Get or create the global Vault client."""
    global _vault_client
    if _vault_client is None:
        _vault_client = VaultAgentClient.with_approle(
            url=config.vault_addr,
            role_id=config.vault_role_id,
            secret_id=config.vault_secret_id,
            cache_ttl=300,  # Cache for 5 minutes
            max_cache_size=1000,
        )
    return _vault_client


def get_session_token(config: Config, user_token: str) -> dict:
    """Get a session token for the user from Vault."""
    vault_client = get_vault_client(config)
    if vault_client is None:
        raise ValueError("Unable to create vault client")

    token = vault_client.get_delegation_token(
        role=config.vault_identity_role, subject_token=user_token
    )

    if token is None:
        raise ValueError("Unable to create session token")

    logger.info("Fetched session token")

    return token["data"]["token"]


async def create_agent(config: Config, user_token: str):
    """Create an agent instance with the given configuration and user token."""
    # Attempt to create a token for the session using the user's token
    # Raises an error on failure
    session_token = get_session_token(config, user_token)

    # Create MCP client with config
    mcp_client = MultiServerMCPClient(
        {
            "customer": {
                "transport": "streamable_http",
                "url": config.customer_mcp_uri,
                "headers": {
                    "Authorization": f"Bearer {session_token}",
                },
            },
            "weather": {
                "transport": "streamable_http",
                "url": config.weather_mcp_uri,
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
