#!/usr/bin/env bash
# Deploys gateway configuration files from this repo to OpenWRT
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GATEWAY="${GATEWAY:-gateway}"

echo "Setting up PXE boot on OpenWRT gateway..."

# Create directories on gateway
ssh "$GATEWAY" "mkdir -p /srv/tftp"

# Download iPXE bootloaders (if not present)
ssh "$GATEWAY" /bin/sh << 'REMOTE_SCRIPT'
cd /srv/tftp
[ -f ipxe.efi ] || wget -q http://boot.salstar.sk/ipxe/ipxe.efi
[ -f undionly.kpxe ] || wget -q http://boot.salstar.sk/ipxe/undionly.kpxe
echo "iPXE bootloaders ready"
REMOTE_SCRIPT

# Deploy iPXE boot script
echo "Deploying iPXE boot script..."
scp "$SCRIPT_DIR/flatcar.ipxe" "$GATEWAY:/srv/tftp/flatcar.ipxe"

# Configure dnsmasq PXE boot via /etc/dnsmasq.conf (persistent across reboots)
echo "Configuring PXE boot in dnsmasq..."
ssh "$GATEWAY" /bin/sh << 'REMOTE_SCRIPT'
# Check if PXE config already exists
if grep -q "PXE boot configuration" /etc/dnsmasq.conf 2>/dev/null; then
    echo "PXE config already in /etc/dnsmasq.conf"
else
    cat >> /etc/dnsmasq.conf << 'EOF'

# PXE boot configuration (any machine can network boot)

# Detect iPXE clients
dhcp-match=set:ipxe,175

# UEFI 64-bit - serve ipxe.efi first, then boot script once iPXE loads
dhcp-match=set:efi64,option:client-arch,7
dhcp-boot=tag:efi64,tag:!ipxe,ipxe.efi
dhcp-match=set:efi64-alt,option:client-arch,9
dhcp-boot=tag:efi64-alt,tag:!ipxe,ipxe.efi

# iPXE clients get the boot menu
dhcp-boot=tag:ipxe,flatcar.ipxe

# BIOS fallback
dhcp-match=set:bios,option:client-arch,0
dhcp-boot=tag:bios,tag:!ipxe,undionly.kpxe
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

echo ""
echo "PXE setup complete!"
echo ""
echo "Files on gateway:"
ssh "$GATEWAY" "ls -lh /srv/tftp/"
echo ""
echo "iPXE will boot directly from Flatcar CDN and GitHub Pages."
echo "To redeploy: ./gateway/setup.sh"
