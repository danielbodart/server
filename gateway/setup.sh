#!/usr/bin/env bash
# Deploys gateway configuration files from this repo to OpenWRT
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GATEWAY="${GATEWAY:-gateway}"

echo "Setting up PXE boot on OpenWRT gateway..."

# Create directories on gateway
ssh "$GATEWAY" "mkdir -p /srv/tftp /www/flatcar /usr/local/bin"

# Download iPXE bootloaders (if not present)
ssh "$GATEWAY" /bin/sh << 'REMOTE_SCRIPT'
cd /srv/tftp
[ -f ipxe.efi ] || wget -q http://boot.salstar.sk/ipxe/ipxe.efi
[ -f undionly.kpxe ] || wget -q http://boot.salstar.sk/ipxe/undionly.kpxe
echo "iPXE bootloaders ready"
REMOTE_SCRIPT

# Deploy config files from this repo
echo "Deploying config files..."
scp "$SCRIPT_DIR/flatcar.ipxe" "$GATEWAY:/srv/tftp/flatcar.ipxe"
scp "$SCRIPT_DIR/update-flatcar-images" "$GATEWAY:/usr/local/bin/update-flatcar-images"
ssh "$GATEWAY" "chmod +x /usr/local/bin/update-flatcar-images"

# Configure dnsmasq PXE boot via /etc/dnsmasq.conf (persistent across reboots)
# OpenWRT includes this file via conf-file directive
echo "Configuring PXE boot in dnsmasq..."
ssh "$GATEWAY" /bin/sh << 'REMOTE_SCRIPT'
# Check if PXE config already exists
if grep -q "PXE boot configuration" /etc/dnsmasq.conf 2>/dev/null; then
    echo "PXE config already in /etc/dnsmasq.conf"
else
    cat >> /etc/dnsmasq.conf << 'EOF'

# PXE boot configuration for Flatcar Linux
# Restricted to new-server by MAC address

# Tag new-server by MAC address (only this machine will PXE boot Flatcar)
dhcp-host=70:85:c2:a2:e5:75,set:flatcar-server

# Detect iPXE clients
dhcp-match=set:ipxe,175

# UEFI 64-bit - serve ipxe.efi first (only to flatcar-server)
dhcp-match=set:efi64,option:client-arch,7
dhcp-boot=tag:flatcar-server,tag:efi64,tag:!ipxe,ipxe.efi
dhcp-match=set:efi64-alt,option:client-arch,9
dhcp-boot=tag:flatcar-server,tag:efi64-alt,tag:!ipxe,ipxe.efi

# iPXE clients with flatcar-server tag get the Flatcar boot script
dhcp-boot=tag:flatcar-server,tag:ipxe,flatcar.ipxe

# BIOS fallback (only to flatcar-server)
dhcp-match=set:bios,option:client-arch,0
dhcp-boot=tag:flatcar-server,tag:bios,tag:!ipxe,undionly.kpxe
EOF
    echo "PXE config added to /etc/dnsmasq.conf"
fi
REMOTE_SCRIPT

# Enable TFTP via UCI
ssh "$GATEWAY" /bin/sh << 'REMOTE_SCRIPT'
uci set dhcp.@dnsmasq[0].enable_tftp='1'
uci set dhcp.@dnsmasq[0].tftp_root='/srv/tftp'
uci commit dhcp
/etc/init.d/dnsmasq restart
echo "dnsmasq configured and restarted"
REMOTE_SCRIPT

# Add weekly cron job (if not present)
ssh "$GATEWAY" /bin/sh << 'REMOTE_SCRIPT'
CRON_LINE="0 3 * * 0 /usr/local/bin/update-flatcar-images >> /var/log/flatcar-update.log 2>&1"
if ! grep -q "update-flatcar-images" /etc/crontabs/root 2>/dev/null; then
    echo "$CRON_LINE" >> /etc/crontabs/root
    /etc/init.d/cron restart
    echo "Weekly cron job added (Sunday 3am)"
else
    echo "Cron job already exists"
fi
REMOTE_SCRIPT

# Run initial download of Flatcar images
echo ""
echo "Downloading Flatcar images (~420MB, this may take a while)..."
ssh "$GATEWAY" "/usr/local/bin/update-flatcar-images"

echo ""
echo "PXE setup complete!"
echo ""
echo "Files on gateway:"
ssh "$GATEWAY" "ls -lh /srv/tftp/ /www/flatcar/"
echo ""
echo "To manually update: ssh gateway /usr/local/bin/update-flatcar-images"
echo "To redeploy configs: ./gateway/setup.sh"
