# Project Guidelines

## iPXE

**Never use pre-built iPXE images from external sources** (e.g., boot.salstar.sk, boot.ipxe.org). These images phone home to their hosting domains.

Always build iPXE locally from the `ipxe/` submodule:

```bash
./build-ipxe
```

The built binary will be at `ipxe/src/bin-x86_64-efi/ipxe.efi`.

### HTTPS Certificate Validation

iPXE needs trusted root CA certificates to validate HTTPS connections. Without them, you get error `0x0216eb` (no usable certificates).

**Important**: iPXE's `TRUST=` option only reads the FIRST certificate from each file. You cannot pass a CA bundle directly - you must extract individual root CA certificates.

The `build-ipxe` script handles this automatically by:
1. Downloading the Mozilla CA bundle
2. Extracting the specific root CAs needed:
   - **ISRG Root X1** - Let's Encrypt (Flatcar CDN)
   - **USERTrust RSA** - Sectigo (GitHub Pages, GitHub)
   - **Amazon Root CA 1** - Amazon (netboot.xyz)
3. Building iPXE with `TRUST=cert1.pem,cert2.pem,cert3.pem`

### Manual Build

If you need to build manually or add more root CAs:

```bash
cd ipxe/src

# Extract a root CA from the bundle (awk extracts from header to END CERTIFICATE)
awk '/ISRG Root X1/,/END CERTIFICATE/' ca-bundle.crt > certs/isrg.pem

# Build with comma-separated cert files
make bin-x86_64-efi/ipxe.efi TRUST=certs/isrg.pem,certs/other.pem
```

### Build Options

- `TRUST=<cert1>,<cert2>,...` - Embed trusted root CA fingerprints for HTTPS validation
- `EMBED=<script>` - Embed an iPXE script to run at boot (optional)
