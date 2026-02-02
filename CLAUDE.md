# Project Guidelines

## iPXE

**Never use pre-built iPXE images from external sources** (e.g., boot.salstar.sk, boot.ipxe.org). These images phone home to their hosting domains.

Always build iPXE locally from the `ipxe/` submodule:

```bash
cd ipxe/src
make clean bin-x86_64-efi/ipxe.efi
```

The built binary will be at `ipxe/src/bin-x86_64-efi/ipxe.efi`.

### HTTPS Certificate Validation

iPXE needs trusted root CA certificates to validate HTTPS connections. Download the Mozilla CA bundle and build with TRUST:

```bash
curl -sL https://curl.se/ca/cacert.pem -o ca-bundle.crt
make bin-x86_64-efi/ipxe.efi TRUST=ca-bundle.crt
```

Without TRUST, iPXE will fail with certificate errors (0x0216eb) when connecting to HTTPS URLs.

### Build Options

- `TRUST=<cert>` - Embed trusted root CA fingerprints for HTTPS validation
- `EMBED=<script>` - Embed an iPXE script to run at boot (optional)
