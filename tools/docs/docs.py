from mcp.server.fastmcp import FastMCP
from pathlib import Path

mcp = FastMCP("Docs")

PRACTICES_DIR = Path(__file__).parent / "practices"


@mcp.tool()
async def get_best_practices(technology: str) -> str:
    """Return best practices for a given technology.

    Args:
        technology: The technology name (e.g., 'http', 'security', etc.)

    Returns:
        The best practices content for the specified technology
    """
    practice_file = PRACTICES_DIR / f"{technology.lower()}.md"

    if not practice_file.exists():
        available_practices = [f.stem for f in PRACTICES_DIR.glob("*.md")]
        return f"No best practices found for '{technology}'. Available technologies: {', '.join(available_practices)}"

    return practice_file.read_text()


if __name__ == "__main__":
    mcp.run(transport="stdio")
