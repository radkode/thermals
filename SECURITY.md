# Security

## Report a vulnerability privately

Use [GitHub private vulnerability reporting](https://github.com/radkode/thermals/security/advisories/new). Include the affected version, macOS version, reproduction steps and impact. Do not include signing keys, access tokens or unrelated personal data.

Do not report vulnerabilities in public issues or pull requests. If the private reporting form is unavailable, do not post exploit details publicly. There is no alternate email reporting channel.

## Supported versions

Security fixes target the latest released version. Upgrade older installations through Homebrew or the signed in-app updater. There is no guaranteed response time or separate long-term-support release line.

## Trust boundaries

Thermals reads local system and process information using public and private macOS interfaces. It is not sandboxed and does not require a privileged helper. A missing sensor is reported as unavailable. A reading is not a hardware safety guarantee.

Official updates use the existing Homebrew tap feed, signed appcasts and signed archives. Debug builds do not check for updates. Forks must configure their own identity and update channel before distributing Release builds; see [CONTRIBUTING.md](./CONTRIBUTING.md).

Ordinary contribution checks use read-only permissions and no release secrets. Only the maintainer release workflow uses the `release` environment. Its current trust boundary is described in [the release guide](./docs/releasing.md).
