"""Configuration for the Customer Agent."""

import os
from dataclasses import dataclass


@dataclass
class Config:
    """Application configuration loaded from environment variables."""

    vault_role_id: str
    vault_secret_id: str
    vault_identity_role: str
    vault_addr: str = "http://localhost:8200"
    customer_mcp_uri: str = "http://localhost:8001/mcp"
    weather_mcp_uri: str = "http://localhost:8000/mcp"
    ollama_host: str = "http://localhost:11434"

    @classmethod
    def from_env(cls) -> "Config":
        """Load configuration from environment variables."""
        role_id = os.getenv("VAULT_ROLE_ID")
        if role_id is None:
            raise ValueError("environment variable VAULT_ROLE_ID must be set")

        secret_id = os.getenv("VAULT_SECRET_ID")
        if secret_id is None:
            raise ValueError("environment variable VAULT_SECRET_ID must be set")

        identity_role = os.getenv("VAULT_IDENTITY_ROLE")
        if identity_role is None:
            raise ValueError("environment variable VAULT_IDENTITY_ROLE must be set")

        return cls(
            vault_role_id=role_id,
            vault_secret_id=secret_id,
            vault_identity_role=identity_role,
            vault_addr=os.getenv("VAULT_ADDR", "http://localhost:8200"),
            customer_mcp_uri=os.getenv("CUSTOMER_MCP_URI", "http://localhost:8001/mcp"),
            weather_mcp_uri=os.getenv("WEATHER_MCP_URI", "http://localhost:8000/mcp"),
            ollama_host=os.getenv("OLLAMA_HOST", "http://localhost:11434"),
        )
