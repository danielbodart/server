# Project Guidelines

## iPXE

**Never use pre-built iPXE images from external sources** (e.g., boot.salstar.sk, boot.ipxe.org). These images phone home to their hosting domains.

Always build iPXE locally from the `ipxe/` submodule:

```bash
cd ipxe/src
make clean bin-x86_64-efi/ipxe.efi
```

The built binary will be at `ipxe/src/bin-x86_64-efi/ipxe.efi`.

To build with an embedded script (optional):
```bash
make bin-x86_64-efi/ipxe.efi EMBED=/path/to/script.ipxe
```
