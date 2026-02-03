/**
 * Agent API service for interacting with Weather and Customer agents
 */

const AGENT_CONFIG = {
  weather: {
    name: 'Weather Agent',
    // Use /api/weather in both dev and production (proxied by Vite in dev, NGINX in prod)
    baseUrl: '/api/weather',
  },
  customer: {
    name: 'Customer Agent',
    baseUrl: '/api/customer',
  },
}

/**
 * Send a message to an agent and get all response messages
 * @param {string} agentId - Agent identifier ('weather' or 'customer')
 * @param {string} message - User message content
 * @param {string} [accessToken] - Optional JWT access token for authentication
 * @returns {Promise<Array>} - All messages from agent response
 */
export async function sendMessageToAgent(agentId, message, accessToken = null) {
  const agent = AGENT_CONFIG[agentId]

  if (!agent) {
    throw new Error(`Unknown agent: ${agentId}`)
  }

  // Build headers with optional Authorization
  const headers = {
    'Content-Type': 'application/json',
  }

  // Add Authorization header if access token is provided
  if (accessToken) {
    headers['Authorization'] = `Bearer ${accessToken}`
  }

  const response = await fetch(`${agent.baseUrl}/invoke`, {
    method: 'POST',
    headers,
    body: JSON.stringify({
      input: {
        messages: [
          {
            role: 'user',
            content: message,
          },
        ],
      },
    }),
  })

  if (!response.ok) {
    const errorText = await response.text()
    throw new Error(`API error (${response.status}): ${errorText}`)
  }

  const data = await response.json()

  // Return all messages from response
  return data.result?.messages || []
}

/**
 * Get agent configuration
 * @param {string} agentId - Agent identifier
 * @returns {object} - Agent config
 */
export function getAgentConfig(agentId) {
  return AGENT_CONFIG[agentId]
}

export const AVAILABLE_AGENTS = Object.keys(AGENT_CONFIG)
