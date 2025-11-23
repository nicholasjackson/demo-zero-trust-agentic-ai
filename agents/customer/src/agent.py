import os
from langchain.agents import create_agent
from langchain_ollama import ChatOllama
from langchain_mcp_adapters.client import MultiServerMCPClient

customer_mcp_uri = os.getenv("CUSTOMER_MCP_URI", "http://localhost:8001/mcp")

client = MultiServerMCPClient(
    {
        "customer": {
            "transport": "streamable_http",  # HTTP transport
            "url": customer_mcp_uri,
        }
    }
)

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
async def agent():
    tools = await client.get_tools()
    return create_agent(
        llm,
        system_prompt=system_prompt,
        tools=tools,
    )
