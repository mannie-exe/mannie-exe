#!/usr/bin/env bash

# System Foundation Analysis Script
# Analyzes core OS configuration, users, packages, and basic system settings
# Part of Atlas Migration Toolkit - Clean separation of concerns

set -euo pipefail

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/99-common.sh"

# === MAIN ANALYSIS FUNCTION ===

analyze_system_foundation() {
    local start_time=$(date +%s)
    
    # Setup output directory
    if ! is_orchestrated; then
        setup_standalone "01-system-foundation.sh"
        log_info "Analyzing core operating system configuration and foundation..."
        log_info "Output directory: $SCRIPT_OUTPUT_DIR"
    fi
    
    # === OPERATING SYSTEM FOUNDATION ===
    log_header "Operating System Information"
    
    local os_content
    os_content=$(cat << EOF
OPERATING SYSTEM FOUNDATION ANALYSIS
====================================
Generated: $(date)

$(get_system_overview)
EOF
)
    
    write_analysis_file "01-os-foundation.txt" "$os_content"
    
    # Backup critical system files
    backup_config_files "system-configs" \
        "/etc/hostname" "/etc/hosts" "/etc/timezone" "/etc/fstab" "/etc/os-release"
    
    # === PACKAGE MANAGEMENT ===
    log_header "Package Management Analysis"
    
    local package_content
    package_content=$(cat << EOF
PACKAGE MANAGEMENT ANALYSIS
==========================

$(get_package_statistics)

$(get_package_categories)
EOF
)
    
    write_analysis_file "02-package-management.txt" "$package_content"
    
    # Export package lists for restoration
    log_step "Exporting manually installed packages..."
    apt-mark showmanual > "$SCRIPT_OUTPUT_DIR/manually-installed-packages.list" 2>/dev/null || \
        log_warning "Could not export manual packages list"
    
    log_step "Exporting all package selections..."
    dpkg --get-selections > "$SCRIPT_OUTPUT_DIR/all-packages.list" 2>/dev/null || \
        log_warning "Could not export package selections"
    
    # Backup APT configuration
    backup_config_files "apt-configs" \
        "/etc/apt/sources.list" "/etc/apt/sources.list.d"
    
    # === USER ACCOUNTS AND AUTHENTICATION ===
    log_header "User Accounts and Authentication"
    
    analyze_user_accounts
    
    # === LOCALE AND INTERNATIONALIZATION ===
    log_header "Locale and Internationalization"
    
    analyze_locale_config
    
    # === SYSTEM SECURITY CONFIGURATION ===
    log_header "System Security Configuration"
    
    analyze_security_config
    
    # === GENERATE FOUNDATION SUMMARY ===
    log_header "Generating Foundation Summary"
    
    generate_foundation_summary "$start_time"
    
    log_success "System foundation analysis completed!"
    if ! is_orchestrated; then
        echo ""
        echo "📊 Foundation summary: $SCRIPT_OUTPUT_DIR/00-FOUNDATION-SUMMARY.txt"
        echo "📁 Full analysis: $SCRIPT_OUTPUT_DIR/"
        echo ""
        log_info "Next: Run 02-kernel-and-drivers.sh for kernel-level configuration analysis"
    fi
}

# === HELPER FUNCTIONS ===

analyze_human_users() {
    # Safely analyze human users without complex awk system() calls
    local user_info=""
    
    getent passwd | awk -F: '$3 >= 1000 && $3 != 65534 {print $1 ":" $3 ":" $5 ":" $6 ":" $7}' | while IFS=: read -r username uid gecos home shell; do
        echo "User: $username (UID: $uid)"
        echo "  Home: $home"
        echo "  Shell: $shell"
        echo "  Description: $gecos"
        
        # Check SSH config safely
        if [ -d "$home/.ssh" ]; then
            echo "  SSH config: Yes"
        else
            echo "  SSH config: No"
        fi
        echo ""
    done
}

analyze_user_accounts() {
    local user_content
    user_content=$(cat << EOF
USER ACCOUNTS AND AUTHENTICATION ANALYSIS
========================================

=== User Account Summary ===
Total user accounts: $(getent passwd | wc -l)
Human users (UID >= 1000): $(getent passwd | awk -F: '$3 >= 1000 && $3 != 65534' | wc -l)
Service users (100-999): $(getent passwd | awk -F: '$3 >= 100 && $3 < 1000' | wc -l)
System users (< 100): $(getent passwd | awk -F: '$3 < 100' | wc -l)

=== Human User Accounts ===
$(analyze_human_users)

=== Service User Accounts ===
$(getent passwd | awk -F: '$3 >= 100 && $3 < 1000 {print $1 ":" $3 ":" $5}' | head -20)

=== Group Memberships ===
Total groups: $(getent group | wc -l)
Important groups:
$(for group in sudo docker adm root; do
    if getent group "$group" >/dev/null 2>&1; then
        members=$(getent group "$group" | cut -d: -f4)
        echo "  $group: ${members:-"(no members)"}"
    fi
done)
EOF
)
    
    write_analysis_file "03-users-authentication.txt" "$user_content"
    
    # Backup user and group information
    getent passwd > "$SCRIPT_OUTPUT_DIR/system-users.txt"
    getent group > "$SCRIPT_OUTPUT_DIR/system-groups.txt"
    getent shadow > "$SCRIPT_OUTPUT_DIR/system-shadow.txt" 2>/dev/null || \
        log_warning "Cannot backup shadow file (permissions)"
    
    # Backup SSH configuration
    backup_config_files "ssh-configs" \
        "/etc/ssh/sshd_config" "/etc/ssh/sshd_config.d"
    
    # Backup SSH keys for root and users
    if [ -f "/root/.ssh/authorized_keys" ]; then
        cp /root/.ssh/authorized_keys "$SCRIPT_OUTPUT_DIR/ssh-configs/root-authorized_keys" 2>/dev/null || true
    fi
    
    for user_home in /home/*; do
        if [ -d "$user_home/.ssh" ]; then
            user=$(basename "$user_home")
            mkdir -p "$SCRIPT_OUTPUT_DIR/ssh-configs/users/$user"
            cp -r "$user_home/.ssh"/* "$SCRIPT_OUTPUT_DIR/ssh-configs/users/$user/" 2>/dev/null || true
        fi
    done
}

analyze_locale_config() {
    local locale_content
    locale_content=$(cat << EOF
LOCALE AND INTERNATIONALIZATION ANALYSIS
=======================================

=== Current Locale Settings ===
$(locale)

=== Available Locales ===
$(locale -a | head -20)
Total available locales: $(locale -a | wc -l)

=== Timezone Configuration ===
Current timezone: $(cat /etc/timezone 2>/dev/null || echo "Not configured")
Current time: $(date)
UTC time: $(date -u)
Timezone info: $(timedatectl status 2>/dev/null | grep 'Time zone' || echo 'Not available')

=== Keyboard Layout ===
$(if [ -f "/etc/default/keyboard" ]; then
    grep -E "^[A-Z]" /etc/default/keyboard
else
    echo "Keyboard configuration not found"
fi)
EOF
)
    
    write_analysis_file "04-locale-internationalization.txt" "$locale_content"
    
    # Backup locale configuration
    backup_config_files "locale-configs" \
        "/etc/locale.gen" "/etc/default/locale" "/etc/timezone" "/etc/default/keyboard"
}

analyze_security_config() {
    local security_content
    security_content=$(cat << EOF
SYSTEM SECURITY CONFIGURATION ANALYSIS
=====================================

=== Security Modules ===
AppArmor status:
$(if command -v apparmor_status >/dev/null 2>&1; then
    apparmor_status | head -10
else
    echo "  AppArmor not available"
fi)

SELinux status:
$(if command -v getenforce >/dev/null 2>&1; then
    getenforce
else
    echo "  SELinux not available"
fi)

=== Password Policy ===
$(if [ -f "/etc/security/pwquality.conf" ]; then
    echo "Password quality configuration:"
    grep -E "^[^#]" /etc/security/pwquality.conf | head -10
else
    echo "No password quality configuration found"
fi)

=== Sudo Configuration ===
Sudoers file exists: $([ -f /etc/sudoers ] && echo "Yes" || echo "No")
$(if [ -d "/etc/sudoers.d" ]; then
    echo "Additional sudo rules: $(ls -1 /etc/sudoers.d | wc -l) files"
fi)

=== SSH Security ===
$(if [ -f "/etc/ssh/sshd_config" ]; then
    echo "Key SSH security settings:"
    grep -E "^(PermitRootLogin|PasswordAuthentication|PubkeyAuthentication|Port|MaxAuthTries)" /etc/ssh/sshd_config || echo "Using default settings"
fi)
EOF
)
    
    write_analysis_file "05-security-configuration.txt" "$security_content"
    
    # Backup security configurations
    backup_config_files "security-configs" \
        "/etc/sudoers" "/etc/security/pwquality.conf" "/etc/pam.d/common-password" "/etc/sudoers.d"
}

generate_foundation_summary() {
    local start_time="$1"
    local summary_content
    summary_content=$(cat << EOF
SYSTEM FOUNDATION ANALYSIS SUMMARY
==================================
$(generate_script_summary "01-system-foundation.sh" "$start_time")

=== System Overview ===
OS: $(grep PRETTY_NAME /etc/os-release | cut -d'"' -f2)
Kernel: $(uname -r)
Architecture: $(uname -m)
Hostname: $(hostname)
Uptime: $(uptime -p)

=== Resource Summary ===
CPU cores: $(nproc)
Memory: $(free -h | grep '^Mem:' | awk '{print $2}') ($(free | grep '^Mem:' | awk '{printf("%.1f%%", $3/$2 * 100)}') used)
Root disk: $(df -h / | tail -1 | awk '{print $2 " (" $5 " used)"}')

=== Account Summary ===
Total packages: $(dpkg --get-selections 2>/dev/null | grep -v deinstall | wc -l || echo "0")
Manual packages: $(apt-mark showmanual 2>/dev/null | wc -l || echo "0")
Human users: $(getent passwd | awk -F: '$3 >= 1000 && $3 != 65534' | wc -l)
Service users: $(getent passwd | awk -F: '$3 >= 100 && $3 < 1000' | wc -l)

=== Security Status ===
AppArmor: $(command -v apparmor_status >/dev/null 2>&1 && echo "Available" || echo "Not available")
SSH root login: $(grep "^PermitRootLogin" /etc/ssh/sshd_config 2>/dev/null | awk '{print $2}' || echo "Default")
Password auth: $(grep "^PasswordAuthentication" /etc/ssh/sshd_config 2>/dev/null | awk '{print $2}' || echo "Default")

=== Critical Files Backed Up ===
Analysis files: $(find "$SCRIPT_OUTPUT_DIR" -name "*.txt" -o -name "*.list" | wc -l)
Configuration directories: $(find "$SCRIPT_OUTPUT_DIR" -type d -name "*configs*" | wc -l)

=== Migration Foundation Status ===
✅ Operating system documented
✅ Package management analyzed
✅ User accounts cataloged
✅ Security configuration backed up
✅ System configuration files preserved

=== Next Steps ===
1. Run 02-kernel-and-drivers.sh for kernel-level analysis
2. Run 03-network-infrastructure.sh for network configuration
3. Continue with remaining analysis scripts
EOF
)
    
    write_analysis_file "00-FOUNDATION-SUMMARY.txt" "$summary_content"
}

# === SCRIPT EXECUTION ===

# Only run analysis if script is executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    analyze_system_foundation
fi