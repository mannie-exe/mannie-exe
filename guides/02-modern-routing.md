# Modern Routing: Security Configuration & Best Practices

**Evidence-based security hardening for self-hosted infrastructure**

*Configuration patterns, threat models, and defense strategies*

---

**Navigation**: [← Back: Migration Guide](01-modern-routing.md)

---

## Security Architecture Overview

Modern self-hosted infrastructure operates on a layered security model where each component contributes to overall system defense. Understanding these layers and their interactions is essential for implementing effective security measures.

### Defense-in-Depth Model

The security architecture follows the principle of defense-in-depth, where multiple security controls work together to protect against various attack vectors ^[1,2]:

**Network Layer**:
- Firewall filtering (UFW/iptables)
- Network segmentation via Docker networks
- Reverse proxy SSL/TLS termination

**Application Layer**: 
- Authentication and authorization
- Input validation and sanitization
- Secure configuration management

**Host Layer**:
- Operating system hardening
- Access control and privilege management
- Security monitoring and logging

**Data Layer**:
- Encryption at rest and in transit
- Secure backup and recovery
- Data integrity validation

### Threat Modeling for Self-Hosted Services

Based on NIST guidelines for container security ^[3], our infrastructure faces these primary threat categories:

**External Threats**:
- Internet-based attacks targeting exposed services
- Credential stuffing and brute force attacks
- Exploitation of known vulnerabilities
- DDoS and resource exhaustion attacks

**Internal Threats**:
- Container escape and privilege escalation
- Lateral movement between services
- Data exfiltration through compromised applications
- Misconfigurations leading to exposure

**Supply Chain Threats**:
- Compromised container images
- Malicious dependencies
- Infrastructure provider compromises

## Host-Level Security Configuration

### Firewall Configuration (UFW)

Ubuntu's Uncomplicated Firewall (UFW) provides a simplified interface to iptables for implementing network-level access controls ^[4].

**Principle: Default Deny with Explicit Allow**

```bash
# Reset UFW to known state
sudo ufw --force reset

# Establish default policies
sudo ufw default deny incoming    # Block all incoming by default
sudo ufw default allow outgoing   # Allow outbound connections

# Allow essential services only
sudo ufw allow ssh                # SSH administration (port 22)
sudo ufw allow 80/tcp             # HTTP (Traefik redirect)
sudo ufw allow 443/tcp            # HTTPS (Traefik SSL termination)

# Cloudflare tunnel support (outbound only)
sudo ufw allow out 7844/tcp       # cloudflared connections

# Enable firewall
sudo ufw enable

# Verify configuration
sudo ufw status verbose
```

**Security Rationale**:
- Forces all traffic through the reverse proxy layer
- Eliminates direct access to application ports (8000, 8100, etc.)
- Cloudflare tunnels work outbound-only, reducing attack surface
- SSH remains accessible for legitimate administration

### SSH Hardening Configuration

SSH is the primary administrative access point and requires comprehensive hardening ^[5].

**Authentication Security**:

```bash
# Generate strong SSH key pair
ssh-keygen -t ed25519 -C "admin@yourdomain.com"

# Copy public key to server
ssh-copy-id -i ~/.ssh/id_ed25519.pub user@yourserver.com
```

**SSH Daemon Configuration** (`/etc/ssh/sshd_config`):

```bash
# Authentication hardening
PasswordAuthentication no         # Disable password auth
PubkeyAuthentication yes         # Enable key-based auth only
PermitRootLogin no              # Block root login
MaxAuthTries 3                  # Limit auth attempts
MaxStartups 2                   # Limit concurrent connections

# Protocol hardening
Protocol 2                      # Use SSH protocol 2 only
Port 2222                      # Change default port (optional)
AddressFamily inet              # IPv4 only (unless IPv6 needed)

# Session management
ClientAliveInterval 300         # Keep-alive interval (5 minutes)
ClientAliveCountMax 2          # Max missed keep-alives
LoginGraceTime 60              # Time allowed for login

# Disable unused features
X11Forwarding no               # Disable X11 forwarding
AllowTcpForwarding no         # Disable TCP forwarding
GatewayPorts no               # Disable gateway ports
PermitTunnel no               # Disable tunneling
```

**Configuration Validation**:
```bash
# Test configuration syntax
sudo sshd -t

# Restart SSH service
sudo systemctl reload sshd

# Test new connection before closing current session
ssh -p 2222 user@yourserver.com
```

### System Hardening

**Automatic Security Updates**:
```bash
# Enable unattended upgrades for security patches
sudo apt install unattended-upgrades
sudo dpkg-reconfigure -plow unattended-upgrades
```

**Kernel Security Parameters** (`/etc/sysctl.conf`):
```bash
# Network security
net.ipv4.conf.default.rp_filter=1
net.ipv4.conf.all.rp_filter=1
net.ipv4.tcp_syncookies=1
net.ipv4.conf.all.accept_redirects=0
net.ipv4.conf.all.send_redirects=0
net.ipv4.conf.all.accept_source_route=0

# Apply changes
sudo sysctl -p
```

## Application-Layer Security

### Coolify Security Configuration

Coolify serves as the infrastructure control plane, making its security critical for overall system integrity.

**Authentication Hardening**:
- Enable two-factor authentication (TOTP)
- Use strong, unique passwords (minimum 16 characters)
- Implement session timeouts
- Regular audit of user accounts and permissions

**API Security**:
```bash
# Generate limited-scope API tokens
# Navigate to: Settings → API → Generate Token
# Scope: Only required permissions
# Expiration: Short-lived tokens (30-90 days)
```

**Network Security**:
- Bind only to localhost (127.0.0.1) when possible
- Use Traefik for SSL termination and reverse proxy
- Implement rate limiting at the reverse proxy level

### Container Security Configuration

Based on NIST SP 800-190 container security guidelines ^[3], implement these Docker security measures:

**Docker Daemon Security**:

```json
{
  "live-restore": true,
  "userland-proxy": false,
  "no-new-privileges": true,
  "log-driver": "journald",
  "log-opts": {
    "max-size": "100m",
    "max-file": "3"
  },
  "default-ulimits": {
    "nofile": {
      "Hard": 64000,
      "Name": "nofile",
      "Soft": 64000
    }
  }
}
```

**Container Runtime Security**:
- Use Docker Bench for Security for compliance testing ^[6]
- Implement resource limits to prevent DoS attacks
- Use read-only root filesystems where possible
- Drop unnecessary capabilities
- Use non-root users inside containers

**Network Isolation**:
```bash
# Create isolated networks for different service tiers
docker network create --driver bridge app-tier
docker network create --driver bridge data-tier

# Verify network isolation
docker network ls
docker network inspect app-tier
```

### Minecraft-Specific Security

**Server Configuration** (`server.properties`):
```properties
# Authentication and validation
online-mode=true                    # Require valid Minecraft accounts
enforce-secure-profile=true         # Require signed player profiles
prevent-proxy-connections=true      # Block VPN/proxy connections

# Access control
enable-whitelist=true              # Whitelist-only access
white-list=true                    # Legacy whitelist setting
enforce-whitelist=true             # Strict whitelist enforcement

# Resource protection
max-players=20                     # Limit concurrent players
rate-limit-packets-per-second=7    # Prevent packet flooding
```

**Whitelist Management**:
```bash
# Add trusted players only
/whitelist add TrustedPlayer
/whitelist reload

# Regular whitelist audits
/whitelist list
```

## TLS/SSL Security Configuration

### Certificate Management Strategy

**Let's Encrypt Integration** ^[7]:
- Automated certificate issuance and renewal
- 90-day certificate lifetime for security
- Domain validation via HTTP-01 challenge
- Rate limiting awareness (5 certificates per week per domain)

**Certificate Storage Security**:
```bash
# Secure certificate permissions
sudo chmod 600 /etc/letsencrypt/live/*/privkey.pem
sudo chmod 644 /etc/letsencrypt/live/*/fullchain.pem

# Regular certificate monitoring
sudo certbot certificates
```

### TLS Configuration Standards

Following Mozilla's Server Side TLS guidelines ^[8], implement the Intermediate configuration for broad compatibility:

**Traefik TLS Configuration**:
```yaml
# Static configuration
tls:
  options:
    default:
      minVersion: "VersionTLS12"
      maxVersion: "VersionTLS13"
      cipherSuites:
        - "TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384"
        - "TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384"
        - "TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256"
        - "TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256"
        - "TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305"
        - "TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305"
      curvePreferences:
        - CurveP521
        - CurveP384
        - CurveP256
      sniStrict: true
```

**HTTP Security Headers**:
```yaml
# Traefik middleware for security headers
middlewares:
  security-headers:
    headers:
      frameDeny: true
      sslRedirect: true
      browserXssFilter: true
      contentTypeNosniff: true
      forceSTSHeader: true
      stsIncludeSubdomains: true
      stsPreload: true
      stsSeconds: 31536000
      customFrameOptionsValue: "SAMEORIGIN"
```

**TLS Testing and Validation**:
```bash
# Test TLS configuration
curl -I https://yourservice.yourdomain.com

# SSL Labs testing (aim for A+ rating)
# https://www.ssllabs.com/ssltest/

# OpenSSL verification
openssl s_client -connect yourservice.yourdomain.com:443 -servername yourservice.yourdomain.com
```

## Monitoring and Intrusion Detection

### Fail2ban Configuration

Fail2ban provides automated intrusion detection and response for SSH and other services ^[9].

**Installation and Configuration**:
```bash
# Install fail2ban
sudo apt install fail2ban

# Create local configuration
sudo cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
```

**SSH Protection Configuration** (`/etc/fail2ban/jail.local`):
```ini
[sshd]
enabled = true
port = 2222              # Match your SSH port
logpath = /var/log/auth.log
maxretry = 3             # Failed attempts before ban
bantime = 3600           # Ban duration (1 hour)
findtime = 600           # Time window for counting failures
ignoreip = 127.0.0.1/8   # Ignore localhost
```

**Traefik Protection**:
```ini
[traefik-auth]
enabled = true
filter = traefik-auth
logpath = /var/log/traefik/access.log
maxretry = 5
bantime = 1800
```

**Custom Filter for Traefik** (`/etc/fail2ban/filter.d/traefik-auth.conf`):
```ini
[Definition]
failregex = ^<HOST> - - \[.*\] "(GET|POST|HEAD).*" 401 .*$
            ^<HOST> - - \[.*\] "(GET|POST|HEAD).*" 403 .*$
ignoreregex =
```

### Log Monitoring Strategy

**Essential Logs for Security Monitoring**:

```bash
# SSH authentication attempts
sudo tail -f /var/log/auth.log | grep sshd

# Docker container logs
docker logs -f container_name

# Traefik access and error logs  
docker logs -f traefik-container

# System security events
sudo journalctl -f -u ssh
sudo journalctl -f -u docker
```

**Automated Log Analysis**:
```bash
# Create daily security summary script
#!/bin/bash
# /home/user/scripts/security-summary.sh

echo "=== Daily Security Summary $(date) ==="

echo "SSH Login Attempts:"
grep "$(date '+%b %d')" /var/log/auth.log | grep sshd | grep -E "(Failed|Accepted)" | wc -l

echo "fail2ban Actions:"
sudo fail2ban-client status sshd

echo "Docker Security Events:"
journalctl --since "24 hours ago" -u docker | grep -i security | wc -l

echo "Certificate Status:"
sudo certbot certificates | grep -E "(VALID|INVALID)"
```

## DNS and External Service Security

### Cloudflare Account Security

**Account Hardening**:
- Enable two-factor authentication (TOTP or hardware key)
- Use API tokens instead of Global API key
- Implement least-privilege API token scoping
- Regular audit of API token usage and permissions

**DNS Security Configuration**:
```bash
# Enable Cloudflare security features
# - DDoS protection (automatic)
# - Rate limiting rules
# - Bot Fight Mode
# - Security level: Medium or High
```

**Tunnel Security**:
```bash
# Monitor tunnel health
cloudflared tunnel info tunnel-name

# Rotate tunnel credentials quarterly
cloudflared tunnel delete old-tunnel-name
cloudflared tunnel create new-tunnel-name
```

## Security Maintenance and Compliance

### Regular Security Tasks

**Daily Monitoring**:
- Review authentication logs for anomalies
- Check service health and resource usage
- Monitor certificate expiration status
- Verify backup completion

**Weekly Security Tasks**:
- Update system packages and security patches
- Review firewall logs for blocked connections
- Audit user accounts and access permissions
- Test backup restore procedures

**Monthly Security Review**:
- Rotate API keys and service credentials
- Update container images to latest versions
- Review and update security configurations
- Conduct security configuration audit

**Quarterly Security Assessment**:
- Full security posture review
- Penetration testing (basic)
- Disaster recovery testing
- Security documentation updates

### Compliance Frameworks

**CIS Benchmarks Alignment** ^[10]:
- Docker CIS Benchmark compliance
- Ubuntu 22.04 LTS CIS Benchmark alignment
- Regular compliance scanning with Docker Bench for Security

**Security Documentation Requirements**:
- Maintain security configuration baselines
- Document all security control implementations
- Track security patches and updates
- Incident response procedures documentation

## Performance vs. Security Trade-offs

### Configuration Optimization

**SSH Performance Tuning**:
```bash
# Balance security with usability
ClientAliveInterval 300          # Keep connections alive
Compression yes                  # Enable compression for slow links
UseDNS no                       # Skip reverse DNS lookups
```

**TLS Performance Considerations**:
- Use ECDSA certificates for better performance
- Enable HTTP/2 in Traefik for multiplexing
- Implement OCSP stapling for faster certificate validation
- Use session resumption for TLS connections

**Container Resource Management**:
```bash
# Set appropriate resource limits
docker run --memory="512m" --cpus="1.0" --security-opt="no-new-privileges:true"
```

### Monitoring Resource Impact

**Security Tool Overhead**:
- fail2ban: Minimal CPU impact, log processing overhead
- UFW: Negligible performance impact
- Container scanning: Schedule during low-usage periods
- Log aggregation: Monitor disk space usage

## Security Tool Integration

### Docker Bench for Security

Automated security compliance testing for Docker configurations ^[6]:

```bash
# Download and run Docker Bench
git clone https://github.com/docker/docker-bench-security.git
cd docker-bench-security
sudo sh docker-bench-security.sh

# Address high and medium severity findings
# Focus on: User namespaces, image scanning, network security
```

### Security Scanning Integration

**Container Image Scanning**:
```bash
# Use Trivy for vulnerability scanning
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
  aquasec/trivy image your-image:latest

# Regular scanning schedule
# Weekly: All running containers
# Daily: New images before deployment
```

### Backup Security

**Secure Backup Configuration**:
- Encrypt backups before storage
- Use separate credentials for backup access
- Implement 3-2-1 backup strategy
- Regular restore testing and validation

**Backup Verification**:
```bash
# Automated backup integrity checking
#!/bin/bash
# Verify backup checksums
# Test restore procedures
# Validate encryption integrity
```

---

## References

[1] NIST. "Security and Privacy Controls for Federal Information Systems and Organizations." *NIST Special Publication 800-53 Revision 5*. September 2020. https://nvlpubs.nist.gov/nistpubs/SpecialPublications/NIST.SP.800-53r5.pdf

[2] Ubuntu Community. "Firewall." *Ubuntu Server Documentation*. Accessed May 28, 2025. https://documentation.ubuntu.com/server/how-to/security/firewalls/index.html

[3] Souppaya, Murugiah, John Morello, and Karen Scarfone. "Application Container Security Guide." *NIST Special Publication 800-190*. September 2017. https://csrc.nist.gov/pubs/sp/800/190/final

[4] Ubuntu Community. "UFW - Uncomplicated Firewall." *Ubuntu Documentation*. May 28, 2025. https://documentation.ubuntu.com/server/how-to/security/firewalls/index.html

[5] OpenSSH Development Team. "OpenSSH Security Advisories." *OpenSSH Documentation*. May 28, 2025. https://www.openssh.com/security.html

[6] Docker, Inc. "Docker Bench for Security." *GitHub Repository*. May 28, 2025. https://github.com/docker/docker-bench-security

[7] Docker, Inc. "Docker Engine Security." *Docker Documentation*. May 28, 2025. https://docs.docker.com/engine/security/

[8] Mozilla Security Team. "Security/Server Side TLS." *Mozilla Wiki*. January 20, 2025. https://wiki.mozilla.org/Security/Server_Side_TLS

[9] fail2ban Development Team. "fail2ban." *GitHub Repository*. May 28, 2025. https://github.com/fail2ban/fail2ban

[10] Center for Internet Security. "CIS Benchmarks." *CIS Security*. May 28, 2025. https://www.cisecurity.org/cis-benchmarks

---

**Navigation**: [← Back: Migration Guide](01-modern-routing.md)

---

**Additional Resources**: For comprehensive incident response procedures, see our [NIST-Based Incident Response Framework](../reference/nist-incident-response-procedures.md).