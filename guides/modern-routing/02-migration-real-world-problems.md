# Migration & Real-World Problems: When Your Hobby Meets Reality

**Converting from "works on my machine" to "handles the chaos of actual users"**

*The beautiful, terrifying moment when people start using your stuff*

---

**Navigation**: [← Back: You're My Route, You're My Source](00-you-are-my-route-you-are-my-source.md) | [Next: Security That Actually Works →](02-security-that-actually-works.md)

---

## The Reality Check Moment

**Where you are**: You've built something genuinely impressive. Multiple services with professional URLs, automatic HTTPS, elegant routing. Everything works beautifully... for you, from your location, with your usage patterns.

**The plot twist**: Success. People want to use your Minecraft server. Your blog is getting traffic. Colleagues are asking about your self-hosted tools. Suddenly, your elegant direct-routing setup is facing the harsh realities of the actual internet.

**What you're about to learn**: When simple routing isn't enough anymore, how to migrate services without breaking them, and the art of handling real-world chaos while keeping your sanity intact.

---

## The Warning Signs: When Your Setup Needs an Upgrade

### Traffic Reality Check

Your simple setup starts showing its age when:

**🌍 Geography becomes a problem**: Users in Australia loading your server in Germany are getting 3-second page loads  
**🤖 Bot attention increases**: Your server logs are full of scan attempts and weird requests  
**📈 Usage spikes hurt**: That blog post that went viral just brought your VPS to its knees  
**🔍 Discoverability becomes dangerous**: Your server IP is getting indexed by Shodan and other scanning services  

### The Exposure Problem

```bash
echo "🕵️ === Exposure Audit ==="
echo "Let's see how visible we are to the internet..."
echo "==========================================="

# Check what the world sees when they scan your domain
echo "🔍 DNS reveals:"
dig mcmap.yourdomain.com +short
echo "(This is your naked server IP - everyone can see it)"

# Check what services are visible
echo "🌐 Port scan simulation:"
nmap -F your-server-ip | grep open
echo "(These are the ports attackers will try first)"

# Check recent access attempts  
echo "🚨 Recent visitors:"
sudo tail -20 /var/log/auth.log | grep "Invalid user" || echo "No SSH attacks yet (lucky you)"

echo "🎯 If any of this makes you uncomfortable, time to upgrade"
```

### The Performance Problem

**Your current architecture**:
```
User (Tokyo) → DNS → Your VPS (London) → Service
         └── 200ms latency ──┘
```

**What users actually experience**:
- DNS lookup: 50ms
- Connection to your VPS: 200ms
- TLS handshake: +100ms  
- Service response: +50ms
- **Total**: 400ms before content even starts loading

**Meanwhile, professional services**:
```
User (Tokyo) → Cloudflare Edge (Tokyo) → Origin (London)  
         └── 20ms ──┘
```

---

## Understanding the Upgrade Path: Enter Cloudflare Tunnels

**The solution**: Cloudflare Tunnels - route traffic through Cloudflare's global network before it reaches your server. It's like having a CDN, DDoS protection, and caching layer without changing your infrastructure.

### The Hybrid Strategy

**Smart approach**: Don't migrate everything. Use the right tool for each job.

**Keep on Direct Routing**:
- **Admin interfaces** (Coolify dashboard) - You need reliable access
- **Game servers** (Minecraft) - UDP traffic and latency matter  
- **Development services** - Internal tools don't need global optimization

**Move to Tunnel Routing**:
- **Public websites** - Global performance and protection
- **APIs with external users** - Rate limiting and analytics
- **Services getting bot attention** - Hide behind Cloudflare's protection

### Architecture Comparison

**Current (All Direct)**:
```
User → DNS → VPS IP → Traefik → Services
      └── Everyone sees your server ──┘
```

**Target (Hybrid)**:
```
Public Services:  User → DNS → Cloudflare → Tunnel → VPS → Service
Admin Services:   User → DNS → VPS IP → Traefik → Service  
Game Services:    User → DNS → VPS IP → Direct Port Access
```

---

## Step 1: Setting Up Your Tunnel Infrastructure

We'll use Coolify to deploy the tunnel, keeping it simple and maintainable.

### Deploy Cloudflare Tunnel via Coolify

**In your Coolify dashboard**:

1. **Services** → **Add New Service**
2. **Search for**: "cloudflared" or "tunnel"
3. **Deploy** the Cloudflare tunnel service
4. **Copy the tunnel token** (you'll need this for configuration)

**Alternative: Manual setup** (if you want more control):

```bash
# Install cloudflared  
curl -L --output cloudflared.deb \
  https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
sudo dpkg -i cloudflared.deb

# Authenticate and create tunnel
cloudflared tunnel login
cloudflared tunnel create my-production-tunnel
```

### Verify Tunnel Connection

```bash
echo "🌉 === Tunnel Status Check ==="
echo "Verifying our bridge to Cloudflare..."
echo "==================================="

# Check tunnel service status
echo "🔧 Service Status:"
docker ps | grep cloudflared | head -1

# Check tunnel logs for connection status
echo "📡 Connection Status:"
docker logs cloudflared-service --tail 5 | grep -E "(Registered|connected|error)"

# Verify tunnel appears in Cloudflare dashboard
echo "🎯 Next: Check Cloudflare Zero Trust dashboard"
echo "   Networks → Tunnels → Should see your tunnel as 'Healthy'"
```

**🎯 Checkpoint**: Tunnel is connected but not routing any traffic yet. Your services still work exactly as before.

---

## Step 2: Your First Migration - Blog/Website to Tunnel

Let's migrate a public-facing service to test the tunnel routing. We'll use your blog or a simple website as the guinea pig.

### Pre-Migration State

**Current setup** (assuming you have a blog):
- **DNS**: `blog.yourdomain.com` A record → your-server-ip
- **Traffic**: User → DNS → VPS → Traefik → Blog service
- **Visibility**: Server IP exposed in DNS

### Configure Tunnel Route

**In Cloudflare Zero Trust dashboard**:

1. **Networks** → **Tunnels** → **Your tunnel** → **Configure**
2. **Public Hostnames** → **Add public hostname**
3. **Configure**:
   - **Subdomain**: blog
   - **Domain**: yourdomain.com
   - **Service Type**: HTTP
   - **URL**: `http://localhost:3000` (adjust port for your blog)

**Advanced configuration** (if needed):
- **Additional settings** → **HTTP** → **Host Header**: `blog.yourdomain.com`
- **TLS** → **No TLS Verify**: Enable if your service uses self-signed certs

### Perform the DNS Migration

**This is the moment of truth**:

```bash
echo "🔄 === DNS Migration Process ==="
echo "Switching blog from direct to tunnel routing..."
echo "============================================="

# Document current state
echo "📊 Before migration:"
dig blog.yourdomain.com +short
echo "(Should show your server IP)"

# The actual migration happens in Cloudflare DNS:
echo "🔧 DNS Changes needed:"
echo "1. Delete A record for blog.yourdomain.com"  
echo "2. Cloudflare will auto-create CNAME to tunnel"
echo "3. Verify CNAME points to: your-tunnel-uuid.cfargotunnel.com"

echo "⏰ Performing migration in Cloudflare dashboard now..."
echo "(Delete A record, tunnel CNAME will auto-create)"
```

**In Cloudflare DNS dashboard**:
1. **Find and delete** the A record for `blog.yourdomain.com`
2. **Cloudflare automatically creates** a CNAME record pointing to your tunnel
3. **Verify** the new record shows: `blog CNAME tunnel-uuid.cfargotunnel.com`

### Test the Migration

```bash
echo "🧪 === Migration Verification ==="
echo "Testing our first tunneled service..."
echo "================================="

# Wait for DNS propagation (usually instant for Cloudflare)
sleep 30

echo "🔍 DNS Resolution (should show Cloudflare IPs):"
dig blog.yourdomain.com +short
echo "Expected: Multiple Cloudflare IP addresses (104.21.x.x, 172.67.x.x)"

echo "🌐 HTTP Headers (should show Cloudflare magic):"
curl -I https://blog.yourdomain.com | grep -E "(server|cf-ray|cf-cache)"

echo "🎯 Success indicators:"
echo "  • DNS returns Cloudflare IPs"
echo "  • Headers include 'server: cloudflare'"  
echo "  • cf-ray header present"
echo "  • Site loads normally (but faster globally)"
```

**What just happened**:
- Your blog now routes through Cloudflare's global network
- Users worldwide connect to the nearest Cloudflare data center
- Your server IP is hidden from public view
- You get DDoS protection and CDN caching automatically

---

## Step 3: The Advanced Migration - Crafty Controller to Tunnel

Now let's tackle something more complex: migrating Crafty Controller while keeping the Minecraft game servers on direct routing.

### The Challenge

Crafty Controller has multiple components:
- **Web interface** (port 8443) - Should go through tunnel for protection
- **BlueMap viewer** (port 8100) - Public service, benefits from CDN
- **Minecraft servers** (25565+) - Must stay direct for UDP and latency

**Goal**: Hybrid routing where web interfaces go through tunnel, game servers stay direct.

### Create Public Tunnel Routes

**In Zero Trust dashboard**, add these public hostnames:

**Crafty Web Interface**:
- **Subdomain**: crafty-public
- **Domain**: yourdomain.com  
- **Service**: `https://localhost:8443`
- **Additional settings** → **TLS** → **No TLS Verify**: ON

**BlueMap Viewer**:
- **Subdomain**: mcmap-public
- **Domain**: yourdomain.com
- **Service**: `http://localhost:8100`

### Update DNS for Public Services

**Create new tunneled services**:
- `crafty-public.yourdomain.com` → (auto-created CNAME to tunnel)
- `mcmap-public.yourdomain.com` → (auto-created CNAME to tunnel)

**Keep existing direct services**:
- `crafty.yourdomain.com` → (existing A record to server IP)
- `mcmap.yourdomain.com` → (existing A record to server IP)

### Test Hybrid Architecture

```bash
echo "🎮 === Hybrid Architecture Test ==="
echo "Testing mixed direct + tunnel routing..."
echo "==================================="

echo "🏠 Direct routing (admin access):"
echo "Crafty admin: https://crafty.yourdomain.com"
curl -k -I https://crafty.yourdomain.com | head -1

echo "🌍 Tunnel routing (public access):"  
echo "Crafty public: https://crafty-public.yourdomain.com"
curl -I https://crafty-public.yourdomain.com | head -1

echo "🗺️ BlueMap comparison:"
echo "Direct: https://mcmap.yourdomain.com"
echo "Tunnel: https://mcmap-public.yourdomain.com"

echo "🎯 You now have choice: direct for admin, tunnel for public"
```

**Why this is beautiful**:
- **Admin access**: Reliable direct routing for server management
- **Public access**: Protected tunnel routing for user-facing services  
- **Game servers**: Still direct for optimal performance
- **Flexibility**: Choose routing method per service needs

---

## Step 4: Performance Optimization and Monitoring

Now that you have both routing methods, let's optimize and monitor the differences.

### Enable Cloudflare Performance Features

**In Cloudflare Dashboard** → **Speed**:

**Auto Minify**: 
- ✅ HTML
- ✅ CSS  
- ✅ JavaScript

**Performance Settings**:
- ✅ **Brotli Compression**: Better than gzip
- ✅ **HTTP/3**: Latest protocol for speed
- ✅ **0-RTT Connection Resumption**: Faster repeat visits

**Caching Rules** (for static content):
- **Page Rules** → **Create Rule**
- **URL**: `yourdomain.com/assets/*`
- **Settings**: Cache Level = Cache Everything, Edge TTL = 1 month

### Performance Comparison Testing

```bash
echo "⚡ === Performance Showdown ==="
echo "Direct vs Tunnel performance comparison..."
echo "========================================="

echo "🏠 Direct routing performance:"
for i in {1..3}; do
  echo -n "Test $i: "
  curl -w "DNS:%{time_namelookup}s Connect:%{time_connect}s Total:%{time_total}s" \
       -o /dev/null -s https://coolify.yourdomain.com
  echo ""
done

echo "🌍 Tunnel routing performance:"
for i in {1..3}; do  
  echo -n "Test $i: "
  curl -w "DNS:%{time_namelookup}s Connect:%{time_connect}s Total:%{time_total}s" \
       -o /dev/null -s https://blog.yourdomain.com
  echo ""
done

echo "📊 Analysis:"
echo "  • Direct: Consistent, but limited by server location"
echo "  • Tunnel: Variable first load, then faster (CDN caching)"
echo "  • Global users should see significant tunnel improvements"
```

### Traffic Analytics and Monitoring

**Monitor your tunneled services** in Cloudflare Analytics:

```bash
echo "📈 === Traffic Monitoring Setup ==="
echo "Getting insights into your service usage..."
echo "======================================"

echo "📊 Available in Cloudflare Dashboard:"
echo "  • Analytics → Traffic: Volume and geographic distribution"
echo "  • Security → Events: Attack mitigation and threat intel"  
echo "  • Speed → Performance: Cache hit rates and optimization"
echo "  • Logs → Real-time: Detailed request analysis"

echo "🎯 Key metrics to watch:"
echo "  • Geographic distribution of users"
echo "  • Cache hit ratio (higher = faster)"
echo "  • Security threats blocked"
echo "  • Bandwidth savings from compression"
```

---

## Step 5: Real-World Problem Solving

Let's tackle the actual problems you'll encounter running this infrastructure.

### Problem 1: Service Dependencies and Startup Order

**The issue**: Services depend on each other, but Docker doesn't guarantee startup order.

**Real example**: BlueMap needs Minecraft servers running, but they start independently.

```bash
# Create dependency-aware startup script
cat > /opt/services/crafty/healthcheck.sh << 'EOF'
#!/bin/bash

echo "🏥 === Service Health Check ==="
echo "Verifying service dependencies..."

# Check if Crafty main service is responding
if curl -k -f https://localhost:8443 >/dev/null 2>&1; then
    echo "✅ Crafty web interface: Healthy"
else
    echo "❌ Crafty web interface: Down"
    docker restart crafty_container
fi

# Check if BlueMap is serving content
if curl -f http://localhost:8100 >/dev/null 2>&1; then
    echo "✅ BlueMap viewer: Healthy"  
else
    echo "⚠️ BlueMap viewer: Not ready (normal if no worlds generated)"
fi

# Check game server ports
if netstat -tuln | grep -q ":25565"; then
    echo "✅ Minecraft server: Listening"
else
    echo "⚠️ Minecraft server: Not running (start via Crafty)"
fi
EOF

chmod +x /opt/services/crafty/healthcheck.sh

# Add to crontab for regular monitoring
echo "*/5 * * * * /opt/services/crafty/healthcheck.sh >> /var/log/service-health.log" | sudo crontab -
```

### Problem 2: Certificate Management for Internal Services

**The issue**: Traefik wants to generate certificates for everything, even internal services.

**Solution**: Strategic certificate management

```bash
echo "🔒 === Certificate Strategy ==="
echo "Managing certificates like a pro..."
echo "==============================="

# Check current certificate status
echo "📋 Current certificates:"
sudo cat /data/coolify/proxy/acme.json | jq -r '.letsencrypt.Certificates[].domain.main' 2>/dev/null || echo "No certificates yet"

# Monitor certificate generation
echo "👀 Watch certificate requests:"
echo "docker logs coolify-proxy -f | grep -i 'certificate'"

echo "🎯 Best practices:"
echo "  • Let direct services handle their own certs"
echo "  • Tunnel services get Cloudflare edge certificates"  
echo "  • Internal services can use self-signed (with insecureSkipVerify)"
```

### Problem 3: Debugging Network Connectivity

**When services can't reach each other**:

```bash
echo "🔧 === Network Debugging Toolkit ==="
echo "Systematic approach to connectivity issues..."
echo "====================================="

# Test Docker networking
echo "🐳 Docker network connectivity:"
docker exec coolify-proxy ping -c 1 host.docker.internal || echo "❌ host.docker.internal unreachable"

# Test service ports
echo "🌐 Service port accessibility:"
for port in 8000 8443 8100 25565; do
  if nc -z localhost $port; then
    echo "✅ Port $port: Open"
  else  
    echo "❌ Port $port: Closed"
  fi
done

# Test external connectivity
echo "🌍 External connectivity:"
curl -I https://httpbin.org/ip >/dev/null 2>&1 && echo "✅ Internet: Connected" || echo "❌ Internet: Issues"

# DNS resolution check
echo "🔍 DNS resolution:"
dig google.com +short >/dev/null && echo "✅ DNS: Working" || echo "❌ DNS: Issues"
```

### Problem 4: Resource Exhaustion and Recovery

**When your server runs out of resources**:

```bash
echo "🚨 === Resource Emergency Kit ==="
echo "When things go sideways..."
echo "==============================="

# Quick resource check
echo "💾 Memory pressure:"
free -h | grep Mem | awk '{print "Used: " $3 "/" $2 " (" int($3/$2 * 100) "%)"}'

echo "💽 Disk pressure:"  
df -h / | tail -1 | awk '{print "Used: " $3 "/" $2 " (" $5 ")"}'

# Emergency cleanup
echo "🧹 Emergency cleanup commands:"
echo "  • docker system prune -a    # Remove unused images/containers"
echo "  • sudo apt autoremove       # Remove unnecessary packages"  
echo "  • sudo journalctl --vacuum-time=7d  # Trim old logs"

# Service restart priority
echo "🔄 Service restart order (if needed):"
echo "  1. docker restart coolify-proxy    # Restore routing"
echo "  2. docker restart cloudflared      # Restore tunnel"
echo "  3. docker restart crafty_container # Restore game services"
```

---

## Troubleshooting the Hybrid Architecture

### Common Migration Issues

**Issue**: "502 Bad Gateway" on tunneled service  
**Cause**: Tunnel can't reach local service  
**Debug**:
```bash
# Test service responds locally
curl -I http://localhost:SERVICE_PORT

# Check tunnel logs
docker logs cloudflared-service --tail 20

# Verify tunnel configuration in Zero Trust dashboard
```

**Issue**: Intermittent connectivity to tunneled services  
**Cause**: DNS caching or tunnel routing issues  
**Fix**:
```bash
# Clear local DNS cache
sudo systemd-resolve --flush-caches

# Test from different locations
curl -H "Cache-Control: no-cache" https://service.yourdomain.com
```

**Issue**: Services work but performance is worse through tunnel  
**Cause**: Tunnel routing inefficiency or configuration  
**Debug**:
```bash
# Compare routing paths
traceroute yourdomain.com
traceroute tunnel-uuid.cfargotunnel.com

# Check Cloudflare edge location
curl -I https://service.yourdomain.com | grep cf-ray
```

### Emergency Rollback Procedures

**If tunnel migration breaks everything**:

```bash
echo "🆘 === Emergency Rollback ==="
echo "Reverting to direct routing..."
echo "============================="

# Rollback DNS (in Cloudflare dashboard):
echo "📋 Rollback checklist:"
echo "1. Delete CNAME record for service.yourdomain.com"
echo "2. Create A record pointing to server IP"  
echo "3. Set proxy status to DNS only (🟠)"
echo "4. Remove tunnel route from Zero Trust dashboard"

# Verify rollback
echo "✅ Verification:"
echo "dig service.yourdomain.com +short  # Should show server IP"
echo "curl -I https://service.yourdomain.com  # Should work directly"

echo "⏰ DNS propagation: 2-5 minutes"
```

---

## Your Evolved Architecture

**🎉 Look what you've built!** You now operate a **hybrid professional infrastructure** that adapts to real-world demands:

### Service Portfolio

**Direct Routing** (reliable, fast, admin-focused):
- `https://coolify.yourdomain.com` - Server management dashboard
- `https://crafty.yourdomain.com` - Admin access to game servers  
- Minecraft servers on direct ports - Optimal gaming performance

**Tunnel Routing** (protected, global, user-facing):
- `https://blog.yourdomain.com` - Public blog with global CDN
- `https://crafty-public.yourdomain.com` - Protected public access  
- `https://mcmap-public.yourdomain.com` - 3D world viewer for players

### What You've Mastered

**Migration methodology** that keeps services working during transitions  
**Hybrid architecture decisions** based on service requirements  
**Performance optimization** through intelligent routing choices  
**Real-world troubleshooting** for complex infrastructure problems  
**Emergency procedures** for when things go sideways  

### The Beautiful Balance

**For administrators**: Direct, reliable access to management interfaces  
**For users**: Fast, protected access through global infrastructure  
**For developers**: Flexibility to choose routing based on service needs  
**For growth**: Architecture that scales with usage and geographic distribution  

---

## What's Next: Security That Actually Works

Your infrastructure now handles public traffic professionally and scales globally. But with great power comes great responsibility - and great attack surface.

In the next guide, we'll implement **security that actually works**: hardening your server against real threats, monitoring for intrusions, and building defense-in-depth that protects without breaking functionality.

**Topics we'll cover**:
- Network perimeter hardening that stops 99% of automated attacks
- Container security that prevents privilege escalation  
- Service-specific hardening based on actual threat models
- Monitoring and detection that alerts you to problems
- Incident response procedures for when (not if) things go wrong

**But first**: Take a moment to test your hybrid infrastructure. Access your services from different locations, monitor the performance differences, and appreciate that you've built something that rivals professional hosting platforms.

*Next up: Making your infrastructure bulletproof against the chaos of internet security threats...*

---

## Daily Operations Reference

### Health Check Commands
```bash
# Quick infrastructure status
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# Performance comparison  
curl -w "%{time_total}s" -o /dev/null -s https://direct-service.yourdomain.com
curl -w "%{time_total}s" -o /dev/null -s https://tunneled-service.yourdomain.com

# Traffic analytics  
echo "Check Cloudflare Analytics for tunneled services"
echo "Check server logs for direct services"
```

### Migration Decision Matrix

| Service Type | Route | Reasoning |
|-------------|-------|-----------|
| **Admin dashboards** | Direct | Reliable access, no dependencies |
| **Public websites** | Tunnel | Global performance, DDoS protection |  
| **APIs** | Tunnel | Rate limiting, analytics, caching |
| **Game servers** | Direct | UDP support, low latency |
| **Development** | Direct | Testing, debugging, internal use |

### Emergency Contacts
- **Cloudflare Status**: https://www.cloudflarestatus.com/
- **Your VPS Provider**: [Your provider's status page]
- **DNS Propagation Check**: https://dnschecker.org/

---

## References

[1] Cloudflare, Inc. "Cloudflare Tunnel." *Cloudflare Zero Trust Documentation*. Accessed January 2025. https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/

[2] Cloudflare, Inc. "Performance Settings." *Cloudflare Documentation*. Accessed January 2025. https://developers.cloudflare.com/speed/optimization/

[3] Docker, Inc. "Container Networking." *Docker Documentation*. Accessed January 2025. https://docs.docker.com/config/containers/container-networking/

[4] Traefik Labs. "Dynamic Configuration." *Traefik Documentation*. Accessed January 2025. https://doc.traefik.io/traefik/reference/dynamic-configuration/

[5] Let's Encrypt. "Rate Limits." *Let's Encrypt Documentation*. Accessed January 2025. https://letsencrypt.org/docs/rate-limits/

[6] Cloudflare, Inc. "Troubleshooting Cloudflare Tunnel." *Cloudflare Documentation*. Accessed January 2025. https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/troubleshoot-tunnels/

---

**Navigation**: [← Back: You're My Route, You're My Source](00-you-are-my-route-you-are-my-source.md) | [Next: Security That Actually Works →](02-security-that-actually-works.md)