#!/usr/bin/env bash

# Complete System Migration Manifest Generator
# Coordinates execution of all analysis scripts to generate comprehensive migration manifest
# Part of Atlas Migration Toolkit - Master analysis orchestrator

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

log_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }
log_header() { echo -e "\n${PURPLE}🎯 === $1 ===${NC}"; }

# Configuration
MANIFEST_ID="manifest_$(date +%Y%m%d_%H%M%S)"
MANIFEST_DIR="./complete-manifest/$MANIFEST_ID"
mkdir -p "$MANIFEST_DIR"

# Available analysis scripts
ANALYSIS_SCRIPTS=(
    "01-system-foundation.sh"
    "02-kernel-and-drivers.sh" 
    "03-network-infrastructure.sh"
    "06-docker-containers.sh"
    "07-coolify-platform.sh"
    "08-custom-applications.sh"
)

# Track completion status
declare -A script_status

log_header "Complete System Migration Manifest Generation"
echo "Generating comprehensive migration manifest using Atlas methodology..."
echo "Manifest ID: $MANIFEST_ID"
echo "Output directory: $MANIFEST_DIR"
echo ""

# === SCRIPT EXECUTION COORDINATOR ===
log_header "Analysis Script Execution"

execute_script() {
    local script_name="$1"
    local script_path="./$script_name"
    
    log_info "Executing: $script_name"
    
    if [ ! -f "$script_path" ]; then
        log_error "Script not found: $script_path"
        script_status["$script_name"]="MISSING"
        return 1
    fi
    
    if [ ! -x "$script_path" ]; then
        log_warning "Making script executable: $script_name"
        chmod +x "$script_path"
    fi
    
    # Execute script and capture output
    local script_output="$MANIFEST_DIR/${script_name%.sh}-output.log"
    local start_time=$(date +%s)
    
    if timeout 300 bash "$script_path" > "$script_output" 2>&1; then
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        log_success "Completed: $script_name (${duration}s)"
        script_status["$script_name"]="SUCCESS"
        
        # Copy analysis results to manifest directory
        if [ -d "./analysis-results" ]; then
            latest_result=$(ls -1t ./analysis-results/ | head -1)
            if [ -n "$latest_result" ]; then
                cp -r "./analysis-results/$latest_result" "$MANIFEST_DIR/${script_name%.sh}-results"
            fi
        fi
        return 0
    else
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        log_error "Failed: $script_name (${duration}s)"
        script_status["$script_name"]="FAILED"
        return 1
    fi
}

# Execute available scripts
for script in "${ANALYSIS_SCRIPTS[@]}"; do
    if [ -f "./$script" ]; then
        execute_script "$script"
    else
        log_warning "Script not found, skipping: $script"
        script_status["$script"]="MISSING"
    fi
    echo ""
done

# === LEGACY SCRIPT INTEGRATION ===
log_header "Legacy Script Integration"

# Execute existing comprehensive manifest if available
if [ -f "./01-discovery/comprehensive-system-manifest.sh" ]; then
    log_info "Executing legacy comprehensive system manifest..."
    if timeout 300 bash "./01-discovery/comprehensive-system-manifest.sh" > "$MANIFEST_DIR/legacy-manifest-output.log" 2>&1; then
        log_success "Legacy manifest completed"
        # Copy results if available
        if [ -d "./system-manifest" ]; then
            latest_manifest=$(ls -1t ./system-manifest/ | head -1)
            if [ -n "$latest_manifest" ]; then
                cp -r "./system-manifest/$latest_manifest" "$MANIFEST_DIR/legacy-manifest-results"
            fi
        fi
    else
        log_warning "Legacy manifest execution failed"
    fi
fi

# Execute service dependency mapping if available
if [ -f "./01-discovery/service-dependency-map.sh" ]; then
    log_info "Executing service dependency mapping..."
    if timeout 300 bash "./01-discovery/service-dependency-map.sh" > "$MANIFEST_DIR/dependency-map-output.log" 2>&1; then
        log_success "Service dependency mapping completed"
        # Copy results if available
        if [ -d "./dependency-maps" ]; then
            latest_deps=$(ls -1t ./dependency-maps/ | head -1)
            if [ -n "$latest_deps" ]; then
                cp -r "./dependency-maps/$latest_deps" "$MANIFEST_DIR/dependency-map-results"
            fi
        fi
    else
        log_warning "Service dependency mapping failed"
    fi
fi

# === MANIFEST CONSOLIDATION ===
log_header "Migration Manifest Consolidation"

{
    echo "COMPLETE SYSTEM MIGRATION MANIFEST"
    echo "=================================="
    echo "Generated: $(date)"
    echo "Manifest ID: $MANIFEST_ID"
    echo "System: $(hostname) ($(cat /etc/os-release | grep PRETTY_NAME | cut -d'=' -f2 | tr -d '\"' 2>/dev/null || echo 'Unknown OS'))"
    echo ""
    
    echo "=== ANALYSIS EXECUTION SUMMARY ==="
    for script in "${ANALYSIS_SCRIPTS[@]}"; do
        status="${script_status[$script]:-MISSING}"
        case "$status" in
            "SUCCESS") echo "✅ $script: Completed successfully" ;;
            "FAILED")  echo "❌ $script: Execution failed" ;;
            "MISSING") echo "⚠️  $script: Script not found" ;;
            *)         echo "❓ $script: Unknown status" ;;
        esac
    done
    echo ""
    
    echo "=== SYSTEM OVERVIEW ==="
    echo "Hostname: $(hostname)"
    echo "Operating System: $(cat /etc/os-release | grep PRETTY_NAME | cut -d'=' -f2 | tr -d '\"' 2>/dev/null || echo 'Unknown')"
    echo "Kernel: $(uname -r)"
    echo "Architecture: $(uname -m)"
    echo "Uptime: $(uptime -p 2>/dev/null || echo 'Unknown')"
    echo "CPU cores: $(nproc 2>/dev/null || echo 'Unknown')"
    echo "Memory: $(free -h 2>/dev/null | grep '^Mem:' | awk '{print $2}' || echo 'Unknown')"
    echo "Root disk: $(df -h / 2>/dev/null | tail -1 | awk '{print $2 " (" $5 " used)"}' || echo 'Unknown')"
    echo ""
    
    echo "=== MIGRATION SCOPE ASSESSMENT ==="
    
    # Package information
    if command -v dpkg >/dev/null 2>&1; then
        total_packages=$(dpkg --get-selections 2>/dev/null | grep -v deinstall | wc -l || echo "0")
        manual_packages=$(apt-mark showmanual 2>/dev/null | wc -l || echo "0")
        echo "Installed packages: $total_packages ($manual_packages manually installed)"
    fi
    
    # Service information
    if command -v systemctl >/dev/null 2>&1; then
        running_services=$(systemctl list-units --type=service --state=running --no-pager 2>/dev/null | wc -l || echo "0")
        enabled_services=$(systemctl list-unit-files --type=service --state=enabled 2>/dev/null | wc -l || echo "0")
        echo "System services: $running_services running, $enabled_services enabled"
    fi
    
    # Docker information
    if command -v docker >/dev/null 2>&1 && docker ps >/dev/null 2>&1; then
        containers=$(docker ps -a -q 2>/dev/null | wc -l || echo "0")
        running_containers=$(docker ps -q 2>/dev/null | wc -l || echo "0")
        volumes=$(docker volume ls -q 2>/dev/null | wc -l || echo "0")
        networks=$(docker network ls -q 2>/dev/null | wc -l || echo "0")
        images=$(docker images -q 2>/dev/null | wc -l || echo "0")
        echo "Docker: $running_containers/$containers containers, $volumes volumes, $networks networks, $images images"
    fi
    
    # Coolify information
    if [ -d "/data/coolify" ]; then
        coolify_size=$(du -sh /data/coolify 2>/dev/null | cut -f1 || echo "Unknown")
        echo "Coolify installation: Found ($coolify_size)"
        
        # Count Coolify components
        apps=$(find /data/coolify -name "*.env" -path "*/applications/*" 2>/dev/null | wc -l || echo "0")
        dbs=$(find /data/coolify -name "*.env" -path "*/databases/*" 2>/dev/null | wc -l || echo "0")
        services=$(find /data/coolify -name "*.env" -path "*/services/*" 2>/dev/null | wc -l || echo "0")
        echo "Coolify components: $apps applications, $dbs databases, $services services"
    else
        echo "Coolify installation: Not found"
    fi
    echo ""
    
    echo "=== MIGRATION COMPLEXITY ASSESSMENT ==="
    
    # Calculate complexity score
    complexity_score=0
    
    # Base system complexity
    if [ -n "${total_packages:-}" ] && [ "$total_packages" -gt 1000 ]; then
        complexity_score=$((complexity_score + 1))
    fi
    
    # Service complexity
    if [ -n "${running_services:-}" ] && [ "$running_services" -gt 50 ]; then
        complexity_score=$((complexity_score + 1))
    fi
    
    # Docker complexity
    if [ -n "${containers:-}" ] && [ "$containers" -gt 10 ]; then
        complexity_score=$((complexity_score + 2))
    fi
    
    # Custom services complexity
    if [ -d "/opt/services" ] || [ "$(find /opt -name "*.sh" 2>/dev/null | wc -l)" -gt 5 ]; then
        complexity_score=$((complexity_score + 1))
    fi
    
    # Network complexity
    if [ "$(ip link show 2>/dev/null | grep -c '^[0-9]*:')" -gt 5 ]; then
        complexity_score=$((complexity_score + 1))
    fi
    
    # Determine complexity level
    if [ $complexity_score -le 2 ]; then
        echo "🟢 LOW COMPLEXITY - Straightforward migration expected"
        echo "   Recommended approach: Direct migration with standard procedures"
    elif [ $complexity_score -le 5 ]; then
        echo "🟡 MEDIUM COMPLEXITY - Careful planning required"
        echo "   Recommended approach: Phased migration with testing checkpoints"
    else
        echo "🔴 HIGH COMPLEXITY - Expert migration planning required"
        echo "   Recommended approach: Incremental migration with extensive validation"
    fi
    echo ""
    
    echo "=== CRITICAL MIGRATION COMPONENTS ==="
    echo ""
    echo "🔴 CRITICAL (Must migrate first):"
    echo "   • Operating system configuration and user accounts"
    echo "   • Network configuration and firewall rules"
    echo "   • Docker infrastructure and volumes"
    if [ -d "/data/coolify" ]; then
        echo "   • Coolify database and application configurations"
        echo "   • SSL certificates and proxy configuration"
    fi
    echo ""
    
    echo "🟡 IMPORTANT (Migrate after foundation):"
    echo "   • System services and scheduled tasks"
    echo "   • Custom applications and scripts"
    if [ -d "/opt/services" ]; then
        echo "   • Custom service monitoring and health checks"
    fi
    echo "   • Log files and historical data"
    echo ""
    
    echo "🟢 OPTIONAL (Migrate last):"
    echo "   • Temporary files and caches"
    echo "   • Development tools and utilities"
    echo "   • Non-critical documentation"
    echo ""
    
    echo "=== MIGRATION STRATEGY RECOMMENDATIONS ==="
    echo ""
    echo "Based on system analysis, recommended migration approach:"
    echo ""
    echo "Phase 1: Foundation Setup"
    echo "1. Prepare destination server with matching OS version"
    echo "2. Install and configure base packages and dependencies"
    echo "3. Set up user accounts, SSH keys, and basic security"
    echo "4. Configure network interfaces and firewall rules"
    echo ""
    
    echo "Phase 2: Infrastructure Migration"
    echo "1. Install and configure Docker with same version"
    echo "2. Set up Docker networks and base configurations"
    if [ -d "/data/coolify" ]; then
        echo "3. Install Coolify and restore database backup"
        echo "4. Migrate SSL certificates and proxy configuration"
    fi
    echo ""
    
    echo "Phase 3: Application Migration"
    echo "1. Migrate Docker volumes and container data"
    if [ -d "/data/coolify" ]; then
        echo "2. Restore Coolify applications and configurations"
        echo "3. Verify service connectivity and SSL certificates"
    fi
    if [ -d "/opt/services" ]; then
        echo "4. Migrate custom services and monitoring scripts"
    fi
    echo ""
    
    echo "Phase 4: Validation and Cutover"
    echo "1. Comprehensive functionality testing"
    echo "2. Performance validation and optimization"
    echo "3. DNS cutover and external connectivity testing"
    echo "4. Monitor for 72 hours before decommissioning source"
    echo ""
    
    echo "=== ROLLBACK PROCEDURES ==="
    echo ""
    echo "Rollback checkpoints and procedures:"
    echo ""
    echo "Checkpoint 1: After foundation setup"
    echo "• Rollback: Revert to source server, minimal impact"
    echo "• Validation: SSH access, basic connectivity, security"
    echo ""
    
    echo "Checkpoint 2: After infrastructure migration"
    echo "• Rollback: Stop destination services, restart source"
    echo "• Validation: Docker functionality, Coolify dashboard access"
    echo ""
    
    echo "Checkpoint 3: After application migration"
    echo "• Rollback: DNS revert, service restart on source"
    echo "• Validation: All applications functional, data integrity"
    echo ""
    
    echo "Emergency rollback command sequence:"
    echo "1. ssh source-server 'cd /data/coolify/source && docker-compose up -d'"
    echo "2. Update DNS records to point back to source server"
    echo "3. Verify all services are operational on source"
    echo "4. Investigate migration issues before retry"
    echo ""
    
    echo "=== FILES AND DIRECTORIES GENERATED ==="
    echo ""
    echo "Manifest directory: $MANIFEST_DIR"
    echo "Contents:"
    ls -la "$MANIFEST_DIR" | sed 's/^/  /'
    echo ""
    
    echo "=== NEXT STEPS ==="
    echo ""
    echo "1. Review all analysis results and identify any failed components"
    echo "2. Address any missing or failed analysis scripts"
    echo "3. Plan migration timeline based on complexity assessment"
    echo "4. Prepare destination server environment"
    echo "5. Execute migration using 09-migration-orchestrator.sh"
    echo ""
    
    echo "=== SUPPORT AND TROUBLESHOOTING ==="
    echo ""
    echo "For migration issues:"
    echo "• Review individual analysis logs in manifest directory"
    echo "• Check script execution status and error messages"
    echo "• Validate all prerequisites before starting migration"
    echo "• Test migration procedures on staging environment first"
    echo ""
    
    echo "Generated by Atlas Migration Toolkit"
    echo "Manifest generation completed: $(date)"
    
} > "$MANIFEST_DIR/00-COMPLETE-MIGRATION-MANIFEST.md"

# === GENERATE EXECUTION SUMMARY ===
{
    echo "MANIFEST GENERATION EXECUTION SUMMARY"
    echo "====================================="
    echo "Execution Date: $(date)"
    echo "Manifest ID: $MANIFEST_ID"
    echo "Total Scripts: ${#ANALYSIS_SCRIPTS[@]}"
    echo ""
    
    successful=0
    failed=0
    missing=0
    
    for script in "${ANALYSIS_SCRIPTS[@]}"; do
        status="${script_status[$script]:-MISSING}"
        case "$status" in
            "SUCCESS") ((successful++)) ;;
            "FAILED")  ((failed++)) ;;
            "MISSING") ((missing++)) ;;
        esac
    done
    
    echo "Execution Results:"
    echo "• Successful: $successful"
    echo "• Failed: $failed"
    echo "• Missing: $missing"
    echo ""
    
    if [ $failed -gt 0 ] || [ $missing -gt 0 ]; then
        echo "⚠️  ATTENTION: Some analysis scripts failed or were missing"
        echo "Review individual script logs for troubleshooting"
        echo ""
    fi
    
    echo "Manifest Quality:"
    if [ $successful -eq ${#ANALYSIS_SCRIPTS[@]} ]; then
        echo "🟢 COMPLETE - All analysis scripts executed successfully"
    elif [ $successful -gt $((${#ANALYSIS_SCRIPTS[@]} / 2)) ]; then
        echo "🟡 PARTIAL - Majority of analysis completed, review missing components"
    else
        echo "🔴 INCOMPLETE - Significant analysis gaps, investigate script issues"
    fi
    
} > "$MANIFEST_DIR/execution-summary.txt"

# === COMPLETION ===
log_success "Complete migration manifest generation finished!"
echo ""
echo "📋 Master manifest: $MANIFEST_DIR/00-COMPLETE-MIGRATION-MANIFEST.md"
echo "📊 Execution summary: $MANIFEST_DIR/execution-summary.txt"
echo "📁 Full manifest: $MANIFEST_DIR/"
echo ""

# Display execution summary
successful=0
failed=0
for script in "${ANALYSIS_SCRIPTS[@]}"; do
    status="${script_status[$script]:-MISSING}"
    if [ "$status" = "SUCCESS" ]; then
        ((successful++))
    else
        ((failed++))
    fi
done

if [ $failed -eq 0 ]; then
    log_success "All available analysis scripts completed successfully!"
    echo "🎯 System is ready for migration planning and execution"
else
    log_warning "$failed analysis components failed or missing"
    echo "📋 Review individual script logs for troubleshooting"
    echo "⚠️  Complete all analysis before proceeding with migration"
fi

echo ""
log_info "Next step: Review manifest and execute migration using 09-migration-orchestrator.sh"