import { useState } from 'react'
import { useAuth } from 'react-oidc-context'
import ChatContainer from './components/ChatContainer'
import AgentSelector from './components/AgentSelector'

function App() {
  const auth = useAuth()
  const [selectedAgent, setSelectedAgent] = useState('weather')
  const [showToolCalls, setShowToolCalls] = useState(false)

  // Get user's full name from profile (firstName + lastName)
  const userFullName = auth.user?.profile.given_name && auth.user?.profile.family_name
    ? `${auth.user.profile.given_name} ${auth.user.profile.family_name}`
    : auth.user?.profile.name || auth.user?.profile.email || 'User'

  return (
    <div className="min-h-screen bg-gradient-to-b from-slate-950 to-slate-900 text-slate-100">
      <div className="container mx-auto max-w-5xl h-screen flex flex-col">
        {/* Header */}
        <header className="flex-shrink-0 py-4 px-6 border-b border-slate-800/50 backdrop-blur-sm">
          <div className="flex items-center justify-between mb-3">
            {/* Left: Branding */}
            <div>
              <h1 className="text-xl font-semibold text-slate-50">Zero Trust Agentic Security</h1>
              <p className="text-xs text-slate-500 mt-0.5">
                Powered by Vault
                {/* Show logged in status in subtitle when authenticated */}
                {auth.isAuthenticated && (
                  <> • Logged in as {auth.user?.profile.email}</>
                )}
              </p>
            </div>

            {/* Right: Controls */}
            <div className="flex items-center gap-4">
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

              {/* Authentication Controls */}
              {auth.isLoading ? (
                // Show loading state during auth check
                <div className="flex items-center gap-2 text-xs text-slate-400">
                  <div className="w-3 h-3 border-2 border-slate-600 border-t-emerald-500 rounded-full animate-spin"></div>
                  <span>Loading...</span>
                </div>
              ) : auth.isAuthenticated ? (
                // Show user name and logout when authenticated
                <div className="flex items-center gap-3">
                  <span className="text-sm text-slate-300 font-medium">
                    {userFullName}
                  </span>
                  <button
                    onClick={() => auth.removeUser()}
                    className="px-3 py-1.5 text-xs text-slate-400 hover:text-slate-300
                             border border-slate-700 hover:border-slate-600 rounded
                             transition-colors"
                  >
                    Logout
                  </button>
                </div>
              ) : (
                // Show login button when not authenticated
                <button
                  onClick={() => auth.signinRedirect()}
                  className="px-4 py-2 text-sm font-medium text-white bg-emerald-600
                           hover:bg-emerald-500 rounded-lg transition-colors
                           shadow-sm hover:shadow-emerald-600/20"
                >
                  Login
                </button>
              )}
            </div>
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
            accessToken={auth.user?.access_token}
          />
        </main>
      </div>
    </div>
  )
}

export default App
