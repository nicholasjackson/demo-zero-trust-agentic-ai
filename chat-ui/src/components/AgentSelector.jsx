export default function AgentSelector({ selectedAgent, onSelectAgent }) {
  // Use external config if available (from Kubernetes ConfigMap), otherwise use defaults
  const defaultAgents = [
    { id: 'weather', name: 'Weather', icon: '🌤️', description: 'Get weather information' },
    { id: 'customer', name: 'Customer', icon: '👤', description: 'Customer support queries' },
  ]

  const agents = window.AGENT_CONFIG?.agents || defaultAgents

  return (
    <div className="flex gap-2">
      {agents.map((agent) => (
        <button
          key={agent.id}
          onClick={() => onSelectAgent(agent.id)}
          className={`flex-1 px-4 py-2.5 rounded-lg font-medium transition-all duration-200
                     border ${
            selectedAgent === agent.id
              ? 'bg-emerald-600 hover:bg-emerald-500 text-white border-emerald-600 shadow-lg shadow-emerald-600/20'
              : 'bg-slate-800/50 hover:bg-slate-800 text-slate-300 hover:text-slate-100 border-slate-700/50'
          }`}
        >
          <div className="flex items-center justify-center gap-2">
            <span className="text-lg">{agent.icon}</span>
            <div className="text-left">
              <div className="text-sm font-semibold">{agent.name}</div>
              <div className="text-xs opacity-70">{agent.description}</div>
            </div>
          </div>
        </button>
      ))}
    </div>
  )
}
