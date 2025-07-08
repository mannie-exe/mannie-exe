#!/usr/bin/env bash

# Kernel and Driver Analysis Script
# Analyzes kernel-level configurations, modules, drivers, and system tuning
# Part of Atlas Migration Toolkit - Addresses kernel-level migration requirements

set -euo pipefail

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/99-common.sh"

# === MAIN ANALYSIS FUNCTION ===

analyze_kernel_and_drivers() {
    local start_time=$(date +%s)
    
    # Setup output directory
    if ! is_orchestrated; then
        setup_standalone "02-kernel-and-drivers.sh"
        log_info "Analyzing kernel-level settings, modules, drivers, and system tuning..."
        log_info "Output directory: $SCRIPT_OUTPUT_DIR"
    fi
    
    # === KERNEL INFORMATION ===
    log_header "Kernel Information and Configuration"
    
    local kernel_content
    kernel_content=$(cat << EOF
KERNEL AND DRIVER CONFIGURATION ANALYSIS
========================================
Generated: $(date)

$(get_kernel_information)
EOF
)
    
    write_analysis_file "01-kernel-information.txt" "$kernel_content"
    
    # === SYSTEM CALL INTERFACE ===
    log_header "System Call and Kernel Interface"
    
    local kernel_params_content
    kernel_params_content=$(cat << EOF
SYSTEM CALL AND KERNEL INTERFACE ANALYSIS
=========================================

$(get_kernel_parameters)
EOF
)
    
    write_analysis_file "02-kernel-parameters.txt" "$kernel_params_content"
    
    # Backup kernel parameter configurations
    backup_kernel_configs
    
    # === KERNEL MODULES ===
    log_header "Kernel Modules Analysis"
    
    local modules_content
    modules_content=$(cat << EOF
KERNEL MODULES ANALYSIS
======================

$(get_kernel_modules)
EOF
)
    
    write_analysis_file "03-kernel-modules.txt" "$modules_content"
    
    # === HARDWARE AND DRIVERS ===
    log_header "Hardware and Driver Analysis"
    
    local hardware_content
    hardware_content=$(cat << EOF
HARDWARE AND DRIVER ANALYSIS
============================

$(get_hardware_info)
EOF
)
    
    write_analysis_file "04-hardware-drivers.txt" "$hardware_content"
    
    # === PERFORMANCE AND TUNING ===
    log_header "Performance and Tuning Analysis"
    
    local performance_content
    performance_content=$(cat << EOF
PERFORMANCE AND TUNING ANALYSIS
===============================

$(get_performance_config)
EOF
)
    
    write_analysis_file "05-performance-tuning.txt" "$performance_content"
    
    # === SECURITY MODULES AND FEATURES ===
    log_header "Security Modules and Features"
    
    local security_content
    security_content=$(cat << EOF
SECURITY MODULES AND FEATURES ANALYSIS
=====================================

$(get_security_modules)
EOF
)
    
    write_analysis_file "06-security-modules.txt" "$security_content"
    
    # === EXPORT KERNEL STATE ===
    log_header "Exporting Kernel Runtime State"
    
    export_kernel_state
    
    # === GENERATE KERNEL SUMMARY ===
    log_header "Generating Kernel Configuration Summary"
    
    generate_kernel_summary "$start_time"
    
    log_success "Kernel and driver analysis completed!"
    if ! is_orchestrated; then
        echo ""
        echo "📊 Kernel summary: $SCRIPT_OUTPUT_DIR/00-KERNEL-SUMMARY.txt"
        echo "📁 Full analysis: $SCRIPT_OUTPUT_DIR/"
        echo ""
        log_info "Next: Run 03-network-infrastructure.sh for network configuration analysis"
        log_warning "⚠️  CRITICAL: Kernel configurations must be compatible with destination hardware"
    fi
}

# === HELPER FUNCTIONS ===

generate_kernel_summary() {
    local start_time="$1"
    local summary_content
    summary_content=$(cat << EOF
KERNEL AND DRIVER CONFIGURATION SUMMARY
=======================================
$(generate_script_summary "02-kernel-and-drivers.sh" "$start_time")

=== Kernel Overview ===
Kernel version: $(uname -r)
Architecture: $(uname -m)
Loaded modules: $(lsmod | wc -l)
Total sysctl parameters: $(sysctl -a 2>/dev/null | wc -l)

=== Critical Configuration Status ===
CPU governor: $(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || echo "Not available")
I/O scheduler: $(cat /sys/block/*/queue/scheduler 2>/dev/null | head -1 | grep -o '\[.*\]' | tr -d '[]' || echo "Not available")
Swappiness: $(cat /proc/sys/vm/swappiness 2>/dev/null)
TCP congestion control: $(cat /proc/sys/net/ipv4/tcp_congestion_control 2>/dev/null)

=== Security Features ===
AppArmor: $(command -v apparmor_status >/dev/null 2>&1 && echo "Available" || echo "Not available")
SELinux: $(command -v getenforce >/dev/null 2>&1 && getenforce || echo "Not available")
ASLR: $(cat /proc/sys/kernel/randomize_va_space 2>/dev/null || echo "Not available")
Audit system: $(command -v auditctl >/dev/null 2>&1 && echo "Available" || echo "Not available")

=== Hardware Summary ===
CPU model: $(grep 'model name' /proc/cpuinfo | head -1 | cut -d: -f2 | xargs 2>/dev/null || echo "Not available")
CPU cores: $(nproc)
Total memory: $(grep MemTotal /proc/meminfo | awk '{print $2 $3}' 2>/dev/null || echo "Not available")
PCI devices: $(lspci 2>/dev/null | wc -l || echo "Not available")

=== Custom Configurations Detected ===
$(analyze_custom_configs)

=== Migration Considerations ===
🔴 CRITICAL: Kernel version and modules must match on destination
🟡 IMPORTANT: Validate custom sysctl parameters on new system
🟡 IMPORTANT: Verify hardware compatibility and drivers
🟢 INFO: Export and restore custom module configurations

=== Files Generated ===
Analysis files: $(find "$SCRIPT_OUTPUT_DIR" -name "*.txt" | wc -l)
Configuration backups: $(find "$SCRIPT_OUTPUT_DIR" -type d -name "*configs*" | wc -l)

=== Next Steps ===
1. Review all kernel configuration files
2. Validate hardware compatibility on destination server
3. Plan kernel parameter migration strategy
4. Run 03-network-infrastructure.sh for network analysis
EOF
)
    
    write_analysis_file "00-KERNEL-SUMMARY.txt" "$summary_content"
}

analyze_custom_configs() {
    local custom_configs=0
    
    if [ -f "/etc/sysctl.conf" ] && grep -q "^[^#]" /etc/sysctl.conf 2>/dev/null; then
        echo "✅ Custom sysctl parameters in /etc/sysctl.conf"
        custom_configs=$((custom_configs + 1))
    fi
    
    if [ -d "/etc/sysctl.d" ] && find /etc/sysctl.d -name "*.conf" -exec grep -l "^[^#]" {} \; 2>/dev/null | grep -q .; then
        echo "✅ Custom sysctl parameters in /etc/sysctl.d/"
        custom_configs=$((custom_configs + 1))
    fi
    
    if [ -d "/etc/modules-load.d" ] && find /etc/modules-load.d -name "*.conf" -exec grep -l "^[^#]" {} \; 2>/dev/null | grep -q .; then
        echo "✅ Custom module loading configuration"
        custom_configs=$((custom_configs + 1))
    fi
    
    if [ -d "/etc/modprobe.d" ] && find /etc/modprobe.d -name "*.conf" -exec grep -l "blacklist" {} \; 2>/dev/null | grep -q .; then
        echo "✅ Module blacklist configurations"
        custom_configs=$((custom_configs + 1))
    fi
    
    if [ $custom_configs -eq 0 ]; then
        echo "ℹ️  No custom kernel configurations detected (using defaults)"
    fi
}

# === SCRIPT EXECUTION ===

# Only run analysis if script is executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    analyze_kernel_and_drivers
fi