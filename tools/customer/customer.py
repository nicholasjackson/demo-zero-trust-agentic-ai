from fastmcp import FastMCP
import uvicorn
import os
import psycopg2
from psycopg2.extras import RealDictCursor
from contextlib import contextmanager

# Customer MCP Server - provides customer data management

mcp = FastMCP(
    name="Customer",
    instructions="""
        This server provides tools to manage and retrieve customer information from a PostgreSQL database.
    """,
)

# Database connection configuration from environment variables
DB_CONFIG = {
    "host": os.getenv("DB_HOST", "localhost"),
    "port": int(os.getenv("DB_PORT", "5432")),
    "database": os.getenv("DB_NAME", "customers"),
    "user": os.getenv("DB_USER", "admin"),
    "password": os.getenv("DB_PASSWORD", "password"),
}


@contextmanager
def get_db_connection():
    """Context manager for database connections."""
    conn = None
    try:
        conn = psycopg2.connect(**DB_CONFIG)
        yield conn
    except Exception as e:
        if conn:
            conn.rollback()
        raise e
    finally:
        if conn:
            conn.close()


@mcp.tool()
def search_customer_by_name(first_name: str, last_name: str) -> dict:
    """
    Search for customers by first and last name.

    Args:
        first_name: Customer's first name
        last_name: Customer's last name

    Returns:
        Dictionary containing matching customers with their IDs and basic info.
    """
    try:
        with get_db_connection() as conn:
            with conn.cursor(cursor_factory=RealDictCursor) as cur:
                cur.execute(
                    """
                    SELECT
                        customer_id,
                        first_name,
                        last_name,
                        email,
                        account_status
                    FROM customers
                    WHERE LOWER(first_name) = LOWER(%s)
                    AND LOWER(last_name) = LOWER(%s)
                    ORDER BY customer_id
                """,
                    (first_name, last_name),
                )

                customers = [dict(row) for row in cur.fetchall()]

                if not customers:
                    return {
                        "error": f"No customers found with name '{first_name} {last_name}'"
                    }

                return {"customers": customers, "count": len(customers)}

    except Exception as e:
        return {"error": f"Database error: {str(e)}"}


@mcp.tool()
def get_customer(customer_id: str) -> dict:
    """
    Get customer information by customer ID.

    Args:
        customer_id: The unique customer identifier

    Returns:
        Dictionary containing customer information including name, email,
        account status, and recent order history.
    """
    try:
        with get_db_connection() as conn:
            with conn.cursor(cursor_factory=RealDictCursor) as cur:
                # Get customer details
                cur.execute(
                    """
                    SELECT
                        customer_id,
                        first_name,
                        last_name,
                        email,
                        phone,
                        address_line1,
                        city,
                        state,
                        postal_code,
                        account_status,
                        credit_card_last4
                    FROM customers
                    WHERE customer_id = %s
                """,
                    (customer_id,),
                )

                customer = cur.fetchone()

                if not customer:
                    return {"error": f"Customer '{customer_id}' not found"}

                # Convert to dict and format
                result = dict(customer)
                result["name"] = f"{result.pop('first_name')} {result.pop('last_name')}"
                result["credit_card"] = (
                    f"****-****-****-{result.pop('credit_card_last4')}"
                )

                # Get recent orders
                cur.execute(
                    """
                    SELECT
                        order_id,
                        order_date::text as date,
                        total_amount as total,
                        status
                    FROM orders
                    WHERE customer_id = %s
                    ORDER BY order_date DESC
                    LIMIT 10
                """,
                    (customer_id,),
                )

                orders = [dict(row) for row in cur.fetchall()]
                result["orders"] = orders

                return result

    except Exception as e:
        return {"error": f"Database error: {str(e)}"}


@mcp.tool()
def get_customer_orders(customer_id: str) -> dict:
    """
    Get order history for a specific customer.

    Args:
        customer_id: The unique customer identifier

    Returns:
        Dictionary containing the customer's order history with items.
    """
    try:
        with get_db_connection() as conn:
            with conn.cursor(cursor_factory=RealDictCursor) as cur:
                # Get customer name
                cur.execute(
                    """
                    SELECT first_name, last_name
                    FROM customers
                    WHERE customer_id = %s
                """,
                    (customer_id,),
                )

                customer = cur.fetchone()

                if not customer:
                    return {"error": f"Customer '{customer_id}' not found"}

                customer_name = f"{customer['first_name']} {customer['last_name']}"

                # Get orders with items
                cur.execute(
                    """
                    SELECT
                        o.order_id,
                        o.order_date::text as date,
                        o.total_amount as total,
                        o.status,
                        json_agg(
                            json_build_object(
                                'product_name', oi.product_name,
                                'quantity', oi.quantity,
                                'unit_price', oi.unit_price,
                                'subtotal', oi.subtotal
                            )
                        ) as items
                    FROM orders o
                    LEFT JOIN order_items oi ON o.order_id = oi.order_id
                    WHERE o.customer_id = %s
                    GROUP BY o.order_id, o.order_date, o.total_amount, o.status
                    ORDER BY o.order_date DESC
                """,
                    (customer_id,),
                )

                orders = [dict(row) for row in cur.fetchall()]

                return {
                    "customer_id": customer_id,
                    "customer_name": customer_name,
                    "orders": orders,
                }

    except Exception as e:
        return {"error": f"Database error: {str(e)}"}


if __name__ == "__main__":
    # Get the HTTP app and run with optional HTTPS configuration
    app = mcp.http_app()

    # Configuration from environment variables
    use_https = os.getenv("USE_HTTPS", "false").lower() == "true"
    host = os.getenv("HOST", "0.0.0.0")
    port = int(os.getenv("PORT", "8001"))
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
