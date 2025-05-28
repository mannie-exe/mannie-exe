# Modern Routing: You're My Route, You're My Source

**A hands-on guide to securing VPS services with proper networking**

*Learn by doing: From zero to production-ready infrastructure*

---

**Navigation**: [Next: Migration & Troubleshooting →](01-modern-routing.md) | [Future: Security Hardening →](02-modern-routing.md)

---

## What We're Building (And Why It Matters)

**The Goal**: Transform a basic VPS into a secure, scalable platform that can host multiple services with proper domain names and HTTPS certificates.

**What You'll Have When We're Done**:
- Multiple services accessible via clean URLs (`https://app.yourdomain.com`)
- Automatic TLS certificates that renew themselves
- Protection against common attacks and monitoring
- A clear understanding of when to use different approaches

**Why This Matters**:
- **Security**: Encrypted connections protect your data and users
- **Professionalism**: Real domains instead of `http://192.168.1.100:8080`
- **Scalability**: Patterns that work for 1 service or 100 services
- **Reliability**: Infrastructure that doesn't break when you're asleep

## What Are We Actually Hosting?

**TL;DR**: We're running Minecraft servers with web-based management, plus 3D map visualization. But the networking patterns apply to *any* self-hosted services.

**The Specific Services**:
- **🏗️ Crafty Controller** - Web-based Minecraft server management panel (`https://crafty.yourdomain.com`)
  - Think: cPanel but for Minecraft servers
  - Manages multiple server instances, backups, logs, player management
  - Runs on port 8000, needs HTTPS for security

- **🗺️ BlueMap** - 3D web-based world visualization (`https://mcmap.yourdomain.com`) 
  - Renders your Minecraft worlds as interactive 3D maps in the browser
  - Like Google Earth but for your Minecraft builds
  - Runs on port 8100, serves static files + real-time updates
  - **🎯 Plot twist**: It's a service *inside* Crafty, creating fun networking challenges

- **⚡ Coolify** - Self-hosted deployment platform (`https://coolify.yourdomain.com`)
  - Think: Heroku/Vercel but on your own server
  - Manages Docker containers, SSL certificates, reverse proxy (Traefik)
  - The foundation that makes hosting other services trivial

**Why These Services Matter for Learning**:
- **Real-world complexity**: Multiple ports, different protocols, actual users
- **Security requirements**: Authentication, SSL, public internet exposure
- **Performance considerations**: Static files, WebSocket connections, resource management
- **Practical value**: You end up with genuinely useful infrastructure

*The same patterns we'll use work for hosting anything: web apps, APIs, databases, monitoring tools, personal clouds, etc.*

---

## Networking Fundamentals (The 5-Minute Primer)

If you've never set up DNS or understand what happens when you type a URL, start here. If you're comfortable with these concepts, [jump to implementation](#getting-started).

### **What Happens When You Visit a Website**

1. **DNS Lookup**: Your browser asks "What IP address is `google.com`?"
2. **Connection**: Browser connects to that IP address on port 443 (HTTPS)
3. **TLS Handshake**: Browser and server establish encrypted connection
4. **Request/Response**: Browser asks for webpage, server responds

### **The Key Players**

**Domain Registrar**: Where you bought your domain (`yourdomain.com`)
**DNS Provider**: Controls where `yourdomain.com` points (often Cloudflare)
**VPS**: Your virtual server with an IP address (like `46.202.176.108`)
**Reverse Proxy**: Routes incoming requests to the right service (Traefik)
**TLS Certificate**: Proves your server is who it claims to be

### **What We're Actually Doing**

**Before**: Services only accessible via IP and port (`http://46.202.176.108:8080`)
**After**: Services accessible via domain (`https://app.yourdomain.com`)

**The Magic**: DNS points domains to your VPS, reverse proxy routes requests to services, TLS certificates encrypt everything.

---

## Getting Started

### **What You Need**

**Required**:
- VPS with SSH access (we'll use Ubuntu 22.04)
- Domain name with DNS managed by Cloudflare
- Basic command line comfort

**Recommended Server Specs**:
- 4GB RAM (minimum 2GB)
- 2 CPU cores
- 40GB storage
- Ubuntu 22.04 LTS

### **Step 1: Basic VPS Security**

Before anything else, secure your server:

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Create non-root user (if you don't have one)
sudo adduser yourusername
sudo usermod -aG sudo yourusername

# Configure SSH (disable root login, key-only auth)
sudo nano /etc/ssh/sshd_config
# Set: PermitRootLogin no
# Set: PasswordAuthentication no
sudo systemctl restart ssh

# Basic firewall
sudo ufw allow ssh
sudo ufw allow 80
sudo ufw allow 443
sudo ufw enable
```

**Why This Matters**: An unsecured VPS will be compromised within hours. These steps prevent the most common attack vectors.

### **Step 2: Install Coolify (Your Service Manager)**

Coolify automates service deployment and provides a reverse proxy (Traefik) that handles TLS certificates^[1]:

```bash
# Install Coolify
curl -fsSL https://cdn.coollabs.io/coolify/install.sh | sudo bash

# Wait for installation to complete
# Access at http://YOUR_VPS_IP:8000
```

**Important**: Create your admin account immediately after installation. The first person to visit the setup page gets full access^[2].

---

## Understanding the Two Routing Pathways

All routing starts with **Cloudflare DNS**, but from there, traffic can take two different paths to your VPS:

### **Pathway 1: Direct VPS Access**
*For administrative services like Coolify dashboard*

```
User → Cloudflare DNS → Your VPS → Traefik → Service
```

**DNS Configuration:**
```dns
coolify.yourdomain.com    A    YOUR_VPS_IP    ; Proxied: OFF (🟠)
```

**What Happens:**
1. User visits `https://coolify.yourdomain.com`
2. Cloudflare DNS returns your VPS IP (`46.202.176.108`)
3. Browser connects directly to your VPS
4. Traefik handles TLS with Let's Encrypt and routes to service

**Best For:** Admin panels, development, monitoring, low-traffic services

### **Pathway 2: Cloudflare Tunnel**
*For public services like Crafty Controller*

```
User → Cloudflare DNS → Cloudflare Edge → Tunnel → Your VPS → Service
```

**DNS Configuration:**
```dns
crafty.yourdomain.com    CNAME    tunnel-uuid.cfargotunnel.com    ; Proxied: ON (🟡)
```

**What Happens:**
1. User visits `https://crafty.yourdomain.com`
2. Cloudflare DNS points to tunnel endpoint
3. Request hits Cloudflare's edge network first
4. Cloudflare routes through secure tunnel to your VPS
5. Cloudflared daemon forwards to your service

**Best For:** Public websites, APIs, high-traffic services, DDoS protection^[3,8]

### **Implementing Pathway 1: Direct Access (Coolify)**

Let's set up Coolify using the direct pathway:

**Step 1: Configure DNS (Direct Pathway)**
1. Go to Cloudflare Dashboard → DNS → Records
2. Add record:
   - Type: `A`
   - Name: `coolify` (or `luminode` as in our example)
   - IPv4 address: `YOUR_VPS_IP`
   - Proxy status: 🟠 **DNS only** (not proxied)

*This creates the direct pathway: DNS → VPS*

**Step 2: Configure Coolify Domain**
```bash
# Edit Coolify configuration
sudo nano /data/coolify/source/.env

# Add this line:
APP_URL=https://coolify.yourdomain.com

# Restart Coolify
cd /data/coolify/source
sudo docker compose -f docker-compose.yml -f docker-compose.prod.yml restart
```

**Step 3: Wait and Test the Direct Pathway**
- Wait 2-3 minutes for Let's Encrypt certificate generation^[7,10]
- Visit `https://coolify.yourdomain.com`
- You should see the Coolify login page with a valid certificate
- Traffic flow: `Your Browser → Cloudflare DNS → Your VPS → Traefik → Coolify`

**If It Doesn't Work**: Check the [debugging section](#common-issues) below^[8].

---

## Adding More Services

Now that you understand the pattern, let's add different types of services:

### **Deploying a Simple Web Application**

**Option A: Using Coolify's Interface**
1. Login to Coolify → Projects → New Project
2. Add Resource → Application
3. Choose source (Git repository or Docker image)
4. Set domain: `app.yourdomain.com`
5. Deploy

**Option B: Custom Docker Service**
1. Coolify → Projects → New Project
2. Add Resource → Docker Compose
3. Use this template:

```yaml
services:
  webapp:
    image: nginx:alpine
    volumes:
      - ./html:/usr/share/nginx/html:ro
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.webapp.rule=Host(`app.yourdomain.com`)"
      - "traefik.http.routers.webapp.entrypoints=https"
      - "traefik.http.routers.webapp.tls.certresolver=letsencrypt"
```

### **The Service-in-Service Problem**

**Real-World Example**: BlueMap runs inside Crafty Controller

Sometimes you need to expose a service that's running inside another service. This is where Docker networking gets tricky.

**The Problem**: Service runs on `localhost:8100` inside a container, but Traefik can't reach `localhost` from its own container.

**The Solution**: Use `host.docker.internal`

```bash
# Create custom Traefik configuration
sudo nano /data/coolify/proxy/dynamic/nested-service.yaml
```

```yaml
http:
  routers:
    nested-service:
      rule: Host(`nested.yourdomain.com`)
      entryPoints: [https]
      service: nested-service
      tls:
        certresolver: letsencrypt
  services:
    nested-service:
      loadBalancer:
        servers:
          - url: 'http://host.docker.internal:8100'  # Key insight!
```

```bash
# Restart Traefik to load new config
docker restart coolify-proxy
```

**Why This Works**: `host.docker.internal` is Docker's way of letting containers access the host machine's network^[5]. This approach is detailed in community guides for BlueMap integration with Coolify and Traefik^[6].

---

## Implementing Pathway 2: Cloudflare Tunnels

*Setting up the tunnel pathway for public services*

Now let's implement the tunnel pathway for services that need Cloudflare's protection and performance benefits.

### **When Each Pathway Makes Sense**

**Use Direct Pathway (like Coolify) For**:
- Administrative interfaces that need reliable access
- Development/staging environments
- Services where you want to bypass any external dependencies

**Use Tunnel Pathway (like Crafty) For**:
- Public websites and applications
- APIs with high traffic
- Services needing DDoS protection
- When you want to hide your VPS IP

### **Setting Up Your First Tunnel**

You have two options for deploying and configuring cloudflared^[3]:

#### **Option A: Coolify Service + Zero Trust UI (Recommended)**

**Step 1: Deploy via Coolify Services Panel**
1. Navigate to your Coolify dashboard
2. Go to Services → Add New Service  
3. Search for "cloudflared" in the service templates
4. Deploy the cloudflared service
5. The service will automatically create a tunnel and provide connection details

**Step 2: Configure via Zero Trust Dashboard**
1. Visit [Cloudflare Zero Trust](https://one.dash.cloudflare.com)^[4]
2. Networks → Tunnels → Your tunnel (created by the service)
3. Public Hostnames → Add a public hostname
4. Configure:
   - Subdomain: `api`
   - Domain: `yourdomain.com` 
   - Service: `http://localhost:3000`
5. Save

**Step 3: DNS Record Auto-Created**
Cloudflare automatically creates the DNS record:
```dns
api.yourdomain.com    CNAME    tunnel-uuid.cfargotunnel.com    ; Proxied: ON
```

#### **Option B: Manual Installation**

If you need custom configuration or prefer manual control:

**Step 1: Create Tunnel in Cloudflare**
1. Visit [Cloudflare Zero Trust](https://one.dash.cloudflare.com)
2. Networks → Tunnels → Create a tunnel
3. Choose "Cloudflared"
4. Name it descriptively: `production-services-2025`
5. Save and copy the tunnel token

**Step 2: Install on VPS**
```bash
# Install cloudflared
curl -L --output cloudflared.deb \
  https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
sudo dpkg -i cloudflared.deb

# Install as service with token
sudo cloudflared service install --token YOUR_TUNNEL_TOKEN
sudo systemctl enable --now cloudflared
```

**Note**: The Coolify service approach simplifies deployment and uses the Zero Trust web interface for configuration, eliminating the need for manual config files while maintaining full functionality.

### **Advanced Tunnel Configuration**

#### **Using Zero Trust Dashboard (Recommended)**

For most configurations, use the web interface^[4]:
1. Zero Trust → Networks → Tunnels → Your tunnel
2. Public Hostnames → Add/Edit
3. Configure advanced settings:
   - **TLS Settings**: No-TLS verify for services with self-signed certs
   - **HTTP Settings**: Custom headers, host header override
   - **Access Control**: Cloudflare Access policies

#### **Manual Configuration Files**

For complex setups or when using manual installation:

```bash
# Create tunnel with specific configuration
sudo mkdir -p /etc/cloudflared
sudo nano /etc/cloudflared/config.yml
```

```yaml
tunnel: YOUR-TUNNEL-UUID
credentials-file: /root/.cloudflared/YOUR-TUNNEL-UUID.json

ingress:
  # Public API
  - hostname: api.yourdomain.com
    service: http://localhost:3000

  # Service with self-signed certificates
  - hostname: secure.yourdomain.com
    service: https://localhost:8443
    originRequest:
      noTLSVerify: true

  # Nested service (like BlueMap in Crafty)
  - hostname: map.yourdomain.com
    service: http://localhost:8100

  # Catch-all
  - service: http_status:404
```

```bash
# Restart with new configuration
sudo systemctl restart cloudflared
```

**Note**: When using the Coolify service, the container can be extended with persistent storage for config files, but the Zero Trust dashboard provides equivalent functionality with a better user experience.

---

## Real-World Implementation: Both Pathways in Action

Here's how we implemented both routing pathways for our actual services:

### **Our Complete Architecture**

**Services Using Direct Pathway:**
- **Coolify** (`luminode.inherent.design`): Admin dashboard
- **BlueMap** (`mcmap.inherent.design`): 3D world viewer

**Services Using Tunnel Pathway:**
- **Crafty Controller** (`crafty.inherent.design`): Public Minecraft management

### **Side-by-Side Pathway Comparison**

| Aspect                     | Direct Pathway (Coolify/BlueMap)      | Tunnel Pathway (Crafty)                   |
| -------------------------- | ------------------------------------- | ----------------------------------------- |
| **DNS Record**             | `A` record to VPS IP, not proxied (🟠) | `CNAME` to tunnel, proxied (🟡)            |
| **Traffic Flow**           | DNS → VPS → Traefik → Service         | DNS → Cloudflare → Tunnel → VPS → Service |
| **TLS Termination**        | Let's Encrypt at Traefik              | Cloudflare Edge + Origin cert             |
| **DDoS Protection**        | Basic (Cloudflare DNS only)           | Full (Cloudflare edge network)            |
| **VPS IP Exposure**        | Visible in DNS                        | Hidden behind Cloudflare                  |
| **Certificate Management** | Auto-renewal every 90 days            | 15-year Origin certificates               |
| **Best For**               | Admin access, reliability             | Public services, performance              |

### **Step-by-Step Implementation**

**1. DNS Configuration (Both Pathways)**
```dns
# Direct Pathway services
luminode.inherent.design    A    46.202.176.108    ; Proxied: OFF (🟠)
mcmap.inherent.design       A    46.202.176.108    ; Proxied: OFF (🟠)

# Tunnel Pathway services
crafty.inherent.design      CNAME your-tunnel-uuid.cfargotunnel.com    ; Proxied: ON (🟡)
```

**Key Insight**: Both pathways start with Cloudflare DNS, but the record type and proxy setting determine which pathway traffic takes.

**2. Direct Pathway Configuration (Coolify)**^[1,7]
```bash
# Configure Coolify for direct access
echo "APP_URL=https://luminode.inherent.design" >> /data/coolify/source/.env
cd /data/coolify/source && sudo docker compose restart

# Result: Traefik automatically generates Let's Encrypt certificate
# Traffic: User → DNS → VPS → Traefik → Coolify
```

**3. Crafty via Coolify**
Deploy Crafty as Docker Compose service in Coolify:
```yaml
services:
  crafty:
    image: registry.gitlab.com/crafty-controller/crafty-4:latest
    ports:
      - "8443:8443"  # HTTPS interface
      - "8100:8100"  # BlueMap HTTP
      - "25565:25565"  # Minecraft
    volumes:
      - crafty_data:/crafty/app/config
      - crafty_servers:/crafty/servers
    environment:
      - CRAFTY_WEB_PORT=8443
      - CRAFTY_HTTPS=true
```

**4. Tunnel Pathway Configuration (Crafty)**

Using Zero Trust Dashboard:
1. Navigate to Networks → Tunnels → Your tunnel
2. Public Hostnames → Add hostname:
   - Subdomain: `crafty`
   - Domain: `inherent.design`
   - Service: `https://host.docker.internal:8443`
   - Additional settings → TLS → No TLS Verify: ON

Alternatively, with config file:
```yaml
# /etc/cloudflared/config.yml
ingress:
  - hostname: crafty.inherent.design
    service: https://host.docker.internal:8443
    originRequest:
      noTLSVerify: true  # Crafty uses self-signed cert
```

# Result: Cloudflare handles edge TLS, tunnel forwards to VPS
# Traffic: User → DNS → Cloudflare Edge → Tunnel → VPS → Crafty

**5. Direct Pathway with Docker Networking (BlueMap)**^[5,6,7]
```yaml
# /data/coolify/proxy/dynamic/bluemap.yaml
# This uses the direct pathway but handles Docker networking complexity
http:
  routers:
    mcmap-router:
      rule: Host(`mcmap.inherent.design`)
      entryPoints: [https]
      service: bluemap-mcmap
      tls:
        certresolver: letsencrypt  # Let's Encrypt via direct pathway
  services:
    bluemap-mcmap:
      loadBalancer:
        servers:
          - url: 'http://host.docker.internal:8100'  # Key Docker insight

# Traffic: User → DNS → VPS → Traefik → Docker Host → BlueMap
```

---

## Common Issues and Solutions

### **TLS Certificate Problems**

**Symptom**: "TRAEFIK DEFAULT CERT" instead of proper certificate

**Cause**: Let's Encrypt challenge failed or ACME data corrupted^[7]

**Solution**:
```bash
# Check certificate status
sudo cat /data/coolify/proxy/acme.json | jq '.letsencrypt.Certificates[].domain'

# If empty or corrupted, reset:
docker stop coolify-proxy
sudo rm /data/coolify/proxy/acme.json
sudo touch /data/coolify/proxy/acme.json
sudo chmod 600 /data/coolify/proxy/acme.json
sudo chown 9999:root /data/coolify/proxy/acme.json
docker start coolify-proxy

# Wait 2-3 minutes for certificate generation
```

### **502 Bad Gateway Errors**

**Most Common Cause**: Service not reachable from Traefik^[8]

**Debug Steps**:
```bash
# 1. Check if service responds locally
curl -I http://localhost:PORT

# 2. Check Docker networking
docker ps | grep your-service

# 3. Test from Traefik container
docker exec coolify-proxy ping host.docker.internal

# 4. Fix service URL in Traefik config
# Replace localhost with host.docker.internal
```

### **DNS Not Resolving**

**Check DNS propagation**:
```bash
dig yourdomain.com
nslookup yourdomain.com

# Test from different locations
dig @8.8.8.8 yourdomain.com
dig @1.1.1.1 yourdomain.com
```

**Verify proxy status matches your setup**:
- Direct access: Proxy status OFF (🟠)
- Tunneled: Proxy status ON (🟡) or auto-managed

---

## Scaling and Advanced Patterns

### **Multiple Services on One VPS**

The beauty of this setup is that adding services is straightforward:

**For each new service**:
1. Choose direct or tunneled based on use case
2. Add DNS record with appropriate proxy setting
3. Deploy via Coolify or add Traefik configuration
4. Test and monitor

**Resource monitoring**:
```bash
# Check system resources
htop
docker stats

# Monitor disk usage
df -h
docker system df
```

### **Environment Separation**

**Development vs Production**:
- Use subdomains: `dev.yourdomain.com`, `staging.yourdomain.com`
- Separate tunnel configurations
- Different TLS certificate management

**Database and Backend Services**:
- Keep databases internal (no external access)
- Use Docker networks for inter-service communication
- Document service dependencies

### **Backup and Recovery**

**Critical data to backup**:
```bash
# Coolify configuration
/data/coolify/source/.env
/data/coolify/proxy/dynamic/

# TLS certificates (auto-regenerate, but good to have)
/data/coolify/proxy/acme.json

# Tunnel configuration
/etc/cloudflared/config.yml
/root/.cloudflared/*.json

# Application data volumes
docker volume ls
```

**Automated backup script**:
```bash
#!/bin/bash
# /opt/backup-config.sh
BACKUP_DIR="/opt/backups/$(date +%Y%m%d)"
mkdir -p "$BACKUP_DIR"

# Backup configs
cp -r /data/coolify/source/.env "$BACKUP_DIR/"
cp -r /data/coolify/proxy/dynamic/ "$BACKUP_DIR/"
cp /etc/cloudflared/config.yml "$BACKUP_DIR/" 2>/dev/null

# Compress
tar -czf "$BACKUP_DIR.tar.gz" "$BACKUP_DIR"
rm -rf "$BACKUP_DIR"

echo "Backup created: $BACKUP_DIR.tar.gz"
```

---

## Monitoring and Maintenance

### **Health Monitoring**

**Simple availability check**^[8,9]:
```bash
#!/bin/bash
# /opt/health-check.sh
SERVICES=("coolify.yourdomain.com" "app.yourdomain.com" "api.yourdomain.com")

for service in "${SERVICES[@]}"; do
  if curl -sf --max-time 10 "https://$service" > /dev/null; then
    echo "✅ $service"
  else
    echo "❌ $service - DOWN"
    # Add alerting here (email, webhook, etc.)
  fi
done
```

**TLS certificate expiration**:
```bash
#!/bin/bash
# Check certificate expiration
for domain in "${SERVICES[@]}"; do
  expiry=$(echo | openssl s_client -servername "$domain" -connect "$domain:443" 2>/dev/null | \
           openssl x509 -noout -dates | grep notAfter | cut -d= -f2)
  days_left=$(( ($(date -d "$expiry" +%s) - $(date +%s)) / 86400 ))

  if [ $days_left -lt 30 ]; then
    echo "⚠️  $domain expires in $days_left days"
  fi
done
```

### **Regular Maintenance Tasks**

**Weekly**:
- Check system updates: `sudo apt update && sudo apt list --upgradable`
- Verify backups are running
- Review service logs for errors

**Monthly**:
- Update Docker images: `docker compose pull && docker compose up -d`
- Clean up unused Docker resources: `docker system prune`
- Review and rotate SSH keys if needed

**Quarterly**:
- Review and update firewall rules
- Audit user accounts and permissions
- Test disaster recovery procedures

---

## Going Further

### **Advanced Security**

**Fail2Ban for brute force protection**:
```bash
sudo apt install fail2ban
sudo systemctl enable --now fail2ban
```

**SSH key rotation**:
```bash
# Generate new key locally
ssh-keygen -t ed25519 -C "your-email@domain.com"

# Add to server
ssh-copy-id -i ~/.ssh/new_key user@server

# Remove old keys from ~/.ssh/authorized_keys
```

**Regular security updates**:
```bash
# Enable automatic security updates
sudo apt install unattended-upgrades
sudo dpkg-reconfigure unattended-upgrades
```

### **Performance Optimization**

**Enable HTTP/3 in Cloudflare**:
- Dashboard → Speed → Optimization → HTTP/3: Enable

**Traefik compression**:
```yaml
# Add to Traefik dynamic config
http:
  middlewares:
    compression:
      compress: {}
  routers:
    your-service:
      middlewares: ["compression"]
```

**CDN and caching**:
- Use Cloudflare's caching for static assets
- Configure appropriate cache headers in your applications
- Consider Redis for session storage

### **Multi-Server Scaling**

When you outgrow a single VPS:

**Load balancing**:
- Multiple VPS instances behind Cloudflare Load Balancer
- Database on separate server or managed service
- Shared storage for persistent data

**Geographic distribution**:
- VPS in different regions
- Tunnel endpoints in multiple locations
- Database replication for global apps

---

## Conclusion: What You've Accomplished

By following this guide, you've built a production-ready infrastructure that:

✅ **Secures multiple services** with automatic TLS certificates
✅ **Provides clean, professional URLs** for all your applications
✅ **Handles the complexity of Docker networking** with proven patterns
✅ **Balances security and accessibility** with hybrid direct/tunneled architecture
✅ **Scales from one service to dozens** using the same fundamental patterns

**Most importantly**: You understand **why** each piece works, not just **how** to configure it.

### **The Patterns You've Learned**

**Direct Access**: Perfect for administrative services that need reliable access
**Cloudflare Tunnels**: Ideal for public services needing protection and performance
**Docker Networking**: How to handle services within services (`host.docker.internal`)
**TLS Management**: Automatic certificates with Let's Encrypt and Origin Certificates

### **Next Steps**

**Immediate**:
- Set up monitoring and alerting for your services
- Create backup procedures for your configurations
- Document your specific setup for future reference

**Advanced**:
- Experiment with additional services and deployment patterns
- Implement CI/CD pipelines that deploy to your infrastructure
- Explore advanced Cloudflare features like Workers and R2 storage

**Share Your Knowledge**:
- Document any unique challenges you encounter
- Contribute improvements to open-source projects you use
- Help others who are learning these same concepts

---

*"You're my DNS, you're my TLS, and you make my heart feel secure..."* 🎵

---

## Quick Reference

### **Essential Commands**
```bash
# TLS certificate debugging
echo | openssl s_client -servername DOMAIN -connect DOMAIN:443 | grep subject

# DNS verification
dig DOMAIN +short

# Docker networking test
docker exec coolify-proxy ping host.docker.internal

# Restart services
docker restart coolify-proxy
sudo systemctl restart cloudflared

# View logs
docker logs coolify-proxy --tail 50
sudo journalctl -u cloudflared -f
```

### **Configuration Files**
- **Coolify**: `/data/coolify/source/.env`
- **Traefik Dynamic**: `/data/coolify/proxy/dynamic/*.yaml`
- **Tunnel**: `/etc/cloudflared/config.yml`
- **TLS Certificates**: `/data/coolify/proxy/acme.json`

### **When Things Break**
1. Check the logs (`docker logs`, `journalctl`)
2. Verify DNS resolution (`dig`, `nslookup`)
3. Test service connectivity (`curl`, `ping`)
4. Review configuration files for syntax errors
5. Restart services in order: application → traefik → tunnel

Remember: **Every problem has been solved before**. Document your solutions and share them with others making the same journey.

---

## References

[1] Coolify Documentation Team. "Introduction to Coolify." *Coolify Documentation*. May 26, 2025. https://coolify.io/docs/get-started/introduction

[2] Coolify Documentation Team. "Coolify Docs." *Coolify Documentation*. May 26, 2025. https://coolify.io/docs

[3] Cloudflare, Inc. "Cloudflare Tunnel." *Cloudflare Zero Trust Documentation*. May 28, 2025. https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/

[4] Cloudflare, Inc. "Create a locally-managed tunnel." *Cloudflare Zero Trust Documentation*. May 28, 2025. https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/do-more-with-tunnels/local-management/create-local-tunnel/

[5] Docker, Inc. "Docker Desktop for Mac networking." *Docker Documentation*. Accessed May 28, 2025. https://docs.docker.com/desktop/networking/#i-want-to-connect-from-a-container-to-a-service-on-the-host

[6] BlueMap Community. "Reverse-Proxy on Coolify with Traefik." *BlueMap Community Guides*. May 25, 2025. https://bluemap.bluecolored.de/community/

[7] Traefik Labs. "Let's Encrypt." *Traefik Documentation*. Accessed May 28, 2025. https://doc.traefik.io/traefik/https/acme/

[8] Cloudflare, Inc. "Troubleshoot tunnels." *Cloudflare Zero Trust Documentation*. May 28, 2025. https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/troubleshoot-tunnels/

[9] Cloudflare, Inc. "Tunnel metrics." *Cloudflare Zero Trust Documentation*. May 28, 2025. https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/monitor-tunnels/metrics/

[10] Let's Encrypt. "How It Works." *Let's Encrypt Documentation*. Accessed May 28, 2025. https://letsencrypt.org/how-it-works/

---

**Navigation**: [Next: Migration & Troubleshooting →](01-modern-routing.md) | [Future: Security Hardening →](02-modern-routing.md)
