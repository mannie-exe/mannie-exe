# You're My Route, You're My Source: Modern Self-Hosting Reality

**A hands-on guide to building professional infrastructure that doesn't suck**

*Learn by doing: From zero to production-ready, with all the beautiful chaos that entails*

---

**Navigation**: [Next: Migration & Real-World Problems →](01-migration-real-world-problems.md) | [Future: Security That Actually Works →](02-security-that-actually-works.md)

---

## What We're Actually Building (And Why It's Going to Change Everything)

**The Honest Truth**: You're about to build infrastructure that will make you feel like a wizard. Not because it's magical - because you'll understand every piece and know exactly why it works.

**What You'll Have When We're Done**:
- Multiple services with clean URLs (`https://app.yourdomain.com`) instead of the amateur hour `http://192.168.1.100:8080` nonsense
- Automatic TLS certificates that renew themselves while you sleep
- Protection against the endless tide of bots trying to break into everything
- The knowledge to debug it when (not if) things go sideways

**The Real Goal**: Transform a basic VPS into a platform that can host anything you throw at it, scales with your ambitions, and handles the real world's chaos with grace.

---

## What Are We Actually Hosting? (The Plot Twist)

**TL;DR**: We're running Minecraft servers with web-based management, plus 3D map visualization. But here's the thing - the networking patterns we're building work for *literally everything*. 

**The Cast of Characters**:

**🏗️ Crafty Controller** - Web-based Minecraft server management (`https://crafty.yourdomain.com`)
- Think cPanel but for Minecraft servers
- Manages multiple server instances, backups, logs, player management  
- Runs on port 8000, needs HTTPS because it handles sensitive server operations
- **The networking challenge**: It's a service that manages other services

**🗺️ BlueMap** - 3D web-based world visualization (`https://mcmap.yourdomain.com`)
- Renders your Minecraft worlds as interactive 3D maps in the browser
- Like Google Earth but for your builds and adventures
- Runs on port 8100, serves static files + real-time updates
- **🎯 The beautiful problem**: It's a service *inside* Crafty, creating delicious networking puzzles

**⚡ Coolify** - Self-hosted deployment platform (`https://coolify.yourdomain.com`)  
- Think Heroku/Vercel but on your own server
- Manages Docker containers, SSL certificates, reverse proxy (Traefik)
- The foundation that makes hosting other services trivial
- **The meta moment**: We use it to host the tools that host other tools

**Why These Services Matter**: They represent every type of self-hosting challenge you'll encounter:
- **Complex multi-port applications** (Crafty + BlueMap)
- **Public-facing services** needing real security
- **Admin interfaces** requiring reliable access
- **Real-time applications** with WebSocket needs
- **Static content** that needs CDN performance

*Same patterns, unlimited applications. Once you understand this setup, you can host anything.*

---

## The Internet: A 5-Minute Crash Course for Adults

*If you already know DNS, reverse proxies, and why HTTPS matters, skip to [Getting Your Hands Dirty](#getting-your-hands-dirty)*

### How the Internet Actually Works (No Lies Edition)

When you type `google.com`, here's the real sequence:

1. **DNS Lookup**: Your computer asks "What IP address owns google.com?"
2. **Connection**: Browser connects to that IP on port 443 (HTTPS) or 80 (HTTP)  
3. **TLS Handshake**: Browser and server negotiate encryption (the security dance)
4. **Request/Response**: Browser asks for content, server delivers

### Your Self-Hosting Challenge

Your server runs services on different ports:
- Coolify on 8000
- Crafty on 8443  
- BlueMap on 8100
- Your blog on 3000

**The Problem**: Browsers expect HTTPS on port 443. You can't run four different services on port 443.

**The Solution**: A reverse proxy - your traffic director:
```
All HTTPS traffic → Port 443 → Reverse Proxy → Routes by domain name:
├── coolify.yourdomain.com → localhost:8000  
├── crafty.yourdomain.com → localhost:8443
├── mcmap.yourdomain.com → localhost:8100
└── blog.yourdomain.com → localhost:3000
```

### The Magic Ingredients

**Domain Name**: You own `yourdomain.com` (bought from Namecheap, GoDaddy, etc.)  
**DNS Provider**: Controls where `yourdomain.com` points (Cloudflare recommended)  
**VPS**: Your virtual server with a public IP address  
**Reverse Proxy**: Routes requests to the right service (Traefik, included with Coolify)  
**TLS Certificates**: Proves you're legit (Let's Encrypt, free and automatic)

**💡 The Pattern**: DNS → Reverse Proxy → Service. Master this, and you can host the universe.

---

## Getting Your Hands Dirty

### What You Need Before We Start

**Hardware Requirements**:
- VPS with SSH access (Ubuntu 22.04 LTS recommended)
- 4GB RAM minimum (2GB if you're brave/broke)  
- 2 CPU cores (1 core works but will cry under load)
- 40GB storage (20GB minimum, but plan for growth)

**Service Requirements**:
- Domain name with DNS managed by Cloudflare ^[1]
- Basic command line comfort (you should know `cd`, `ls`, `sudo` without panic)
- Willingness to break things and fix them (the best way to learn)

**Mental Requirements**:
- Patience for the first setup (it's worth every minute)
- Understanding that copying commands without comprehension is a path to suffering
- Acceptance that documentation lies and the real world is messier

---

## Step 1: Lock Down Your Server (Before the Bots Find You)

An unsecured VPS gets compromised faster than you can say "I should have read the security guide." These steps stop 99% of automated attacks.

### Basic System Hardening

```bash
# Update everything (always start here)
sudo apt update && sudo apt upgrade -y

# Create a non-root user if you don't have one
sudo adduser yourusername  
sudo usermod -aG sudo yourusername
```

### SSH: Your Front Door Security

**Why this matters**: Password authentication is like leaving your house key under a fake rock. Everyone knows about fake rocks.

```bash
# Generate a proper SSH key (run this on your LOCAL machine)
ssh-keygen -t ed25519 -C "your-email@example.com"

# Copy it to your server (replace with your details)  
ssh-copy-id -i ~/.ssh/id_ed25519.pub root@your-server-ip
```

**Harden SSH configuration**:

```bash
# Edit SSH daemon config
sudo nano /etc/ssh/sshd_config

# Find and modify these lines (or add them):
PasswordAuthentication no         # Keys only, no passwords
PubkeyAuthentication yes         # Enable key authentication  
PermitRootLogin yes             # Keep it simple (documented choice)
MaxAuthTries 3                  # Limit brute force attempts
MaxStartups 2                   # Prevent connection flooding

# Optional hardening (uncomment if you want maximum security):
# Port 2222                     # Move SSH off standard port  
# AllowUsers yourusername       # Limit who can even try to login

# Test config and restart
sudo sshd -t                    # Check for syntax errors
sudo systemctl reload sshd     # Apply changes

# Test new connection (keep current session open!)
ssh root@your-server-ip
```

### Firewall: Default Deny Everything

```bash
# Check current state
sudo ufw status verbose

# Reset to clean slate  
sudo ufw --force reset

# Set paranoid defaults
sudo ufw default deny incoming    # Block everything coming in
sudo ufw default allow outgoing   # Allow outbound (server needs internet)

# Allow only what we need
sudo ufw allow ssh                # SSH (port 22) 
sudo ufw allow 80/tcp             # HTTP (Let's Encrypt needs this)
sudo ufw allow 443/tcp            # HTTPS (where the magic happens)

# Optional: Game server ports (add only if you're running game servers)
# sudo ufw allow 25565/tcp         # Minecraft Java Edition
# sudo ufw allow 25565/udp         # Minecraft Bedrock Edition  

# Activate the fortress
sudo ufw enable

# Verify the lockdown
sudo ufw status verbose
```

**What you've built**: A server that ignores most of the internet's attempts to break in, while remaining accessible for legitimate purposes.

---

## Step 2: Install Your Swiss Army Knife (Coolify)

Coolify is like having a whole DevOps team in a container. It gives you:
- **Traefik**: Reverse proxy with automatic HTTPS
- **Let's Encrypt**: Free SSL certificates that renew themselves  
- **Docker management**: Deploy anything with a few clicks
- **Monitoring**: See what's happening with your services

### The Installation

```bash
# Download and run the installer
curl -fsSL https://cdn.coollabs.io/coolify/install.sh | sudo bash

# Wait for the magic (usually 2-3 minutes)
# You'll see Docker containers downloading and starting
```

**What just happened**:
- Docker got installed and configured properly
- Coolify containers were pulled and started
- Traefik reverse proxy is now running
- A web dashboard is available on port 8000

**First reality check**: Visit `http://your-server-ip:8000` - you should see Coolify's setup wizard.

### Complete the Setup

1. **Create admin account** (first visitor gets the keys to the kingdom)
2. **Set up initial project** (Coolify organizes everything into projects)  
3. **Generate API tokens** if you plan to automate deployments

**Important**: Coolify is running but only accessible via IP:port. This is exactly what we're going to fix.

---

## Understanding the Two Routing Pathways

All routing starts with **DNS**, but traffic can take different paths to reach your services. Understanding these pathways is crucial for making smart architectural decisions.

### Pathway 1: Direct VPS Access
*For services that need reliable, unfiltered access*

```
User → Cloudflare DNS → Your VPS IP → Traefik → Service
```

**DNS Configuration**:
```dns
coolify.yourdomain.com    A    YOUR_VPS_IP    # Proxy: OFF (🟠)
```

**Traffic Flow**:
1. User visits `https://coolify.yourdomain.com`
2. DNS returns your VPS IP directly
3. Browser connects to your server
4. Traefik handles TLS and routes to Coolify

**Best For**: Admin interfaces, development servers, services where you want complete control

### Pathway 2: Cloudflare Tunnel  
*For services that need protection and global performance*

```
User → Cloudflare DNS → Cloudflare Edge → Tunnel → Your VPS → Service
```

**DNS Configuration**:
```dns  
crafty.yourdomain.com    CNAME    tunnel-uuid.cfargotunnel.com    # Proxy: ON (🟡)
```

**Traffic Flow**:
1. User visits `https://crafty.yourdomain.com`
2. DNS points to Cloudflare's tunnel endpoint
3. Request hits Cloudflare's global network first
4. Cloudflare routes through secure tunnel to your VPS
5. Your server receives the request and responds

**Best For**: Public websites, APIs, services needing DDoS protection

---

## Implementing Pathway 1: Direct Access (Coolify Dashboard)

Let's get Coolify working with a professional URL using the direct pathway.

### Step 1: Configure DNS  

**In Cloudflare Dashboard** → **DNS** → **Records**:
- **Type**: A
- **Name**: coolify (creates `coolify.yourdomain.com`)  
- **IPv4 address**: `YOUR_VPS_IP`
- **Proxy status**: 🟠 **DNS only** (not proxied)

*This creates direct pathway: DNS points straight to your server*

### Step 2: Configure Coolify Domain

```bash
# Tell Coolify its public URL
sudo nano /data/coolify/source/.env

# Add this line (replace with your actual domain):
APP_URL=https://coolify.yourdomain.com

# Restart Coolify to apply changes
cd /data/coolify/source
sudo docker compose -f docker-compose.yml -f docker-compose.prod.yml restart
```

### Step 3: The Moment of Truth

**Wait 2-3 minutes** for Let's Encrypt certificate generation, then:

```bash
# Test the transformation
echo "🌟 === Professional URL Test ==="
echo "Testing if we've achieved URL enlightenment..."
echo "Domain: coolify.yourdomain.com"  
echo "================================="

# Check DNS resolution
echo "🔍 DNS Resolution:"
dig coolify.yourdomain.com +short
echo "(Should show your server IP)"

# Test HTTPS access  
echo "🔒 HTTPS Certificate:"
curl -I https://coolify.yourdomain.com | head -5
echo "(Should show HTTP/2 200 with no certificate warnings)"
```

**Success looks like**:
- DNS resolves to your server IP
- HTTPS loads without browser security warnings
- You see the Coolify dashboard at a professional URL
- HTTP automatically redirects to HTTPS

**If it doesn't work**: Wait 5 more minutes. DNS propagation and certificate generation take time. Check Traefik logs: `docker logs coolify-proxy --tail 20`

---

## Adding Your First Real Service: The Service-in-Service Challenge

Now let's tackle something more complex: Crafty Controller with BlueMap. This demonstrates the "service hosting other services" pattern you'll encounter constantly in self-hosting.

### The Challenge

Crafty Controller runs multiple web services:
- Main web interface on port 8443 (HTTPS)
- BlueMap 3D viewer on port 8100 (HTTP)
- Minecraft servers on various ports (25565, etc.)

We want:
- `https://crafty.yourdomain.com` → Crafty web interface
- `https://mcmap.yourdomain.com` → BlueMap viewer  
- Direct access to Minecraft servers for game clients

### Deploy Crafty Controller

**Option A: Via Coolify** (if it's in their service catalog)

**Option B: Manual Docker Compose** (more educational)

```bash
# Create service directory
mkdir -p /opt/services/crafty
cd /opt/services/crafty

# Create Docker Compose configuration
cat > docker-compose.yml << 'EOF'
version: '3'
services:
  crafty:
    container_name: crafty_container
    image: 'registry.gitlab.com/crafty-controller/crafty-4:latest'
    restart: always
    environment:
      - TZ=US/Eastern
    ports:
      # Web interfaces - accessible to Traefik
      - '8443:8443'     # Crafty HTTPS interface
      - '8100:8100'     # BlueMap HTTP interface
      
      # Game servers - direct public access  
      - '25565:25565'   # Minecraft Java Edition
      - '25566:25566'   # Additional server
      - '19132:19132/udp' # Minecraft Bedrock Edition
    volumes:
      - './data/backups:/crafty/backups'
      - './data/logs:/crafty/logs'  
      - './data/servers:/crafty/servers'
      - './data/config:/crafty/app/config'
      - './data/import:/crafty/import'
    networks:
      - crafty-network

networks:
  crafty-network:
    driver: bridge
EOF

# Deploy the service
docker compose up -d

# Verify it's running
docker ps | grep crafty
```

### Configure Traefik Routing for Crafty

Here's where it gets spicy. Crafty runs HTTPS on port 8443, but Traefik needs to route HTTPS traffic to it. We need custom Traefik configuration.

```bash
# Create Traefik dynamic routing configuration
sudo nano /data/coolify/proxy/dynamic/crafty.yaml
```

```yaml
http:
  routers:
    crafty-router:
      rule: Host(`crafty.yourdomain.com`)
      entryPoints: [https]
      service: crafty-service
      tls:
        certresolver: letsencrypt
        
  services:
    crafty-service:
      loadBalancer:
        servers:
          - url: 'https://host.docker.internal:8443'
        serversTransport: crafty-transport
          
  serversTransports:
    crafty-transport:
      insecureSkipVerify: true  # Crafty uses self-signed certificates
```

**Key insight**: `host.docker.internal` is Docker's magic hostname that lets containers reach services on the host. This solves the "container needs to talk to other containers/services" problem elegantly.

### Configure BlueMap Routing

BlueMap runs on HTTP port 8100 inside the Crafty container. Let's give it its own professional URL:

```bash
# Create BlueMap routing configuration  
sudo nano /data/coolify/proxy/dynamic/bluemap.yaml
```

```yaml
http:
  routers:
    bluemap-router:
      rule: Host(`mcmap.yourdomain.com`)  
      entryPoints: [https]
      service: bluemap-service
      tls:
        certresolver: letsencrypt
        
  services:
    bluemap-service:
      loadBalancer:
        servers:
          - url: 'http://host.docker.internal:8100'
```

### Apply Routing Configuration

```bash
# Restart Traefik to load new configurations
docker restart coolify-proxy

# Check logs for configuration errors
docker logs coolify-proxy --tail 20 | grep -E "(crafty|bluemap)"
```

### Add DNS Records

**For Crafty** (`crafty.yourdomain.com`):
- **Type**: A
- **Name**: crafty
- **IPv4 address**: your-server-ip  
- **Proxy status**: 🟠 **DNS only**

**For BlueMap** (`mcmap.yourdomain.com`):
- **Type**: A  
- **Name**: mcmap
- **IPv4 address**: your-server-ip
- **Proxy status**: 🟠 **DNS only**

### Test Your Multi-Service Setup

```bash
echo "🎮 === Multi-Service Reality Check ==="
echo "Testing our service empire..."
echo "==================================="

# Test Coolify (should still work)
echo "⚡ Coolify Dashboard:"  
curl -I https://coolify.yourdomain.com | head -1

# Test Crafty Controller
echo "🏗️ Crafty Controller:"
curl -k -I https://crafty.yourdomain.com | head -1

# Test BlueMap  
echo "🗺️ BlueMap Viewer:"
curl -I https://mcmap.yourdomain.com | head -1

echo "✅ All services should return HTTP 200"
```

---

## The Beautiful Pattern You've Just Mastered

Let's step back and admire what you've built:

### Service Architecture

```
Internet Traffic (Port 443)
    ↓
Traefik Reverse Proxy
    ├── coolify.yourdomain.com → Coolify (Port 8000)
    ├── crafty.yourdomain.com → Crafty (Port 8443)  
    └── mcmap.yourdomain.com → BlueMap (Port 8100)
```

### The Patterns That Emerge

**Pattern 1**: Simple service deployment via Coolify UI
- Deploy → Configure domain → DNS record → Done

**Pattern 2**: Custom Docker Compose + Traefik routing
- Docker Compose → Custom Traefik YAML → DNS record → Done

**Pattern 3**: Service-within-service routing  
- Multiple Traefik routes to different ports on same container
- Each gets its own professional URL

**Pattern 4**: Mixed public/private port access
- Web interfaces go through reverse proxy  
- Game servers get direct port access
- Best of both worlds

### Why This Architecture Is Beautiful

**Scalable**: Adding services is just "DNS + Traefik config + deploy"  
**Secure**: All web traffic encrypted, game traffic direct  
**Professional**: Clean URLs, no port numbers  
**Maintainable**: Each service isolated, independent failures
**Flexible**: Can handle any type of service or networking requirement

---

## Real-World Service Management

Now that you understand the patterns, let's talk about operating this infrastructure day-to-day.

### Resource Monitoring

```bash
echo "📊 === Infrastructure Health Check ==="
echo "Monitoring our growing empire..."  
echo "====================================="

# System resources
echo "💾 Memory Usage:"
free -h | grep Mem

echo "💽 Disk Usage:"  
df -h / | tail -1

echo "🏃 CPU Load:"
uptime

# Docker resources
echo "🐳 Container Status:"
docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}"

echo "🌐 Network Ports:"
netstat -tuln | grep LISTEN | grep -E "(80|443|8000|8443|8100)"
```

### Service Organization Strategy

```bash
# Create organized structure for your services
mkdir -p /opt/services/{web-apps,game-servers,monitoring,databases}

# Each major service gets its own directory:
# /opt/services/game-servers/crafty/
# /opt/services/web-apps/blog/  
# /opt/services/monitoring/uptime/
# /opt/services/databases/postgres/
```

### Backup Strategy (Before You Learn This the Hard Way)

```bash
echo "💾 === Critical Files to Backup ==="
echo "Don't learn this lesson the hard way..."
echo "===================================="

# Coolify configuration
echo "📁 Coolify:"
echo "  • /data/coolify/source/.env"
echo "  • /data/coolify/proxy/dynamic/"

# Custom services  
echo "🎮 Custom Services:"
echo "  • /opt/services/*/docker-compose.yml"
echo "  • /opt/services/*/data/"

# System configuration
echo "⚙️ System Config:"
echo "  • /etc/docker/daemon.json"
echo "  • /etc/ssh/sshd_config"  
echo "  • /etc/ufw/user.rules"

echo "🎯 Automate these backups. Seriously."
```

---

## Troubleshooting Real-World Problems

When (not if) things break, here's your debugging methodology:

### The DNS → Proxy → Service Debug Chain

**Step 1: DNS Resolution**
```bash
# Check if DNS points to your server
dig yourdomain.com +short

# Should return your server IP
# If not: DNS misconfiguration
```

**Step 2: Reverse Proxy Health**
```bash  
# Check if Traefik is running and healthy
docker logs coolify-proxy --tail 20

# Look for certificate errors, routing failures, backend unavailable
```

**Step 3: Service Health**
```bash
# Check if service responds locally
curl -I http://localhost:SERVICE_PORT

# If this fails, service is down
# If this works but URL doesn't, routing problem
```

### Common Issues and Solutions

**Issue**: "502 Bad Gateway"  
**Cause**: Service not reachable from Traefik  
**Debug**: Check `host.docker.internal` connectivity, service actually running

**Issue**: "Certificate errors"  
**Cause**: Let's Encrypt can't verify domain  
**Debug**: Ensure port 80 accessible, DNS points to your server

**Issue**: "DNS_PROBE_FINISHED_NXDOMAIN"  
**Cause**: DNS record doesn't exist or hasn't propagated  
**Debug**: Check Cloudflare DNS records, wait for propagation

---

## What You've Actually Accomplished

**🎉 Take a moment to appreciate this**: You've built professional infrastructure that handles multiple complex services with elegant routing, automatic HTTPS, and proper security. This is genuinely impressive work.

### Your Service Portfolio

✅ **Coolify Dashboard** (`https://coolify.yourdomain.com`) - Professional deployment platform  
✅ **Crafty Controller** (`https://crafty.yourdomain.com`) - Minecraft server management  
✅ **BlueMap Viewer** (`https://mcmap.yourdomain.com`) - 3D world visualization  
✅ **Game Servers** (direct ports) - Low-latency player connections  

### The Skills You've Developed

- **DNS mastery**: Understanding how domain names actually work
- **Reverse proxy patterns**: Traffic routing and SSL termination
- **Docker networking**: Container communication and `host.docker.internal`
- **Service architecture**: Designing scalable, maintainable systems  
- **Troubleshooting methodology**: Systematic debugging approach

### What's Next

In the next guide, we'll explore **migration strategies and real-world problems** - what happens when you need to move services, handle traffic spikes, deal with service failures, and plan for growth.

After that, we'll dive into **security that actually works** - hardening your infrastructure against real threats without breaking functionality or driving yourself insane.

**But first**: Test everything. Click around your services. Add a Minecraft server through Crafty. Watch BlueMap render your world. You've built something genuinely cool.

*Next up: Making this infrastructure bulletproof against the chaos of the real world...*

---

## Quick Reference for Your Daily Operations

### Essential Commands
```bash
# Check all service health
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# View Traefik logs  
docker logs coolify-proxy --tail 50

# Test HTTPS certificate
echo | openssl s_client -servername DOMAIN -connect DOMAIN:443 | grep subject

# Check DNS resolution
dig DOMAIN +short

# Restart everything if needed
cd /data/coolify/source && sudo docker compose restart
```

### Configuration Files  
- **Coolify**: `/data/coolify/source/.env`
- **Traefik Dynamic Config**: `/data/coolify/proxy/dynamic/*.yaml`  
- **Custom Services**: `/opt/services/*/docker-compose.yml`

### When Things Break
1. Check the logs (`docker logs`, `journalctl`)
2. Verify DNS resolution (`dig`, `nslookup`)  
3. Test service connectivity (`curl`, `ping`)
4. Review configuration files for syntax errors
5. Restart services in order: application → traefik → network

---

## References

[1] Cloudflare, Inc. "Getting Started with Cloudflare." *Cloudflare Documentation*. Accessed January 2025. https://developers.cloudflare.com/fundamentals/get-started/

[2] Coolify Documentation Team. "Installation Guide." *Coolify Documentation*. Accessed January 2025. https://coolify.io/docs/installation

[3] Docker, Inc. "Docker Networking Overview." *Docker Documentation*. Accessed January 2025. https://docs.docker.com/network/

[4] Traefik Labs. "Getting Started with Traefik." *Traefik Documentation*. Accessed January 2025. https://doc.traefik.io/traefik/getting-started/quick-start/

[5] Let's Encrypt. "How It Works." *Let's Encrypt Documentation*. Accessed January 2025. https://letsencrypt.org/how-it-works/

[6] Ubuntu Community. "UFW - Uncomplicated Firewall." *Ubuntu Documentation*. Accessed January 2025. https://help.ubuntu.com/community/UFW

---

**Navigation**: [Next: Migration & Real-World Problems →](01-migration-real-world-problems.md) | [Future: Security That Actually Works →](02-security-that-actually-works.md)