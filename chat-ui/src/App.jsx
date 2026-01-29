import { useState, useEffect } from 'react'
import { useAuth } from 'react-oidc-context'
import ChatContainer from './components/ChatContainer'
import AgentSelector from './components/AgentSelector'

function App() {
  const auth = useAuth()
  const [selectedAgent, setSelectedAgent] = useState('weather')
  const [showToolCalls, setShowToolCalls] = useState(false)
  const [showAuthError, setShowAuthError] = useState(false)

  // Show error popup when auth error occurs
  useEffect(() => {
    if (auth.error) {
      setShowAuthError(true)
    }
  }, [auth.error])

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
                    onClick={async () => {
                      const idToken = auth.user?.id_token
                      await auth.removeUser()
                      const authority = auth.settings.authority
                      const postLogoutUri = encodeURIComponent(window.location.origin)
                      window.location.href = `${authority}/protocol/openid-connect/logout?id_token_hint=${idToken}&post_logout_redirect_uri=${postLogoutUri}`
                    }}
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

      {/* Auth Error Popup */}
      {showAuthError && auth.error && (
        <div className="fixed inset-0 bg-black/50 backdrop-blur-sm flex items-center justify-center z-50">
          <div className="bg-slate-800 border border-slate-700 rounded-lg shadow-xl max-w-md w-full mx-4 p-6">
            <div className="flex items-start gap-4">
              <div className="flex-shrink-0 w-10 h-10 bg-red-500/20 rounded-full flex items-center justify-center">
                <svg className="w-5 h-5 text-red-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" />
                </svg>
              </div>
              <div className="flex-1">
                <h3 className="text-lg font-semibold text-slate-100">Login Failed</h3>
                <p className="mt-2 text-sm text-slate-400">
                  {auth.error.message || 'An error occurred during authentication. Please try again.'}
                </p>
              </div>
            </div>
            <div className="mt-6 flex justify-end gap-3">
              <button
                onClick={() => setShowAuthError(false)}
                className="px-4 py-2 text-sm text-slate-400 hover:text-slate-300
                         border border-slate-600 hover:border-slate-500 rounded-lg
                         transition-colors"
              >
                Dismiss
              </button>
              <button
                onClick={() => {
                  setShowAuthError(false)
                  auth.signinRedirect()
                }}
                className="px-4 py-2 text-sm font-medium text-white bg-emerald-600
                         hover:bg-emerald-500 rounded-lg transition-colors"
              >
                Try Again
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}

export default App
