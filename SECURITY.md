# Security Policy

## The model (important)

This project copies operator-planted files from a device's **world-readable FAT
firmware partition** into a root-only `/run` file at boot. A secret on that
partition is **exposed to anyone with physical access to the card**. Use it for
*appliance* secrets (tunnel tokens, Wi-Fi PSKs) where the alternative is a bricked
headless device — not as a general secrets manager. For git-encrypted or
multi-machine secrets, use `sops-nix` / `agenix`.

## Reporting a vulnerability

Please open a **private** security advisory via GitHub
("Security" → "Report a vulnerability"), or contact the maintainer directly.
Do not file public issues for undisclosed vulnerabilities.
