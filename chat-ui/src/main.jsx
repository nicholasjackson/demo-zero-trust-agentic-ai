import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import { AuthProvider } from 'react-oidc-context'
import './index.css'
import App from './App.jsx'

// Runtime config from /config.js (Kubernetes ConfigMap) or fallback to env/defaults
const runtimeConfig = window.__RUNTIME_CONFIG__ || {}

// Keycloak OIDC configuration for demo realm
const oidcConfig = {
  authority: runtimeConfig.KEYCLOAK_AUTHORITY || import.meta.env.VITE_KEYCLOAK_AUTHORITY || 'http://keycloak.container.local.jmpd.in:8080/realms/demo',
  client_id: runtimeConfig.KEYCLOAK_CLIENT_ID || import.meta.env.VITE_KEYCLOAK_CLIENT_ID || 'demo-app',
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
