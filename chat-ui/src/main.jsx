import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import { AuthProvider } from 'react-oidc-context'
import './index.css'
import App from './App.jsx'

// Keycloak OIDC configuration for demo realm
// Use environment variable for authority URL, fallback to localhost for dev
const oidcConfig = {
  authority: import.meta.env.VITE_KEYCLOAK_AUTHORITY || 'http://localhost:8080/realms/demo',
  client_id: import.meta.env.VITE_KEYCLOAK_CLIENT_ID || 'demo-app',
  redirect_uri: window.location.origin,
  post_logout_redirect_uri: window.location.origin,
  scope: 'openid profile email',
  response_type: 'code',
  automaticSilentRenew: true,
  loadUserInfo: true,
}

createRoot(document.getElementById('root')).render(
  <StrictMode>
    <AuthProvider {...oidcConfig}>
      <App />
    </AuthProvider>
  </StrictMode>,
)
