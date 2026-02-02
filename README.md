# Server

Flatcar Linux server with automatic updates, plus network boot menu for OS installers.

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           On Push to Master                             │
│  GitHub Actions: Build flatcar-config.bu → config.ign → GitHub Pages   │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    v
┌─────────────────┐         ┌─────────────────────────────┐
│  GitHub Pages   │         │       OpenWRT Gateway       │
│  config.ign     │         │ TFTP: ipxe.efi, flatcar.ipxe│
└────────┬────────┘         └──────────────┬──────────────┘
         │                                 │
         │                                 │ PXE boot (any machine)
         v                                 v
┌─────────────────────────────────────────────────────────┐
│                    Network Boot Menu                    │
│  - Flatcar Linux (install to disk)                     │
│  - NixOS Minimal                                        │
│  - netboot.xyz (Ubuntu, Debian, Arch, Fedora, etc.)   │
└─────────────────────────────────────────────────────────┘
```

## Network Boot Menu

Any machine on the network can PXE boot and get a menu with:

| Option | Description |
|--------|-------------|
| Flatcar Linux | Boot live Flatcar, then install to disk |
| NixOS Minimal | NixOS with CLI installer |
| netboot.xyz | Menu with many other distros (Ubuntu, Debian, Arch, Fedora, etc.) |
| iPXE Shell | For debugging |

## How It Works

1. **One-time PXE boot** into live Flatcar to run installer
2. **Install to disk** with Ignition config from GitHub Pages
3. **Flatcar auto-updates** via Zincati (reboots Sundays 3-4am)
4. **Docker containers** run from `/data/servers/`

## Initial Server Setup

1. Configure server BIOS for one-time network boot
2. Server PXE boots, select "Flatcar Linux" from menu
3. From the live system, install to disk:
   ```bash
   flatcar-install -d /dev/nvme0n1 -C stable -i https://danielbodart.github.io/server/config.ign
   ```
4. Reboot into installed system

## Files

| File | Purpose |
|------|---------|
| `flatcar-config.bu` | Butane config (human-readable Ignition) |
| `.github/workflows/deploy.yml` | Builds config.ign, deploys to Pages, deploys containers |
| `gateway/setup.sh` | One-time gateway setup script |
| `gateway/flatcar.ipxe` | iPXE boot menu script |
| `run` | Local script to deploy containers |

## Gateway Files

```
/srv/tftp/
├── ipxe.efi              # UEFI bootloader
├── undionly.kpxe         # BIOS bootloader
└── flatcar.ipxe          # Boot menu (Flatcar, NixOS, netboot.xyz)
```

## Server Layout

```
/                         # Flatcar root (A/B partitions, auto-updated)
/data                     # /dev/sda1 - persistent storage
/data/bin/docker-compose  # Persisted docker-compose binary
/data/servers/            # Container data and configs
```

## Common Tasks

### Deploy container changes
```bash
./run update
```

### SSH to server
```bash
ssh core@server.bodar.com -p 222
```

### Redeploy gateway config
```bash
./gateway/setup.sh
```

### Check Zincati update status
```bash
ssh new-server "systemctl status zincati"
ssh new-server "journalctl -u zincati -f"
```

## Config Changes

1. Edit `flatcar-config.bu`
2. Push to master
3. GitHub Actions builds and deploys to Pages
4. For new installs, config is fetched automatically
5. For existing installs, re-run Ignition or reinstall

## Secrets

- `SERVER_SSH_KEY` - GitHub Actions secret for SSH deployment (private key for `github-actions@server`)
