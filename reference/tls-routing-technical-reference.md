# Modern Routing: The Practical Guide

**Zero Trust networking, hybrid SSL, and the messy realities of production infrastructure**

*Updated May 2025 - Battle-tested patterns from real deployments*

---

## The Architecture Decision Tree

Before diving into implementation details, understand the **fundamental trade-offs** that drive every routing decision:

### **Direct vs Tunneled Access**
- **Direct**: VPS IP → Traefik → Service (Let's Encrypt SSL, simpler debugging)
- **Tunneled**: Cloudflare Edge → Tunnel → Service (DDoS protection, no exposed ports)

### **The Docker Networking Reality**
Most guides ignore this: **container services can't reach each other via `localhost`**. You'll need:
- `host.docker.internal:PORT` for host services
- `container-name:PORT` for inter-container communication
- VPS IP for external references

### **SSL Certificate Strategy**
- **Let's Encrypt**: Direct access services, automatic renewal, 90-day validity
- **Cloudflare Origin**: Tunneled services, 15-year validity, zero rate limits
- **Wildcard Universal**: Catch-all for edge termination

---

## Core Infrastructure Components

### **Cloudflare Zero Trust Tunnel**
*The secure connection between your VPS and Cloudflare's edge*

```bash
# Installation (always use latest)
curl -L --output cloudflared.deb \
  https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
sudo dpkg -i cloudflared.deb

# Service installation with token
sudo cloudflared service install --token YOUR_TUNNEL_TOKEN
sudo systemctl enable --now cloudflared
```

**Key Insight**: Tunnels create **outbound-only connections**. Your VPS never accepts inbound traffic on exposed ports.

### **Coolify Service Orchestration**
*Docker-based PaaS with Traefik reverse proxy*

```bash
# Installation
curl -fsSL https://cdn.coollabs.io/coolify/install.sh | sudo bash

# Post-install: Set domain immediately
echo "APP_URL=https://your-domain.com" >> /data/coolify/source/.env
cd /data/coolify/source && sudo docker compose -f docker-compose.yml -f docker-compose.prod.yml restart
```

**Critical Detail**: Coolify's Traefik proxy only routes domains specified in its configuration. Random subdomains won't work without explicit setup.

### **Traefik Dynamic Configuration**
*Runtime routing rules for custom services*

Location: `/data/coolify/proxy/dynamic/`

```yaml
# Template for any HTTP service requiring HTTPS
http:
  routers:
    service-name:
      rule: Host(`service.your-domain.com`)
      entryPoints: [https]
      service: service-name
      tls:
        certresolver: letsencrypt
  services:
    service-name:
      loadBalancer:
        servers:
          - url: 'http://host.docker.internal:PORT'  # For host services
          - url: 'http://container-name:PORT'        # For containers
```

---

## Production Patterns That Actually Work

### **Pattern 1: Administrative Services (Direct SSL)**
*Coolify dashboard, monitoring, admin panels*

**DNS**: `A` record pointing to VPS IP, **not proxied**
**SSL**: Let's Encrypt via Traefik
**Access**: Direct to VPS, bypass Cloudflare entirely

```dns
admin.example.com.    A    YOUR_VPS_IP    ; Proxied: OFF
```

**Why**: Administrative access shouldn't depend on external services. When Cloudflare is down, you still need server access.

### **Pattern 2: Public Applications (Tunneled)**
*User-facing apps, APIs, high-traffic services*

**DNS**: `CNAME` to tunnel domain
**SSL**: Cloudflare Origin Certificate (15-year)
**Access**: Edge → Tunnel → Service

```dns
app.example.com.    CNAME    uuid.cfargotunnel.com    ; Proxied: ON
```

**Why**: DDoS protection, global CDN, free bandwidth, advanced security features.

### **Pattern 3: Nested Container Services**
*Services running inside other containers (like BlueMap in Crafty)*

**The Problem**: Service exists at `container:PORT` but Traefik needs to route external domains to it.

**The Solution**: Docker host networking
```yaml
# Traefik config for nested services
services:
  nested-service:
    loadBalancer:
      servers:
        - url: 'http://host.docker.internal:8100'  # Not localhost!
```

**Real Example**: BlueMap runs inside Crafty container, exposed on host port 8100, accessed via `host.docker.internal:8100`.

---

## The Hybrid SSL Architecture

Based on the decision tree above, here's the production-tested approach:

### **Cloudflare Universal SSL (Edge)**
- Handles all `*.your-domain.com` automatically
- Covers both tunneled and direct services
- Zero configuration required

### **Let's Encrypt (Direct Services)**
```yaml
# Traefik automatic certificate generation
tls:
  certresolver: letsencrypt  # Configured by Coolify
```

### **Origin Certificates (Tunneled Services)**
Generate once in Cloudflare dashboard:
- Validity: 15 years
- Coverage: `*.your-domain.com` + `your-domain.com`
- Format: PEM (for most web servers)

**Install location**: `/data/coolify/proxy/certs/`
**Permissions**: `600` owned by `9999:root`

---

## Docker Networking Deep Dive

### **The Localhost Trap**
Container-to-container communication **never** uses `localhost`. Common mistakes:

```yaml
# ❌ Wrong - won't work from Traefik container
- url: 'http://localhost:8100'

# ✅ Correct options:
- url: 'http://host.docker.internal:8100'  # Host service
- url: 'http://service-container:8100'     # Container service
- url: 'http://172.17.0.1:8100'           # Docker bridge IP
```

### **Service Discovery Debugging**
```bash
# Check what's accessible from Traefik container
docker exec coolify-proxy ping host.docker.internal
docker exec coolify-proxy wget -qO- http://host.docker.internal:8100

# Inspect Docker networks
docker network ls
docker network inspect coolify
```

### **Port Binding Reality**
When Coolify deploys containers, port bindings create **host accessibility**:
```yaml
# In docker-compose.yml
ports:
  - "8100:8100"  # Creates host.docker.internal:8100 access
```

---

## Real-World Implementation: Crafty + BlueMap

*How we solved the actual routing problem*

### **The Setup**
- **Crafty Controller**: Minecraft server management (HTTPS self-signed on 8443)
- **BlueMap**: 3D world viewer running inside Crafty (HTTP on 8100)
- **Coolify**: Managing Crafty as Docker service

### **The Challenge**
BlueMap exists as a **service within a service** - it's not a direct Docker container, but a process inside Crafty's container.

### **DNS Architecture**
```dns
# Administrative access (direct)
coolify.inherent.design.     A    46.202.176.108    ; Proxied: OFF

# User services (tunneled)  
crafty.inherent.design.      CNAME    tunnel.cfargotunnel.com    ; Proxied: ON

# Nested services (hybrid)
mcmap.inherent.design.       A    46.202.176.108    ; Proxied: OFF
```

### **Tunnel Configuration**
```yaml
# /etc/cloudflared/config.yml
ingress:
  - hostname: crafty.inherent.design
    service: https://host.docker.internal:8443
    originRequest:
      noTLSVerify: true  # Self-signed certificate
```

### **Traefik Configuration**
```yaml
# /data/coolify/proxy/dynamic/bluemap.yaml
http:
  routers:
    mcmap-router:
      rule: Host(`mcmap.inherent.design`)
      entryPoints: [https]
      service: bluemap-mcmap
      tls:
        certresolver: letsencrypt
  services:
    bluemap-mcmap:
      loadBalancer:
        servers:
          - url: 'http://host.docker.internal:8100'  # Key insight!
```

### **The Critical Learning**
**Docker networking is not intuitive**. Services running inside containers managed by Coolify require `host.docker.internal` to be accessible by Traefik's reverse proxy. This isn't documented anywhere obvious.

---

## Debugging Production Issues

### **SSL Certificate Problems**

**Symptom**: `TRAEFIK DEFAULT CERT` appears instead of Let's Encrypt
**Cause**: Certificate generation failure or corrupted ACME data
**Fix**:
```bash
# Nuclear option - reset ACME completely
docker stop coolify-proxy
sudo rm /data/coolify/proxy/acme.json
sudo touch /data/coolify/proxy/acme.json
sudo chmod 600 /data/coolify/proxy/acme.json
sudo chown 9999:root /data/coolify/proxy/acme.json
docker start coolify-proxy
# Wait 2 minutes for generation
```

### **502 Bad Gateway Errors**

**Most Common Cause**: Service unreachable from Traefik container
**Debug Process**:
```bash
# 1. Check if service responds locally
curl -I http://localhost:PORT

# 2. Check from Traefik's perspective  
docker exec coolify-proxy wget -qO- http://host.docker.internal:PORT

# 3. Fix networking in Traefik config
# Use host.docker.internal instead of localhost
```

### **DNS Resolution Issues**

**Symptom**: Domain works sometimes, fails other times
**Cause**: DNS propagation or proxy status mismatch
**Debug**:
```bash
# Check current DNS resolution
dig your-domain.com
nslookup your-domain.com

# Verify proxy status matches routing method
# Tunneled services: Proxied ON
# Direct services: Proxied OFF
```

---

## Production Monitoring

### **Health Check Script**
```bash
#!/bin/bash
# /opt/routing-health-check.sh

DOMAINS=("admin.example.com" "app.example.com" "api.example.com")

for domain in "${DOMAINS[@]}"; do
  if curl -sf --max-time 10 "https://$domain" > /dev/null; then
    echo "✅ $domain"
  else
    echo "❌ $domain"
    # Add alerting logic here
  fi
done
```

### **SSL Expiration Monitoring**
```bash
#!/bin/bash
# Check certificate expiration
for domain in "${DOMAINS[@]}"; do
  expiry=$(echo | openssl s_client -servername "$domain" -connect "$domain:443" 2>/dev/null | \
           openssl x509 -noout -dates | grep notAfter | cut -d= -f2)
  days_left=$(( ($(date -d "$expiry" +%s) - $(date +%s)) / 86400 ))
  
  if [ $days_left -lt 30 ]; then
    echo "⚠️  $domain expires in $days_left days"
  fi
done
```

---

## The Philosophical Framework

### **Complexity Budget**
Every architectural decision has a **complexity cost**. The goal isn't to use every available feature, but to solve actual problems with the simplest possible approach.

**Trade-offs we've tested**:
- **Tunnels everywhere**: Simpler networking, vendor lock-in
- **Direct everything**: More control, more attack surface  
- **Hybrid approach**: Balanced complexity, clear separation of concerns

### **The Docker Reality**
Modern infrastructure is **container-native**. Traditional networking assumptions (localhost, port binding) often don't apply. Plan for container-to-container communication from the start.

### **Operational Simplicity**
**The best architecture is the one you can debug at 3 AM**. Prefer explicit configuration over magical auto-discovery. Document the non-obvious (like `host.docker.internal`).

---

## Quick Reference

### **Command Arsenal**
```bash
# SSL debugging
echo | openssl s_client -servername DOMAIN -connect DOMAIN:443 | grep subject

# DNS verification  
dig DOMAIN +short

# Container networking
docker exec coolify-proxy ping host.docker.internal

# Traefik restart
docker restart coolify-proxy

# Certificate reset
sudo rm /data/coolify/proxy/acme.json && docker restart coolify-proxy
```

### **Configuration Locations**
- **Cloudflare Tunnel**: `/etc/cloudflared/config.yml`
- **Coolify Environment**: `/data/coolify/source/.env`
- **Traefik Dynamic**: `/data/coolify/proxy/dynamic/*.yml`
- **SSL Certificates**: `/data/coolify/proxy/acme.json`

### **Decision Matrix**
| Service Type | DNS Record | SSL Method | Access Pattern |
|-------------|------------|------------|----------------|
| Admin/Monitoring | A (not proxied) | Let's Encrypt | Direct to VPS |
| Public Apps | CNAME (proxied) | Origin Cert | Cloudflare Tunnel |
| Nested Services | A (not proxied) | Let's Encrypt | host.docker.internal |

---

## Documentation Sources

*Verified as of May 2025*

**Cloudflare Zero Trust**: https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/  
**Coolify Installation**: https://coolify.io/docs/installation  
**BlueMap Docker Networking**: https://bluemap.bluecolored.de/community/CoolifyAndTraefikProxy.html  
**Traefik Configuration**: https://doc.traefik.io/traefik/routing/routers/  

---

*Architecture is the art of drawing lines between things that matter and things that don't. In production, the line is often drawn by what breaks at 3 AM.*