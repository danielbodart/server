# Server

Diskless Flatcar Linux server booting via PXE from local OpenWRT gateway.

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           On Push to Master                             │
│  GitHub Actions: Build flatcar-config.bu → config.ign → GitHub Pages   │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    v
┌─────────────────┐         ┌─────────────────────────────┐         ┌─────────────────┐
│  GitHub Pages   │         │       OpenWRT Gateway       │         │     Server      │
│  config.ign     │         │ TFTP: ipxe.efi              │         │                 │
└────────┬────────┘         │ HTTP (cached locally):      │ <─PXE─> │ Diskless boot   │
         │                  │   - kernel + initrd (420MB) │         │ /data on sda1   │
         │  cron weekly     │   - config.ign              │         │                 │
         └─────────────────>│ Cron: pulls from CDN+Pages  │         └─────────────────┘
                            └─────────────────────────────┘
                                      ^
┌─────────────────┐                   │ cron weekly
│   Flatcar CDN   │───────────────────┘
│ kernel + initrd │
└─────────────────┘
```

## How It Works

1. **Server PXE boots** from gateway (no local OS install)
2. **Gateway serves** iPXE bootloader → Flatcar kernel/initrd → config.ign
3. **Flatcar runs from RAM**, mounts `/dev/sda1` to `/data` for persistent storage
4. **Docker containers** run from `/data/servers/`

### Boot Flow

1. Server UEFI requests PXE boot
2. Gateway dnsmasq serves `ipxe.efi` via TFTP
3. iPXE loads `flatcar.ipxe` script
4. Script fetches kernel + initrd + config.ign from gateway HTTP
5. Flatcar boots, applies Ignition config
6. Mounts `/data`, starts Docker

### Updates

- **OS updates**: Gateway cron pulls new Flatcar images weekly (Sunday 3am)
- **Config updates**: Push to master → GitHub Actions builds config.ign → Gateway cron pulls it
- **Apply updates**: Reboot server

## Files

| File | Purpose |
|------|---------|
| `flatcar-config.bu` | Butane config (human-readable Ignition) |
| `.github/workflows/deploy.yml` | Builds config.ign, deploys to Pages, deploys containers |
| `gateway/setup.sh` | One-time gateway setup script |
| `gateway/flatcar.ipxe` | iPXE boot script |
| `gateway/update-flatcar-images` | Weekly update script on gateway |
| `run` | Local script to deploy containers |

## Gateway Files

```
/srv/tftp/
├── ipxe.efi              # UEFI bootloader
├── undionly.kpxe         # BIOS bootloader
└── flatcar.ipxe          # Boot script

/www/flatcar/
├── vmlinuz               # Flatcar kernel (~59MB)
├── initrd.cpio.gz        # Flatcar initrd (~359MB)
└── config.ign            # Ignition config

/usr/local/bin/
└── update-flatcar-images # Weekly update script
```

## Server Layout

```
/                         # tmpfs (RAM) - ephemeral
/data                     # /dev/sda1 - persistent
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

### Manual gateway update
```bash
ssh gateway /usr/local/bin/update-flatcar-images
```

### Redeploy gateway config
```bash
./gateway/setup.sh
```

### Check gateway status
```bash
ssh gateway "ls -lh /srv/tftp/ /www/flatcar/"
```

## Config Changes

1. Edit `flatcar-config.bu`
2. Push to master
3. Wait for GitHub Actions (or manually: `ssh gateway /usr/local/bin/update-flatcar-images`)
4. Reboot server to apply

## Adding Another Server

Add MAC address to gateway's `/etc/dnsmasq.conf`:
```
dhcp-host=<MAC>,set:flatcar-server
```
Then restart dnsmasq: `/etc/init.d/dnsmasq restart`

## Secrets

- `SERVER_SSH_KEY` - GitHub Actions secret for SSH deployment (private key for `github-actions@server`)
