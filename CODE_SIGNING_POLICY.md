# Code signing policy

ZerkiWatch is free and open source (MIT). Its release files (`ZerkiWatch.exe`, `ZerkiWatch-Setup.exe`, `ZerkiWatch-windows.zip`) are built by the public GitHub Actions workflow [`build-exe`](.github/workflows/build-exe.yml) from the source in this repository, and carry a signed build-provenance attestation:

    gh attestation verify ZerkiWatch-Setup.exe --repo zerkino/ZerkiWatch

Authenticode signing of the executables is being set up through the SignPath Foundation (free for open source projects). Until it is announced here, the executables are **not** Authenticode-signed.

## Roles

- **Authors / committers:** [zerkino](https://github.com/zerkino) (maintainer).
- **Reviewers:** pull requests from other contributors are reviewed by the maintainer before merge.
- **Approvers:** the maintainer approves every signing request manually.

All accounts with these roles use multi-factor authentication.

## Rules

- Only binaries built by the public workflow from this repository's source are signed (own binaries only). No third-party binary is signed.
- The project contains no proprietary component and no dual licensing.
- Signing keys are never stored in this repository.
- `ZerkiWatch.bat`, the program itself, is a readable script: it is not an executable and is not signed. Its SHA-256 is listed in `SHA256.txt` with each release.

## Privacy

ZerkiWatch has no telemetry and sends no personal data anywhere. Its only network use is:

- connectivity tests: a plain TCP connection to well-known public addresses (and a ping of your router) to tell whether the Internet is reachable;
- an optional update check against `api.github.com`, off by default;
- an optional iPhone remote that listens on your local network only, protected by a PIN.
