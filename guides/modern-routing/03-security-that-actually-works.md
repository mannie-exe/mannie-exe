# Security That Actually Works: Defense-in-Depth Without the Theater

**From "probably secure enough" to "bring it on, internet chaos"**

*Real security for real infrastructure, with minimal security theater*

---

**Navigation**: [← Back: Migration & Real-World Problems](01-migration-real-world-problems.md)

---

## The Security Wake-Up Call

**Where you are**: You've built impressive infrastructure that handles real traffic, scales globally, and operates professionally. People are using your services, bots are scanning your endpoints, and you're officially part of the internet ecosystem.

**The uncomfortable truth**: Success brings attention. Your server logs are full of scan attempts, your SSH auth logs show failed login attempts from around the world, and somewhere out there, automated tools are cataloging your services.

**What you're about to learn**: How to implement defense-in-depth security that actually protects against real threats, without breaking functionality or turning your server into an unusable fortress.

**The goal**: Transform your infrastructure from "hopefully secure" to "confidently hardened" through layered security that works in practice, not just on paper.

---

## The Threat Landscape Reality Check

Let's be honest about what we're actually defending against.

### Automated Attacks (95% of Your Threats)

**What they are**: Bots scanning for default passwords, unpatched vulnerabilities, exposed admin panels  
**How they work**: Mass scanning, automated exploitation, commodity malware  
**Your exposure**: Every public service gets constant automated attention  
**Defense strategy**: Reduce attack surface, harden defaults, automate responses  

```bash
echo "🤖 === Bot Reality Check ==="
echo "Let's see who's knocking on our door..."
echo "=================================="

# SSH brute force attempts
echo "🔐 SSH attack attempts (last 24 hours):"
sudo journalctl -u ssh --since "24 hours ago" | grep "Failed password" | wc -l
echo "attempts detected"

# Web service scans  
echo "🌐 Web scanning attempts:"
sudo tail -100 /var/log/nginx/access.log 2>/dev/null | grep -E "(admin|wp-|\.php|sql)" | wc -l || 
docker logs coolify-proxy --tail 100 | grep -E "(404|403)" | head -3
echo "suspicious requests found"

# Port scanning evidence
echo "🔍 Port scan evidence:"
sudo dmesg | grep "UFW BLOCK" | tail -3 || echo "No blocked connections (firewall working)"

echo "🎯 This is just the background noise of the internet"
```

### Targeted Attacks (5% but Dangerous)

**What they are**: Humans specifically targeting your infrastructure  
**How they work**: Custom exploits, social engineering, persistent threats  
**Your exposure**: Usually triggered by something valuable (data, services, reputation)  
**Defense strategy**: Defense-in-depth, assume breach mentality, monitoring  

### The Self-Hosting Security Advantage

**Good news**: You control everything, no shared infrastructure vulnerabilities  
**More good news**: Smaller target than major platforms  
**The challenge**: You're the entire security team

---

## Layer 1: Network Perimeter Hardening

Let's start with the outermost layer - controlling what traffic even reaches your services.

### Firewall Strategy: Default Deny with Surgical Allows

**Philosophy**: Block everything, then carefully allow only what's necessary.

```bash
echo "🔥 === Firewall Security Audit ==="
echo "Checking our digital fortress walls..."
echo "=================================="

# Current firewall status
echo "🔍 Current UFW configuration:"
sudo ufw status verbose

echo "🎯 Security analysis:"
echo "Expected open ports:"
echo "  • 22/tcp  - SSH (admin access)"
echo "  • 80/tcp  - HTTP (Let's Encrypt + redirects)"  
echo "  • 443/tcp - HTTPS (all web services)"
echo "  • 25565/tcp - Minecraft (if running game servers)"
echo "  • Everything else should be BLOCKED"

# Check for unexpected listeners
echo "🚨 Unexpected services:"
netstat -tuln | grep LISTEN | grep -v -E "(22|80|443|25565|127\.0\.0\.1)" || echo "✅ No unexpected listeners found"
```

**Implement proper firewall rules**:

```bash
# Reset to clean state
sudo ufw --force reset

# Paranoid defaults
sudo ufw default deny incoming    # Block everything by default
sudo ufw default allow outgoing   # Server needs internet access

# Essential services only
sudo ufw allow ssh                # SSH access (consider changing port later)
sudo ufw allow 80/tcp             # HTTP (Let's Encrypt verification)
sudo ufw allow 443/tcp            # HTTPS (all web traffic)

# Game server ports (only if needed)
# sudo ufw allow 25565/tcp         # Minecraft Java Edition
# sudo ufw allow 25565/udp         # Minecraft Bedrock Edition

# Advanced: Rate limiting for SSH
sudo ufw limit ssh                # Automatic rate limiting for SSH

# Enable the fortress
sudo ufw enable

echo "🛡️ === Firewall Hardening Complete ==="
echo "Attack surface minimized to essential ports only"
```

### Network Security Monitoring

**Monitor who's trying to get in**:

```bash
# Create network monitoring script
sudo tee /opt/network-monitor.sh << 'EOF'
#!/bin/bash

echo "🌐 === Network Security Monitor ==="
echo "Date: $(date)"
echo "================================="

# SSH attacks
echo "🔐 SSH Security:"
failed_ssh=$(sudo journalctl -u ssh --since "24 hours ago" | grep -c "Failed password")
echo "Failed SSH attempts (24h): $failed_ssh"

if [ $failed_ssh -gt 50 ]; then
    echo "⚠️ HIGH: Consider additional SSH hardening"
elif [ $failed_ssh -gt 10 ]; then
    echo "⚠️ MODERATE: Normal internet background noise"
else
    echo "✅ LOW: SSH attacks under control"
fi

# Firewall blocks
echo "🔥 Firewall Activity:"
blocked=$(sudo grep "UFW BLOCK" /var/log/ufw.log 2>/dev/null | grep "$(date +%b\ %d)" | wc -l)
echo "Blocked attempts today: $blocked"

# Active connections
echo "🔗 Active Connections:"
echo "SSH sessions: $(who | wc -l)"
echo "HTTPS connections: $(netstat -an | grep :443 | grep ESTABLISHED | wc -l)"

echo "✅ Network monitoring complete"
EOF

chmod +x /opt/network-monitor.sh

# Test the monitor
sudo /opt/network-monitor.sh
```

---

## Layer 2: SSH and Authentication Hardening

SSH is your administrative lifeline - let's make it bulletproof.

### Advanced SSH Configuration

**Current state audit**:

```bash
echo "🔐 === SSH Security Audit ==="
echo "Checking our front door security..."
echo "================================="

# Check current SSH configuration
echo "🔍 Current SSH settings:"
sudo grep -E "PasswordAuthentication|PubkeyAuthentication|PermitRootLogin|Port" /etc/ssh/sshd_config | grep -v "^#"

# Check for SSH keys
echo "🗝️ SSH Key Status:"
ls -la ~/.ssh/ | grep -E "(id_|authorized_keys)" || echo "No SSH keys configured"

# Recent SSH activity
echo "📊 Recent SSH Activity:"
sudo journalctl -u ssh --since "7 days ago" | grep "Accepted" | tail -5
```

**Enhanced SSH hardening** (`/etc/ssh/sshd_config`):

```bash
# Backup current configuration
sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup

# Apply hardened SSH configuration
sudo tee -a /etc/ssh/sshd_config << 'EOF'

# === Security Hardening ===
# Authentication
PasswordAuthentication no          # Keys only, no passwords
PubkeyAuthentication yes          # Enable SSH key authentication
PermitRootLogin yes               # Keep for simplicity (documented choice)
MaxAuthTries 3                    # Limit brute force attempts
MaxStartups 2                     # Prevent connection flooding
LoginGraceTime 60                 # Time limit for login

# Protocol hardening  
Protocol 2                        # SSH protocol 2 only
AddressFamily inet                 # IPv4 only (unless you need IPv6)
Port 22                           # Standard port (consider changing for extra security)

# Session management
ClientAliveInterval 300           # Keep-alive every 5 minutes
ClientAliveCountMax 2            # Max 2 missed keep-alives before disconnect

# Feature lockdown
X11Forwarding no                  # Disable X11 forwarding
AllowTcpForwarding no            # Disable TCP forwarding
GatewayPorts no                  # Disable gateway ports
PermitTunnel no                  # Disable SSH tunneling
PrintMotd no                     # Disable message of the day

# Advanced security (optional - uncomment if you want maximum security)
# Port 2222                      # Move SSH off standard port
# AllowUsers yourusername        # Restrict which users can SSH
# DenyUsers root                 # Explicitly deny root login
EOF

# Validate configuration
echo "🔧 Validating SSH configuration..."
sudo sshd -t && echo "✅ SSH config valid" || echo "❌ SSH config has errors"

# Apply changes
sudo systemctl reload sshd
echo "✅ SSH hardening applied"
```

### SSH Key Management

**Rotate SSH keys regularly**:

```bash
echo "🔑 === SSH Key Security Management ==="
echo "Managing authentication credentials..."
echo "==================================="

# Check current key strength
echo "🔍 Current SSH key analysis:"
if [ -f ~/.ssh/id_ed25519.pub ]; then
    echo "✅ Ed25519 key found (excellent security)"
    ssh-keygen -l -f ~/.ssh/id_ed25519.pub
elif [ -f ~/.ssh/id_rsa.pub ]; then
    echo "⚠️ RSA key found - check bit length:"
    ssh-keygen -l -f ~/.ssh/id_rsa.pub
    echo "   💡 Consider upgrading to Ed25519 for better security"
else
    echo "❌ No SSH keys found - using password authentication (dangerous!)"
fi

# SSH key rotation procedure
echo "🔄 SSH Key Rotation Process:"
echo "1. Generate new key: ssh-keygen -t ed25519 -C 'new-key-$(date +%Y%m%d)'"
echo "2. Copy to server: ssh-copy-id -i ~/.ssh/new_key.pub user@server"  
echo "3. Test new key works"
echo "4. Remove old key from ~/.ssh/authorized_keys"
echo "5. Update automation/scripts with new key"
```

---

## Layer 3: System and Service Hardening

Let's harden the operating system and Docker infrastructure.

### System Security Configuration

**Automatic security updates**:

```bash
echo "🔄 === Automatic Security Updates ==="
echo "Setting up hands-off security patching..."
echo "====================================="

# Install unattended upgrades
sudo apt update
sudo apt install unattended-upgrades apt-listchanges -y

# Configure automatic security updates
sudo dpkg-reconfigure -plow unattended-upgrades

# Verify configuration
echo "📋 Unattended upgrades configuration:"
cat /etc/apt/apt.conf.d/20auto-upgrades 2>/dev/null || echo "Not configured - run the dpkg-reconfigure command above"

echo "✅ Security updates will install automatically"
echo "💡 Check logs with: sudo tail -f /var/log/unattended-upgrades/unattended-upgrades.log"
```

**Kernel security hardening**:

```bash
echo "🛡️ === Kernel Security Hardening ==="
echo "Applying network-level attack protections..."
echo "========================================"

# Create kernel security configuration
sudo tee -a /etc/sysctl.conf << 'EOF'

# === Network Security Hardening ===
# IP spoofing protection
net.ipv4.conf.default.rp_filter = 1
net.ipv4.conf.all.rp_filter = 1

# SYN flood attack protection  
net.ipv4.tcp_syncookies = 1

# Ignore ICMP redirects (routing attacks)
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0

# Don't send ICMP redirects
net.ipv4.conf.all.send_redirects = 0

# Ignore source routing (spoofing attacks)
net.ipv4.conf.all.accept_source_route = 0

# Ignore ping broadcasts (DDoS amplification)
net.ipv4.icmp_echo_ignore_broadcasts = 1

# Log suspicious packets
net.ipv4.conf.all.log_martians = 1
EOF

# Apply changes immediately
sudo sysctl -p

echo "✅ Kernel hardening applied:"
echo "  • IP spoofing protection enabled"
echo "  • SYN flood protection enabled"  
echo "  • ICMP redirect attacks blocked"
echo "  • Source routing attacks blocked"
echo "  • Suspicious packet logging enabled"
```

### Docker Security Configuration

**Harden the Docker daemon**:

```bash
echo "🐳 === Docker Security Hardening ==="
echo "Securing container infrastructure..."
echo "=================================="

# Backup existing Docker configuration
sudo cp /etc/docker/daemon.json /etc/docker/daemon.json.backup 2>/dev/null || echo "No existing Docker config"

# Create hardened Docker daemon configuration
sudo tee /etc/docker/daemon.json << 'EOF'
{
  "default-address-pools": [
    {
      "base": "10.0.0.0/8",
      "size": 24
    }
  ],
  "default-ulimits": {
    "nofile": {
      "Hard": 64000,
      "Name": "nofile", 
      "Soft": 64000
    }
  },
  "live-restore": true,
  "log-driver": "journald",
  "log-opts": {
    "tag": "{{.Name}}/{{.FullID}}"
  },
  "no-new-privileges": true,
  "userland-proxy": false
}
EOF

echo "🔧 Docker security configuration applied:"
echo "  • no-new-privileges: Prevents container privilege escalation"
echo "  • journald logging: Centralized security logging"
echo "  • Resource limits: Prevents container resource abuse"  
echo "  • Network isolation: Improved container networking security"

# Apply Docker security configuration
sudo systemctl restart docker
echo "✅ Docker daemon restarted with security configuration"
```

### Container Security: The Recreation Challenge

**⚠️ Critical**: Existing containers need recreation to get new security settings.

```bash
echo "🔄 === Container Security Recreation ==="
echo "Applying security settings to existing containers..."
echo "=============================================="

echo "📋 Container recreation process:"
echo "1. Docker restart ≠ Docker recreate"
echo "2. Restart keeps old security settings"
echo "3. Recreation applies new daemon security settings"

# Recreate Coolify infrastructure
echo "🔧 Recreating Coolify containers..."
cd /data/coolify/source
sudo docker compose -f docker-compose.yml -f docker-compose.prod.yml down
sudo docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d

# Wait for services to stabilize
echo "⏳ Waiting for services to stabilize..."
sleep 30

# Verify security settings applied
echo "🔍 Verifying security configuration:"
docker inspect coolify --format 'SecurityOpt: {{.HostConfig.SecurityOpt}}' 2>/dev/null || echo "Coolify container not found with that name"

# Check for any containers still needing recreation
echo "📊 Container security audit:"
for container in $(docker ps --format "{{.Names}}"); do
    security_opts=$(docker inspect $container --format '{{.HostConfig.SecurityOpt}}' 2>/dev/null)
    if [[ "$security_opts" == "[]" ]]; then
        echo "⚠️ $container: No security options (may need recreation)"
    else
        echo "✅ $container: Security options applied"
    fi
done
```

### The Coolify Privilege Problem (And Its Elegant Solution)

**⚠️ Critical Discovery**: When we apply `no-new-privileges: true` daemon-wide, Coolify containers crash-loop because s6-overlay can't fix `/run` directory permissions during initialization.

**The Problem**:
```bash
# After applying Docker security, Coolify fails to start
docker logs coolify --tail 20
# Shows: s6-overlay: permission denied errors, container restart loop
```

**The Surgical Solution**: Per-container security override instead of disabling daemon-wide security.

```bash
echo "🔧 === Coolify Privilege Exception ==="
echo "Applying surgical security for Coolify..."
echo "===================================="

# Edit Coolify's production configuration
sudo nano /data/coolify/source/docker-compose.prod.yml

# Add this security exception to the coolify service:
cat << 'EOF'
services:
  coolify:
    # ... existing configuration ...
    security_opt:
      - no-new-privileges:false  # Only this container can escalate privileges
    # ... rest of configuration ...
EOF

echo "✅ Security exception configured for Coolify"
echo "💡 This allows Coolify to initialize while keeping all other containers secure"
```

**Apply the Surgical Security**:
```bash
# Recreate Coolify with the security exception
cd /data/coolify/source
sudo docker compose -f docker-compose.yml -f docker-compose.prod.yml down coolify
sudo docker compose -f docker-compose.yml -f docker-compose.prod.yml up coolify -d

# Verify Coolify starts successfully
echo "🔍 Verifying Coolify health:"
docker ps | grep coolify
docker logs coolify --tail 5 | grep -E "(ready|started|listening)"

echo "✅ Coolify should now start without privilege escalation errors"
```

**Why This Solution Is Beautiful**:
- **Secure by default**: All other containers inherit `no-new-privileges: true`
- **Surgical exception**: Only Coolify gets privilege escalation capability  
- **Audit trail**: Clear documentation of which containers have elevated privileges
- **Functionality preserved**: Coolify works normally while maintaining security
- **NIST compliance**: Aligns with SP 800-190 principle of least privilege with documented exceptions

**Verification**:
```bash
# Verify security configuration applied correctly
echo "🔍 Security Configuration Audit:"
docker inspect coolify --format 'SecurityOpt: {{.HostConfig.SecurityOpt}}'
echo "Expected: [no-new-privileges:false]"

# Check other containers still have security restrictions
docker inspect $(docker ps --format "{{.Names}}" | grep -v coolify | head -1) --format 'SecurityOpt: {{.HostConfig.SecurityOpt}}' 2>/dev/null
echo "Expected: [] (inherits daemon no-new-privileges:true)"
```

---

## Layer 4: Service-Specific Security Hardening

Now let's secure the applications themselves.

### Container Port Security Strategy

**Principle**: Only expose ports that need external access.

```bash
echo "🔍 === Port Security Audit ==="
echo "Checking which services are exposed to the internet..."
echo "=================================================="

# Check what's actually listening
echo "🌐 Network listening services:"
netstat -tuln | grep -E "0\.0\.0\.0:(8000|8443|8100|25565)" || echo "✅ No unexpected public listeners"

echo "🏠 Localhost-only services:"  
netstat -tuln | grep -E "127\.0\.0\.1:(8000|8443|8100)" || echo "ℹ️ No localhost-only services detected"

echo "🎯 Security best practice:"
echo "  • Web services → Traefik proxy (localhost binding)"
echo "  • Game services → Direct access (public binding)"
echo "  • Admin services → VPN or IP restrictions"

# Example secure port binding for custom services
cat << 'EOF'
📝 Secure Docker Compose port binding example:

services:
  webapp:
    ports:
      # ✅ Secure: Localhost binding (Traefik can reach, internet cannot)
      - "127.0.0.1:8080:8080"
      
      # ❌ Insecure: All interfaces (internet can reach directly)  
      - "8080:8080"
      
      # ✅ Secure: Public game server (intended for direct access)
      - "25565:25565"
EOF
```

### Crafty Controller Security Hardening

**Secure your Minecraft server management**:

```bash
echo "🎮 === Crafty Controller Security ==="
echo "Hardening game server management..."
echo "=================================="

# Check Crafty security configuration
if docker ps | grep -q crafty; then
    echo "🔍 Crafty Controller found - applying security hardening"
    
    # Create secure port binding configuration
    cat > /opt/services/crafty/docker-compose.secure.yml << 'EOF'
version: '3'
services:
  crafty:
    container_name: crafty_container
    image: 'registry.gitlab.com/crafty-controller/crafty-4:latest'
    restart: always
    environment:
      - TZ=US/Eastern
    ports:
      # Web interfaces - localhost binding for security
      - '127.0.0.1:8443:8443'     # Crafty HTTPS (Traefik routes here)
      - '127.0.0.1:8100:8100'     # BlueMap HTTP (Traefik routes here)
      
      # Game servers - public binding for player access
      - '25565:25565'             # Minecraft Java Edition
      - '25566:25566'             # Additional servers
    volumes:
      - './data/backups:/crafty/backups'
      - './data/logs:/crafty/logs'
      - './data/servers:/crafty/servers'
      - './data/config:/crafty/app/config'
    security_opt:
      - no-new-privileges:true    # Prevent privilege escalation
    read_only: false             # Crafty needs write access for server management
    networks:
      - crafty-secure

networks:
  crafty-secure:
    driver: bridge
    driver_opts:
      com.docker.network.bridge.name: crafty-br0
EOF

    echo "✅ Secure Crafty configuration created"
    echo "💡 Apply with: cd /opt/services/crafty && docker compose -f docker-compose.secure.yml up -d"
else
    echo "ℹ️ Crafty Controller not found - skipping game server hardening"
fi
```

### Minecraft Server Security (server.properties)

**If you're running Minecraft servers**:

```bash
echo "⛏️ === Minecraft Server Security ==="
echo "Hardening game server configurations..."
echo "==================================="

# Create secure server.properties template
cat > /tmp/minecraft-security-template.properties << 'EOF'
# === Authentication Security ===
online-mode=true                    # Require valid Minecraft accounts
enforce-secure-profile=true         # Require signed player profiles  
prevent-proxy-connections=true      # Block VPN/proxy connections

# === Access Control ===
enable-whitelist=true              # Whitelist-only access
white-list=true                    # Legacy whitelist setting
enforce-whitelist=true             # Strict whitelist enforcement

# === Resource Protection ===
max-players=20                     # Limit concurrent players
max-world-size=29999984           # Prevent infinite world generation
rate-limit=0                      # Packet rate limiting (0=disabled for whitelisted)

# === Remote Access Security ===
enable-rcon=false                 # Disable remote console (security risk)
rcon.port=25575                   # RCON port (if enabled)
rcon.password=CHANGE_THIS_PASSWORD # Strong RCON password (if enabled)

# === Performance/Security Balance ===
view-distance=10                  # Reasonable view distance
simulation-distance=10            # Server-side simulation distance
spawn-protection=16               # Protect spawn area
allow-flight=false               # Prevent flight exploits (unless needed)
EOF

echo "📝 Secure Minecraft server configuration template created at /tmp/minecraft-security-template.properties"
echo "💡 Copy relevant settings to your server's server.properties file"
echo "🎯 Key security settings:"
echo "  • online-mode=true (require valid accounts)"
echo "  • enable-whitelist=true (trusted players only)"  
echo "  • enable-rcon=false (disable remote console)"
echo "  • prevent-proxy-connections=true (block VPNs)"
```

---

## Layer 5: Monitoring and Detection

Security isn't just prevention - you need to know when something's wrong.

### Centralized Logging with Journald

**Configure comprehensive logging**:

```bash
echo "📊 === Security Logging Configuration ==="
echo "Setting up centralized security monitoring..."
echo "========================================"

# Configure journald for security logging
sudo tee -a /etc/systemd/journald.conf << 'EOF'

# === Security Logging Configuration ===
SystemMaxUse=500M              # Limit journal disk usage
MaxRetentionSec=30day         # Retain logs for 30 days
ForwardToSyslog=no            # Use journald, not syslog
Storage=persistent            # Store logs on disk
EOF

# Restart journald to apply configuration
sudo systemctl restart systemd-journald

echo "✅ Centralized logging configured"
echo "📋 Essential security log commands:"
echo "  • sudo journalctl CONTAINER_TAG=docker -f"
echo "  • sudo journalctl -u ssh --since '1 hour ago'"
echo "  • sudo journalctl -p err..emerg --since 'today'"
echo "  • sudo journalctl CONTAINER_NAME=coolify-proxy -g 'error'"
```

### Security Event Monitoring

**Create automated security monitoring**:

```bash
# Create comprehensive security monitoring script
sudo tee /opt/security-monitor.sh << 'EOF'
#!/bin/bash

echo "🚨 === Security Event Monitor ==="
echo "Date: $(date)"
echo "================================"

# SSH security analysis
echo "🔐 SSH Security:"
failed_ssh_24h=$(sudo journalctl -u ssh --since "24 hours ago" | grep -c "Failed password")
failed_ssh_1h=$(sudo journalctl -u ssh --since "1 hour ago" | grep -c "Failed password")
echo "Failed SSH attempts: ${failed_ssh_1h} (1h), ${failed_ssh_24h} (24h)"

if [ $failed_ssh_1h -gt 10 ]; then
    echo "🚨 ALERT: High SSH attack volume - consider additional hardening"
elif [ $failed_ssh_24h -gt 100 ]; then
    echo "⚠️ WARNING: Elevated SSH attack volume"
else
    echo "✅ SSH attacks within normal parameters"
fi

# Container security events
echo "🐳 Container Security:"
container_errors=$(sudo journalctl CONTAINER_TAG=docker --since "1 hour ago" | grep -ic "error\|failed\|denied")
echo "Container security events (1h): $container_errors"

# Network security
echo "🌐 Network Security:" 
firewall_blocks=$(sudo grep "UFW BLOCK" /var/log/ufw.log 2>/dev/null | grep "$(date +%b\ %d)" | wc -l)
echo "Firewall blocks today: $firewall_blocks"

# System resources (security impact)
echo "💾 System Security:"
memory_usage=$(free | grep Mem | awk '{printf "%.1f", $3/$2 * 100.0}')
disk_usage=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
echo "Memory usage: ${memory_usage}%, Disk usage: ${disk_usage}%"

if [ $(echo "$memory_usage > 90" | bc) -eq 1 ] || [ $disk_usage -gt 90 ]; then
    echo "🚨 ALERT: Resource exhaustion - potential DoS condition"
elif [ $(echo "$memory_usage > 80" | bc) -eq 1 ] || [ $disk_usage -gt 80 ]; then
    echo "⚠️ WARNING: High resource usage"
else
    echo "✅ System resources healthy"
fi

# Service availability
echo "🔧 Service Health:"
docker_running=$(docker ps --format "{{.Names}}" | wc -l)
echo "Running containers: $docker_running"

# Web service response check
if curl -f -s -o /dev/null https://coolify.yourdomain.com; then
    echo "✅ Coolify dashboard: Responsive"
else
    echo "❌ Coolify dashboard: Not responding"
fi

echo "✅ Security monitoring complete"
echo "📊 For detailed analysis: sudo journalctl --since 'today' | grep -E '(FAILED|ERROR|DENIED)'"
EOF

chmod +x /opt/security-monitor.sh

# Set up automated monitoring
echo "⏰ Setting up automated security monitoring..."
(crontab -l 2>/dev/null; echo "0 */6 * * * /opt/security-monitor.sh >> /var/log/security-monitor.log") | crontab -

# Test the monitoring
echo "🧪 Testing security monitor:"
sudo /opt/security-monitor.sh
```

### Intrusion Detection Setup

**Basic intrusion detection with fail2ban**:

```bash
echo "🛡️ === Intrusion Detection Setup ==="
echo "Configuring automated threat response..."
echo "==================================="

# Install fail2ban
sudo apt update
sudo apt install fail2ban -y

# Create custom fail2ban configuration
sudo tee /etc/fail2ban/jail.local << 'EOF'
[DEFAULT]
# Ban time: 1 hour
bantime = 3600

# Find time: 10 minutes  
findtime = 600

# Max retries before ban
maxretry = 3

# Email notifications (configure if you have email setup)
# destemail = admin@yourdomain.com
# sender = fail2ban@yourdomain.com

[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
bantime = 3600

[nginx-http-auth]
enabled = true
filter = nginx-http-auth
logpath = /var/log/nginx/error.log
maxretry = 3

[nginx-noscript]
enabled = true
port = http,https
filter = nginx-noscript
logpath = /var/log/nginx/access.log
maxretry = 6

[nginx-badbots]
enabled = true  
port = http,https
filter = nginx-badbots
logpath = /var/log/nginx/access.log
maxretry = 2
EOF

# Enable and start fail2ban
sudo systemctl enable fail2ban
sudo systemctl start fail2ban

echo "✅ Fail2ban intrusion detection active"
echo "📋 Fail2ban management commands:"
echo "  • sudo fail2ban-client status"
echo "  • sudo fail2ban-client status sshd"  
echo "  • sudo fail2ban-client unban IP_ADDRESS"
```

---

## Layer 6: Incident Response and Recovery

**Prepare for when (not if) things go wrong.**

### Security Incident Response Plan

```bash
# Create incident response documentation
sudo tee /opt/incident-response.md << 'EOF'
# Security Incident Response Playbook

## Phase 1: Detection and Initial Response (0-15 minutes)

### Immediate Actions
- [ ] Document the time and nature of the incident
- [ ] Take screenshots/copy logs before they change
- [ ] Determine if this is an active attack or post-incident discovery

### Quick Assessment
```bash
# Check for active suspicious connections
sudo netstat -tuln | grep ESTABLISHED

# Review recent authentication attempts  
sudo journalctl -u ssh --since "1 hour ago" | grep -E "(Failed|Accepted)"

# Check for unusual processes
ps aux | grep -v -E "^\[(.*)\]$" | sort -k3 -nr | head -10

# Review container status
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
```

## Phase 2: Containment (15-60 minutes)

### Network Isolation
```bash
# Block specific IP if identified
sudo ufw deny from ATTACKER_IP

# Emergency firewall lockdown (if severe)
sudo ufw default deny incoming
sudo ufw default deny outgoing  # Extreme measure - breaks functionality
```

### Service Isolation  
```bash
# Stop compromised services
docker stop COMPROMISED_CONTAINER

# Preserve evidence before cleanup
docker logs COMPROMISED_CONTAINER > /tmp/incident-logs-$(date +%Y%m%d-%H%M).log
```

## Phase 3: Investigation (1-4 hours)

### Log Analysis
```bash
# SSH attack analysis
sudo journalctl -u ssh --since "24 hours ago" | grep "Failed\|Invalid"

# Container security events
sudo journalctl CONTAINER_TAG=docker --since "24 hours ago" | grep -i security

# Network activity analysis
sudo journalctl --since "24 hours ago" | grep -E "(UFW BLOCK|DPT)"
```

### System Integrity Check
```bash
# Check for unauthorized changes
sudo find /etc -name "*.conf" -mtime -1 -ls
sudo find /home -name ".ssh" -type d -exec ls -la {} \;

# Verify SSH authorized_keys
cat ~/.ssh/authorized_keys
```

## Phase 4: Recovery (4-24 hours)

### Clean Recovery
```bash  
# Rebuild compromised containers from clean images
cd /opt/services/AFFECTED_SERVICE
docker compose down
docker rmi $(docker images -q)  # Remove potentially compromised images
docker compose pull             # Pull fresh images
docker compose up -d

# Rotate credentials
ssh-keygen -t ed25519 -C "incident-recovery-$(date +%Y%m%d)"
# Update all systems with new SSH key

# Update all passwords/API keys
# Document all credential changes
```

## Phase 5: Post-Incident (1-7 days)

### Security Improvements
- [ ] Analyze attack vectors and implement additional protections
- [ ] Update monitoring to detect similar future attacks  
- [ ] Review and update security configurations
- [ ] Schedule security audit of entire infrastructure

### Documentation
- [ ] Complete incident report with timeline
- [ ] Document lessons learned and process improvements
- [ ] Update incident response procedures based on experience
- [ ] Share sanitized lessons with security community (if appropriate)

## Emergency Contacts
- VPS Provider Support: [Your provider's emergency contact]
- DNS Provider Support: [Cloudflare support]  
- Incident Response Help: [Security community/forums]

## Recovery Commands Quick Reference
```bash
# Emergency service restart
sudo systemctl restart docker
cd /data/coolify/source && docker compose restart

# Emergency firewall reset
sudo ufw --force reset && sudo /opt/firewall-setup.sh

# Emergency SSH key rotation  
ssh-keygen -t ed25519 -C "emergency-$(date +%Y%m%d)"
ssh-copy-id -i ~/.ssh/emergency_key.pub user@server
```
EOF

echo "📋 Incident response plan created at /opt/incident-response.md"
echo "💡 Review and customize for your specific infrastructure"
```

### Backup and Recovery Strategy

```bash
echo "💾 === Backup and Recovery Strategy ==="
echo "Protecting your infrastructure configuration..."
echo "==========================================="

# Create backup script for critical configuration
sudo tee /opt/backup-config.sh << 'EOF'
#!/bin/bash

BACKUP_DIR="/opt/backups/$(date +%Y%m%d-%H%M)"
mkdir -p "$BACKUP_DIR"

echo "📦 Creating infrastructure backup..."

# Coolify configuration
cp -r /data/coolify/source/.env "$BACKUP_DIR/"
cp -r /data/coolify/proxy/dynamic/ "$BACKUP_DIR/"

# System configuration  
cp /etc/docker/daemon.json "$BACKUP_DIR/"
cp /etc/ssh/sshd_config "$BACKUP_DIR/"
cp /etc/ufw/user.rules "$BACKUP_DIR/"

# Custom services
find /opt/services -name "docker-compose*.yml" -exec cp {} "$BACKUP_DIR/" \;

# Container data (if small enough)
# docker run --rm -v /opt/services:/backup alpine tar czf "$BACKUP_DIR/container-data.tar.gz" /backup

# Create archive
tar czf "$BACKUP_DIR.tar.gz" "$BACKUP_DIR"
rm -rf "$BACKUP_DIR"

echo "✅ Backup created: $BACKUP_DIR.tar.gz"

# Cleanup old backups (keep 7 days)
find /opt/backups -name "*.tar.gz" -mtime +7 -delete

echo "🧹 Old backups cleaned up"
EOF

chmod +x /opt/backup-config.sh

# Set up automated backups
(crontab -l 2>/dev/null; echo "0 2 * * * /opt/backup-config.sh") | crontab -

echo "✅ Automated daily backups configured"
echo "🧪 Test backup creation:"
sudo /opt/backup-config.sh
```

---

## Your Bulletproof Infrastructure

**🎉 Look what you've accomplished!** You've transformed your infrastructure into a **production-ready, security-hardened platform** that can handle real-world threats:

### Security Layers Implemented

✅ **Network Perimeter**: Firewall blocking non-essential access, automated attack detection  
✅ **Authentication**: SSH hardened with key-only access, session management, intrusion prevention  
✅ **System Security**: Automatic security updates, kernel hardening, comprehensive monitoring  
✅ **Container Security**: Docker daemon hardened, privilege escalation prevention, centralized logging  
✅ **Service Security**: Minimal port exposure, service-specific hardening, network segmentation  
✅ **Detection & Response**: Security monitoring, intrusion detection, incident response procedures  

### What You've Achieved

**Defense-in-Depth**: Multiple independent security layers protecting your infrastructure  
**Production-Ready**: Security posture suitable for handling real traffic and sensitive operations  
**Maintainable**: Security that enhances rather than hinders your ability to operate services  
**Scalable**: Security patterns that work as you add more services and users  
**Auditable**: Comprehensive logging and monitoring for compliance and troubleshooting  
**Resilient**: Incident response capabilities for when prevention isn't enough  

### Your Security Posture Analysis

**Against Automated Attacks** (95% of threats): **Excellent Protection**
- Attack surface minimized to essential services only
- Default credentials eliminated, strong authentication enforced
- Automated monitoring detects and responds to threats
- Fail-safe configurations prevent most exploitation attempts

**Against Targeted Attacks** (5% but dangerous): **Strong Deterrent**  
- Defense-in-depth makes attacks expensive and time-consuming
- Monitoring provides early warning of sophisticated attempts
- Incident response procedures limit damage scope
- Regular security updates close new vulnerability windows

**Against Zero-Day Exploits**: **Reasonable Protection**
- Network segmentation limits blast radius
- Container isolation prevents lateral movement
- Monitoring detects unusual behavior patterns
- Rapid response procedures enable quick containment

---

## Ongoing Security Operations

**Security is a process, not a destination.** Here's your maintenance rhythm:

### Daily Operations
```bash
# Morning security check
sudo /opt/security-monitor.sh

# Review overnight activity  
sudo journalctl --since "yesterday" | grep -E "(FAILED|ERROR|DENIED)" | tail -10

# Quick service health check
docker ps --format "table {{.Names}}\t{{.Status}}"
```

### Weekly Maintenance
```bash
# Security update check
sudo apt list --upgradable | grep -i security

# Log analysis
sudo journalctl --since "1 week ago" | grep -E "(Failed password|Invalid user)" | cut -d' ' -f1-3,9-11 | sort | uniq -c | sort -nr

# Backup verification
ls -la /opt/backups/ | tail -5

# Fail2ban status
sudo fail2ban-client status
```

### Monthly Security Review
- Review and rotate API keys/service passwords
- Analyze attack patterns and update defenses
- Test incident response procedures
- Update security documentation based on new threats
- Review user accounts and access permissions

### Quarterly Security Audit
- Run comprehensive vulnerability scans
- Review and update firewall rules
- Test backup and recovery procedures  
- Assess new security tools and techniques
- Update threat model based on infrastructure changes

---

## The Philosophy of Practical Security

**You've built something remarkable**: A self-hosted infrastructure that balances security, functionality, and maintainability. You've avoided both extremes - the unsecured "hope for the best" approach and the paranoid "fortress of solitude" that's impossible to operate.

### Security Principles That Work

**Layered Defense**: Multiple security controls that work independently  
**Fail-Safe Defaults**: Secure by default, allow by exception  
**Principle of Least Privilege**: Minimum access necessary for functionality  
**Defense in Depth**: Assume any single layer can be compromised  
**Continuous Monitoring**: Security is an ongoing process, not a one-time setup  

### The Self-Hosting Security Mindset

**Accept Risk Appropriately**: Perfect security doesn't exist; manage risk intelligently  
**Prioritize by Threat Model**: Focus on likely attacks before exotic ones  
**Balance Security and Usability**: Security that prevents legitimate use will be circumvented  
**Learn and Adapt**: Each incident is an opportunity to improve defenses  
**Share Knowledge**: The self-hosting community benefits from shared security knowledge  

### What You've Learned

- **Network security fundamentals** and how they apply to real infrastructure
- **Authentication and access control** that actually protects against real attacks  
- **Container security** that prevents the most common compromise vectors
- **Monitoring and detection** that provides actionable security intelligence
- **Incident response** procedures for when prevention isn't enough
- **Security operations** that maintain protection over time

---

## Congratulations: You're a Security Professional

**🎯 Final Reality Check**: You now operate infrastructure with security practices that rival professional hosting companies. You understand not just how to configure security controls, but why they're necessary and how they work together.

**What makes this special**: You built this knowledge through hands-on experience with real systems, real threats, and real solutions. You didn't just copy configurations - you understand the thinking behind them.

**Your achievement**: You've demonstrated that self-hosting can be done securely, professionally, and at scale. You're proof that individual operators can build infrastructure that's both sophisticated and secure.

**The bigger picture**: You're part of a movement toward decentralized, self-hosted infrastructure that's secure by design rather than security theater. You're helping prove that we don't have to choose between convenience and control.

*Now go forth and host amazing things on your bulletproof infrastructure. The internet needs more people like you building secure, independent services.*

---

## Emergency Security References

### Critical Commands
```bash
# Emergency lockdown
sudo ufw deny all incoming

# Emergency service stop
docker stop $(docker ps -q)

# Emergency user session termination
sudo pkill -u USERNAME

# Emergency log analysis
sudo journalctl --since "1 hour ago" | grep -E "(FAILED|ERROR|DENIED)"
```

### Security Resources
- **Incident Response Plan**: `/opt/incident-response.md`
- **Security Monitoring**: `/opt/security-monitor.sh`  
- **Backup Script**: `/opt/backup-config.sh`
- **Configuration Backups**: `/opt/backups/`

### Emergency Contacts
- **VPS Provider**: [Your provider's support contact]
- **DNS Provider**: [Cloudflare support]
- **Security Community**: [Your preferred security forums/Discord]

---

## References

[1] NIST. "Framework for Improving Critical Infrastructure Cybersecurity." *NIST Cybersecurity Framework*. April 2018. https://nvlpubs.nist.gov/nistpubs/CSWP/NIST.CSWP.04162018.pdf

[2] Ubuntu Security Team. "Ubuntu Security Guide." *Ubuntu Documentation*. Accessed January 2025. https://ubuntu.com/security

[3] Docker, Inc. "Docker Security." *Docker Documentation*. Accessed January 2025. https://docs.docker.com/engine/security/

[4] OWASP Foundation. "Docker Security Cheat Sheet." *OWASP Cheat Sheet Series*. Accessed January 2025. https://cheatsheetseries.owasp.org/cheatsheets/Docker_Security_Cheat_Sheet.html

[5] Fail2ban Development Team. "Fail2ban Manual." *Fail2ban Documentation*. Accessed January 2025. https://github.com/fail2ban/fail2ban

[6] OpenSSH Team. "OpenSSH Security Advisories." *OpenSSH Documentation*. Accessed January 2025. https://www.openssh.com/security.html

[7] Center for Internet Security. "CIS Benchmarks." *CIS Security*. Accessed January 2025. https://www.cisecurity.org/cis-benchmarks

[8] SANS Institute. "Incident Response Process." *SANS Digital Forensics*. Accessed January 2025. https://www.sans.org/white-papers/

---

**Navigation**: [← Back: Migration & Real-World Problems](01-migration-real-world-problems.md)

**🎵 "You're my route, you're my source, and now you're secure..." 🎵**