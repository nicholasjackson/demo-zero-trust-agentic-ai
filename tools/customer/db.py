import os
import logging
import sqlite3
from contextlib import contextmanager
from pathlib import Path

logger = logging.getLogger(__name__)

# Database configuration: DB_TYPE=postgres for PostgreSQL, default is sqlite
DB_TYPE = os.getenv("DB_TYPE", "sqlite").lower()
SQLITE_PATH = os.getenv("SQLITE_PATH", "./customers.db")

if DB_TYPE == "postgres":
    import psycopg2
    from psycopg2.extras import RealDictCursor

    DB_CONFIG = {
        "host": os.getenv("DB_HOST", "localhost"),
        "port": int(os.getenv("DB_PORT", "5432")),
        "database": os.getenv("DB_NAME", "customers"),
        "user": os.getenv("DB_USER", "admin"),
        "password": os.getenv("DB_PASSWORD", "password"),
    }

    @contextmanager
    def get_db_connection():
        """Context manager for PostgreSQL connections."""
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

    def execute_query(query: str, params: tuple = (), fetch_one: bool = False):
        """Execute a query and return results as list of dicts."""
        with get_db_connection() as conn:
            with conn.cursor(cursor_factory=RealDictCursor) as cur:
                cur.execute(query, params)
                if fetch_one:
                    row = cur.fetchone()
                    return dict(row) if row else None
                return [dict(row) for row in cur.fetchall()]

else:
    # SQLite mode (default)
    def dict_factory(cursor, row):
        """Convert SQLite rows to dictionaries."""
        return {col[0]: row[idx] for idx, col in enumerate(cursor.description)}

    @contextmanager
    def get_db_connection():
        """Context manager for SQLite connections."""
        conn = None
        try:
            conn = sqlite3.connect(SQLITE_PATH)
            conn.row_factory = dict_factory
            yield conn
        except Exception as e:
            if conn:
                conn.rollback()
            raise e
        finally:
            if conn:
                conn.close()

    def execute_query(query: str, params: tuple = (), fetch_one: bool = False):
        """Execute a query and return results as list of dicts."""
        # Convert PostgreSQL-style %s placeholders to SQLite ? placeholders
        sqlite_query = query.replace("%s", "?")
        # Remove PostgreSQL-specific syntax
        sqlite_query = sqlite_query.replace("::text", "")

        with get_db_connection() as conn:
            cur = conn.cursor()
            cur.execute(sqlite_query, params)
            if fetch_one:
                return cur.fetchone()
            return cur.fetchall()

    def init_sqlite_db():
        """Initialize SQLite database with schema and seed data."""
        if Path(SQLITE_PATH).exists():
            logger.info(f"SQLite database already exists at {SQLITE_PATH}")
            return

        logger.info(f"Initializing SQLite database at {SQLITE_PATH}")

        with get_db_connection() as conn:
            cur = conn.cursor()

            # Create tables
            cur.execute("""
                CREATE TABLE IF NOT EXISTS customers (
                    customer_id TEXT PRIMARY KEY,
                    first_name TEXT NOT NULL,
                    last_name TEXT NOT NULL,
                    email TEXT NOT NULL,
                    phone TEXT,
                    address_line1 TEXT,
                    city TEXT,
                    state TEXT,
                    postal_code TEXT,
                    account_status TEXT DEFAULT 'active',
                    credit_card_last4 TEXT
                )
            """)

            cur.execute("""
                CREATE TABLE IF NOT EXISTS orders (
                    order_id TEXT PRIMARY KEY,
                    customer_id TEXT NOT NULL,
                    order_date TEXT NOT NULL,
                    total_amount REAL NOT NULL,
                    status TEXT DEFAULT 'pending',
                    FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
                )
            """)

            cur.execute("""
                CREATE TABLE IF NOT EXISTS order_items (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    order_id TEXT NOT NULL,
                    product_name TEXT NOT NULL,
                    quantity INTEGER NOT NULL,
                    unit_price REAL NOT NULL,
                    subtotal REAL NOT NULL,
                    FOREIGN KEY (order_id) REFERENCES orders(order_id)
                )
            """)

            # Seed data - customers
            customers = [
                ("CUST001", "John", "Doe", "john.doe@example.com", "+1-555-123-4567",
                 "123 Main Street", "San Francisco", "CA", "94102", "active", "4242"),
                ("CUST002", "Jane", "Smith", "jane.smith@example.com", "+1-555-987-6543",
                 "456 Oak Avenue", "Los Angeles", "CA", "90001", "active", "1234"),
                ("CUST003", "Bob", "Johnson", "bob.johnson@example.com", "+1-555-456-7890",
                 "789 Pine Road", "Seattle", "WA", "98101", "suspended", "5678"),
            ]

            cur.executemany("""
                INSERT INTO customers (customer_id, first_name, last_name, email, phone,
                    address_line1, city, state, postal_code, account_status, credit_card_last4)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """, customers)

            # Seed data - orders
            orders = [
                ("ORD-10001", "CUST001", "2025-01-15", 149.99, "delivered"),
                ("ORD-10002", "CUST001", "2025-01-20", 299.00, "shipped"),
                ("ORD-10003", "CUST002", "2025-01-18", 549.99, "processing"),
            ]

            cur.executemany("""
                INSERT INTO orders (order_id, customer_id, order_date, total_amount, status)
                VALUES (?, ?, ?, ?, ?)
            """, orders)

            # Seed data - order items
            order_items = [
                ("ORD-10001", "Wireless Headphones", 1, 99.99, 99.99),
                ("ORD-10001", "USB-C Cable", 2, 25.00, 50.00),
                ("ORD-10002", "Mechanical Keyboard", 1, 299.00, 299.00),
                ("ORD-10003", "Monitor 27inch", 1, 499.99, 499.99),
                ("ORD-10003", "HDMI Cable", 1, 50.00, 50.00),
            ]

            cur.executemany("""
                INSERT INTO order_items (order_id, product_name, quantity, unit_price, subtotal)
                VALUES (?, ?, ?, ?, ?)
            """, order_items)

            conn.commit()
            logger.info("SQLite database initialized with seed data")

    # Initialize SQLite on module load
    init_sqlite_db()
