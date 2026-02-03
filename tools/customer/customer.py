from fastmcp import FastMCP
from fastmcp.server.auth.providers.jwt import JWTVerifier
from fastmcp.server.dependencies import get_access_token
import uvicorn
import os
import logging
import jwt

from db import execute_query, DB_TYPE, SQLITE_PATH

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Customer MCP Server - provides customer data management

# Vault configuration for JWT verification
VAULT_ADDR = os.getenv("VAULT_ADDR", "http://localhost:8200")
VAULT_IDENTITY_PATH = os.getenv("VAULT_IDENTITY_PATH", "identity-delegation")
JWKS_URL = f"{VAULT_ADDR}/v1/{VAULT_IDENTITY_PATH}/jwks"

logger.info("Vault JWT configuration:")
logger.info(f"  VAULT_ADDR: {VAULT_ADDR}")
logger.info(f"  VAULT_IDENTITY_PATH: {VAULT_IDENTITY_PATH}")
logger.info(f"  JWKS_URL: {JWKS_URL}")

# Create JWT verifier that validates against Vault's JWKS endpoint
jwt_verifier = JWTVerifier(jwks_uri=JWKS_URL)

mcp = FastMCP(
    name="Customer",
    instructions="""
        This server provides tools to manage and retrieve customer information.
        Always look up customers by their customer ID. If you do not have a
        customer ID, use the search_customer_by_name tool first to find it.
    """,
    auth=jwt_verifier,
)


def get_token_claims(tool_name: str) -> dict | None:
    """Decode the JWT access token and log user details. Returns claims or None."""
    token = get_access_token()
    if token is None:
        logger.warning(f"[{tool_name}] No access token available")
        return None
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
def search_customer_by_name(first_name: str, last_name: str) -> dict:
    """
    Search for customers by their name. Use this tool when you need to find a
    customer's ID and you only have their name. Returns matching customer IDs
    which can then be used with get_customer or get_customer_orders.

    Args:
        first_name: Customer's first name, e.g. "John"
        last_name: Customer's last name, e.g. "Doe"

    Returns:
        Dictionary with "customers" list containing customer_id, first_name,
        last_name, email, and account_status for each match, plus a "count".
    """
    denied = check_permission("search_customer_by_name", "read:customers")
    if denied:
        return {"error": denied}

    try:
        customers = execute_query(
            """
            SELECT customer_id, first_name, last_name, email, account_status
            FROM customers
            WHERE LOWER(first_name) = LOWER(%s) AND LOWER(last_name) = LOWER(%s)
            ORDER BY customer_id
            """,
            (first_name, last_name),
        )

        if not customers:
            return {"error": f"No customers found with name '{first_name} {last_name}'"}

        return {"customers": customers, "count": len(customers)}

    except Exception as e:
        return {"error": f"Database error: {str(e)}"}


@mcp.tool()
def get_customer(customer_id: str) -> dict:
    """
    Get full customer profile by their ID. Returns contact details, address,
    account status, and up to 10 recent orders. Requires a customer ID — use
    search_customer_by_name first if you only have the customer's name.

    Args:
        customer_id: The unique customer identifier, e.g. "CUST001"

    Returns:
        Dictionary with customer_id, name, email, phone, address fields,
        account_status, credit_card (masked), and an "orders" list.
    """
    denied = check_permission("get_customer", "read:customers")
    if denied:
        return {"error": denied}

    try:
        customer = execute_query(
            """
            SELECT customer_id, first_name, last_name, email, phone,
                   address_line1, city, state, postal_code, account_status, credit_card_last4
            FROM customers
            WHERE customer_id = %s
            """,
            (customer_id,),
            fetch_one=True,
        )

        if not customer:
            return {"error": f"Customer '{customer_id}' not found"}

        # Format result
        result = {
            "customer_id": customer["customer_id"],  # type: ignore
            "name": f"{customer['first_name']} {customer['last_name']}",  # type: ignore
            "email": customer["email"],  # type: ignore
            "phone": customer["phone"],  # type: ignore
            "address_line1": customer["address_line1"],  # type: ignore
            "city": customer["city"],  # type: ignore
            "state": customer["state"],  # type: ignore
            "postal_code": customer["postal_code"],  # type: ignore
            "account_status": customer["account_status"],  # type: ignore
            "credit_card": f"****-****-****-{customer['credit_card_last4']}",  # type: ignore
        }

        # Get recent orders
        orders = execute_query(
            """
            SELECT order_id, order_date as date, total_amount as total, status
            FROM orders
            WHERE customer_id = %s
            ORDER BY order_date DESC
            LIMIT 10
            """,
            (customer_id,),
        )
        result["orders"] = orders

        return result

    except Exception as e:
        return {"error": f"Database error: {str(e)}"}


@mcp.tool()
def get_customer_orders(customer_id: str) -> dict:
    """
    Get the full order history for a customer including line items for each
    order. Use this when you need detailed order information such as products
    purchased, quantities, and prices. Requires a customer ID — use
    search_customer_by_name first if you only have the customer's name.

    Args:
        customer_id: The unique customer identifier, e.g. "CUST001"

    Returns:
        Dictionary with customer_id, customer_name, and an "orders" list
        where each order includes order_id, date, total, status, and an
        "items" list with product_name, quantity, unit_price, and subtotal.
    """
    denied = check_permission("get_customer_orders", "read:customers")
    if denied:
        return {"error": denied}

    try:
        customer = execute_query(
            "SELECT first_name, last_name FROM customers WHERE customer_id = %s",
            (customer_id,),
            fetch_one=True,
        )

        if not customer:
            return {"error": f"Customer '{customer_id}' not found"}

        # Get orders
        orders = execute_query(
            """
            SELECT order_id, order_date as date, total_amount as total, status
            FROM orders
            WHERE customer_id = %s
            ORDER BY order_date DESC
            """,
            (customer_id,),
        )

        # Get items for each order
        for order in orders:
            items = execute_query(
                """
                SELECT product_name, quantity, unit_price, subtotal
                FROM order_items
                WHERE order_id = %s
                """,
                (order["order_id"],),
            )
            order["items"] = items

        customer_name = f"{customer['first_name']} {customer['last_name']}"  # type: ignore

        return {
            "customer_id": customer_id,
            "customer_name": customer_name,
            "orders": orders,
        }

    except Exception as e:
        return {"error": f"Database error: {str(e)}"}


if __name__ == "__main__":
    logger.info("=" * 60)
    logger.info("Starting Customer MCP Server")
    logger.info("=" * 60)

    # Get the HTTP app with streamable-http transport
    app = mcp.http_app(transport="streamable-http")

    # Configuration from environment variables
    use_https = os.getenv("USE_HTTPS", "false").lower() == "true"
    host = os.getenv("HOST", "0.0.0.0")
    port = int(os.getenv("PORT", "8001"))
    ssl_keyfile = os.getenv("SSL_KEYFILE", "./private.pem")
    ssl_certfile = os.getenv("SSL_CERTFILE", "./certificate.pem")

    logger.info("Server configuration:")
    logger.info(f"  Host: {host}")
    logger.info(f"  Port: {port}")
    logger.info(f"  HTTPS: {use_https}")
    logger.info("  Transport: streamable-http")
    logger.info(f"  Database: {DB_TYPE}")
    if DB_TYPE == "sqlite":
        logger.info(f"  SQLite path: {SQLITE_PATH}")
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

    logger.info("=" * 60)

    uvicorn.run(**config)
