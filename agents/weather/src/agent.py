from langchain.agents import create_agent
from langchain_ollama import ChatOllama
from langchain_mcp_adapters.client import MultiServerMCPClient

client = MultiServerMCPClient(
    {
        "weather": {
            "transport": "streamable_http",  # HTTP transport
            "url": "http://localhost:8000/mcp",
        }
    }
)

# Load the system prompt from a file
with open("./prompt.md") as f:
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
