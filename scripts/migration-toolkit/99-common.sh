#!/usr/bin/env bash

# Atlas Migration Toolkit - Common Utilities and Shared State
# Provides shared functionality for all migration analysis scripts
# Part of Atlas Migration Toolkit - Clean separation of concerns

# === SHARED CONFIGURATION ===
TOOLKIT_VERSION="1.0.0"
TOOLKIT_NAME="Atlas Migration Toolkit"

# Runtime detection - set by orchestrator if running orchestrated
EMPACK_ORCHESTRATED=${EMPACK_ORCHESTRATED:-false}

# === COLOR DEFINITIONS ===
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# === LOGGING SYSTEM ===

log_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }
log_header() { echo -e "\n${PURPLE}🎯 === $1 ===${NC}"; }
log_step() { echo -e "${CYAN}📋 $1${NC}"; }
log_progress() { echo -e "${YELLOW}🔄 $1${NC}"; }

# === OUTPUT MANAGEMENT ===

# Global state for output directories
ANALYSIS_OUTPUT_DIR=""
ANALYSIS_TIMESTAMP=""

setup_output_directory() {
    local script_name="$1"
    local base_dir="${2:-./analysis-results}"
    
    if [ "$EMPACK_ORCHESTRATED" = "true" ]; then
        # Orchestrated mode - use shared output directory
        if [ -z "$ANALYSIS_OUTPUT_DIR" ]; then
            log_error "Orchestrated mode but no shared output directory set"
            return 1
        fi
        log_info "Using orchestrated output directory: $ANALYSIS_OUTPUT_DIR"
    else
        # Standalone mode - create own output directory
        ANALYSIS_TIMESTAMP=$(date +%Y%m%d_%H%M%S)
        ANALYSIS_OUTPUT_DIR="$base_dir/$ANALYSIS_TIMESTAMP"
        mkdir -p "$ANALYSIS_OUTPUT_DIR"
        log_info "Created output directory: $ANALYSIS_OUTPUT_DIR"
    fi
    
    # Create script-specific subdirectory if orchestrated
    if [ "$EMPACK_ORCHESTRATED" = "true" ]; then
        local script_dir="$ANALYSIS_OUTPUT_DIR/${script_name%.sh}"
        mkdir -p "$script_dir"
        export SCRIPT_OUTPUT_DIR="$script_dir"
    else
        export SCRIPT_OUTPUT_DIR="$ANALYSIS_OUTPUT_DIR"
    fi
}

# === SAFE FILE OPERATIONS ===

# Write content to file safely without complex redirections
write_analysis_file() {
    local filename="$1"
    local content="$2"
    local output_file="$SCRIPT_OUTPUT_DIR/$filename"
    
    echo "$content" > "$output_file"
    if [ $? -eq 0 ]; then
        log_info "Analysis saved to $filename"
    else
        log_error "Failed to write $filename"
        return 1
    fi
}

# Append content to file safely
append_analysis_file() {
    local filename="$1"
    local content="$2"
    local output_file="$SCRIPT_OUTPUT_DIR/$filename"
    
    echo "$content" >> "$output_file"
}

# Create backup directory and copy files
backup_config_files() {
    local backup_subdir="$1"
    shift
    local files=("$@")
    
    local backup_dir="$SCRIPT_OUTPUT_DIR/$backup_subdir"
    mkdir -p "$backup_dir"
    
    for file in "${files[@]}"; do
        if [ -f "$file" ]; then
            cp "$file" "$backup_dir/" 2>/dev/null && \
                log_info "Backed up $(basename "$file")" || \
                log_warning "Could not backup $file"
        elif [ -d "$file" ]; then
            cp -r "$file" "$backup_dir/" 2>/dev/null && \
                log_info "Backed up directory $(basename "$file")" || \
                log_warning "Could not backup directory $file"
        fi
    done
}

# === SYSTEM ANALYSIS HELPERS ===

# Get system overview safely
get_system_overview() {
    cat << EOF
=== System Identity ===
Hostname: $(hostname)
FQDN: $(hostname -f 2>/dev/null || echo "Not configured")
Domain: $(hostname -d 2>/dev/null || echo "Not configured")

=== Operating System ===
$(cat /etc/os-release)

Kernel: $(uname -r)
Architecture: $(uname -m)
Platform: $(uname -i 2>/dev/null || echo "Unknown")
Hardware: $(uname -p 2>/dev/null || echo "Unknown")

=== Boot Information ===
Uptime: $(uptime -p)
Boot time: $(uptime -s)
System load: $(cat /proc/loadavg)

=== Hardware Resources ===
CPU cores: $(nproc)
CPU info: $(grep 'model name' /proc/cpuinfo | head -1 | cut -d: -f2 | xargs)
Total memory: $(free -h | grep '^Mem:' | awk '{print $2}')
Available memory: $(free -h | grep '^Mem:' | awk '{print $7}')
Memory usage: $(free | grep '^Mem:' | awk '{printf("%.1f%%", $3/$2 * 100)}')
Root filesystem: $(df -h / | tail -1 | awk '{print $2 " (" $5 " used)"}')

=== System Configuration Files ===
Timezone: $(cat /etc/timezone 2>/dev/null || echo "Not set")
Locale: $(locale | grep LANG= | cut -d= -f2)
Hosts file entries: $(grep -v '^#\|^$' /etc/hosts | wc -l)
Filesystem table entries: $(grep -v '^#\|^$' /etc/fstab | wc -l)
EOF
}

# Get package statistics safely
get_package_statistics() {
    local total_packages manual_packages auto_packages
    
    # Get counts safely
    total_packages=$(dpkg --get-selections 2>/dev/null | grep -v deinstall | wc -l || echo "0")
    manual_packages=$(apt-mark showmanual 2>/dev/null | wc -l || echo "0")
    auto_packages=$((total_packages - manual_packages))
    
    cat << EOF
=== Package Statistics ===
Total installed packages: $total_packages
Manually installed packages: $manual_packages
Automatically installed packages: $auto_packages

=== APT Configuration ===
APT sources:
$(if [ -f "/etc/apt/sources.list" ]; then
    grep -v '^#\|^$' /etc/apt/sources.list 2>/dev/null | wc -l | xargs echo "  Main sources.list entries:"
fi)

$(if [ -d "/etc/apt/sources.list.d" ]; then
    additional_sources=$(find /etc/apt/sources.list.d -name "*.list" -o -name "*.sources" 2>/dev/null | wc -l)
    echo "  Additional source files: $additional_sources"
fi)
EOF
}

# Get package categories safely with caching
get_package_categories() {
    # Cache manual packages to avoid multiple calls
    local manual_packages_list
    manual_packages_list=$(apt-mark showmanual 2>/dev/null || echo "")
    
    cat << EOF
=== Critical Package Categories ===
System packages:
$(echo "$manual_packages_list" | grep -E "(^linux-|^ubuntu-|^base-)" 2>/dev/null | wc -l | xargs echo "  Kernel/base packages:")

Development packages:
$(echo "$manual_packages_list" | grep -E "(dev|build|gcc|python|nodejs|git)" 2>/dev/null | wc -l | xargs echo "  Development tools:")

Security packages:
$(echo "$manual_packages_list" | grep -E "(ssh|ssl|security|firewall)" 2>/dev/null | wc -l | xargs echo "  Security tools:")

Container packages:
$(echo "$manual_packages_list" | grep -E "(docker|containerd|runc)" 2>/dev/null | wc -l | xargs echo "  Container runtime:")

=== Third-Party Repositories ===
$(if [ -d "/etc/apt/sources.list.d" ]; then
    for source_file in /etc/apt/sources.list.d/*.list; do
        if [ -f "$source_file" ]; then
            echo "$(basename "$source_file"): $(grep -v '^#\|^$' "$source_file" 2>/dev/null | head -1 | awk '{print $3}' || echo "Unknown")"
        fi
    done
fi)
EOF
}

# === ORCHESTRATION SUPPORT ===

# Initialize for standalone execution
setup_standalone() {
    local script_name="$1"
    log_header "$TOOLKIT_NAME - $(echo "${script_name%.sh}" | tr '[:lower:]' '[:upper:]' | sed 's/-/ /g')"
    setup_output_directory "$script_name"
}

# Check if we're running in orchestrated mode
is_orchestrated() {
    [ "$EMPACK_ORCHESTRATED" = "true" ]
}

# Set orchestrated mode (called by orchestrator)
set_orchestrated_mode() {
    export EMPACK_ORCHESTRATED=true
    export ANALYSIS_OUTPUT_DIR="$1"
    export ANALYSIS_TIMESTAMP="$2"
}

# === KERNEL ANALYSIS HELPERS ===

# Get kernel information safely
get_kernel_information() {
    cat << EOF
=== Kernel Version and Build ===
Kernel version: $(uname -r)
Kernel name: $(uname -s)
Machine type: $(uname -m)
Processor type: $(uname -p 2>/dev/null || echo "Unknown")
Hardware platform: $(uname -i 2>/dev/null || echo "Unknown")

=== Kernel Build Information ===
$(if [ -f "/proc/version" ]; then
    echo "Build info: $(cat /proc/version)"
fi)

=== Boot Parameters ===
$(if [ -f "/proc/cmdline" ]; then
    echo "Kernel command line:"
    cat /proc/cmdline
    echo ""
    echo "Parsed boot parameters:"
    cat /proc/cmdline | tr ' ' '\n' | grep '=' | sort
fi)

=== Kernel Configuration ===
$(if [ -f "/boot/config-$(uname -r)" ]; then
    echo "Kernel config file: /boot/config-$(uname -r)"
    echo "Notable configurations:"
    grep -E "^CONFIG_(DOCKER|CONTAINER|NAMESPACE|CGROUP|BRIDGE|NETFILTER)" "/boot/config-$(uname -r)" 2>/dev/null | head -20 || echo "Cannot read kernel config"
else
    echo "Kernel configuration file not found"
fi)
EOF
}

# Get kernel parameters safely with caching
get_kernel_parameters() {
    # Cache sysctl output to avoid multiple expensive calls
    local sysctl_all
    sysctl_all=$(sysctl -a 2>/dev/null || echo "sysctl failed")
    
    cat << EOF
=== Kernel Parameters (sysctl) ===
All kernel parameters:
$(echo "$sysctl_all" | wc -l | xargs echo "Total parameters:")

=== Critical Kernel Parameters ===
Network parameters:
$(echo "$sysctl_all" | grep -E "^net\.(ipv4|ipv6|core)" | head -20)

Virtual memory parameters:
$(echo "$sysctl_all" | grep "^vm\." | head -15)

Kernel parameters:
$(echo "$sysctl_all" | grep "^kernel\." | head -15)

Filesystem parameters:
$(echo "$sysctl_all" | grep "^fs\." | head -10)

=== Modified Kernel Parameters ===
$(if [ -f "/etc/sysctl.conf" ]; then
    echo "System sysctl configuration:"
    grep -E "^[^#]" /etc/sysctl.conf 2>/dev/null || echo "No custom parameters in main config"
fi)

$(if [ -d "/etc/sysctl.d" ]; then
    echo "Additional sysctl configurations:"
    for sysctl_file in /etc/sysctl.d/*.conf; do
        if [ -f "$sysctl_file" ]; then
            echo "File: $(basename "$sysctl_file")"
            grep -E "^[^#]" "$sysctl_file" 2>/dev/null | sed 's/^/  /' || echo "  No active parameters"
        fi
    done
fi)

=== System Limits ===
Process limits (ulimit -a):
$(ulimit -a | sed 's/^/  /')

$(if [ -f "/etc/security/limits.conf" ]; then
    echo "System limits configuration:"
    grep -E "^[^#]" /etc/security/limits.conf | head -10
fi)
EOF
}

# Get kernel modules safely with caching
get_kernel_modules() {
    # Cache lsmod output to avoid multiple calls
    local lsmod_output
    lsmod_output=$(lsmod)
    
    cat << EOF
=== Loaded Kernel Modules ===
Total loaded modules: $(echo "$lsmod_output" | wc -l)

Largest modules by memory usage:
$(echo "$lsmod_output" | sort -k2 -nr | head -20)

=== Module Dependencies ===
Modules with most dependencies:
$(echo "$lsmod_output" | awk 'NR>1 {print NF-3, $1}' | sort -nr | head -10 | while read deps module; do
    echo "  $module: $deps dependencies"
done)

=== Critical System Modules ===
Network modules:
$(echo "$lsmod_output" | grep -E "(bridge|iptable|netfilter|nf_|ip_)" | head -10)

Filesystem modules:
$(echo "$lsmod_output" | grep -E "(ext4|xfs|btrfs|nfs|fuse)" | head -10)

Container/Docker modules:
$(echo "$lsmod_output" | grep -E "(overlay|aufs|docker|container)" | head -10)

=== Module Loading Configuration ===
$(if [ -d "/etc/modules-load.d" ]; then
    echo "Auto-loaded modules configuration:"
    for module_file in /etc/modules-load.d/*.conf; do
        if [ -f "$module_file" ]; then
            echo "File: $(basename "$module_file")"
            grep -E "^[^#]" "$module_file" | sed 's/^/  /' || echo "  No modules configured"
        fi
    done
fi)

$(if [ -f "/etc/modules" ]; then
    echo "Legacy modules file:"
    grep -E "^[^#]" /etc/modules | sed 's/^/  /' || echo "  No modules configured"
fi)

=== Module Blacklists ===
$(if [ -d "/etc/modprobe.d" ]; then
    echo "Module blacklist configurations:"
    for blacklist_file in /etc/modprobe.d/*.conf; do
        if [ -f "$blacklist_file" ] && grep -q "blacklist" "$blacklist_file" 2>/dev/null; then
            echo "File: $(basename "$blacklist_file")"
            grep "blacklist" "$blacklist_file" | sed 's/^/  /'
        fi
    done
fi)
EOF
}

# Get hardware information safely
get_hardware_info() {
    cat << EOF
=== CPU Information ===
$(if [ -f "/proc/cpuinfo" ]; then
    echo "CPU details:"
    grep -E "(processor|model name|cpu MHz|cache size|flags)" /proc/cpuinfo | head -20
    echo ""
    echo "CPU capabilities (first processor):"
    grep "^flags" /proc/cpuinfo | head -1 | cut -d: -f2 | tr ' ' '\n' | grep -E "(vmx|svm|aes|avx|sse)" | sort
fi)

=== Memory Information ===
$(if [ -f "/proc/meminfo" ]; then
    echo "Memory details:"
    grep -E "(MemTotal|MemFree|MemAvailable|Buffers|Cached|SwapTotal|SwapFree|Hugepagesize)" /proc/meminfo
fi)

=== PCI Devices ===
$(if command -v lspci >/dev/null 2>&1; then
    echo "PCI devices:"
    safe_execute 10 lspci | head -20
    echo ""
    echo "Network controllers:"
    safe_execute 5 lspci | grep -i network
    echo ""
    echo "Storage controllers:"
    safe_execute 5 lspci | grep -i -E "(storage|sata|scsi|raid)"
else
    echo "lspci not available (install pciutils)"
fi)

=== USB Devices ===
$(if command -v lsusb >/dev/null 2>&1; then
    echo "USB devices:"
    safe_execute 10 lsusb
else
    echo "lsusb not available (install usbutils)"
fi)

=== Block Devices ===
$(if command -v lsblk >/dev/null 2>&1; then
    echo "Block devices:"
    lsblk
else
    echo "lsblk not available"
fi)

=== Network Interfaces ===
Network interface details:
$(ip link show | grep -E "^[0-9]+:" | head -10)
EOF
}

# Get performance configuration safely
get_performance_config() {
    cat << EOF
=== CPU Governor and Frequency Scaling ===
$(if [ -d "/sys/devices/system/cpu/cpu0/cpufreq" ]; then
    echo "CPU frequency scaling:"
    echo "  Current governor: $(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || echo "Not available")"
    echo "  Available governors: $(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_available_governors 2>/dev/null || echo "Not available")"
    echo "  Current frequency: $(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq 2>/dev/null || echo "Not available") kHz"
    echo "  Min frequency: $(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_min_freq 2>/dev/null || echo "Not available") kHz"
    echo "  Max frequency: $(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq 2>/dev/null || echo "Not available") kHz"
else
    echo "CPU frequency scaling not available"
fi)

=== I/O Scheduler ===
$(for device in /sys/block/*/queue/scheduler; do
    if [ -f "$device" ]; then
        block_device=$(echo "$device" | cut -d/ -f4)
        current_scheduler=$(cat "$device" | grep -o '\[.*\]' | tr -d '[]')
        available_schedulers=$(cat "$device" | tr -d '[]')
        echo "  $block_device: $current_scheduler (available: $available_schedulers)"
    fi
done | head -10)

=== Memory Management ===
Transparent Huge Pages:
$(if [ -f "/sys/kernel/mm/transparent_hugepage/enabled" ]; then
    echo "  Status: $(cat /sys/kernel/mm/transparent_hugepage/enabled)"
fi)
$(if [ -f "/sys/kernel/mm/transparent_hugepage/defrag" ]; then
    echo "  Defrag: $(cat /sys/kernel/mm/transparent_hugepage/defrag)"
fi)

Swap configuration:
  Swappiness: $(cat /proc/sys/vm/swappiness 2>/dev/null || echo "Not available")
  VFS cache pressure: $(cat /proc/sys/vm/vfs_cache_pressure 2>/dev/null || echo "Not available")
  Overcommit memory: $(cat /proc/sys/vm/overcommit_memory 2>/dev/null || echo "Not available")

=== Network Performance ===
Network tuning parameters:
  TCP congestion control: $(cat /proc/sys/net/ipv4/tcp_congestion_control 2>/dev/null || echo "Not available")
  TCP window scaling: $(cat /proc/sys/net/ipv4/tcp_window_scaling 2>/dev/null || echo "Not available")
  TCP timestamps: $(cat /proc/sys/net/ipv4/tcp_timestamps 2>/dev/null || echo "Not available")
  TCP SACK: $(cat /proc/sys/net/ipv4/tcp_sack 2>/dev/null || echo "Not available")

=== Security Mitigations ===
Security mitigations status:
$(if [ -f "/proc/sys/kernel/kptr_restrict" ]; then
    echo "  Kernel pointer restriction: $(cat /proc/sys/kernel/kptr_restrict)"
fi)
$(if [ -f "/proc/sys/kernel/dmesg_restrict" ]; then
    echo "  Dmesg restriction: $(cat /proc/sys/kernel/dmesg_restrict)"
fi)
$(if [ -f "/proc/sys/kernel/perf_event_paranoid" ]; then
    echo "  Perf event paranoid: $(cat /proc/sys/kernel/perf_event_paranoid)"
fi)
EOF
}

# Get security modules information safely
get_security_modules() {
    cat << EOF
=== AppArmor Status ===
$(if command -v apparmor_status >/dev/null 2>&1; then
    echo "AppArmor information:"
    safe_execute 10 apparmor_status
else
    echo "AppArmor not available or not installed"
fi)

=== SELinux Status ===
$(if command -v getenforce >/dev/null 2>&1; then
    echo "SELinux status: $(getenforce)"
    if command -v sestatus >/dev/null 2>&1; then
        safe_execute 5 sestatus
    fi
else
    echo "SELinux not available"
fi)

=== Kernel Security Features ===
Security-related kernel parameters:
$(sysctl -a 2>/dev/null | grep -E "(randomize_va_space|exec-shield|kptr_restrict|dmesg_restrict)" || echo "Standard security parameters not found")

Capabilities information:
$(if [ -f "/proc/sys/kernel/cap_last_cap" ]; then
    echo "  Last capability: $(cat /proc/sys/kernel/cap_last_cap)"
fi)

=== Audit System ===
$(if command -v auditctl >/dev/null 2>&1; then
    echo "Audit system status:"
    safe_execute 5 auditctl -s 2>/dev/null || echo "Cannot get audit status"
    echo ""
    echo "Audit rules:"
    safe_execute 5 auditctl -l 2>/dev/null | head -10 || echo "No audit rules or cannot access"
else
    echo "Audit system not available"
fi)

=== Kernel Hardening ===
ASLR status: $(cat /proc/sys/kernel/randomize_va_space 2>/dev/null || echo "Not available")
Control groups: $(mount | grep cgroup | wc -l) cgroup mounts
Namespaces support:
$(if [ -d "/proc/self/ns" ]; then
    ls /proc/self/ns/ | sed 's/^/  /'
else
    echo "  Namespace information not available"
fi)
EOF
}

# Backup kernel configurations
backup_kernel_configs() {
    backup_config_files "kernel-configs" \
        "/etc/sysctl.conf" "/etc/sysctl.d" "/etc/security/limits.conf"
    
    backup_config_files "module-configs" \
        "/etc/modules-load.d" "/etc/modprobe.d" "/etc/modules"
}

# Export kernel runtime state
export_kernel_state() {
    log_step "Exporting current kernel parameters..."
    sysctl -a > "$SCRIPT_OUTPUT_DIR/all-kernel-parameters.txt" 2>/dev/null || \
        log_warning "Could not export kernel parameters"
    
    log_step "Exporting loaded modules..."
    lsmod > "$SCRIPT_OUTPUT_DIR/loaded-modules.txt" || \
        log_warning "Could not export module list"
    
    log_step "Exporting hardware information..."
    if command -v lspci >/dev/null 2>&1; then
        safe_execute 15 lspci -v > "$SCRIPT_OUTPUT_DIR/pci-devices-verbose.txt" 2>/dev/null || \
            log_warning "Could not export PCI device details"
    fi
    
    if command -v lsusb >/dev/null 2>&1; then
        safe_execute 15 lsusb -v > "$SCRIPT_OUTPUT_DIR/usb-devices-verbose.txt" 2>/dev/null || \
            log_warning "Could not export USB device details"
    fi
    
    # Copy proc/sys information
    if [ -f "/proc/cpuinfo" ]; then
        cp /proc/cpuinfo "$SCRIPT_OUTPUT_DIR/cpu-information.txt"
    fi
    if [ -f "/proc/meminfo" ]; then
        cp /proc/meminfo "$SCRIPT_OUTPUT_DIR/memory-information.txt"
    fi
}

# === SCRIPT EXECUTION HELPERS ===

# Safe command execution with timeout
safe_execute() {
    local timeout_seconds="${1:-60}"
    shift
    local command=("$@")
    
    if timeout "$timeout_seconds" "${command[@]}" 2>/dev/null; then
        return 0
    else
        log_warning "Command timed out after ${timeout_seconds}s: ${command[*]}"
        return 1
    fi
}

# Generate script completion summary
generate_script_summary() {
    local script_name="$1"
    local start_time="$2"
    local end_time="${3:-$(date +%s)}"
    local duration=$((end_time - start_time))
    
    cat << EOF
=== Analysis Summary ===
Script: $script_name
Completion time: $(date)
Analysis duration: ${duration}s
Output directory: $SCRIPT_OUTPUT_DIR
Files generated: $(find "$SCRIPT_OUTPUT_DIR" -type f 2>/dev/null | wc -l)

=== Generated Files ===
$(find "$SCRIPT_OUTPUT_DIR" -type f -name "*.txt" 2>/dev/null | sed 's/^/  /')
EOF
}

# === INITIALIZATION ===

# Auto-detect if we need to set up standalone mode
if [ "$EMPACK_ORCHESTRATED" != "true" ] && [ -n "$0" ] && [[ "$0" != *"99-common.sh" ]]; then
    # Script is being run directly, not sourced
    SCRIPT_NAME=$(basename "$0")
    if [[ "$SCRIPT_NAME" =~ ^[0-9]{2}- ]]; then
        log_info "Common utilities loaded for standalone execution"
    fi
fi