#!/bin/bash
# Intermediary Worker User Data Script
# This script configures the Boundary PKI worker as a systemd service.
# Assumes Boundary binary is already installed via custom AMI.
# Target OS: Ubuntu
#
# Usage (manual):   sudo ./intermediary_worker_user_data.sh <hcp_boundary_cluster_id>
# Usage (Terraform): Automatically rendered via templatefile() in user_data

# Enable verbose logging and exit on error
set -e

# Logging function
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

log "Starting Boundary intermediary worker setup..."

# Configuration
# When rendered by Terraform templatefile(), the line below contains the actual cluster ID.
# When running the raw template manually, it will be empty — pass the ID as $1 instead.
HCP_BOUNDARY_CLUSTER_ID="${hcp_boundary_cluster_id}"

# CLI argument overrides (for manual use)
if [ $# -gt 0 ] && [ -n "$1" ]; then
    HCP_BOUNDARY_CLUSTER_ID="$1"
fi

if [ -z "$HCP_BOUNDARY_CLUSTER_ID" ]; then
    log "ERROR: HCP Boundary Cluster ID is required."
    log "Usage: sudo $0 <hcp_boundary_cluster_id>"
    exit 1
fi
log "HCP Boundary Cluster ID: $HCP_BOUNDARY_CLUSTER_ID"

# -----------------------------------------------
# Step 1: Get the private IP from instance metadata (IMDSv2)
# -----------------------------------------------
log "Getting private IP from metadata..."
IMDS_TOKEN=$(curl -s --retry 5 --retry-delay 2 -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
INTERMEDIARY_WORKER_PRIVATE_IP=$(curl -s --retry 5 --retry-delay 2 -H "X-aws-ec2-metadata-token: $IMDS_TOKEN" http://169.254.169.254/latest/meta-data/local-ipv4)
log "Intermediary worker private IP: $INTERMEDIARY_WORKER_PRIVATE_IP"

# -----------------------------------------------
# Step 2: Find boundary binary
# -----------------------------------------------
log "Looking for boundary binary..."
if [ -f /usr/local/bin/boundary ]; then
    BINARY_PATH="/usr/local/bin/boundary"
elif [ -f /usr/bin/boundary ]; then
    BINARY_PATH="/usr/bin/boundary"
else
    log "ERROR: Boundary binary not found!"
    exit 1
fi
log "Boundary found at: $BINARY_PATH"

# Verify boundary is executable
if [ ! -x "$BINARY_PATH" ]; then
    log "Making boundary executable..."
    chmod +x "$BINARY_PATH"
fi

# -----------------------------------------------
# Step 3: Create boundary user and directories
# -----------------------------------------------
log "Creating boundary user and directories..."
adduser --system --group boundary || true
mkdir -p /etc/boundary.d/worker
chown -R boundary:boundary /etc/boundary.d
log "Directory /etc/boundary.d/worker ready and owned by boundary:boundary"

# -----------------------------------------------
# Step 4: Write Boundary worker configuration
# -----------------------------------------------
log "Creating worker configuration file..."
cat > /etc/boundary.d/pki-worker.hcl <<EOF
disable_mlock = true
hcp_boundary_cluster_id = "$HCP_BOUNDARY_CLUSTER_ID"

listener "tcp" {
  address = "0.0.0.0:9202"
  purpose = "proxy"
}

worker {
  public_addr = "$INTERMEDIARY_WORKER_PRIVATE_IP"
  auth_storage_path = "/etc/boundary.d/worker"
  tags {
    type = ["intermediate", "lawi"]
  }
}
EOF

chown boundary:boundary /etc/boundary.d/pki-worker.hcl
chmod 644 /etc/boundary.d/pki-worker.hcl
log "Configuration file created at /etc/boundary.d/pki-worker.hcl"

# Verify config file was created
if [ ! -f /etc/boundary.d/pki-worker.hcl ]; then
    log "ERROR: Configuration file was not created!"
    exit 1
fi

# -----------------------------------------------
# Step 5: Create systemd service file
# -----------------------------------------------
log "Creating systemd service file..."
cat > /etc/systemd/system/boundary-worker.service <<EOF
[Unit]
Description=Boundary Intermediary Worker
After=network.target

[Service]
ExecStart=$BINARY_PATH server -config /etc/boundary.d/pki-worker.hcl
User=boundary
Group=boundary
LimitMEMLOCK=infinity
Capabilities=CAP_IPC_LOCK+ep
CapabilityBoundingSet=CAP_SYSLOG CAP_IPC_LOCK
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF

log "Systemd service file created"

# -----------------------------------------------
# Step 6: Enable and start the service
# -----------------------------------------------
log "Enabling and starting Boundary worker service..."
systemctl daemon-reload
systemctl enable boundary-worker.service
systemctl start boundary-worker.service

# Wait a moment and check service status
sleep 3
if systemctl is-active --quiet boundary-worker.service; then
    log "SUCCESS: Boundary intermediary worker service is running!"
else
    log "WARNING: Boundary intermediary worker service may not be running properly"
    systemctl status boundary-worker.service || true
fi

log "================================================"
log "BOUNDARY INTERMEDIARY WORKER SETUP COMPLETE!"
log "================================================"
