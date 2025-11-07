from fastmcp import FastMCP

# Weather MCP Server - provides current weather data via OpenWeather API

mcp = FastMCP(
    name="Weather",
    instructions="""
        This server provides tool to obtain up to the minute weather forecasts.
    """,
)

if __name__ == "__main__":
    # This runs the server, defaulting to STDIO transport
    mcp.run()
