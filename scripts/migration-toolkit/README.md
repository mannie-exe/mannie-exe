# Atlas Migration Toolkit - Comprehensive System Migration

*Systematic VPS analysis and migration toolkit with clean separation of concerns*

**Complete system migration toolkit designed for complex infrastructure migrations**

---

## Overview

The Atlas Migration Toolkit provides comprehensive system analysis and migration capabilities with a focus on clean separation of concerns and systematic execution. Redesigned with a flat directory structure for simple, predictable operation.

### Key Features

- **🏗️ System Foundation Analysis**: OS configuration, packages, users, security
- **🔧 Kernel-Level Analysis**: Kernel parameters, modules, drivers, performance tuning
- **🌐 Network Infrastructure**: Network configuration, firewall rules, routing, security
- **💾 Storage and Filesystem**: Mount points, LVM, RAID, storage configurations
- **⚙️ Services and Scheduling**: SystemD services, cron jobs, scheduled tasks
- **🐳 Container Infrastructure**: Docker configuration, networks, volumes, images
- **🚀 Application Platforms**: Coolify analysis and migration procedures
- **🛠️ Custom Applications**: Custom services, scripts, monitoring, and configurations
- **🎯 Migration Orchestration**: Automated backup, transfer, restoration, and validation

---

## Quick Start

### 1. Complete System Analysis
```bash
# Generate comprehensive migration manifest
./00-generate-complete-manifest.sh

# Or run individual analysis components
./01-system-foundation.sh
./02-kernel-and-drivers.sh
./03-network-infrastructure.sh
```

### 2. Review Analysis Results
```bash
# Review the master manifest
cat ./complete-manifest/manifest_*/00-COMPLETE-MIGRATION-MANIFEST.md

# Review individual component analyses
ls ./analysis-results/
```

### 3. Execute Migration
```bash
# Configure migration parameters
./09-migration-orchestrator.sh --setup

# Execute complete migration
./09-migration-orchestrator.sh --full
```

---

## Toolkit Structure

### Flat Directory Organization

```
migration-toolkit/
├── 00-generate-complete-manifest.sh    # Master analysis coordinator
├── 01-system-foundation.sh             # OS, packages, users, security
├── 02-kernel-and-drivers.sh            # Kernel parameters, modules, drivers
├── 03-network-infrastructure.sh        # Network config, firewall, routing
├── 04-filesystem-storage.sh            # Storage, mounts, LVM, filesystems
├── 05-services-scheduling.sh           # SystemD services, cron, timers
├── 06-docker-containers.sh             # Docker infrastructure analysis
├── 07-coolify-platform.sh              # Coolify-specific analysis
├── 08-custom-applications.sh           # Custom services and applications
├── 09-migration-orchestrator.sh        # Migration execution engine
└── README.md                           # This documentation
```

### Clean Separation of Concerns

Each script has a specific responsibility with no functional overlap:

- **Foundation (01)**: Core OS and basic system configuration
- **Kernel (02)**: Low-level system configuration and hardware
- **Network (03)**: All networking aspects and security
- **Storage (04)**: Filesystem, storage, and data management
- **Services (05)**: Service management and scheduling
- **Containers (06)**: Docker and container infrastructure
- **Platform (07)**: Application platform (Coolify) specific analysis
- **Custom (08)**: Custom applications and service-specific configurations
- **Orchestration (09)**: Migration execution and coordination

---

## Analysis Capabilities

### System Foundation Analysis (`01-system-foundation.sh`)

**Analyzes:**
- Operating system information and version details
- Hardware resources (CPU, memory, disk)
- Package management (APT sources, installed packages)
- User accounts, groups, and SSH key management
- Locale, timezone, and internationalization settings
- Basic security configuration and policies

**Generates:**
- Complete package inventory for restoration
- User account and permission backup
- SSH key and authentication configuration
- System configuration file backups

### Kernel and Driver Analysis (`02-kernel-and-drivers.sh`)

**NEW: Comprehensive kernel-level analysis**

**Analyzes:**
- Kernel version, build information, and boot parameters
- System call interface and kernel parameters (sysctl)
- Loaded kernel modules and dependencies
- Hardware detection and driver information
- Performance tuning (CPU governor, I/O scheduler)
- Security modules (AppArmor, SELinux, audit system)

**Generates:**
- Complete kernel parameter export
- Module loading and blacklist configurations
- Hardware compatibility information
- Performance and security tuning settings

### Network Infrastructure Analysis (`03-network-infrastructure.sh`)

**Analyzes:**
- Network interface configuration and status
- Routing tables, policy routing, and gateway configuration
- DNS configuration (SystemD resolved, hosts file)
- Firewall rules (UFW, iptables, nftables)
- Docker network configuration and port mappings
- Network security settings and exposure analysis

**Generates:**
- Complete network configuration backup
- Firewall rules export for restoration
- Docker network configuration files
- Network security assessment

### Migration Orchestration (`09-migration-orchestrator.sh`)

**Features:**
- Interactive migration configuration setup
- Connectivity testing and validation
- Automated backup creation and verification
- Incremental migration with rollback procedures
- DNS cutover automation (Cloudflare supported)
- Comprehensive post-migration validation

---

## Migration Strategies

### Strategy 1: Complete Infrastructure Migration
- **Best for**: Full server replacement with comprehensive analysis
- **Approach**: Systematic analysis of all system components
- **Complexity**: Handles everything from kernel to applications
- **Safety**: Multiple rollback checkpoints and validation steps

### Strategy 2: Component-Based Migration
- **Best for**: Selective migration of specific system components
- **Approach**: Run individual analysis scripts for targeted components
- **Flexibility**: Migrate foundation, applications, or platform independently
- **Control**: Fine-grained control over migration scope

### Strategy 3: Incremental Platform Migration
- **Best for**: Coolify platform migration with minimal downtime
- **Approach**: Focus on platform-specific components (06, 07, 08)
- **Speed**: Faster migration for platform-focused moves
- **Risk**: Lower risk with focused scope

---

## Advanced Features

### Kernel-Level Migration Support

**NEW: Comprehensive kernel configuration migration**
- Complete sysctl parameter analysis and backup
- Kernel module loading and blacklist configurations
- Hardware driver compatibility assessment
- Performance tuning parameter preservation
- Security module configuration backup

### Network Security Analysis

- External port exposure assessment
- Firewall rule validation and backup
- Network security parameter analysis
- Docker network security configuration
- DNS security and configuration validation

### Container Infrastructure Support

- Complete Docker configuration analysis
- Container network mapping and port analysis
- Volume and data persistence management
- Container security configuration
- Multi-network architecture support

### Custom Application Integration

- Service discovery and dependency mapping
- Custom script and configuration backup
- Health monitoring and alerting configuration
- Integration point identification and preservation

---

## Migration Complexity Assessment

The toolkit automatically assesses migration complexity based on:

- **System Complexity**: Package count, service count, custom configurations
- **Network Complexity**: Interface count, firewall rules, custom networking
- **Container Complexity**: Container count, network count, volume count
- **Application Complexity**: Custom services, integration points, dependencies

**Complexity Levels:**
- 🟢 **LOW**: Straightforward migration with standard procedures
- 🟡 **MEDIUM**: Phased migration with testing checkpoints required
- 🔴 **HIGH**: Expert migration planning with incremental validation required

---

## Security Considerations

### Data Protection
- **Configuration Backup**: All system configurations securely backed up
- **Credential Management**: SSH keys and authentication properly preserved
- **Sensitive Data**: Automatic identification and secure handling
- **Access Control**: Proper permission preservation and validation

### Migration Security
- **Encrypted Transfer**: Secure SCP-based file transfer
- **Validation**: Comprehensive post-migration security validation
- **Rollback Safety**: Secure rollback procedures with integrity checking
- **Audit Trails**: Complete migration logging and audit capability

---

## Troubleshooting

### Common Analysis Issues

**Script execution fails:**
```bash
# Make scripts executable
chmod +x *.sh

# Check system dependencies
sudo apt update && sudo apt install -y jq curl net-tools
```

**Analysis incomplete:**
```bash
# Review execution logs
cat ./complete-manifest/manifest_*/execution-summary.txt

# Re-run specific analysis
./01-system-foundation.sh
```

**Permission errors:**
```bash
# Run with appropriate privileges
sudo ./00-generate-complete-manifest.sh
```

### Migration Issues

**Connectivity problems:**
```bash
# Test SSH connectivity
./09-migration-orchestrator.sh --test
```

**Validation failures:**
```bash
# Review migration logs
./09-migration-orchestrator.sh --verify
```

---

## Contributing

This toolkit follows Atlas framework principles:

1. **Clean Separation**: Each script handles one specific domain
2. **Systematic Analysis**: Comprehensive coverage with no overlap
3. **Real-World Focus**: Tested on actual production environments
4. **Flat Structure**: Simple, predictable organization

**To extend the toolkit:**
- Add new analysis capabilities to existing numbered scripts
- Create new numbered scripts for additional domains
- Update the master coordinator (00-) to include new scripts
- Follow the established logging and output patterns

---

## Support Resources

### Documentation
- [Atlas Framework Methodology](../guides/modern-routing/)
- [Docker Best Practices](https://docs.docker.com/develop/dev-best-practices/)
- [Coolify Documentation](https://coolify.io/docs/)

### Community Resources
- [Coolify Discord](https://coolify.io/discord)
- [Self-Hosted Community](https://reddit.com/r/selfhosted)

---

**Generated by Atlas Framework - Systematic Infrastructure Migration**  
*Last updated: June 2, 2025*

*This toolkit provides comprehensive system migration capabilities with clean separation of concerns and systematic execution. Test thoroughly in staging environments before production use.*