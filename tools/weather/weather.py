from fastmcp import FastMCP
import uvicorn
import os
import reqeusts as requests

# Weather MCP Server - provides current weather data via OpenWeather API

mcp = FastMCP(
    name="Weather",
    instructions="""
        This server provides tool to obtain up to the minute weather forecasts.
    """,
)

@mcp.tool()
def get_weather(location: str) -> dict:
    """
    Get current weather data for a specified location.

    Args:
        location: City name or location string (e.g., "London", "New York", "Tokyo")

    Returns:
        Dictionary containing current weather information including temperature,
        conditions, humidity, and wind speed.
    """
    api_key = os.getenv("OPENWEATHER_API_KEY")
    if not api_key:
        return {"error": "OPENWEATHER_API_KEY environment variable not set"}

    # OpenWeather API endpoint
    url = "https://api.openweathermap.org/data/2.5/weather"
    params = {
        "q": location,
        "appid": api_key,
        "units": "metric"  # Use metric units (Celsius)
    }

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

        return weather_info

    except requests.exceptions.HTTPError as e:
        # Check response status if available
        status_code = getattr(e.response, 'status_code', None) if hasattr(e, 'response') else None
        if status_code == 404:
            return {"error": f"Location '{location}' not found"}
        return {"error": f"HTTP error: {str(e)}"}
    except requests.exceptions.RequestException as e:
        return {"error": f"Request failed: {str(e)}"}
    except (KeyError, IndexError) as e:
        return {"error": f"Failed to parse weather data: {str(e)}"}

if __name__ == "__main__":
    # Get the HTTP app and run with optional HTTPS configuration
    app = mcp.http_app()

    # Configuration from environment variables
    use_https = os.getenv("USE_HTTPS", "false").lower() == "true"
    host = os.getenv("HOST", "0.0.0.0")
    port = int(os.getenv("PORT", "8000"))
    ssl_keyfile = os.getenv("SSL_KEYFILE", "./private.pem")
    ssl_certfile = os.getenv("SSL_CERTFILE", "./certificate.pem")

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
        print(f"Starting HTTPS server on {host}:{port}")
    else:
        print(f"Starting HTTP server on {host}:{port}")

    uvicorn.run(**config)
