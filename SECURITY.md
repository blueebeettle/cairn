# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 1.x     | :white_check_mark: |

## Reporting a Vulnerability

We take the security of Cairn seriously. If you discover a security vulnerability (such as a flaw in encryption, data leak, or authentication handling), please report it responsibly.

### How to Report
- **Email:** Please send an email to `dalwadipriyesh@gmail.com` with the subject `[Security Vulnerability] Cairn`.
- Include detailed steps to reproduce the issue, along with proof of concept if applicable.
- **Do not open a public GitHub issue** for undisclosed security vulnerabilities.

### Scope & Expectations
Cairn uses client-side encryption (**AES-256-GCM** with PBKDF2 key derivation):
- User backup files should never be decryptable without the user's passphrase.
- Local SQLite database files remain on-device only.
- Row Level Security (RLS) policies on remote storage buckets restrict access strictly to authenticated owners.

We will review reports promptly and work on a fix before public disclosure.
