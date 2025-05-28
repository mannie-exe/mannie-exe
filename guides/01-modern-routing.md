# Modern Routing: Migration Playbook

**Converting Direct Services to Cloudflare Tunnels**

*Hands-on migration from DNS-only to tunneled routing*

---

**Navigation**: [← Back: Setup Guide](00-modern-routing.md) | [Next: Security Hardening →](02-modern-routing.md)

---

## Migration Overview

This guide shows how to migrate `mcmap.inherent.design` from **Direct Pathway** to **Tunnel Pathway** without service interruption.

### **Current State: Direct Pathway**
```
User → Cloudflare DNS → VPS IP → Traefik → Docker Host → BlueMap
```

### **Target State: Tunnel Pathway**  
```
User → Cloudflare DNS → Cloudflare Edge → Tunnel → VPS → BlueMap
```

### **Why Migrate?**
- **Hide VPS IP**: Direct DNS exposes your server location
- **DDoS Protection**: Cloudflare's edge network absorbs attacks
- **Performance**: Global CDN and HTTP/3 acceleration
- **Analytics**: Better visibility into traffic patterns
- **Consistent Architecture**: All public services use same pathway

---

## Pre-Migration Checklist

**Verify Current Setup:**
```bash
# Test current mcmap service
curl -I https://mcmap.inherent.design

# Check DNS configuration
dig mcmap.inherent.design +short
# Should return: 46.202.176.108

# Verify Traefik routing
docker logs coolify-proxy --tail 20 | grep mcmap
```

**Backup Current Configuration:**
```bash
# Backup Traefik dynamic config
sudo cp /data/coolify/proxy/dynamic/bluemap.yaml /data/coolify/proxy/dynamic/bluemap.yaml.backup

# Note current DNS settings (for rollback)
echo "Current DNS: A record to $(dig mcmap.inherent.design +short)"
```

---

## Step 1: Add Service to Tunnel Configuration

You have two options for configuring the tunnel:

### **Option A: Zero Trust Dashboard (Recommended)**

**Add mcmap to existing tunnel:**
1. Visit [Cloudflare Zero Trust](https://one.dash.cloudflare.com)
2. Networks → Tunnels → Your Tunnel → Configure
3. Public Hostnames → Add public hostname
4. Configure:
   - Subdomain: `mcmap`
   - Domain: `inherent.design` 
   - Service: `http://host.docker.internal:8100`
   - Additional settings → HTTP → Host Header: `mcmap.inherent.design` (optional for caching)
5. Save hostname

### **Option B: Manual Configuration File**

If using manual cloudflared installation:

**Edit tunnel configuration:**
```bash
sudo nano /etc/cloudflared/config.yml
```

**Add mcmap to existing tunnel:**
```yaml
tunnel: your-tunnel-uuid
credentials-file: /root/.cloudflared/your-tunnel-uuid.json

ingress:
  # Existing services
  - hostname: crafty.inherent.design
    service: https://host.docker.internal:8443
    originRequest:
      noTLSVerify: true
  
  # NEW: Add BlueMap service
  - hostname: mcmap.inherent.design  
    service: http://host.docker.internal:8100
    originRequest:
      # Optional: Add caching headers for map tiles
      httpHostHeader: mcmap.inherent.design
  
  # Catch-all (required)
  - service: http_status:404
```

**Reload tunnel configuration:**
```bash
sudo systemctl restart cloudflared

# Verify tunnel is running
sudo systemctl status cloudflared
sudo journalctl -u cloudflared --tail 10
```

**Note**: When using the Coolify cloudflared service, configuration changes through the Zero Trust dashboard are applied automatically without manual restarts.

---

## Step 2: Create Tunnel DNS Record

**Add tunnel hostname in Cloudflare Zero Trust:**
1. Go to [Cloudflare Zero Trust](https://one.dash.cloudflare.com)
2. Networks → Tunnels → Your Tunnel → Edit
3. Public Hostnames tab → Add public hostname
4. Configure:
   - Subdomain: `mcmap`
   - Domain: `inherent.design`
   - Service: `http://localhost:8100`
5. Save

**Alternative: Manual DNS Configuration**
1. Go to Cloudflare Dashboard → DNS → Records
2. Add new record:
   - Type: `CNAME`
   - Name: `mcmap-tunnel` (temporary name)
   - Target: `your-tunnel-uuid.cfargotunnel.com`
   - Proxy status: 🟡 **Proxied** (ON)

---

## Step 3: Test Tunnel Route

**Test tunnel connectivity before switching DNS:**
```bash
# Test via tunnel (if using temporary DNS name)
curl -I https://mcmap-tunnel.inherent.design

# Or test tunnel directly
curl -H "Host: mcmap.inherent.design" https://your-tunnel-uuid.cfargotunnel.com

# Verify in tunnel logs
sudo journalctl -u cloudflared -f
# Look for requests to mcmap.inherent.design
```

**Expected Result:** BlueMap should be accessible through tunnel

---

## Step 4: Perform DNS Cutover

**Option A: Immediate Cutover (5-10 minutes downtime)**
```bash
# 1. Delete existing A record
# Cloudflare Dashboard → DNS → mcmap.inherent.design → Delete

# 2. Create CNAME record
# Type: CNAME
# Name: mcmap
# Target: your-tunnel-uuid.cfargotunnel.com  
# Proxy: ON (🟡)

# 3. Wait for DNS propagation
dig mcmap.inherent.design
# Should return Cloudflare IPs, not your VPS IP
```

**Option B: Blue-Green Deployment (Zero Downtime)**
```bash
# 1. Create tunnel route with new subdomain
# mcmap-new.inherent.design → tunnel

# 2. Test thoroughly on new subdomain
curl -I https://mcmap-new.inherent.design

# 3. Update references to use new subdomain
# 4. Delete old DNS record after migration complete
```

---

## Step 5: Remove Traefik Configuration

**After DNS propagation and verification:**
```bash
# Remove Traefik dynamic configuration (no longer needed)
sudo rm /data/coolify/proxy/dynamic/bluemap.yaml

# Restart Traefik to apply changes
docker restart coolify-proxy

# Clean up logs
docker logs coolify-proxy --tail 20
```

**Why Remove?** The service now routes through tunnel, bypassing Traefik entirely.

---

## Step 6: Verification and Testing

**Test complete migration:**
```bash
# 1. DNS resolution check
dig mcmap.inherent.design
# Should return Cloudflare IPs (104.21.x.x, 172.67.x.x, etc.)

# 2. SSL certificate check  
echo | openssl s_client -servername mcmap.inherent.design -connect mcmap.inherent.design:443 | grep subject
# Should show Cloudflare certificate

# 3. Service functionality test
curl -I https://mcmap.inherent.design
# Should return HTTP 200 with Cloudflare headers

# 4. Performance test
curl -w "DNS: %{time_namelookup}s | Connect: %{time_connect}s | Total: %{time_total}s\n" \
     -o /dev/null -s https://mcmap.inherent.design
```

**Expected Headers After Migration**^[1,4]:
```http
HTTP/2 200
server: cloudflare
cf-ray: [unique-ray-id]
alt-svc: h3=":443"; ma=86400
```

---

## Rollback Procedure

**If migration fails, quick rollback:**
```bash
# 1. Delete CNAME record in Cloudflare DNS
# 2. Recreate A record:
#    Type: A
#    Name: mcmap  
#    IPv4: 46.202.176.108
#    Proxy: OFF (🟠)

# 3. Restore Traefik configuration
sudo cp /data/coolify/proxy/dynamic/bluemap.yaml.backup /data/coolify/proxy/dynamic/bluemap.yaml
docker restart coolify-proxy

# 4. Remove from tunnel config
# Go to Zero Trust Dashboard → Networks → Tunnels → Your Tunnel → Edit
# Delete the mcmap.inherent.design public hostname
# Or if using config file:
# sudo nano /etc/cloudflared/config.yml
# sudo systemctl restart cloudflared
```

**Rollback Time:** 2-5 minutes for DNS propagation

---

## Post-Migration Optimizations

### **Cloudflare Performance Settings**

**Enable Performance Features:**
1. Cloudflare Dashboard → Speed → Optimization
2. Enable:
   - **Auto Minify**: HTML, CSS, JS
   - **Brotli Compression**: On
   - **HTTP/3**: On
   - **0-RTT Connection Resumption**: On

### **Caching Configuration**

**Create Page Rule for map tiles:**
1. Cloudflare Dashboard → Rules → Page Rules
2. Create rule:
   - URL: `mcmap.inherent.design/maps/*/tiles/*`
   - Settings:
     - Cache Level: Cache Everything
     - Edge Cache TTL: 1 hour
     - Browser Cache TTL: 4 hours

### **Security Enhancements**

**Enable Security Features:**
1. **Security** → **Settings**:
   - Security Level: Medium
   - Challenge Passage: 30 minutes
2. **Firewall** → **Firewall Rules**:
   - Block bad bots
   - Rate limiting for excessive requests

---

## Architecture Comparison

### **Before Migration (Direct)**
```
✅ Pros:
- Simple configuration
- Direct server control
- No external dependencies for basic access

❌ Cons:
- VPS IP exposed (46.202.176.108 visible)
- No DDoS protection
- Limited performance optimization
- Manual SSL certificate management
```

### **After Migration (Tunnel)**
```
✅ Pros:
- VPS IP hidden behind Cloudflare
- DDoS protection and WAF^[1]
- Global CDN and HTTP/3
- Automatic SSL at edge
- Analytics and monitoring^[4]

❌ Cons:
- Dependency on Cloudflare service
- Slightly more complex debugging^[3,5]
- Additional configuration layer
```

---

## Monitoring the Migration

### **DNS Propagation Tracking**
```bash
#!/bin/bash
# Check DNS propagation globally
echo "DNS Propagation Check for mcmap.inherent.design"
echo "=============================================="

NAMESERVERS=("8.8.8.8" "1.1.1.1" "9.9.9.9" "208.67.222.222")

for ns in "${NAMESERVERS[@]}"; do
  result=$(dig @$ns mcmap.inherent.design +short | head -1)
  echo "$ns: $result"
done
```

### **Performance Monitoring**
```bash
#!/bin/bash
# Performance comparison script
echo "Performance Test: mcmap.inherent.design"
echo "====================================="

for i in {1..5}; do
  curl -w "Run $i - DNS: %{time_namelookup}s | Connect: %{time_connect}s | Total: %{time_total}s\n" \
       -o /dev/null -s https://mcmap.inherent.design
  sleep 1
done
```

---

## Troubleshooting Common Issues

### **Issue: 502 Bad Gateway After Migration**

**Cause**: Tunnel can't reach service

**Debug:**
```bash
# Check tunnel logs
sudo journalctl -u cloudflared -f

# Test service locally
curl -I http://localhost:8100

# Verify tunnel configuration
sudo cat /etc/cloudflared/config.yml | grep -A 5 mcmap
```

**Fix**: Ensure service URL in tunnel config matches actual service location³

### **Issue: DNS Still Pointing to Old IP**

**Cause**: DNS propagation delay or caching

**Fix:**
```bash
# Clear local DNS cache
sudo systemctl flush-dns  # systemd
# or
sudo dscacheutil -flushcache  # macOS

# Check TTL values
dig mcmap.inherent.design | grep "IN\s"
```

### **Issue: Certificate Errors**

**Cause**: Mixed certificate sources during transition

**Fix**: Wait 10-15 minutes for Cloudflare edge certificates to propagate globally

---

## Next Steps

After successful migration:

1. **Monitor Performance**: Compare before/after metrics
2. **Update Documentation**: Record new architecture
3. **Plan Additional Services**: Consider migrating other public services
4. **Security Review**: Configure WAF rules and security policies
5. **Backup New Config**: Update backup procedures for tunnel configuration

---

## Conclusion

You've successfully migrated `mcmap.inherent.design` from direct VPS access to Cloudflare Tunnel routing. The service now benefits from:

- **Enhanced Security**: VPS IP hidden, DDoS protection active
- **Improved Performance**: Global CDN, HTTP/3, optimized delivery
- **Better Monitoring**: Cloudflare analytics and logging
- **Consistent Architecture**: All public services use tunnel pathway

**Key Learning**: Migration between routing pathways is straightforward with proper planning and testing. The tunnel pathway provides significant benefits for public-facing services while maintaining reliable service delivery^[1].

*Next: Let's explore additional attack surfaces and security hardening in the following guide...*

---

## References

[1] Cloudflare, Inc. "Cloudflare Tunnel." *Cloudflare Zero Trust Documentation*. May 28, 2025. https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/

[2] Cloudflare, Inc. "Configuration file." *Cloudflare Zero Trust Documentation*. May 28, 2025. https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/do-more-with-tunnels/local-management/configuration-file/

[3] Cloudflare, Inc. "Tunnel diagnostic logs." *Cloudflare Zero Trust Documentation*. May 28, 2025. https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/troubleshoot-tunnels/diag-logs/

[4] Cloudflare, Inc. "Tunnel notifications." *Cloudflare Zero Trust Documentation*. May 28, 2025. https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/monitor-tunnels/notifications/

[5] Cloudflare, Inc. "Troubleshooting common errors." *Cloudflare Zero Trust Documentation*. May 28, 2025. https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/troubleshoot-tunnels/common-errors/

[6] BlueMap Team. "BlueMap FAQ." *BlueMap Documentation*. May 25, 2025. https://bluemap.bluecolored.de/wiki/FAQ.html

[7] BlueMap Team. "External Webservers (FILE-Storage)." *BlueMap Documentation*. May 25, 2025. https://bluemap.bluecolored.de/wiki/webserver/ExternalWebserversFile.html

---

**Navigation**: [← Back: Setup Guide](00-modern-routing.md) | [Next: Security Hardening →](02-modern-routing.md)