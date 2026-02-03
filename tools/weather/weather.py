from fastmcp import FastMCP
from fastmcp.server.auth.providers.jwt import JWTVerifier
from fastmcp.server.dependencies import get_access_token
import uvicorn
import os
import requests
import logging
import jwt

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Weather MCP Server - provides current weather data via OpenWeather API

# Vault configuration for JWT verification
VAULT_ADDR = os.getenv("VAULT_ADDR", "http://localhost:8200")
VAULT_IDENTITY_PATH = os.getenv("VAULT_IDENTITY_PATH", "identity-delegation")
JWKS_URL = f"{VAULT_ADDR}/v1/{VAULT_IDENTITY_PATH}/jwks"
DEBUG = os.getenv("DEBUG", "false").lower() == "true"

logger.info("Vault JWT configuration:")
logger.info(f"  VAULT_ADDR: {VAULT_ADDR}")
logger.info(f"  VAULT_IDENTITY_PATH: {VAULT_IDENTITY_PATH}")
logger.info(f"  JWKS_URL: {JWKS_URL}")

# Create JWT verifier that validates against Vault's JWKS endpoint
jwt_verifier = JWTVerifier(jwks_uri=JWKS_URL)

mcp = FastMCP(
    name="Weather",
    instructions="""
        This server provides a tool to obtain up to the minute weather forecasts
        for any city worldwide using the OpenWeather API.
    """,
    auth=jwt_verifier,
)


def get_token_claims(tool_name: str) -> dict | None:
    """Decode the JWT access token and log user details. Returns claims or None."""
    token = get_access_token()
    if token is None:
        logger.warning(f"[{tool_name}] No access token available")
        return None
    if DEBUG:
        logger.info(f"[{tool_name}] Raw JWT: {token.token}")
    try:
        claims = jwt.decode(token.token, options={"verify_signature": False})
        logger.info(f"[{tool_name}] Token claims:")
        for key, value in claims.items():
            logger.info(f"  {key}: {value}")
        return claims
    except Exception as e:
        logger.warning(f"[{tool_name}] Could not decode user token: {e}")
        return None


def check_permission(tool_name: str, permission: str) -> str | None:
    """Check that the JWT contains the required permission in both agent
    and subject claims. Returns an error string if denied, None if allowed."""
    claims = get_token_claims(tool_name)
    if claims is None:
        return "Access denied: no valid token"

    # Check agent-level permissions
    agent_permissions = claims.get("scope", [])
    if permission not in agent_permissions:
        logger.warning(f"[{tool_name}] Agent missing permission: {permission}")
        return f"Access denied: agent does not have '{permission}' permission"

    # Check subject (user) permissions
    subject_claims = claims.get("subject_claims", {})
    subject_permissions = subject_claims.get("permissions", [])
    if permission not in subject_permissions:
        logger.warning(f"[{tool_name}] Subject missing permission: {permission}")
        return f"Access denied: user does not have '{permission}' permission"

    logger.info(f"[{tool_name}] Permission '{permission}' granted")
    return None


@mcp.tool()
async def get_weather(location: str) -> dict:
    """
    Get current weather data for a specified location using the OpenWeather API.
    Returns temperature, conditions, humidity, and wind speed.

    Args:
        location: City name or location string, e.g. "London", "New York", "Tokyo"

    Returns:
        Dictionary with location, country, temperature (Celsius), feels_like,
        humidity, pressure, description, and wind_speed.
    """
    denied = check_permission("get_weather", "read:weather")
    if denied:
        return {"error": denied}

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
            f"Successfully fetched weather for {location}: {weather_info['temperature']}C, {weather_info['description']}"
        )
        return weather_info

    except requests.exceptions.HTTPError as e:
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
    logger.info(f"  JWT validation: {JWKS_URL}")

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
