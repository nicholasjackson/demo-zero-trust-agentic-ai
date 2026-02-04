# Demo: Agentic Zero Trust

A demonstration project showcasing zero-trust security architecture with agentic AI. This project implements LangGraph-based agents that use HashiCorp Vault's identity delegation plugin for secure bearer token management and MCP (Model Context Protocol) servers for tool access.

## Architecture Overview

```
┌─────────────┐     JWT      ┌──────────────┐    Session    ┌─────────────┐
│   Chat UI   │─────────────▶│    Agent     │─────Token────▶│  MCP Tools  │
│   (React)   │              │  (LangGraph) │               │  (FastMCP)  │
└─────────────┘              └──────────────┘               └─────────────┘
                                    │                              │
                                    │ Token                        │ JWKS
                                    │ Exchange                     │ Validation
                                    ▼                              ▼
                             ┌─────────────────────────────────────────┐
                             │     HashiCorp Vault                     │
                             │     (Identity Delegation Plugin)        │
                             └─────────────────────────────────────────┘
```

### Security Flow

1. User authenticates via Keycloak (OIDC) and receives a JWT
2. User sends requests to agents with their JWT as a bearer token
3. Agent exchanges the user JWT for a session token via Vault's identity delegation endpoint
4. The session token contains both agent permissions (scope) and user permissions (subject_claims)
5. Agent calls MCP tools with the session token
6. Tools validate the session token against Vault's JWKS endpoint
7. Tools enforce both agent-level and user-level permissions

## Project Structure

```
├── agents/                 # LangGraph agents
│   ├── customer/           # Customer service agent
│   └── weather/            # Weather information agent
│
├── tools/                  # MCP tool servers
│   ├── customer/           # Customer data management tools
│   ├── weather/            # Weather data tools
│   └── docs/               # Development documentation
│
├── chat-ui/                # React frontend
│
└── .docs/                  # Project planning and documentation
```

### `/agents`

Contains LangGraph-based agents that orchestrate AI tasks using LangChain and Ollama LLM.

| Agent | Port | Description |
|-------|------|-------------|
| `weather` | 8123 | Weather information agent |
| `customer` | 8124 | Customer service agent |

**Key Components:**
- `src/agent.py` - Agent creation and MCP client setup
- `src/server.py` - FastAPI server with bearer token authentication
- `src/vault.py` - Vault client and session token management
- `src/config.py` - Configuration (Vault, URIs, Ollama settings)

**Technology Stack:**
- LangChain & LangGraph for agent orchestration
- Ollama (llama3.2) for local LLM
- FastAPI/Uvicorn for API servers
- LangChain MCP Adapters for tool connectivity

### `/tools`

FastMCP tool servers providing specialized capabilities via Model Context Protocol.

| Tool | Description |
|------|-------------|
| `customer` | Customer data management (search, get details, orders) |
| `weather` | Weather data retrieval via OpenWeather API |

**Key Features:**
- JWT verification against Vault's JWKS endpoint
- Permission-based access control at both agent and user levels
- Uses FastMCP framework for MCP server implementation

### `/chat-ui`

Modern React-based frontend for interacting with agents.

**Features:**
- Multi-agent support (switch between Weather and Customer agents)
- Dark mode UI with Tailwind CSS
- Tool call visualization (show/hide agent tool calls and results)
- Responsive design

**Technology Stack:**
- React 18
- Vite for build tooling
- Tailwind CSS v4

## Bearer Tokens and Vault Integration

### Current Setup

The agents and tools are configured to use bearer tokens with the [Vault Identity Delegation Plugin](https://github.com/nicholasjackson/vault-plugin-identity-delegation), which implements **OAuth 2.0 Token Exchange (RFC 8693)** for "on behalf of" scenarios.

### How the Plugin Works

The Vault Identity Delegation plugin enables AI agents to exchange user OIDC tokens for new JWTs that represent delegated authority. The generated tokens combine both user identity and agent identity in a single JWT.

**Key Characteristics:**
- **Policy-based authorization** - Permissions are pre-configured at admin time via Vault roles (not runtime user consent)
- **RFC 8693 compliant** - Implements the `act` (actor) claim to identify which agent performed actions
- **Template-based claims** - Flexible claim extraction using Mustache templates
- **Public JWKS endpoint** - Unauthenticated endpoint for downstream token verification

### Token Flow

```
User JWT ──▶ Agent ──▶ Vault /token/:role ──▶ Delegated JWT ──▶ MCP Tools
                              │                                      │
                              │                                      ▼
                              │                              Vault /jwks
                              │                          (verify signature)
                              ▼
                    ┌─────────────────────┐
                    │ 1. Validate subject │
                    │    token signature  │
                    │ 2. Check expiration │
                    │ 3. Apply templates  │
                    │ 4. Sign new JWT     │
                    └─────────────────────┘
```

### Plugin Setup

For detailed setup instructions and a full working demo, see the [vault-plugin-identity-delegation repository](https://github.com/nicholasjackson/vault-plugin-identity-delegation), particularly the `./demo` folder which contains a complete runnable example.

### Agent Authentication

Agents authenticate to Vault before requesting token exchange:

```bash
# AppRole Authentication
VAULT_AUTH_METHOD=approle
VAULT_ROLE_ID=<role-id>
VAULT_SECRET_ID=<secret-id>

# Kubernetes Authentication
VAULT_AUTH_METHOD=kubernetes
VAULT_K8S_ROLE=<k8s-role>

# Common
VAULT_ADDR=http://localhost:8200
VAULT_IDENTITY_ROLE=customer-agent  # Role name for token exchange
```

### Permission Enforcement

MCP tools validate permissions at two levels using the delegated token:

1. **Agent Scope** (`scope` claim): What the agent is authorized to do
2. **User Permissions** (`subject_claims.permissions`): What the user is authorized to do

The effective permissions are the **intersection** of both - both the agent AND user must have the required permission.

**Example:**
| User | Agent | User Permissions | Agent Scope | Result |
|------|-------|------------------|-------------|--------|
| John | Customer | `read:customers` | `read:customers` | ✅ Can read customers |
| John | Weather | `read:customers` | `read:weather` | ❌ No overlap |
| Jane | Weather | `read:weather` | `read:weather` | ✅ Can read weather |

### Delegated Token Structure

The plugin generates JWTs with RFC 8693 compliant structure:

```json
{
  "iss": "https://vault.example.com",
  "sub": "user-123",
  "iat": 1699564800,
  "exp": 1699568400,
  "scope": "read:customers write:customers",
  "subject_claims": {
    "permissions": ["read:customers", "write:customers"],
    "email": "john@example.com"
  },
  "act": {
    "sub": "customer-agent",
    "iss": "https://vault.example.com"
  }
}
```

**Key Claims:**
- `scope` - Agent's permitted operations (from role's `context`)
- `subject_claims` - User's identity and permissions (from `subject_template`)
- `act` - RFC 8693 actor claim identifying the agent (from `actor_template`)

## Getting Started

### Prerequisites

- Docker and Docker Compose
- HashiCorp Vault with the identity delegation plugin
- Keycloak (for OIDC authentication)
- Ollama with llama3.2 model

### Running the Services

Each component has a `Makefile` with common targets:

```bash
# Build Docker image
make build

# Run the service
make run
```

### Environment Variables

See each component's README or configuration files for specific environment variable requirements.

## Development

### Project Documentation

Planning documents and implementation details are in the `.docs/` directory:

- `.docs/adhoc/` - Feature implementation plans
- `.docs/knowledge/` - Institutional knowledge and learnings

### Code Guidelines

See `CLAUDE.md` for AI-assisted development guidelines, including:
- LangGraph documentation resources
- Project-specific conventions
