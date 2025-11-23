import { useState } from 'react'
import ChatContainer from './components/ChatContainer'
import AgentSelector from './components/AgentSelector'

function App() {
  const [selectedAgent, setSelectedAgent] = useState('weather')
  const [showToolCalls, setShowToolCalls] = useState(false)

  return (
    <div className="min-h-screen bg-gradient-to-b from-slate-950 to-slate-900 text-slate-100">
      <div className="container mx-auto max-w-5xl h-screen flex flex-col">
        {/* Header */}
        <header className="flex-shrink-0 py-4 px-6 border-b border-slate-800/50 backdrop-blur-sm">
          <div className="flex items-center justify-between mb-3">
            <div>
              <h1 className="text-xl font-semibold text-slate-50">Agent Chat</h1>
              <p className="text-xs text-slate-500 mt-0.5">Powered by LangGraph</p>
            </div>

            {/* Tool Calls Toggle */}
            <label className="flex items-center gap-2.5 cursor-pointer group">
              <span className="text-xs text-slate-400 group-hover:text-slate-300 transition-colors">
                Show Tools
              </span>
              <div className="relative">
                <input
                  type="checkbox"
                  checked={showToolCalls}
                  onChange={(e) => setShowToolCalls(e.target.checked)}
                  className="sr-only peer"
                />
                <div className="w-9 h-5 bg-slate-700 rounded-full peer
                              peer-checked:bg-emerald-600 transition-all duration-200
                              peer-focus:ring-2 peer-focus:ring-emerald-500/20"></div>
                <div className="absolute left-0.5 top-0.5 w-4 h-4 bg-white rounded-full
                              peer-checked:translate-x-4 transition-transform duration-200
                              shadow-sm"></div>
              </div>
            </label>
          </div>

          <AgentSelector
            selectedAgent={selectedAgent}
            onSelectAgent={setSelectedAgent}
          />
        </header>

        {/* Chat Container */}
        <main className="flex-1 overflow-hidden">
          <ChatContainer
            selectedAgent={selectedAgent}
            showToolCalls={showToolCalls}
          />
        </main>
      </div>
    </div>
  )
}

export default App
