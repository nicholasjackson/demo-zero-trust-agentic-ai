"""Vault client initialization and session token management."""

import os
import logging
from vault_agent import VaultAgentClient

logger = logging.getLogger(__name__)

DEBUG = os.getenv("DEBUG", "false").lower() == "true"

# Global Vault client (lazily initialized)
_vault_client = None


def get_vault_client(config) -> VaultAgentClient:
    """Get or create the global Vault client."""
    global _vault_client
    if _vault_client is None:
        if config.vault_auth_method == "kubernetes":
            _vault_client = VaultAgentClient.with_kubernetes(
                url=config.vault_addr,
                role=config.vault_k8s_role,  # type: ignore[arg-type]
                cache_ttl=300,
                max_cache_size=1000,
                auth_mount_point=config.vault_auth_mount_point or "kubernetes",
            )
        else:
            _vault_client = VaultAgentClient.with_approle(
                url=config.vault_addr,
                role_id=config.vault_role_id,  # type: ignore[arg-type]
                secret_id=config.vault_secret_id,  # type: ignore[arg-type]
                cache_ttl=300,
                max_cache_size=1000,
                auth_mount_point=config.vault_auth_mount_point or "approle",
            )
    return _vault_client


def get_session_token(config, user_token: str) -> str:
    """Get a session token for the user from Vault."""
    vault_client = get_vault_client(config)
    if vault_client is None:
        raise ValueError("Unable to create vault client")

    token = vault_client.get_delegation_token(
        role=config.vault_identity_role, subject_token=user_token
    )

    if token is None:
        raise ValueError("Unable to create session token")

    logger.info("Fetched session token")

    session_token = token["data"]["token"]
    if DEBUG:
        logger.info(f"Session JWT: {session_token}")
    return session_token
