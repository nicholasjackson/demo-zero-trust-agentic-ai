"""Configuration for the weather agent."""

import os
from dataclasses import dataclass
from typing import Optional


@dataclass
class Config:
    """Application configuration loaded from environment variables."""

    vault_auth_method: str
    vault_identity_role: str
    vault_role_id: Optional[str] = None
    vault_secret_id: Optional[str] = None
    vault_k8s_role: Optional[str] = None
    vault_auth_mount_point: Optional[str] = None
    vault_addr: str = "http://localhost:8200"
    weather_mcp_uri: str = "http://localhost:8000/mcp"
    customer_mcp_uri: str = "http://localhost:8001/mcp"
    ollama_host: str = "http://localhost:11434"

    @classmethod
    def from_env(cls) -> "Config":
        """Load configuration from environment variables."""
        auth_method = os.getenv("VAULT_AUTH_METHOD", "approle")
        if auth_method not in ("approle", "kubernetes"):
            raise ValueError(
                f"VAULT_AUTH_METHOD must be 'approle' or 'kubernetes', got '{auth_method}'"
            )

        identity_role = os.getenv("VAULT_IDENTITY_ROLE")
        if identity_role is None:
            raise ValueError("environment variable VAULT_IDENTITY_ROLE must be set")

        role_id = os.getenv("VAULT_ROLE_ID")
        secret_id = os.getenv("VAULT_SECRET_ID")
        k8s_role = os.getenv("VAULT_K8S_ROLE")

        if auth_method == "approle":
            if role_id is None:
                raise ValueError("environment variable VAULT_ROLE_ID must be set for approle auth")
            if secret_id is None:
                raise ValueError("environment variable VAULT_SECRET_ID must be set for approle auth")
        elif auth_method == "kubernetes":
            if k8s_role is None:
                raise ValueError("environment variable VAULT_K8S_ROLE must be set for kubernetes auth")

        return cls(
            vault_auth_method=auth_method,
            vault_role_id=role_id,
            vault_secret_id=secret_id,
            vault_k8s_role=k8s_role,
            vault_identity_role=identity_role,
            vault_auth_mount_point=os.getenv("VAULT_AUTH_MOUNT_POINT"),
            vault_addr=os.getenv("VAULT_ADDR", "http://localhost:8200"),
            weather_mcp_uri=os.getenv("WEATHER_MCP_URI", "http://localhost:8000/mcp"),
            customer_mcp_uri=os.getenv("CUSTOMER_MCP_URI", "http://localhost:8001/mcp"),
            ollama_host=os.getenv("OLLAMA_HOST", "http://localhost:11434"),
        )
