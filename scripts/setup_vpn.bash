#!/bin/bash

# --- CONFIGURATION PARAMETERS ---
# Change these values before running the script
MY_DOMAIN="vpn.tudominio.es"
MY_ZONE_ID="Z0123456789ABC"
MY_LOCAL_IP="192.168.1.50"      # Change this to your RPi's actual local IP
MY_ROUTER_GW="192.168.1.1"      # Your router's local IP

# --- ENVIRONMENT DETECTION ---
CURRENT_USER=$(whoami)
USER_HOME=$(eval echo ~$CURRENT_USER)
SCRIPT_DIR="$USER_HOME/scripts"
ROUTE53_SCRIPT="$SCRIPT_DIR/update_route53.sh"

echo "------------------------------------------------"
echo "Starting VPN Environment Setup for: $CURRENT_USER"
echo "Target Domain: $MY_DOMAIN"
echo "------------------------------------------------"

# --- 1. DIRECTORY STRUCTURE ---
if [ ! -d "$SCRIPT_DIR" ]; then
    echo "[*] Creating scripts directory..."
    mkdir -p "$SCRIPT_DIR"
fi

# --- 2. CREATE ROUTE 53 UPDATE SCRIPT ---
echo "[*] Generating Route 53 update script..."

cat << EOF > "$ROUTE53_SCRIPT"
#!/bin/bash
# --- CONFIGURATION ---
ZONE_ID="$MY_ZONE_ID"
RECORD_NAME="$MY_DOMAIN"
TTL=300
COMMENT="Auto-update triggered by Raspberry Pi"

# 1. Fetch current public IP
CURRENT_IP=\$(curl -s https://checkip.amazonaws.com)

# 2. Fetch current IP registered in Route 53
REGISTERED_IP=\$(aws route53 list-resource-record-sets \\
  --hosted-zone-id \$ZONE_ID \\
  --query "ResourceRecordSets[?Name == '\$RECORD_NAME.'].ResourceRecords[0].Value" \\
  --output text)

# 3. Compare and update only if they differ
if [ "\$CURRENT_IP" != "\$REGISTERED_IP" ]; then
    echo "IP mismatch detected. Current: \$CURRENT_IP | Registered: \$REGISTERED_IP"
    echo "Updating Route 53 record..."
    
    TMP_JSON=\$(mktemp)
    cat << EOT > \$TMP_JSON
{
  "Comment": "\$COMMENT",
  "Changes": [
    {
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "\$RECORD_NAME.",
        "Type": "A",
        "TTL": \$TTL,
        "ResourceRecords": [ { "Value": "\$CURRENT_IP" } ]
      }
    }
  ]
}
EOT
    aws route53 change-resource-record-sets --hosted-zone-id \$ZONE_ID --change-batch file://\$TMP_JSON
    rm \$TMP_JSON
    echo "Update request submitted to AWS."
else
    echo "IP is up to date (\$CURRENT_IP). No action required."
fi
EOF

# --- 3. PERMISSIONS & CRON ---
echo "[*] Setting permissions and Cron job..."
chmod +x "$ROUTE53_SCRIPT"
(crontab -l 2>/dev/null | grep -v "update_route53.sh"; echo "*/5 * * * * $ROUTE53_SCRIPT > /dev/null 2>&1") | crontab -

# --- 4. PIVPN UNATTENDED CONFIGURATION ---
echo "[*] Preparing PiVPN unattended installation profile..."

PIVPN_CONF="/tmp/pivpn_install.conf"
cat << EOF > "$PIVPN_CONF"
IPv4dev=eth0
install_user=$CURRENT_USER
VPN=wireguard
WireguardPort=51820
IPv4addr=$MY_LOCAL_IP/24
IPv4gw=$MY_ROUTER_GW
USE_PREDEFINED_DNS_SERVER=Cloudflare
pivpnDNS1=$MY_DOMAIN
EOF

# --- 5. EXECUTION ---
echo "[!] Starting PiVPN Installation..."
curl -L https://install.pivpn.io | bash /dev/stdin --unattended "$PIVPN_CONF"

echo "------------------------------------------------"
echo "SETUP FINISHED!"
echo "1. Run 'aws configure' to set your IAM keys."
echo "2. Your VPN endpoint is set to: $MY_DOMAIN"
echo "------------------------------------------------"