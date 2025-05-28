# NIST-Based Incident Response Procedures

**Comprehensive security incident response framework for enterprise infrastructure**

*Following NIST SP 800-61r2 guidelines for incident handling and cybersecurity framework alignment*

---

## Incident Response Framework Overview

This guide follows the NIST Computer Security Incident Handling methodology ^[1], adapted for modern self-hosted infrastructure environments. The framework provides structured procedures for detecting, responding to, and recovering from security incidents while minimizing impact and preventing recurrence.

### NIST Incident Response Lifecycle

The incident response process consists of four primary phases ^[1]:

1. **Preparation**: Establishing capabilities, policies, and procedures
2. **Detection & Analysis**: Identifying and characterizing incidents
3. **Containment, Eradication & Recovery**: Limiting damage and restoring operations
4. **Post-Incident Activity**: Learning from incidents and improving defenses

### Incident Classification Framework

Based on NIST Cybersecurity Framework 2.0 guidelines ^[2], incidents are classified by:

**Severity Levels**:
- **Critical**: Complete system compromise, data breach, or service unavailability
- **High**: Significant security control failures or suspected intrusions
- **Medium**: Policy violations, suspicious activity, or degraded services
- **Low**: Minor security events requiring documentation

**Incident Categories**:
- **Unauthorized Access**: Authentication bypasses, privilege escalation
- **Malicious Code**: Malware, ransomware, suspicious scripts
- **Denial of Service**: Resource exhaustion, DDoS attacks
- **Information Breach**: Data exfiltration, unauthorized disclosure
- **System Compromise**: Container escapes, host-level intrusions

## Pre-Incident Preparation

### Incident Response Team Structure

**Incident Commander (IC)**:
- Overall incident coordination and decision authority
- Communication with stakeholders and external parties
- Resource allocation and escalation decisions

**Technical Lead**:
- Technical investigation and analysis
- System remediation and recovery actions
- Evidence collection and preservation

**Communications Lead**:
- Internal and external communications
- Documentation and reporting
- Media relations (if applicable)

### Essential Tools and Resources

**Incident Response Toolkit**:

```bash
# Create incident response directory
mkdir -p /opt/incident-response/{tools,evidence,documentation}

# Essential tools installation
sudo apt install -y tcpdump wireshark nmap netcat-openbsd \
  sleuthkit autopsy volatility-tools foremost \
  chkrootkit rkhunter lynis

# Docker security scanning
docker pull aquasec/trivy
docker pull anchore/syft

# Network analysis tools
sudo apt install -y ngrep dsniff ettercap-text-only
```

**Evidence Collection Scripts**:

```bash
#!/bin/bash
# /opt/incident-response/tools/collect-evidence.sh

INCIDENT_ID="$1"
EVIDENCE_DIR="/opt/incident-response/evidence/${INCIDENT_ID}"

if [ -z "$INCIDENT_ID" ]; then
    echo "Usage: $0 <incident-id>"
    exit 1
fi

mkdir -p "$EVIDENCE_DIR"
cd "$EVIDENCE_DIR"

echo "=== Evidence Collection Started: $(date) ===" | tee collection.log

# System information
echo "Collecting system information..." | tee -a collection.log
uname -a > system_info.txt
ps auxwww > processes.txt
netstat -tulpn > network_connections.txt
ss -tulpn > socket_stats.txt
lsof > open_files.txt

# Docker information
echo "Collecting Docker information..." | tee -a collection.log
docker ps -a > docker_containers.txt
docker images > docker_images.txt
docker network ls > docker_networks.txt
docker system df > docker_disk_usage.txt

# System logs
echo "Collecting system logs..." | tee -a collection.log
cp /var/log/auth.log auth.log.$(date +%Y%m%d_%H%M%S)
journalctl --since "24 hours ago" > systemd_logs.txt

# Container logs
echo "Collecting container logs..." | tee -a collection.log
for container in $(docker ps -aq); do
    docker logs "$container" > "container_${container}.log" 2>&1
done

# Memory dump (if needed)
if [ "$2" = "memory" ]; then
    echo "Creating memory dump..." | tee -a collection.log
    sudo dd if=/dev/mem of=memory_dump.raw bs=1024 count=1024
fi

echo "=== Evidence Collection Completed: $(date) ===" | tee -a collection.log
echo "Evidence stored in: $EVIDENCE_DIR"
```

### Communication Templates

**Initial Incident Notification**:

```
SUBJECT: [INCIDENT-${ID}] Security Incident Declaration - ${SEVERITY}

INCIDENT DETAILS:
- Incident ID: ${ID}
- Severity: ${SEVERITY}
- Classification: ${CATEGORY}
- Discovered: ${TIMESTAMP}
- Reporter: ${REPORTER}

INITIAL ASSESSMENT:
- Affected Systems: ${SYSTEMS}
- Potential Impact: ${IMPACT}
- Current Status: ${STATUS}

IMMEDIATE ACTIONS TAKEN:
- ${ACTION_1}
- ${ACTION_2}

NEXT STEPS:
- ${NEXT_ACTION}
- Estimated Update: ${ETA}

Incident Commander: ${IC_NAME}
Contact: ${IC_CONTACT}
```

## Detection and Analysis Procedures

### Security Event Monitoring

**Automated Detection Triggers**:

```bash
# Fail2ban alert integration
#!/bin/bash
# /etc/fail2ban/action.d/incident-trigger.sh

INCIDENT_TYPE="Automated Detection"
SEVERITY="Medium"
SOURCE_IP="<ip>"
SERVICE="<name>"

# Create incident if threshold exceeded
RECENT_BANS=$(fail2ban-client status | grep "Number of jail:" | awk '{print $4}')
if [ "$RECENT_BANS" -gt 5 ]; then
    INCIDENT_ID="INC-$(date +%Y%m%d-%H%M%S)"
    echo "Creating incident: $INCIDENT_ID"
    
    # Log incident
    echo "$(date): Incident $INCIDENT_ID created - Multiple service bans detected" >> /var/log/security-incidents.log
    
    # Trigger automated response
    /opt/incident-response/tools/auto-response.sh "$INCIDENT_ID" "multiple_bans"
fi
```

**Log Analysis for Indicators of Compromise (IOCs)**:

```bash
#!/bin/bash
# /opt/incident-response/tools/ioc-scanner.sh

LOG_DIR="/var/log"
ALERT_THRESHOLD=5

echo "=== IOC Analysis Started: $(date) ==="

# SSH brute force detection
SSH_FAILURES=$(grep "Failed password" "$LOG_DIR/auth.log" | grep "$(date '+%b %d')" | wc -l)
if [ "$SSH_FAILURES" -gt "$ALERT_THRESHOLD" ]; then
    echo "ALERT: $SSH_FAILURES SSH failures detected today"
fi

# Docker security events
DOCKER_ERRORS=$(journalctl -u docker --since "1 hour ago" | grep -i -E "(error|fatal|critical)" | wc -l)
if [ "$DOCKER_ERRORS" -gt 3 ]; then
    echo "ALERT: $DOCKER_ERRORS Docker errors in past hour"
fi

# Network anomalies
NETWORK_CONNS=$(netstat -tn | grep ESTABLISHED | wc -l)
if [ "$NETWORK_CONNS" -gt 100 ]; then
    echo "ALERT: High number of network connections: $NETWORK_CONNS"
fi

# Certificate expiration monitoring
CERT_EXPIRY=$(certbot certificates 2>/dev/null | grep "INVALID" | wc -l)
if [ "$CERT_EXPIRY" -gt 0 ]; then
    echo "ALERT: $CERT_EXPIRY expired certificates detected"
fi

echo "=== IOC Analysis Completed: $(date) ==="
```

### Incident Triage Process

**Initial Triage Checklist**:

1. **Immediate Safety Assessment**:
   - [ ] Are critical services operational?
   - [ ] Is data integrity intact?
   - [ ] Are user accounts compromised?
   - [ ] Is the incident contained to specific systems?

2. **Scope Determination**:
   - [ ] Which systems are affected?
   - [ ] What is the timeline of the incident?
   - [ ] Are there signs of lateral movement?
   - [ ] What data may be compromised?

3. **Impact Assessment**:
   - [ ] Service availability impact
   - [ ] Data confidentiality impact
   - [ ] System integrity impact
   - [ ] Regulatory/compliance implications

**Triage Decision Matrix**:

| Impact | Probability | Action |
|--------|-------------|--------|
| Critical | High | Immediate escalation, full response team activation |
| Critical | Medium | Escalate to senior staff, begin containment |
| High | High | Activate incident response, coordinate team |
| High | Medium | Begin investigation, prepare for escalation |
| Medium | Any | Standard investigation procedures |
| Low | Any | Log and monitor, minimal response |

## Containment Procedures

### Immediate Containment Actions

**Network Isolation**:

```bash
#!/bin/bash
# /opt/incident-response/tools/emergency-isolation.sh

INCIDENT_ID="$1"
TARGET_IP="$2"
REASON="$3"

if [ $# -lt 3 ]; then
    echo "Usage: $0 <incident-id> <target-ip> <reason>"
    exit 1
fi

echo "$(date): Emergency isolation initiated for $TARGET_IP (Incident: $INCIDENT_ID, Reason: $REASON)"

# Block IP immediately
sudo ufw insert 1 deny from "$TARGET_IP"
sudo ufw reload

# Log the action
echo "$(date): IP $TARGET_IP blocked via UFW (Incident: $INCIDENT_ID)" >> /var/log/security-incidents.log

# Notify incident commander
echo "EMERGENCY ISOLATION EXECUTED" | mail -s "[${INCIDENT_ID}] IP Blocked: $TARGET_IP" incident-commander@company.com

# Kill active connections from this IP
sudo ss -K dst "$TARGET_IP"

echo "Isolation completed for $TARGET_IP"
```

**Container Isolation**:

```bash
#!/bin/bash
# /opt/incident-response/tools/container-isolation.sh

CONTAINER_ID="$1"
INCIDENT_ID="$2"

if [ $# -lt 2 ]; then
    echo "Usage: $0 <container-id> <incident-id>"
    exit 1
fi

echo "$(date): Container isolation initiated for $CONTAINER_ID (Incident: $INCIDENT_ID)"

# Stop container immediately
docker stop "$CONTAINER_ID"

# Disconnect from all networks
NETWORKS=$(docker inspect "$CONTAINER_ID" | jq -r '.[0].NetworkSettings.Networks | keys[]')
for network in $NETWORKS; do
    docker network disconnect "$network" "$CONTAINER_ID" 2>/dev/null || true
done

# Create forensic snapshot
docker commit "$CONTAINER_ID" "forensic-${CONTAINER_ID}-${INCIDENT_ID}"

# Log the action
echo "$(date): Container $CONTAINER_ID isolated and snapshotted (Incident: $INCIDENT_ID)" >> /var/log/security-incidents.log

echo "Container isolation completed"
```

**Service Isolation**:

```bash
#!/bin/bash
# /opt/incident-response/tools/service-isolation.sh

SERVICE_NAME="$1"
INCIDENT_ID="$2"
ACTION="$3"  # stop, restart, isolate

case "$ACTION" in
    "stop")
        echo "$(date): Stopping service $SERVICE_NAME (Incident: $INCIDENT_ID)"
        sudo systemctl stop "$SERVICE_NAME"
        ;;
    "restart")
        echo "$(date): Restarting service $SERVICE_NAME (Incident: $INCIDENT_ID)"
        sudo systemctl restart "$SERVICE_NAME"
        ;;
    "isolate")
        echo "$(date): Isolating service $SERVICE_NAME (Incident: $INCIDENT_ID)"
        sudo systemctl isolate "$SERVICE_NAME"
        ;;
    *)
        echo "Usage: $0 <service-name> <incident-id> <stop|restart|isolate>"
        exit 1
        ;;
esac

# Log the action
echo "$(date): Service $SERVICE_NAME $ACTION completed (Incident: $INCIDENT_ID)" >> /var/log/security-incidents.log
```

### Evidence Preservation

**Live System Analysis**:

```bash
#!/bin/bash
# /opt/incident-response/tools/live-analysis.sh

INCIDENT_ID="$1"
EVIDENCE_DIR="/opt/incident-response/evidence/${INCIDENT_ID}/live"

mkdir -p "$EVIDENCE_DIR"
cd "$EVIDENCE_DIR"

echo "=== Live Analysis Started: $(date) ===" | tee analysis.log

# System state
echo "Capturing system state..." | tee -a analysis.log
date > timestamp.txt
w > logged_users.txt
who > current_sessions.txt
last -n 50 > recent_logins.txt

# Process analysis
echo "Analyzing processes..." | tee -a analysis.log
ps auxwwwf > process_tree.txt
pstree -p > process_tree_visual.txt
top -bn1 > system_performance.txt

# Network analysis
echo "Analyzing network..." | tee -a analysis.log
netstat -anp > network_connections_detailed.txt
ss -tulpn > socket_stats_detailed.txt
arp -a > arp_table.txt
route -n > routing_table.txt

# File system analysis
echo "Analyzing file system..." | tee -a analysis.log
find /tmp -type f -mtime -1 > recent_temp_files.txt
find /var/log -type f -mtime -1 > recent_log_files.txt
lsof | grep -E "(LISTEN|ESTABLISHED)" > network_file_handles.txt

# Docker analysis
echo "Analyzing Docker..." | tee -a analysis.log
docker system events --since 1h --until now > docker_events.txt
docker stats --no-stream > docker_resource_usage.txt

# Check for indicators of compromise
echo "Checking for IOCs..." | tee -a analysis.log
chkrootkit > chkrootkit_results.txt 2>&1
rkhunter --check --sk > rkhunter_results.txt 2>&1

echo "=== Live Analysis Completed: $(date) ===" | tee -a analysis.log
```

## Eradication and Recovery

### Malware Removal Procedures

**Container Cleaning Process**:

```bash
#!/bin/bash
# /opt/incident-response/tools/container-clean.sh

INCIDENT_ID="$1"
CONTAINER_ID="$2"

echo "=== Container Cleaning Process Started ==="
echo "Incident: $INCIDENT_ID, Container: $CONTAINER_ID"

# Stop and backup container
docker stop "$CONTAINER_ID"
docker commit "$CONTAINER_ID" "backup-${CONTAINER_ID}-$(date +%Y%m%d_%H%M%S)"

# Scan for malware
echo "Scanning container for malware..."
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
    aquasec/trivy image "$CONTAINER_ID" > "malware_scan_${CONTAINER_ID}.txt"

# Remove container
docker rm "$CONTAINER_ID"

# Rebuild from clean image
IMAGE_NAME=$(docker inspect "backup-${CONTAINER_ID}-$(date +%Y%m%d_%H%M%S)" | jq -r '.[0].Config.Image')
echo "Rebuilding container from clean image: $IMAGE_NAME"

# Pull latest image
docker pull "$IMAGE_NAME"

# Recreate container with security settings
docker run -d \
    --name "${CONTAINER_ID}_clean" \
    --security-opt no-new-privileges:true \
    --read-only \
    --tmpfs /tmp:rw,noexec,nosuid,size=100m \
    "$IMAGE_NAME"

echo "Container cleaning completed"
```

**System Cleaning Procedures**:

```bash
#!/bin/bash
# /opt/incident-response/tools/system-clean.sh

INCIDENT_ID="$1"

echo "=== System Cleaning Started: $(date) ==="

# Update all packages
echo "Updating system packages..."
sudo apt update && sudo apt upgrade -y

# Reset SSH configuration
echo "Resetting SSH configuration..."
sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup.$(date +%Y%m%d_%H%M%S)
sudo systemctl restart sshd

# Clean temporary files
echo "Cleaning temporary files..."
sudo find /tmp -type f -mtime +7 -delete
sudo find /var/tmp -type f -mtime +7 -delete

# Reset firewall rules
echo "Resetting firewall rules..."
sudo ufw --force reset
/opt/incident-response/tools/restore-firewall.sh

# Scan for rootkits
echo "Scanning for rootkits..."
sudo chkrootkit > "/opt/incident-response/evidence/${INCIDENT_ID}/post_clean_chkrootkit.txt"
sudo rkhunter --update
sudo rkhunter --check --sk > "/opt/incident-response/evidence/${INCIDENT_ID}/post_clean_rkhunter.txt"

# Verify system integrity
echo "Verifying system integrity..."
sudo debsums -s > "/opt/incident-response/evidence/${INCIDENT_ID}/integrity_check.txt"

echo "=== System Cleaning Completed: $(date) ==="
```

### Service Recovery Procedures

**Service Restoration Checklist**:

1. **Pre-Recovery Verification**:
   - [ ] Threat has been completely eradicated
   - [ ] All affected systems have been cleaned
   - [ ] Backup integrity has been verified
   - [ ] Security controls are functioning

2. **Recovery Process**:
   - [ ] Restore from clean backups
   - [ ] Apply all security patches
   - [ ] Reconfigure security settings
   - [ ] Test all functionality

3. **Post-Recovery Validation**:
   - [ ] All services are operational
   - [ ] Security monitoring is active
   - [ ] User access is restored
   - [ ] Performance is within normal ranges

**Automated Recovery Script**:

```bash
#!/bin/bash
# /opt/incident-response/tools/service-recovery.sh

INCIDENT_ID="$1"
SERVICE_TYPE="$2"  # docker, system, network

echo "=== Service Recovery Started: $(date) ==="
echo "Incident: $INCIDENT_ID, Service Type: $SERVICE_TYPE"

case "$SERVICE_TYPE" in
    "docker")
        echo "Recovering Docker services..."
        
        # Stop all containers
        docker stop $(docker ps -aq)
        
        # Remove compromised containers
        docker system prune -af
        
        # Restore from Coolify configuration
        echo "Redeploying services via Coolify..."
        # This would typically involve Coolify API calls
        
        # Verify deployment
        docker ps
        ;;
        
    "system")
        echo "Recovering system services..."
        
        # Restart essential services
        sudo systemctl restart sshd
        sudo systemctl restart ufw
        sudo systemctl restart fail2ban
        
        # Verify services
        sudo systemctl status sshd ufw fail2ban
        ;;
        
    "network")
        echo "Recovering network configuration..."
        
        # Reset firewall rules
        sudo ufw --force reset
        /opt/security/configure-firewall.sh
        
        # Restart networking
        sudo systemctl restart networking
        
        # Verify connectivity
        ping -c 3 8.8.8.8
        ;;
        
    *)
        echo "Usage: $0 <incident-id> <docker|system|network>"
        exit 1
        ;;
esac

echo "=== Service Recovery Completed: $(date) ==="
```

## Incident Investigation Procedures

### Digital Forensics Analysis

**File System Forensics**:

```bash
#!/bin/bash
# /opt/incident-response/tools/forensic-analysis.sh

INCIDENT_ID="$1"
TARGET_PATH="$2"
FORENSICS_DIR="/opt/incident-response/evidence/${INCIDENT_ID}/forensics"

mkdir -p "$FORENSICS_DIR"
cd "$FORENSICS_DIR"

echo "=== Forensic Analysis Started: $(date) ===" | tee forensics.log

# Create filesystem timeline
echo "Creating filesystem timeline..." | tee -a forensics.log
find "$TARGET_PATH" -type f -printf "%T@ %Tc %p\n" | sort -n > filesystem_timeline.txt

# Analyze recent file modifications
echo "Analyzing recent modifications..." | tee -a forensics.log
find "$TARGET_PATH" -type f -mtime -7 -ls > recent_modifications.txt

# Search for suspicious files
echo "Searching for suspicious files..." | tee -a forensics.log
find "$TARGET_PATH" -type f \( -name "*.sh" -o -name "*.py" -o -name "*.pl" \) -mtime -7 > suspicious_scripts.txt

# File carving for deleted files
echo "Attempting file recovery..." | tee -a forensics.log
sudo foremost -t all -i /dev/sda1 -o "$FORENSICS_DIR/recovered" 2>/dev/null || echo "File carving not possible"

# Hash analysis
echo "Computing file hashes..." | tee -a forensics.log
find "$TARGET_PATH" -type f -exec sha256sum {} \; > file_hashes.txt

echo "=== Forensic Analysis Completed: $(date) ===" | tee -a forensics.log
```

**Network Forensics**:

```bash
#!/bin/bash
# /opt/incident-response/tools/network-forensics.sh

INCIDENT_ID="$1"
CAPTURE_TIME="300"  # 5 minutes
FORENSICS_DIR="/opt/incident-response/evidence/${INCIDENT_ID}/network"

mkdir -p "$FORENSICS_DIR"
cd "$FORENSICS_DIR"

echo "=== Network Forensics Started: $(date) ==="

# Capture live traffic
echo "Capturing network traffic for $CAPTURE_TIME seconds..."
sudo timeout "$CAPTURE_TIME" tcpdump -i any -w live_capture.pcap &

# Analyze current connections
echo "Analyzing current connections..."
netstat -anp > current_connections.txt
ss -tupln > socket_stats.txt

# DNS analysis
echo "Analyzing DNS activity..."
sudo journalctl -u systemd-resolved --since "1 hour ago" > dns_activity.txt

# Wait for packet capture to complete
wait

# Analyze captured traffic
echo "Analyzing captured traffic..."
tcpdump -r live_capture.pcap -n > traffic_summary.txt

# Extract HTTP requests
tcpdump -r live_capture.pcap -A | grep -E "(GET|POST|HEAD)" > http_requests.txt

echo "=== Network Forensics Completed: $(date) ==="
```

### Log Analysis Procedures

**Centralized Log Analysis**:

```bash
#!/bin/bash
# /opt/incident-response/tools/log-analysis.sh

INCIDENT_ID="$1"
START_TIME="$2"  # Format: "YYYY-MM-DD HH:MM:SS"
END_TIME="$3"    # Format: "YYYY-MM-DD HH:MM:SS"
LOG_DIR="/opt/incident-response/evidence/${INCIDENT_ID}/logs"

mkdir -p "$LOG_DIR"
cd "$LOG_DIR"

echo "=== Log Analysis Started: $(date) ===" | tee analysis.log
echo "Time Range: $START_TIME to $END_TIME" | tee -a analysis.log

# System authentication logs
echo "Analyzing authentication logs..." | tee -a analysis.log
journalctl _COMM=sshd --since "$START_TIME" --until "$END_TIME" > ssh_activity.txt
grep -E "(Failed|Accepted)" /var/log/auth.log > auth_events.txt

# Docker logs
echo "Analyzing Docker logs..." | tee -a analysis.log
journalctl -u docker --since "$START_TIME" --until "$END_TIME" > docker_system.txt

for container in $(docker ps -aq); do
    container_name=$(docker inspect "$container" --format '{{.Name}}' | sed 's/\///')
    docker logs --since "$START_TIME" --until "$END_TIME" "$container" > "container_${container_name}.txt" 2>&1
done

# Web server logs (if available)
echo "Analyzing web server logs..." | tee -a analysis.log
if [ -f /var/log/traefik/access.log ]; then
    awk -v start="$START_TIME" -v end="$END_TIME" '$0 >= start && $0 <= end' /var/log/traefik/access.log > traefik_access.txt
fi

# Firewall logs
echo "Analyzing firewall logs..." | tee -a analysis.log
journalctl _COMM=ufw --since "$START_TIME" --until "$END_TIME" > firewall_activity.txt

# Generate timeline
echo "Generating event timeline..." | tee -a analysis.log
{
    echo "=== Event Timeline ==="
    echo "SSH Events:"
    grep "$(date -d "$START_TIME" '+%b %d')" ssh_activity.txt | head -20
    echo -e "\nDocker Events:"
    head -20 docker_system.txt
    echo -e "\nFirewall Events:"
    head -20 firewall_activity.txt
} > timeline_summary.txt

echo "=== Log Analysis Completed: $(date) ===" | tee -a analysis.log
```

## Communication Procedures

### Internal Communication

**Escalation Matrix**:

| Incident Severity | Initial Notification | Escalation Time | Escalation Target |
|-------------------|---------------------|-----------------|-------------------|
| Critical | Immediate | 15 minutes | C-Level executives |
| High | Within 30 minutes | 1 hour | Senior management |
| Medium | Within 2 hours | 4 hours | Department heads |
| Low | Within 8 hours | 24 hours | Team leads |

**Status Update Template**:

```
SUBJECT: [INCIDENT-${ID}] Status Update #${UPDATE_NUMBER}

CURRENT STATUS: ${STATUS}
Time Since Last Update: ${TIME_ELAPSED}

PROGRESS SINCE LAST UPDATE:
- ${PROGRESS_ITEM_1}
- ${PROGRESS_ITEM_2}

CURRENT ACTIVITIES:
- ${CURRENT_ACTIVITY_1}
- ${CURRENT_ACTIVITY_2}

NEXT PLANNED ACTIONS:
- ${NEXT_ACTION_1} (ETA: ${ETA_1})
- ${NEXT_ACTION_2} (ETA: ${ETA_2})

ESTIMATED RESOLUTION TIME: ${RESOLUTION_ETA}

IMPACT ASSESSMENT:
- Affected Systems: ${AFFECTED_SYSTEMS}
- User Impact: ${USER_IMPACT}
- Business Impact: ${BUSINESS_IMPACT}

NEXT UPDATE: ${NEXT_UPDATE_TIME}

Incident Commander: ${IC_NAME}
```

### External Communication

**Customer Notification Template**:

```
SUBJECT: Service Status Update - ${SERVICE_NAME}

Dear Valued Users,

We are currently experiencing ${ISSUE_DESCRIPTION} that may affect your ability to access ${SERVICE_NAME}.

CURRENT STATUS:
We identified the issue at ${DISCOVERY_TIME} and have immediately begun working to resolve it.

IMPACT:
${IMPACT_DESCRIPTION}

RESOLUTION PROGRESS:
${RESOLUTION_STEPS}

ESTIMATED RESOLUTION:
We expect to have this issue resolved by ${ESTIMATED_RESOLUTION}.

We sincerely apologize for any inconvenience this may cause and appreciate your patience as we work to resolve this matter.

For real-time updates, please check our status page at ${STATUS_PAGE_URL}

Thank you,
${TEAM_NAME}
```

## Post-Incident Activities

### Incident Documentation

**Incident Report Template**:

```markdown
# Incident Report: ${INCIDENT_ID}

## Executive Summary
${EXECUTIVE_SUMMARY}

## Incident Details
- **Incident ID**: ${INCIDENT_ID}
- **Classification**: ${CLASSIFICATION}
- **Severity**: ${SEVERITY}
- **Discovery Date**: ${DISCOVERY_DATE}
- **Resolution Date**: ${RESOLUTION_DATE}
- **Duration**: ${TOTAL_DURATION}
- **Incident Commander**: ${IC_NAME}

## Timeline of Events
| Time | Event | Action Taken |
|------|-------|--------------|
| ${TIME_1} | ${EVENT_1} | ${ACTION_1} |
| ${TIME_2} | ${EVENT_2} | ${ACTION_2} |

## Root Cause Analysis
### Primary Cause
${PRIMARY_CAUSE}

### Contributing Factors
- ${FACTOR_1}
- ${FACTOR_2}

### Evidence
${EVIDENCE_SUMMARY}

## Impact Assessment
### Systems Affected
- ${AFFECTED_SYSTEM_1}
- ${AFFECTED_SYSTEM_2}

### Business Impact
- **Downtime**: ${DOWNTIME_DURATION}
- **Users Affected**: ${USER_COUNT}
- **Financial Impact**: ${FINANCIAL_IMPACT}

## Response Effectiveness
### What Worked Well
- ${SUCCESS_1}
- ${SUCCESS_2}

### Areas for Improvement
- ${IMPROVEMENT_1}
- ${IMPROVEMENT_2}

## Corrective Actions
| Action | Owner | Due Date | Status |
|--------|-------|----------|--------|
| ${ACTION_1} | ${OWNER_1} | ${DATE_1} | ${STATUS_1} |
| ${ACTION_2} | ${OWNER_2} | ${DATE_2} | ${STATUS_2} |

## Lessons Learned
${LESSONS_LEARNED}

## Recommendations
1. ${RECOMMENDATION_1}
2. ${RECOMMENDATION_2}

---
Report Prepared By: ${AUTHOR}
Date: ${REPORT_DATE}
Review Status: ${REVIEW_STATUS}
```

### Post-Incident Review Process

**Review Meeting Agenda**:

1. **Incident Overview** (5 minutes)
   - Summary of what happened
   - Timeline overview
   - Impact assessment

2. **Response Analysis** (15 minutes)
   - What worked well
   - Response time analysis
   - Communication effectiveness
   - Resource utilization

3. **Root Cause Analysis** (15 minutes)
   - Technical cause analysis
   - Process breakdown review
   - Contributing factors

4. **Improvement Opportunities** (15 minutes)
   - Process improvements
   - Tool enhancements
   - Training needs
   - Policy updates

5. **Action Planning** (10 minutes)
   - Immediate actions
   - Long-term improvements
   - Ownership assignments
   - Timeline establishment

### Continuous Improvement

**Incident Metrics Tracking**:

```bash
#!/bin/bash
# /opt/incident-response/tools/metrics-report.sh

REPORT_PERIOD="$1"  # weekly, monthly, quarterly
METRICS_DIR="/opt/incident-response/metrics"
REPORT_FILE="$METRICS_DIR/incident_metrics_$(date +%Y%m%d).txt"

mkdir -p "$METRICS_DIR"

echo "=== Incident Response Metrics Report ===" > "$REPORT_FILE"
echo "Report Period: $REPORT_PERIOD" >> "$REPORT_FILE"
echo "Generated: $(date)" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

# Count incidents by severity
echo "Incidents by Severity:" >> "$REPORT_FILE"
grep -h "Severity:" /opt/incident-response/evidence/*/documentation/incident_report.md | sort | uniq -c >> "$REPORT_FILE"

# Average response time
echo -e "\nResponse Time Analysis:" >> "$REPORT_FILE"
grep -h "Response Time:" /opt/incident-response/evidence/*/documentation/incident_report.md >> "$REPORT_FILE"

# Most common incident types
echo -e "\nIncident Types:" >> "$REPORT_FILE"
grep -h "Classification:" /opt/incident-response/evidence/*/documentation/incident_report.md | sort | uniq -c >> "$REPORT_FILE"

# Recovery time statistics
echo -e "\nRecovery Time Statistics:" >> "$REPORT_FILE"
grep -h "Duration:" /opt/incident-response/evidence/*/documentation/incident_report.md >> "$REPORT_FILE"

echo "Metrics report generated: $REPORT_FILE"
```

**Process Improvement Tracking**:

```bash
#!/bin/bash
# /opt/incident-response/tools/improvement-tracker.sh

IMPROVEMENT_DB="/opt/incident-response/improvements.csv"

# Initialize database if it doesn't exist
if [ ! -f "$IMPROVEMENT_DB" ]; then
    echo "Date,Incident_ID,Improvement_Type,Description,Owner,Status,Due_Date" > "$IMPROVEMENT_DB"
fi

# Add new improvement
add_improvement() {
    local incident_id="$1"
    local type="$2"
    local description="$3"
    local owner="$4"
    local due_date="$5"
    
    echo "$(date '+%Y-%m-%d'),$incident_id,$type,\"$description\",$owner,Open,$due_date" >> "$IMPROVEMENT_DB"
    echo "Improvement added to tracking database"
}

# Update improvement status
update_status() {
    local incident_id="$1"
    local new_status="$2"
    
    # This would typically use a more sophisticated database
    sed -i "s/\($incident_id.*\),Open,/\1,$new_status,/" "$IMPROVEMENT_DB"
    echo "Status updated for incident $incident_id"
}

# Generate improvement report
generate_report() {
    echo "=== Incident Response Improvement Report ==="
    echo "Generated: $(date)"
    echo ""
    
    echo "Open Improvements:"
    grep ",Open," "$IMPROVEMENT_DB" | while IFS=, read -r date incident_id type description owner status due_date; do
        echo "- [$incident_id] $description (Owner: $owner, Due: $due_date)"
    done
    
    echo ""
    echo "Completed Improvements:"
    grep ",Completed," "$IMPROVEMENT_DB" | wc -l
}

# Command line interface
case "$1" in
    "add")
        add_improvement "$2" "$3" "$4" "$5" "$6"
        ;;
    "update")
        update_status "$2" "$3"
        ;;
    "report")
        generate_report
        ;;
    *)
        echo "Usage: $0 {add|update|report}"
        echo "  add <incident_id> <type> <description> <owner> <due_date>"
        echo "  update <incident_id> <new_status>"
        echo "  report"
        ;;
esac
```

---

## Quick Reference Checklists

### Incident Response Quick Start

**First 15 Minutes**:
- [ ] Assess immediate safety and impact
- [ ] Declare incident and assign IC
- [ ] Begin evidence collection
- [ ] Implement immediate containment
- [ ] Notify stakeholders

**First Hour**:
- [ ] Complete initial analysis
- [ ] Confirm containment effectiveness
- [ ] Begin eradication planning
- [ ] Establish communication cadence
- [ ] Document all actions

**First 4 Hours**:
- [ ] Complete threat eradication
- [ ] Begin recovery procedures
- [ ] Validate system integrity
- [ ] Restore critical services
- [ ] Prepare interim report

### Emergency Contact Information

**Technical Escalation**:
- System Administrator: ${SYSADMIN_CONTACT}
- Network Administrator: ${NETADMIN_CONTACT}
- Security Team: ${SECURITY_CONTACT}
- Vendor Support: ${VENDOR_CONTACT}

**Management Escalation**:
- Department Head: ${DEPT_HEAD_CONTACT}
- IT Manager: ${IT_MANAGER_CONTACT}
- Security Officer: ${CISO_CONTACT}
- Executive Team: ${EXEC_CONTACT}

**External Resources**:
- Law Enforcement: ${LAW_ENFORCEMENT}
- Legal Counsel: ${LEGAL_CONTACT}
- Public Relations: ${PR_CONTACT}
- Cyber Insurance: ${INSURANCE_CONTACT}

---

## References

[1] Cichonski, Paul, Tom Millar, Tim Grance, and Karen Scarfone. "Computer Security Incident Handling Guide." *NIST Special Publication 800-61 Revision 2*. August 2012. https://nvlpubs.nist.gov/nistpubs/SpecialPublications/NIST.SP.800-61r2.pdf

[2] NIST. "NIST Cybersecurity Framework 2.0." *National Institute of Standards and Technology*. February 2024. https://www.nist.gov/cyberframework

[3] NIST. "CSF 2.0 Quick Start Guides." *National Institute of Standards and Technology*. March 2025. https://www.nist.gov/cyberframework/quick-start-guides

[4] Docker, Inc. "Docker Bench for Security." *GitHub Repository*. May 28, 2025. https://github.com/docker/docker-bench-security

[5] Souppaya, Murugiah, John Morello, and Karen Scarfone. "Application Container Security Guide." *NIST Special Publication 800-190*. September 2017. https://csrc.nist.gov/pubs/sp/800/190/final

[6] fail2ban Development Team. "fail2ban." *GitHub Repository*. May 28, 2025. https://github.com/fail2ban/fail2ban

[7] OpenSSH Development Team. "OpenSSH Security Advisories." *OpenSSH Documentation*. May 28, 2025. https://www.openssh.com/security.html

[8] Center for Internet Security. "CIS Benchmarks." *CIS Security*. May 28, 2025. https://www.cisecurity.org/cis-benchmarks

---

*This document serves as a standalone reference for implementing NIST-compliant incident response procedures in any infrastructure environment.*