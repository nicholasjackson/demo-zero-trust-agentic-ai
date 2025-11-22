# LangGraph Multi-Agent TLS Deployment Plan

## Overview

Comprehensive deployment plan for LangGraph multi-agent system with proper zero-trust security using HashiCorp Vault PKI and Envoy TLS sidecars. This architecture addresses the fundamental flaw in LangGraph's assumption that network-level TLS is sufficient by implementing workload-level identity and encryption.

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Agent Pod                             │
├─────────────────────────────────────────────────────────┤
│  ┌────────────────────────────────────────────────────┐  │
│  │     LangGraph Server                               │  │
│  │     (HTTP on 8000)                                 │  │
│  └───────────────────────┬────────────────────────────┘  │
│                          │ localhost:8000                │
│                          │                               │
│  ┌───────────────────────────────────────┐              │
│  │  Kubernetes Secret (VSO-managed)     │              │
│  │  ├── tls.crt                          │              │
│  │  ├── tls.key                          │              │
│  │  └── ca.crt                           │              │
│  └───────────────────────┬───────────────┘              │
│                          │ mounted volume                │
│                          ▼                               │
│  ┌────────────────┐                                     │
│  │  Envoy sidecar │◄──── HTTPS :8443 ──── External     │
│  │  (TLS term)    │                                     │
│  └────────────────┘                                     │
└─────────────────────────────────────────────────────────┘
```

## Phase 1: Infrastructure Setup

### 1.1 Deploy Vault PKI for Certificate Management

- Configure Vault PKI secrets engine with appropriate TTL settings
- Set up Kubernetes auth method for VSO authentication
- Configure certificate roles for each agent identity:
    - `weather-agent-role`: CN=weather-agent.agents.svc.cluster.local
    - `currency-agent-role`: CN=currency-agent.agents.svc.cluster.local
    - `orchestrator-agent-role`: CN=orchestrator-agent.agents.svc.cluster.local

### 1.2 Deploy Vault Secrets Operator

- Install VSO in the cluster via Helm chart
- Configure VSO with Vault connection and Kubernetes authentication
- Set up RBAC permissions for secret management across agent namespaces

### 1.3 Deploy Shared Infrastructure

- **Redis**: Configure with appropriate memory sizing for workload
    - Set unique `REDIS_KEY_PREFIX` values per agent to prevent data collisions
    - Implement monitoring for connection counts and memory usage
- **PostgreSQL**: Size database for checkpoint storage across all agents
    - Configure separate databases or schemas per agent if isolation preferred
    - Set up backup and recovery procedures for persistent state data

## Phase 2: TLS Implementation with VSO

### 2.1 Configure VaultPKISecret Resources

Create VaultPKISecret for each agent:

```yaml
apiVersion: secrets.hashicorp.com/v1beta1
kind: VaultPKISecret
metadata:
  name: weather-agent-tls
  namespace: agents
spec:
  vaultAuthRef: vault-auth
  mount: pki
  role: weather-agent-role
  commonName: weather-agent.agents.svc.cluster.local
  format: pem
  destination:
    name: weather-agent-tls-secret
    create: true
```

### 2.2 Envoy Sidecar Configuration

Create Envoy ConfigMap for TLS termination:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: envoy-tls-config
data:
  envoy.yaml: |
    static_resources:
      listeners:
      - name: https_listener
        address:
          socket_address:
            protocol: TCP
            address: 0.0.0.0
            port_value: 8443
        filter_chains:
        - transport_socket:
            name: envoy.transport_sockets.tls
            typed_config:
              "@type": type.googleapis.com/envoy.extensions.transport_sockets.tls.v3.DownstreamTlsContext
              common_tls_context:
                tls_certificates:
                - certificate_chain:
                    filename: /etc/ssl/certs/tls.crt
                  private_key:
                    filename: /etc/ssl/certs/tls.key
          filters:
          - name: envoy.filters.network.http_connection_manager
            typed_config:
              "@type": type.googleapis.com/envoy.extensions.filters.network.http_connection_manager.v3.HttpConnectionManager
              stat_prefix: ingress_http
              route_config:
                name: local_route
                virtual_hosts:
                - name: local_service
                  domains: ["*"]
                  routes:
                  - match:
                      prefix: "/"
                    route:
                      cluster: langgraph_service
              http_filters:
              - name: envoy.filters.http.router
      clusters:
      - name: langgraph_service
        connect_timeout: 30s
        type: STATIC
        load_assignment:
          cluster_name: langgraph_service
          endpoints:
          - lb_endpoints:
            - endpoint:
                address:
                  socket_address:
                    address: 127.0.0.1
                    port_value: 8000
```

## Phase 3: Build and Deployment Process

### 3.1 Update Agent Build Script

Modify existing `scripts/build-agents.sh`:

- Include Envoy sidecar configuration in container builds
- Add Vault Secrets Operator configuration templates
- Configure TLS certificate paths and rotation settings

### 3.2 Update Kubernetes Manifests

For each agent deployment, add:

```yaml
spec:
  template:
    spec:
      containers:
      - name: langgraph-server
        # existing LangGraph configuration
        ports:
        - containerPort: 8000
          name: http
      - name: envoy-sidecar
        image: envoyproxy/envoy:v1.28-latest
        ports:
        - containerPort: 8443
          name: https
        volumeMounts:
        - name: tls-certs
          mountPath: /etc/ssl/certs
          readOnly: true
        - name: envoy-config
          mountPath: /etc/envoy
        command: ["/usr/local/bin/envoy"]
        args: ["-c", "/etc/envoy/envoy.yaml"]
      volumes:
      - name: tls-certs
        secret:
          secretName: weather-agent-tls-secret  # VSO-managed
      - name: envoy-config
        configMap:
          name: envoy-tls-config
```

### 3.3 Service Configuration

Update services to expose HTTPS endpoints:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: weather-agent
spec:
  selector:
    app: weather-agent
  ports:
  - name: https
    port: 8443
    targetPort: 8443
    protocol: TCP
  - name: http-internal  # for health checks
    port: 8000
    targetPort: 8000
    protocol: TCP
```

## Phase 4: Agent-to-Agent Communication

### 4.1 Update Discovery Mechanism

- Configure orchestrator to discover agents via HTTPS endpoints
- Update agent HTTP clients to use TLS for inter-agent communication
- Implement proper certificate validation with mounted CA certificates

### 4.2 Certificate Validation Configuration

- Mount CA certificate from VSO-managed secrets for client-side validation
- Configure proper Server Name Indication (SNI) for multi-agent scenarios
- Implement retry logic with exponential backoff for certificate rotation periods

## Phase 5: Deployment Sequence

### 5.1 Infrastructure First

```bash
# Deploy shared infrastructure
kubectl apply -f manifests/infrastructure/vault-pki/
kubectl apply -f manifests/infrastructure/redis/
kubectl apply -f manifests/infrastructure/postgresql/

# Deploy Vault Secrets Operator
helm install vault-secrets-operator hashicorp/vault-secrets-operator
```

### 5.2 Certificate Management

```bash
# Deploy VaultPKISecret resources
kubectl apply -f manifests/certificates/

# Verify certificate generation
kubectl get vaultpkisecret -n agents
kubectl get secrets -n agents | grep tls-secret
```

### 5.3 Agent Deployment

```bash
# Deploy agents with TLS sidecars
kubectl apply -f manifests/agents/

# Verify TLS endpoints
kubectl get pods -n agents
kubectl logs -f deployment/weather-agent -c envoy-sidecar
```

## Phase 6: Validation and Security Testing

### 6.1 Certificate Lifecycle Testing

- Verify VSO creates certificates automatically from Vault PKI
- Test certificate rotation (force renewal, verify zero-downtime)
- Validate certificate chain from Vault PKI root CA
- Check Vault audit logs for all certificate issuance events

### 6.2 TLS Connectivity Testing

```bash
# Test HTTPS endpoints
curl -v https://weather-agent.agents.svc.cluster.local:8443/health

# Test inter-agent communication  
kubectl exec -it deployment/orchestrator -- curl -v \
  https://weather-agent.agents.svc.cluster.local:8443/api/v1/weather?city=London
```

### 6.3 Security Validation

- Verify no plaintext HTTP communication between agents
- Test certificate revocation scenarios
- Validate audit trail in Vault logs
- Confirm workload identity binding via Kubernetes service accounts

## Phase 7: Monitoring and Observability

### 7.1 TLS Metrics

- Monitor certificate expiration times
- Track TLS handshake success/failure rates
- Alert on certificate rotation failures

### 7.2 Agent Communication Metrics

- Monitor inter-agent request latency with TLS overhead
- Track failed agent discovery events
- Alert on certificate validation failures

## Benefits Demonstrated

### Security Advantages

- **Workload Identity**: Each agent has cryptographic identity via Vault-issued certificates
- **Zero Network Trust**: All communication encrypted, no reliance on network security
- **Certificate Lifecycle Management**: Automatic issuance, rotation, and revocation via Vault
- **Audit Trail**: Complete certificate and access logging in Vault
- **Defense in Depth**: TLS at application level, not just infrastructure level

### Enterprise Integration

- **HashiCorp Vault PKI**: Enterprise-grade certificate authority integration
- **Policy Enforcement**: Certificate policies enforced at Vault level
- **Compliance**: Full audit trail for regulatory requirements
- **Scalability**: VSO manages certificate lifecycle across all agent workloads

## Demo Talking Points

1. **Problem Statement**: LangGraph's assumption that network-level TLS is sufficient creates security gaps in zero-trust architectures
    
2. **Solution Architecture**: Workload-level identity and encryption using Vault PKI with Kubernetes-native secret management
    
3. **Key Demo Flow**:
    
    - Show Vault PKI issuing certificates for agent identities
    - Demonstrate VSO automatically delivering certificates as K8s secrets
    - Test agent-to-agent HTTPS communication with certificate validation
    - Show Vault audit logs capturing all certificate lifecycle events
4. **Zero Trust Validation**: Prove that agent communication is cryptographically secured independent of network infrastructure
    

## Next Steps

- [ ] Implement build script modifications for Envoy sidecar inclusion
- [ ] Create Kubernetes manifests with VSO integration
- [ ] Test certificate rotation scenarios
- [ ] Validate inter-agent HTTPS communication flows
- [ ] Create monitoring dashboards for TLS metrics
- [ ] Prepare demo scenarios for AWS re:Invent presentation

## Related Notes

- [[Vault PKI Certificate Management]]
- [[Zero Trust Agentic Security Presentation Outline]]
- [[Kubernetes Service Mesh Security Patterns]]
- [[HashiCorp Vault Enterprise Features]]