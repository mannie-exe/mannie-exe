#!/usr/bin/env bash

# Network Infrastructure Analysis Script
# Analyzes network configuration, firewall rules, routing, and security
# Part of Atlas Migration Toolkit - Comprehensive network analysis

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

log_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }
log_header() { echo -e "\n${PURPLE}🌐 === $1 ===${NC}"; }

# Create output directory
OUTPUT_DIR="./analysis-results/$(date +%Y%m%d_%H%M%S)"
mkdir -p "$OUTPUT_DIR"

log_header "Network Infrastructure Analysis"
echo "Analyzing network configuration, routing, firewall, and security..."
echo "Output directory: $OUTPUT_DIR"

# === NETWORK INTERFACES ===
log_header "Network Interface Configuration"

{
    echo "NETWORK INFRASTRUCTURE ANALYSIS"
    echo "==============================="
    echo "Generated: $(date)"
    echo ""
    
    echo "=== Network Interface Overview ==="
    echo "Active network interfaces:"
    ip link show | grep -E "^[0-9]+:" | while read line; do
        interface=$(echo "$line" | cut -d: -f2 | xargs)
        state=$(echo "$line" | grep -o "state [A-Z]*" | cut -d' ' -f2)
        echo "  $interface: $state"
    done
    echo ""
    
    echo "=== Interface Details ==="
    for interface in $(ip link show | grep -E "^[0-9]+:" | cut -d: -f2 | xargs); do
        echo "Interface: $interface"
        
        # Get interface type and hardware info
        ip link show "$interface" | grep -E "(link/|mtu)" | sed 's/^/  /'
        
        # Get IP addresses
        ip addr show "$interface" | grep "inet" | sed 's/^/  /'
        
        # Get interface statistics
        if [ -f "/sys/class/net/$interface/statistics/rx_bytes" ]; then
            rx_bytes=$(cat "/sys/class/net/$interface/statistics/rx_bytes" 2>/dev/null || echo "0")
            tx_bytes=$(cat "/sys/class/net/$interface/statistics/tx_bytes" 2>/dev/null || echo "0")
            rx_mb=$((rx_bytes / 1024 / 1024))
            tx_mb=$((tx_bytes / 1024 / 1024))
            echo "  Traffic: RX ${rx_mb}MB, TX ${tx_mb}MB"
        fi
        echo ""
    done
    
    echo "=== Network Configuration Files ==="
    if [ -d "/etc/netplan" ]; then
        echo "Netplan configuration files:"
        ls -la /etc/netplan/ | grep -v "^total"
        echo ""
        for netplan_file in /etc/netplan/*.yaml /etc/netplan/*.yml; do
            if [ -f "$netplan_file" ]; then
                echo "File: $(basename "$netplan_file")"
                cat "$netplan_file" | sed 's/^/  /'
                echo ""
            fi
        done
    else
        echo "No Netplan configuration found"
    fi
    
    if [ -d "/etc/systemd/network" ]; then
        echo "SystemD network configuration:"
        ls -la /etc/systemd/network/ | grep -v "^total"
    else
        echo "No SystemD network configuration found"
    fi
    echo ""
    
} > "$OUTPUT_DIR/01-network-interfaces.txt"

# Backup network configuration
mkdir -p "$OUTPUT_DIR/network-configs"
if [ -d "/etc/netplan" ]; then
    cp -r /etc/netplan "$OUTPUT_DIR/network-configs/"
fi
if [ -d "/etc/systemd/network" ]; then
    cp -r /etc/systemd/network "$OUTPUT_DIR/network-configs/"
fi

# Export current network state
ip addr show > "$OUTPUT_DIR/network-interfaces-current.txt"
ip link show > "$OUTPUT_DIR/network-links-current.txt"

log_info "Network interfaces analysis saved to 01-network-interfaces.txt"

# === ROUTING CONFIGURATION ===
log_header "Routing Configuration"

{
    echo "ROUTING CONFIGURATION ANALYSIS"
    echo "============================="
    echo ""
    
    echo "=== IPv4 Routing Table ==="
    ip route show table main
    echo ""
    
    echo "=== IPv6 Routing Table ==="
    ip -6 route show table main 2>/dev/null || echo "IPv6 routing not available"
    echo ""
    
    echo "=== Routing Tables ==="
    echo "Available routing tables:"
    if [ -f "/etc/iproute2/rt_tables" ]; then
        grep -v "^#" /etc/iproute2/rt_tables | grep -v "^$"
    else
        echo "Standard routing tables only"
    fi
    echo ""
    
    echo "=== Policy Routing ==="
    echo "IPv4 routing rules:"
    ip rule show 2>/dev/null | head -20
    echo ""
    echo "IPv6 routing rules:"
    ip -6 rule show 2>/dev/null | head -20 || echo "IPv6 rules not available"
    echo ""
    
    echo "=== Default Gateway ==="
    default_gw=$(ip route show default | awk '/default/ {print $3; exit}')
    if [ -n "$default_gw" ]; then
        echo "Default gateway: $default_gw"
        echo "Gateway reachability:"
        ping -c 3 -W 2 "$default_gw" >/dev/null 2>&1 && echo "  ✅ Reachable" || echo "  ❌ Not reachable"
    else
        echo "No default gateway configured"
    fi
    echo ""
    
    echo "=== ARP Table ==="
    echo "ARP entries:"
    ip neigh show | head -20
    echo ""
    
} > "$OUTPUT_DIR/02-routing-configuration.txt"

# Export routing information
ip route show table all > "$OUTPUT_DIR/routing-tables-all.txt" 2>/dev/null
ip rule show > "$OUTPUT_DIR/routing-rules.txt" 2>/dev/null
ip neigh show > "$OUTPUT_DIR/arp-table.txt"

log_info "Routing configuration saved to 02-routing-configuration.txt"

# === DNS CONFIGURATION ===
log_header "DNS Configuration"

{
    echo "DNS CONFIGURATION ANALYSIS"
    echo "=========================="
    echo ""
    
    echo "=== Current DNS Resolution ==="
    if [ -f "/etc/resolv.conf" ]; then
        echo "Active DNS configuration (/etc/resolv.conf):"
        cat /etc/resolv.conf
    else
        echo "No /etc/resolv.conf found"
    fi
    echo ""
    
    echo "=== SystemD Resolved ==="
    if systemctl is-active systemd-resolved >/dev/null 2>&1; then
        echo "SystemD resolved is active"
        if [ -f "/etc/systemd/resolved.conf" ]; then
            echo "SystemD resolved configuration:"
            grep -E "^[^#]" /etc/systemd/resolved.conf || echo "Using default configuration"
        fi
        echo ""
        
        echo "Resolved status:"
        resolvectl status 2>/dev/null | head -30 || echo "Cannot get resolved status"
    else
        echo "SystemD resolved is not active"
    fi
    echo ""
    
    echo "=== DNS Testing ==="
    echo "DNS resolution test:"
    for test_domain in google.com cloudflare.com; do
        if nslookup "$test_domain" >/dev/null 2>&1; then
            echo "  ✅ $test_domain resolves"
        else
            echo "  ❌ $test_domain fails to resolve"
        fi
    done
    echo ""
    
    echo "=== Hosts File ==="
    if [ -f "/etc/hosts" ]; then
        echo "Custom hosts entries:"
        grep -v "^#\|^$\|127.0.0.1\|::1" /etc/hosts | head -10 || echo "No custom entries"
    fi
    echo ""
    
} > "$OUTPUT_DIR/03-dns-configuration.txt"

# Backup DNS configuration
if [ -f "/etc/resolv.conf" ]; then
    cp /etc/resolv.conf "$OUTPUT_DIR/network-configs/"
fi
if [ -f "/etc/systemd/resolved.conf" ]; then
    cp /etc/systemd/resolved.conf "$OUTPUT_DIR/network-configs/"
fi
if [ -f "/etc/hosts" ]; then
    cp /etc/hosts "$OUTPUT_DIR/network-configs/"
fi

log_info "DNS configuration saved to 03-dns-configuration.txt"

# === FIREWALL CONFIGURATION ===
log_header "Firewall Configuration"

{
    echo "FIREWALL CONFIGURATION ANALYSIS"
    echo "==============================="
    echo ""
    
    echo "=== UFW (Uncomplicated Firewall) ==="
    if command -v ufw >/dev/null 2>&1; then
        echo "UFW status:"
        ufw status verbose 2>/dev/null || echo "UFW not configured or access denied"
        echo ""
        
        echo "UFW rules (numbered):"
        ufw status numbered 2>/dev/null | head -20 || echo "Cannot get numbered rules"
    else
        echo "UFW not installed"
    fi
    echo ""
    
    echo "=== iptables Rules ==="
    if command -v iptables >/dev/null 2>&1; then
        echo "IPv4 iptables rules:"
        echo "Filter table:"
        iptables -L -n -v 2>/dev/null | head -50 || echo "Cannot read iptables rules"
        echo ""
        
        echo "NAT table:"
        iptables -t nat -L -n -v 2>/dev/null | head -20 || echo "Cannot read NAT rules"
        echo ""
        
        echo "Mangle table:"
        iptables -t mangle -L -n 2>/dev/null | head -10 || echo "Cannot read mangle rules"
    else
        echo "iptables not available"
    fi
    echo ""
    
    echo "=== ip6tables Rules ==="
    if command -v ip6tables >/dev/null 2>&1; then
        echo "IPv6 ip6tables rules:"
        ip6tables -L -n 2>/dev/null | head -30 || echo "Cannot read ip6tables rules"
    else
        echo "ip6tables not available"
    fi
    echo ""
    
    echo "=== nftables Rules ==="
    if command -v nft >/dev/null 2>&1; then
        echo "nftables configuration:"
        nft list ruleset 2>/dev/null | head -30 || echo "No nftables rules or access denied"
    else
        echo "nftables not available"
    fi
    echo ""
    
    echo "=== Listening Services ==="
    echo "Services listening on network ports:"
    ss -tulnp | grep LISTEN | head -30
    echo ""
    
    echo "=== Open Ports Summary ==="
    echo "TCP ports:"
    ss -tln | grep LISTEN | awk '{print $4}' | cut -d: -f2 | sort -n | uniq | head -20
    echo ""
    echo "UDP ports:"
    ss -uln | awk '{print $4}' | cut -d: -f2 | sort -n | uniq | head -20
    echo ""
    
} > "$OUTPUT_DIR/04-firewall-configuration.txt"

# Export firewall rules
mkdir -p "$OUTPUT_DIR/firewall-configs"
if command -v iptables >/dev/null 2>&1; then
    iptables-save > "$OUTPUT_DIR/firewall-configs/iptables-rules.txt" 2>/dev/null || echo "Cannot save iptables rules"
fi
if command -v ip6tables >/dev/null 2>&1; then
    ip6tables-save > "$OUTPUT_DIR/firewall-configs/ip6tables-rules.txt" 2>/dev/null || echo "Cannot save ip6tables rules"
fi
if command -v nft >/dev/null 2>&1; then
    nft list ruleset > "$OUTPUT_DIR/firewall-configs/nftables-rules.txt" 2>/dev/null || echo "Cannot save nftables rules"
fi

# Export listening services
ss -tulnp > "$OUTPUT_DIR/listening-services.txt"

log_info "Firewall configuration saved to 04-firewall-configuration.txt"

# === DOCKER NETWORK ANALYSIS ===
log_header "Docker Network Analysis"

{
    echo "DOCKER NETWORK ANALYSIS"
    echo "======================="
    echo ""
    
    if command -v docker >/dev/null 2>&1 && docker ps >/dev/null 2>&1; then
        echo "=== Docker Networks ==="
        echo "Docker network list:"
        docker network ls
        echo ""
        
        echo "=== Docker Network Details ==="
        for network in $(docker network ls --format "{{.Name}}" | grep -v "bridge\|host\|none"); do
            echo "Network: $network"
            docker network inspect "$network" 2>/dev/null | jq -r '.[0] | "  Driver: \(.Driver)\n  IPAM: \(.IPAM.Config[0].Subnet // "No subnet")\n  Gateway: \(.IPAM.Config[0].Gateway // "No gateway")"' 2>/dev/null || \
            docker network inspect "$network" 2>/dev/null | grep -E "(Driver|Subnet|Gateway)" | sed 's/^/  /'
            echo ""
        done
        
        echo "=== Container Network Mapping ==="
        docker ps --format "table {{.Names}}\t{{.Networks}}\t{{.Ports}}" | head -20
        echo ""
        
        echo "=== Docker Bridge Configuration ==="
        for bridge in $(docker network ls --filter driver=bridge --format "{{.Name}}"); do
            echo "Bridge: $bridge"
            docker network inspect "$bridge" 2>/dev/null | jq -r '.[0].IPAM.Config[]? | "  Subnet: \(.Subnet)\n  Gateway: \(.Gateway)"' 2>/dev/null || \
            echo "  Cannot parse bridge configuration"
            echo ""
        done
        
        echo "=== Container Port Mappings ==="
        docker ps --format "{{.Names}}" | while read container; do
            ports=$(docker port "$container" 2>/dev/null)
            if [ -n "$ports" ]; then
                echo "Container: $container"
                echo "$ports" | sed 's/^/  /'
                echo ""
            fi
        done
        
    else
        echo "Docker not available or not running"
    fi
    
} > "$OUTPUT_DIR/05-docker-networks.txt"

# Export Docker network information
if command -v docker >/dev/null 2>&1 && docker ps >/dev/null 2>&1; then
    docker network ls > "$OUTPUT_DIR/docker-networks-list.txt"
    mkdir -p "$OUTPUT_DIR/docker-network-configs"
    for network in $(docker network ls --format "{{.Name}}"); do
        docker network inspect "$network" > "$OUTPUT_DIR/docker-network-configs/${network}.json" 2>/dev/null
    done
fi

log_info "Docker networks analysis saved to 05-docker-networks.txt"

# === NETWORK SECURITY ANALYSIS ===
log_header "Network Security Analysis"

{
    echo "NETWORK SECURITY ANALYSIS"
    echo "========================="
    echo ""
    
    echo "=== External Connectivity ==="
    # Get public IP
    public_ip=$(curl -s --max-time 5 ifconfig.me 2>/dev/null || curl -s --max-time 5 ipecho.net/plain 2>/dev/null || echo "Unable to determine")
    echo "Public IP address: $public_ip"
    echo ""
    
    echo "=== Port Exposure Analysis ==="
    if [ "$public_ip" != "Unable to determine" ] && command -v nmap >/dev/null 2>&1; then
        echo "External port scan (common ports):"
        nmap -F "$public_ip" 2>/dev/null | grep -E "(open|filtered)" | head -20 || echo "No open ports detected or scan failed"
    else
        echo "Cannot perform external port scan (nmap not available or no public IP)"
    fi
    echo ""
    
    echo "=== Network Interface Security ==="
    echo "Interface promiscuous mode check:"
    for interface in $(ip link show | grep -E "^[0-9]+:" | cut -d: -f2 | xargs); do
        if ip link show "$interface" | grep -q "PROMISC"; then
            echo "  ⚠️  $interface: PROMISCUOUS mode enabled"
        else
            echo "  ✅ $interface: Normal mode"
        fi
    done
    echo ""
    
    echo "=== TCP Security Parameters ==="
    echo "SYN cookies: $(cat /proc/sys/net/ipv4/tcp_syncookies 2>/dev/null || echo "Not available")"
    echo "ICMP redirects accept: $(cat /proc/sys/net/ipv4/conf/all/accept_redirects 2>/dev/null || echo "Not available")"
    echo "ICMP redirects send: $(cat /proc/sys/net/ipv4/conf/all/send_redirects 2>/dev/null || echo "Not available")"
    echo "IP forwarding: $(cat /proc/sys/net/ipv4/ip_forward 2>/dev/null || echo "Not available")"
    echo "Source routing: $(cat /proc/sys/net/ipv4/conf/all/accept_source_route 2>/dev/null || echo "Not available")"
    echo ""
    
    echo "=== Network Monitoring ==="
    echo "Active network connections:"
    ss -tupn | grep ESTAB | wc -l | xargs echo "Established connections:"
    echo ""
    echo "Top connection destinations:"
    ss -tupn | grep ESTAB | awk '{print $6}' | cut -d: -f1 | sort | uniq -c | sort -nr | head -10
    echo ""
    
    echo "=== Suspicious Network Activity ==="
    echo "Large number of connections from single IP:"
    ss -tupn | grep ESTAB | awk '{print $6}' | cut -d: -f1 | sort | uniq -c | awk '$1 > 10 {print "  " $1 " connections from " $2}' | head -5
    echo ""
    
} > "$OUTPUT_DIR/06-network-security.txt"

log_info "Network security analysis saved to 06-network-security.txt"

# === GENERATE NETWORK SUMMARY ===
log_header "Generating Network Infrastructure Summary"

{
    echo "NETWORK INFRASTRUCTURE SUMMARY"
    echo "=============================="
    echo "Generated: $(date)"
    echo "Analysis ID: $(basename $OUTPUT_DIR)"
    echo ""
    
    echo "=== Network Overview ==="
    echo "Active interfaces: $(ip link show | grep -E "^[0-9]+:" | grep -c "state UP")"
    echo "Total interfaces: $(ip link show | grep -E "^[0-9]+:" | wc -l)"
    echo "Default gateway: $(ip route show default | awk '/default/ {print $3; exit}' || echo "Not configured")"
    echo "Public IP: $(curl -s --max-time 3 ifconfig.me 2>/dev/null || echo "Unable to determine")"
    echo ""
    
    echo "=== DNS Configuration ==="
    echo "DNS servers: $(grep "^nameserver" /etc/resolv.conf 2>/dev/null | wc -l || echo "0")"
    echo "SystemD resolved: $(systemctl is-active systemd-resolved 2>/dev/null || echo "inactive")"
    echo "Custom hosts entries: $(grep -v "^#\|^$\|127.0.0.1\|::1" /etc/hosts 2>/dev/null | wc -l || echo "0")"
    echo ""
    
    echo "=== Firewall Status ==="
    if command -v ufw >/dev/null 2>&1; then
        ufw_status=$(ufw status 2>/dev/null | grep "Status:" | awk '{print $2}' || echo "unknown")
        echo "UFW status: $ufw_status"
        if [ "$ufw_status" = "active" ]; then
            echo "UFW rules: $(ufw status numbered 2>/dev/null | grep -c "^\[" || echo "0")"
        fi
    else
        echo "UFW: Not installed"
    fi
    
    echo "iptables rules: $(iptables -L 2>/dev/null | grep -c "^Chain\|^target" || echo "Cannot access")"
    echo ""
    
    echo "=== Network Services ==="
    tcp_ports=$(ss -tln | grep LISTEN | wc -l)
    udp_ports=$(ss -uln | wc -l)
    echo "TCP listening ports: $tcp_ports"
    echo "UDP listening ports: $udp_ports"
    echo ""
    
    echo "=== Docker Networks ==="
    if command -v docker >/dev/null 2>&1 && docker ps >/dev/null 2>&1; then
        echo "Docker networks: $(docker network ls 2>/dev/null | wc -l || echo "0")"
        echo "Custom networks: $(docker network ls 2>/dev/null | grep -v "bridge\|host\|none" | wc -l || echo "0")"
        echo "Running containers: $(docker ps -q 2>/dev/null | wc -l || echo "0")"
    else
        echo "Docker: Not available"
    fi
    echo ""
    
    echo "=== Security Assessment ==="
    echo "Network security parameters:"
    syncookies=$(cat /proc/sys/net/ipv4/tcp_syncookies 2>/dev/null || echo "unknown")
    echo "  SYN cookies: $syncookies"
    
    ip_forward=$(cat /proc/sys/net/ipv4/ip_forward 2>/dev/null || echo "unknown")
    echo "  IP forwarding: $ip_forward"
    
    redirects=$(cat /proc/sys/net/ipv4/conf/all/accept_redirects 2>/dev/null || echo "unknown")
    echo "  ICMP redirects: $redirects"
    echo ""
    
    echo "=== Configuration Files Backed Up ==="
    find "$OUTPUT_DIR/network-configs" -type f 2>/dev/null | wc -l | xargs echo "Network config files:"
    find "$OUTPUT_DIR/firewall-configs" -type f 2>/dev/null | wc -l | xargs echo "Firewall config files:"
    find "$OUTPUT_DIR" -name "*docker-network*" 2>/dev/null | wc -l | xargs echo "Docker network configs:"
    echo ""
    
    echo "=== Migration Considerations ==="
    echo "🔴 CRITICAL: Validate network configuration on destination server"
    echo "🔴 CRITICAL: Ensure firewall rules are properly migrated"
    echo "🟡 IMPORTANT: Test external connectivity after migration"
    echo "🟡 IMPORTANT: Verify Docker network configurations"
    echo "🟢 INFO: DNS settings may need adjustment for new environment"
    echo ""
    
    echo "=== Next Steps ==="
    echo "1. Review all network configuration files"
    echo "2. Plan firewall rule migration strategy"
    echo "3. Validate Docker network requirements"
    echo "4. Run 04-filesystem-storage.sh for storage analysis"
    echo ""
    
} > "$OUTPUT_DIR/00-NETWORK-SUMMARY.txt"

log_success "Network infrastructure analysis completed!"
echo ""
echo "📊 Network summary: $OUTPUT_DIR/00-NETWORK-SUMMARY.txt"
echo "📁 Full analysis: $OUTPUT_DIR/"
echo ""
log_info "Next: Run 04-filesystem-storage.sh for filesystem and storage analysis"
log_warning "⚠️  IMPORTANT: Verify firewall rules and network security settings after migration"