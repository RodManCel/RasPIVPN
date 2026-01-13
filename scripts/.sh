#!/bin/bash

# --- 1. ENVIRONMENT DETECTION ---
# Detect current user and home directory
CURRENT_USER=$(whoami)
USER_HOME=$(eval echo ~$CURRENT_USER)
SCRIPT_DIR="$USER_HOME/scripts"
ROUTE53_SCRIPT="$SCRIPT_DIR/update_route53.sh"

echo "------------------------------------------------"
echo "Starting VPN Environment Setup for: $CURRENT_USER"
echo "Target directory: $SCRIPT_DIR"
echo "------------------------------------------------"

# --- 2. DIRECTORY STRUCTURE ---
if [ ! -d "$SCRIPT_DIR" ]; then
    echo "[*] Creating scripts directory..."
    mkdir -p "$SCRIPT_DIR"
fi

# --- 3. CREATE ROUTE 53 UPDATE SCRIPT (English comments) ---
echo "[*] Generating Route 53 update script..."

cat << 'EOF' > "$ROUTE53_SCRIPT"
#!/bin/bash
# --- CONFIGURATION ---
# Replace these values with your AWS CloudFormation outputs
ZONE_ID="YOUR_ZONE_ID_HERE"
RECORD_NAME="vpn.yourdomain.com"
TTL=300
COMMENT="Auto-update triggered by Raspberry Pi"

# 1. Fetch current public IP using AWS utility
CURRENT_IP=$(curl -s https://checkip.amazonaws.com)

# 2. Fetch current IP registered in Route 53
REGISTERED_IP=$(aws route53 list-resource-record-sets \
  --hosted-zone-id $ZONE_ID \
  --query "ResourceRecordSets[?Name == '$RECORD_NAME.'].ResourceRecords[0].Value" \
  --output text)

# 3. Compare and update only if they differ
if [ "$CURRENT_IP" != "$REGISTERED_IP" ]; then
    echo "IP mismatch detected. Current: $CURRENT_IP | Registered: $REGISTERED_IP"
    echo "Updating Route 53 record..."
    
    TMP_JSON=$(mktemp)
    cat << EOT > $TMP_JSON
{
  "Comment": "$COMMENT",
  "Changes": [
    {
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "$RECORD_NAME.",
        "Type": "A",
        "TTL": $TTL,
        "ResourceRecords": [ { "Value": "$CURRENT_IP" } ]
      }
    }
  ]
}
EOT
    aws route53 change-resource-record-sets --hosted-zone-id $ZONE_ID --change-batch file://$TMP_JSON
    rm $TMP_JSON
    echo "Update