# Agent Chat UI

Modern React-based chat interface for LangGraph agents with dark mode design and tool call visualization.

## Features

- 🎨 **Modern UI** - Clean dark mode interface with gradient backgrounds
- 🔄 **Multi-Agent Support** - Switch between Weather and Customer agents
- 🛠️ **Tool Visualization** - Toggle to show/hide agent tool calls and results
- ⚡ **Fast Development** - Vite with Hot Module Replacement
- 📱 **Responsive Design** - Works on desktop and mobile

## Quick Start

### Development

```bash
# Install dependencies
npm install

# Start development server
npm run dev
# Visit http://localhost:5173
```

### Build for Production

```bash
# Build optimized bundle
npm run build

# Preview production build
npm run preview
```

## Agent Configuration

The UI supports multiple agents that can be switched at runtime. Configuration differs between development and production environments.

### Production Configuration (Kubernetes)

In production, agents are configured via ConfigMaps for zero-downtime updates:

**Edit the ConfigMap:**
```bash
kubectl edit configmap chat-ui-config -n chat-ui
```

**Add/modify agents in the `config.js` data:**
```js
window.AGENT_CONFIG = {
  agents: [
    {
      id: 'weather',
      name: 'Weather',
      icon: '🌤️',
      description: 'Get weather information',
      baseUrl: '/api/weather'
    },
    {
      id: 'customer',
      name: 'Customer',
      icon: '👤',
      description: 'Customer support queries',
      baseUrl: '/api/customer'
    },
    // Add new agents here
  ]
};
```

**Apply changes:**
```bash
kubectl rollout restart deployment chat-ui -n chat-ui
```

**Add NGINX proxy routes** if needed (edit `chat-ui-nginx-config` ConfigMap):
```nginx
location /api/support/ {
    proxy_pass http://support-agent.agents.svc.cluster.local:8125/;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
}
```

### Development Configuration

For local development, agents are configured in three files:

#### 1. Frontend - Agent Selector

Edit `src/components/AgentSelector.jsx` to add default agents:

```jsx
const defaultAgents = [
  {
    id: 'weather',
    name: 'Weather',
    icon: '🌤️',
    description: 'Get weather information'
  },
  {
    id: 'customer',
    name: 'Customer',
    icon: '👤',
    description: 'Customer support queries'
  },
]
```

**Note:** These are fallback defaults. Production uses `window.AGENT_CONFIG` from ConfigMap.

#### 2. API Service - Backend URLs

Edit `src/services/agentApi.js` to configure API endpoints:

```js
const AGENT_CONFIG = {
  weather: {
    name: 'Weather Agent',
    baseUrl: '/api/weather',  // Proxied to agent backend
  },
  customer: {
    name: 'Customer Agent',
    baseUrl: '/api/customer',  // Proxied to agent backend
  },
}
```

#### 3. Development Proxy

Edit `vite.config.js` to configure dev server proxies:

```js
server: {
  proxy: {
    '/api/weather': {
      target: 'http://localhost:18123',  // Weather agent port
      changeOrigin: true,
      rewrite: (path) => path.replace(/^\/api\/weather/, ''),
    },
    '/api/customer': {
      target: 'http://localhost:18124',  // Customer agent port
      changeOrigin: true,
      rewrite: (path) => path.replace(/^\/api\/customer/, ''),
    },
  },
}
```

### Adding a New Agent

**Production (Kubernetes):**
1. Edit `chat-ui-config` ConfigMap to add agent to `window.AGENT_CONFIG.agents` array
2. Edit `chat-ui-nginx-config` ConfigMap to add proxy route
3. Restart deployment: `kubectl rollout restart deployment chat-ui -n chat-ui`

**Development:**
1. Add to `AgentSelector.jsx` `defaultAgents`
2. Add to `agentApi.js` `AGENT_CONFIG`
3. Add to `vite.config.js` proxy configuration

**Example - Adding "Support Agent" on port 18125:**

```jsx
// AgentSelector.jsx
{ id: 'support', name: 'Support', icon: '🎧', description: 'Technical support' }

// agentApi.js
support: { name: 'Support Agent', baseUrl: '/api/support' }

// vite.config.js
'/api/support': {
  target: 'http://localhost:18125',
  changeOrigin: true,
  rewrite: (path) => path.replace(/^\/api\/support/, ''),
}
```

The new agent will appear in the UI automatically!

## Architecture

### Technology Stack
- **React 18** - UI framework
- **Vite** - Build tool with fast HMR
- **Tailwind CSS v4** - Utility-first styling with dark mode
- **LangGraph** - Agent backend (via API)

### Project Structure
```
chat-ui/
├── src/
│   ├── components/
│   │   ├── AgentSelector.jsx    # Agent switcher buttons
│   │   ├── ChatContainer.jsx    # Main chat logic & state
│   │   ├── MessageList.jsx      # Message display & bubbles
│   │   └── MessageInput.jsx     # Input field & send button
│   ├── services/
│   │   └── agentApi.js          # API service layer
│   ├── App.jsx                  # Root component
│   └── index.css                # Tailwind imports
├── vite.config.js               # Vite configuration
└── tailwind.config.js           # Tailwind configuration
```

### API Integration

The UI communicates with LangGraph agents via REST APIs:

**Request Format:**
```json
{
  "input": {
    "messages": [
      { "role": "user", "content": "What's the weather in London?" }
    ]
  }
}
```

**Response Format:**
```json
{
  "result": {
    "messages": [
      { "type": "ai", "content": "In London, UK, it's currently 15°C..." },
      { "type": "tool", "name": "get_weather", "content": "{...}" }
    ]
  }
}
```

### Tool Call Visualization

When "Show Tools" toggle is enabled, the UI displays:
- **Tool Calls** - Function invocations with parameters (purple bubbles)
- **Tool Results** - JSON responses from tools (green bubbles)

When disabled, only user and assistant messages are shown.

## Development

### Prerequisites
- Node.js 20 or later
- Weather Agent running on `localhost:18123`
- Customer Agent running on `localhost:18124`

### Environment
All configuration is compile-time via Vite. No environment variables required.

### Styling
The UI uses Tailwind CSS v4 with custom dark mode colors:

```js
colors: {
  'dark-bg': '#0f172a',        // slate-900
  'dark-surface': '#1e293b',   // slate-800
  'dark-border': '#334155',    // slate-700
  'dark-text': '#e2e8f0',      // slate-200
  'dark-text-muted': '#94a3b8', // slate-400
  'primary': '#3b82f6',        // blue-500
  'primary-hover': '#2563eb',  // blue-600
}
```

## Deployment

The chat UI is deployed to Kubernetes alongside the agents.

### Build Docker Image

```bash
# Build image
make build

# Or with custom version
make build VERSION=1.0.0

# Push to registry (requires authentication)
make push
```

### Deploy to Kubernetes

The chat UI is automatically deployed via Jumppad configuration:

```bash
# From project root
jumppad up

# Verify deployment
kubectl get pods -n chat-ui
kubectl get svc -n chat-ui
```

### Access

**Production Access:** http://localhost:18090

The UI is exposed via Jumppad ingress and proxies API requests to:
- Weather Agent: `http://weather-agent.agents.svc.cluster.local:8123`
- Customer Agent: `http://customer-agent.agents.svc.cluster.local:8124`

### Kubernetes Resources

- **Namespace**: `chat-ui`
- **Deployment**: `chat-ui` (1 replica)
- **Service**: `chat-ui` (ClusterIP on port 80)
- **Ingress**: Port 18090 → chat-ui service

See `../jumppad/k8s/chat-ui.yaml` for full configuration.

## Troubleshooting

### UI loads but API calls fail
- Ensure agent backends are running on the correct ports
- Check browser console for CORS or network errors
- Verify Vite proxy configuration in `vite.config.js`

### Build errors about Tailwind
- Ensure `@tailwindcss/postcss` is installed: `npm install -D @tailwindcss/postcss`
- Check `postcss.config.js` uses `@tailwindcss/postcss` (not `tailwindcss`)

### Messages not displaying
- Check browser console for errors
- Verify API response format matches expected structure
- Enable "Show Tools" toggle to see all messages including tool calls

## Contributing

When adding features:
1. Follow existing component patterns
2. Use Tailwind utility classes for styling
3. Keep components small and focused
4. Test with both Weather and Customer agents
5. Ensure responsive design works on mobile

## License

Part of the demo-agentic-zero-trust project.
