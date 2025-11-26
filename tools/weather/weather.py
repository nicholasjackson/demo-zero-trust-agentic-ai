from fastmcp import FastMCP
from fastmcp.server.auth.providers.debug import DebugTokenVerifier
from fastmcp.server.dependencies import get_access_token
import uvicorn
import os
import requests
import logging

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Weather MCP Server - provides current weather data via OpenWeather API

# Keycloak configuration
KEYCLOAK_URL = os.getenv("KEYCLOAK_URL", "http://localhost:8080")
KEYCLOAK_REALM = os.getenv("KEYCLOAK_REALM", "demo")
JWKS_URL = f"{KEYCLOAK_URL}/realms/{KEYCLOAK_REALM}/protocol/openid-connect/certs"
ISSUER = f"{KEYCLOAK_URL}/realms/{KEYCLOAK_REALM}"

logger.info("Keycloak configuration:")
logger.info(f"  KEYCLOAK_URL: {KEYCLOAK_URL}")
logger.info(f"  KEYCLOAK_REALM: {KEYCLOAK_REALM}")
logger.info(f"  JWKS_URL: {JWKS_URL}")
logger.info(f"  ISSUER: {ISSUER}")

# Use DebugTokenVerifier to inspect tokens
logger.info("Using DebugTokenVerifier to inspect JWT tokens")

mcp = FastMCP(
    name="Weather",
    instructions="""
        This server provides tool to obtain up to the minute weather forecasts.
    """,
    auth=DebugTokenVerifier(),
)


@mcp.tool()
async def get_weather(location: str) -> dict:
    """
    Get current weather data for a specified location.

    Args:
        location: City name or location string (e.g., "London", "New York", "Tokyo")

    Returns:
        Dictionary containing current weather information including temperature,
        conditions, humidity, and wind speed.
    """
    logger.info(f"get_weather called for location: {location}")

    # get the token
    token = get_access_token()
    logger.info(f"With token {token}")

    api_key = os.getenv("OPENWEATHER_API_KEY")
    if not api_key:
        logger.error("OPENWEATHER_API_KEY not configured")
        return {"error": "OPENWEATHER_API_KEY environment variable not set"}

    # OpenWeather API endpoint
    url = "https://api.openweathermap.org/data/2.5/weather"
    params = {
        "q": location,
        "appid": api_key,
        "units": "metric",  # Use metric units (Celsius)
    }

    logger.info(f"Fetching weather for {location} from OpenWeather API")

    try:
        response = requests.get(url, params=params)
        response.raise_for_status()
        data = response.json()

        # Extract relevant weather information
        weather_info = {
            "location": data["name"],
            "country": data["sys"]["country"],
            "temperature": data["main"]["temp"],
            "feels_like": data["main"]["feels_like"],
            "humidity": data["main"]["humidity"],
            "pressure": data["main"]["pressure"],
            "description": data["weather"][0]["description"],
            "wind_speed": data["wind"]["speed"],
        }

        logger.info(
            f"✅ Successfully fetched weather for {location}: {weather_info['temperature']}°C, {weather_info['description']}"
        )
        return weather_info

    except requests.exceptions.HTTPError as e:
        # Check response status if available
        status_code = (
            getattr(e.response, "status_code", None) if hasattr(e, "response") else None
        )
        logger.error(f"HTTP error fetching weather: {e} (status: {status_code})")
        if status_code == 404:
            return {"error": f"Location '{location}' not found"}
        return {"error": f"HTTP error: {str(e)}"}
    except requests.exceptions.RequestException as e:
        logger.error(f"Request failed: {e}")
        return {"error": f"Request failed: {str(e)}"}
    except (KeyError, IndexError) as e:
        logger.error(f"Failed to parse weather data: {e}")
        return {"error": f"Failed to parse weather data: {str(e)}"}


if __name__ == "__main__":
    logger.info("=" * 60)
    logger.info("Starting Weather MCP Server")
    logger.info("=" * 60)

    # Get the HTTP app - FastMCP handles request context automatically
    app = mcp.http_app(transport="streamable-http")

    # Configuration from environment variables
    use_https = os.getenv("USE_HTTPS", "false").lower() == "true"
    host = os.getenv("HOST", "0.0.0.0")
    port = int(os.getenv("PORT", "8000"))
    ssl_keyfile = os.getenv("SSL_KEYFILE", "./private.pem")
    ssl_certfile = os.getenv("SSL_CERTFILE", "./certificate.pem")

    logger.info("Server configuration:")
    logger.info(f"  Host: {host}")
    logger.info(f"  Port: {port}")
    logger.info(f"  HTTPS: {use_https}")
    logger.info("  Transport: streamable-http")

    # Build uvicorn config
    config = {
        "app": app,
        "host": host,
        "port": port,
    }

    # Add SSL configuration if HTTPS is enabled
    if use_https:
        config["ssl_keyfile"] = ssl_keyfile
        config["ssl_certfile"] = ssl_certfile
        logger.info(f"Starting HTTPS server on {host}:{port}")
    else:
        logger.info(f"Starting HTTP server on {host}:{port}")

    logger.info("=" * 60)

    uvicorn.run(**config)
