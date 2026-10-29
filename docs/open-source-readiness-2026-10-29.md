# Open-source readiness, 2026-10-29

The assessment below records the original baseline. See the [implementation checkpoint](#implementation-checkpoint) for subsequent owner decisions and preparation work.

## Decision

Thermals is a plausible small open-source project, but it is not ready for an immediate public contributor launch. The required work is licensing, distribution notices, a deliberate disclosure decision and contributor infrastructure. This assessment found no reason to rewrite the app or wait for every product improvement.

The minimum publication gate is an owner-selected project license, complete dependency notices, and approval of the information exposed by making the existing repository public. Before inviting contributions, also establish a credential-free development path, automatic checks and a public contribution/security policy. Release hardening is a separate decision because the owner previously accepted automatic releases from `main`.

Canonical investigation: [#72](https://github.com/radkode/thermals/issues/72). The owner requested investigation, not a visibility change, license adoption, release, credential change or history rewrite. None of those actions was performed.

## Scope and evidence

- Source baseline: local `main` at `277fdd5de85107892ac8b53a64f3549b3c609d60`, 93 tracked files, including 15 test files. GitHub `main` was `73796d20f30f9ede8bc0d36a9bdafa89b2f7da45`, two commits behind the local checkout.
- History: all 88 commits reachable through local refs. All 11 remote branch/tag tips were present locally; the remote main was an ancestor of the inspected local commit. Historical filenames contained no credential-like `.env`, `.p8`, `.p12`, `.pem` or `.key` files.
- GitHub: repository metadata, main protection, rulesets, Actions permissions, release environment and branch policy, community profile, 71 issues, 36 issue comments, all 18 available Actions runs and their logs. These counts precede this audit's follow-up filings. No Actions artifacts were listed.
- Dependencies: `project.yml`, the resolved Sparkle 2.10.0 package and artifact license, both Barlow OFL files, the local Debug bundle and installed Thermals 0.4.4 build 10 bundle.
- The owner confirmed no known copied code or assets beyond Sparkle and Barlow. Git history attributes all 88 commits to one maintainer. These observations support provenance but do not independently prove ownership of every line or asset.
- Pre-existing `.playwright-cli/` and `ThermalsTests/RenderingPerformanceTests.swift` were excluded. Another task began changing `Thermals/Board/Board.swift` during the audit; that work is outside this assessment.

This is a publication and contributor-readiness investigation, not a UI audit, complete application-security review or hardware certification. No fresh build/test was run: the shared host had a one-minute load average of 14.93, and this task changes documentation only. Fresh-account Debug build/launch, current-revision test success, the minimum build Xcode version, cross-chip/macOS coverage, upstream vulnerability status and Vercel deployment permissions remain unverified.

## Findings and priority

| Priority | Finding | Required outcome | Tracking |
|---|---|---|---|
| Before calling the project open source | No project license. GitHub reports `license: null`; OFL only licenses the fonts. | Select the intended reuse terms and copyright holder; add root license and README link. | [#73](https://github.com/radkode/thermals/issues/73) |
| Before publication / next distribution | No Sparkle notice found in the source or inspected app bundles. | Preserve all applicable Sparkle/bundled-component notices in source and binary distributions. | [#74](https://github.com/radkode/thermals/issues/74) |
| Before changing visibility | Internal release inventory and personal/history metadata would become public. | Approve the disclosure scope and resolve genuinely private material across all public surfaces. | [#75](https://github.com/radkode/thermals/issues/75) |
| Before inviting contributions | No automatic tests for source-only pushes or PRs. | Secret-free native checks for ordinary changes and the selected contribution path. | [#65](https://github.com/radkode/thermals/issues/65) |
| Before inviting contributions | Development instructions assume maintainer context; outside-contributor policy is unspecified. | Document a clean Debug build/test path, tested tools, support boundaries and how outsiders propose changes. | [#76](https://github.com/radkode/thermals/issues/76) |
| Before inviting contributions | No tracked security policy; scanning disabled; broad Actions defaults. | Establish private vulnerability reporting, verified scanning and least-privilege defaults. | [#77](https://github.com/radkode/thermals/issues/77) |
| Before advertising local Release packaging | `--dry-run` still requires the official Sparkle private key; ad-hoc Release launch already has a reported failure. | Separate credential-free packaging from production signing, then verify launch independently. | [#78](https://github.com/radkode/thermals/issues/78), [#61](https://github.com/radkode/thermals/issues/61) |
| Revisit for public operation | Any authorized main writer can alter the job that receives release secrets. | Explicitly retain the accepted trust boundary or adopt a protected release approval boundary. | [#9](https://github.com/radkode/thermals/issues/9) |

### Licensing and provenance

Making a repository public does not itself grant the general reuse rights expected of open-source software. GitHub distinguishes public visibility from an open-source license. [GitHub licensing guidance](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/licensing-a-repository)

MIT is the simplest candidate if the owner wants permissive reuse, including commercial and closed-source derivatives, with attribution requirements. It is a recommendation for that intent, not a selected license. If retaining openness of derivatives matters, choose the licensing policy before drafting the file. Confirm the correct copyright holder rather than assuming the GitHub organization owns the work. [MIT terms](https://choosealicense.com/licenses/mit/)

The dependency footprint is small:

- Sparkle is the only declared package, pinned exactly to 2.10.0. Its package supplies a checksummed binary artifact. Its `LICENSE` contains Sparkle's MIT terms and additional bundled-component notices, so copying only a generic MIT template would be incomplete. The inspected installed and Debug bundles contain `Contents/Resources/OFL.txt`, but no Sparkle license/notice file was found. The release script zips the app bundle. Include the applicable full notices as a resource and verify the resulting archive. [Sparkle 2.10.0 license](https://github.com/sparkle-project/Sparkle/blob/2.10.0/LICENSE)
- Barlow's OFL is committed in both `Thermals/Fonts/` and `site/fonts/`, and is present in the installed app. Keep those terms separate from the new project license, including for the converted WOFF2 files.
- Sensor code uses private Apple interfaces through runtime symbol resolution. That creates compatibility and support obligations; it is not evidence that the code was copied or that the repository cannot be open source. The implementation's provenance is not inferred from other apps using the same APIs.

No architecture change, new dependency manager or blanket file-header rewrite is needed for this work.

### Exposure and secret scanning

Gitleaks 8.30.1 was downloaded from its official GitHub release. The Darwin ARM64 archive matched the GitHub asset digest:

```text
b40ab0ae55c505963e365f271a8d3846efbc170aa17f2607f13df610a9aeb6a5
```

The history scan used the default rules, `--log-opts='--all --full-history'`, `--ignore-gitleaks-allow` and full redaction. It scanned 88 commits and approximately 806.70 KB of changes. Exit status was 1 because it reported one `generic-api-key` match: `project.yml:33` in commit `ec9c4aa067a2947d2a525ebd669fd1405340698f`. Manual inspection identified `SUPublicEDKey`, identical to the current intentionally public update-verification key. This is a false positive; neither removal nor rotation is warranted for that finding.

Separate stdin scans of issue/comment JSON and the extracted text from every available Actions log all returned 0 with no findings, covering 1,400,495 bytes in aggregate. Log archives were processed in memory; retained scanner reports redact matches. This means **no confirmed secrets were found in the inspected material**, not that the repository is certified secret-free. Scanner rules do not establish whether prose is commercially or personally sensitive.

The pre-publication release guide contained internal operational details, which were removed from the publication history. Other documents link private tooling and describe the repository remaining private. Git author metadata includes a personal email address. The only `/Users/` path found in current tracked text is a synthetic `/Users/me/...` test fixture.

GitHub makes Actions history and logs visible when a repository becomes public. Review history and discussions as well as current files; deleting a sentence from HEAD does not erase it from older commits. Preserve the existing history unless the disclosure review identifies a reason to change it. If an actual credential is later found, rotate it before publication; merely deleting its text is insufficient. No deletion, rewrite or rotation was performed. [GitHub visibility consequences](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/managing-repository-settings/setting-repository-visibility)

### CI and release authority

Observed settings on 2026-10-29:

| Control | Observed state |
|---|---|
| Visibility | Private |
| Main branch protection | Disabled; no required checks |
| Repository rulesets | Empty |
| Release environment | Exact `main` branch deployment policy; no required reviewer; admin bypass allowed |
| Actions policy | All actions allowed; full SHA pinning required |
| Default workflow token | Write; workflow PR approval enabled |
| Secret scanning / push protection | Disabled |
| Code security / Dependabot security updates | Disabled |

The current workflow is more restrictive than the repository defaults: `contents: read` globally, `contents: write` only for release, SHA-pinned checkout, checksum-verified XcodeGen, environment-scoped secrets and cleanup. It has no `pull_request` or `pull_request_target` trigger. **The current configuration does not give arbitrary fork contributions access to release secrets merely because visibility changes.**

Nevertheless, `.github/workflows/release.yml` runs automatically only for `main` pushes touching `project.yml`. The release script builds Release but does not run the test suite. Tests run only in the manual preflight when the version is already tagged. A green release is therefore not proof of passing tests. The latest listed run passed at release commit `a77914a`, not the inspected current main. Existing #65 captures the missing source-push checks; public contributions add a need for fork-safe checks without signing secrets or publishing privileges.

The owner previously accepted automatic publication from `main` in #9. Preserve that decision unless explicitly changed. Public repositories make environment required reviewers available on plans where private repositories lack them, so publication provides a new option worth considering. One practical alternative is automatic tests and builds, followed by a deliberate gate before signing/publishing. No policy was changed here. [GitHub environment availability](https://docs.github.com/en/actions/how-tos/deploy/configure-and-manage-deployments/manage-environments)

The fork-approval endpoint rejected the read because the repository is private; the private vulnerability-reporting endpoint returned 404. Neither establishes the future public configuration. Verify those controls after an authorized visibility transition. Also review the Git-connected website deployment boundary before enabling outside preview deployments.

### Contributor and fork experience

The repository already has useful foundations: a small Swift app, a generated Xcode project with `project.yml` as the source, one exactly pinned package, pure sensor-selection logic, 15 tracked test files, detailed reading semantics and explicit unsupported hardware. It does not require a backend or a JavaScript application build system. No JavaScript package lockfile is present; that is consistent with the static site, not evidence of a broken install.

The missing piece is a short public entry point. The README starts with source building, while the user-facing Homebrew installation command is in the release guide. Document installation, a verified Debug build/test path, tested Xcode/XcodeGen versions, optional website-check tooling, supported hardware and how to report a problem. State whether external PRs are welcome or changes are proposed through issues. The maintainer's direct-main/no-PR rule need not dictate what outside contributors can submit. GitHub's community profile confirms missing license, contributing guide and templates; a code of conduct or templates are optional, not license prerequisites.

Debug updater initialization is disabled by `#if !DEBUG`, and project signing is ad hoc. That supports a credential-free Debug route by configuration, but this audit did not prove it on a fresh account. Known ad-hoc Release launch failures remain in #61. In addition, `scripts/release.sh --dry-run` still calls `sign_update` using `SPARKLE_ED_PRIVATE_KEY` or the maintainer's Keychain account, then verifies against the official public key. It cannot complete on a clean machine with no such key. Document or change that path without weakening production signatures.

A Release fork inherits `com.radkode.thermals`, the official update feed and its verification key. Fork documentation should explain how to choose a separate identity/update channel or disable update checks. Do not share production credentials or casually migrate the existing feed: shipped apps already depend on the tap's appcast and public key. Keeping releases in the current tap is compatible with opening the source repository.

Public support notes should explain local peak/episode/session persistence, recorded process names where applicable, user-initiated clipboard export, and Sparkle's update-network behavior. Hardware compatibility limits and private API changes warrant clear expectations, not a promise to support all Macs. The existing incorrect `ios` product-platform metadata is already tracked in [#15](https://github.com/radkode/thermals/issues/15); it does not require a duplicate task.

## Suggested preparation sequence

1. Owner selects license/copyright holder and approves the intended disclosure scope. Add project license and complete dependency notices.
2. Prepare public README, contributor and security instructions. Prove the Debug path on a clean account; resolve or clearly separate the Release dry-run limitations.
3. Add automatic secret-free checks and set appropriate public security defaults. Revisit #9 while preserving the chosen release authority until a new decision is explicit.
4. Re-scan the exact final refs and public surfaces. Confirm remaining local work is accounted for, then obtain explicit authorization for the visibility change. Verify public rendering, fork/reporting settings and access afterward.

Performance optimization, Intel support, a new release-hosting arrangement, extensive governance, a CLA and a full product backlog cleanup are not prerequisites demonstrated by this investigation. Dependency-update monitoring should cover the real XcodeGen manifest and pinned tools rather than assuming Dependabot will manage them automatically.

## Reproduction and handoff

Private local evidence lives in `build/open-source-readiness/`, which is ignored and mode 0700. It contains the brief, GitHub readbacks and their exit/stderr files, redacted scanner results, input hashes, issue filing receipts and this task's handoff. It must not be committed wholesale. The durable findings and decisions are this report and the linked issues.

With a verified Gitleaks executable, the relevant history command is:

```sh
gitleaks git --log-opts='--all --full-history' --ignore-gitleaks-allow \
  --redact=100 --no-banner --no-color --report-format=json \
  --report-path=build/open-source-readiness/history-scan.json .
```

Inspect scanner exit status and classify each match; do not silently suppress the public-key match or describe exit 1 as a clean scanner run. Re-query GitHub counts and pagination before reusing the public-surface results. The current evidence does not cover future commits/comments, deleted logs, unreferenced local objects, inaccessible content, or release archives beyond the inspected installed/local bundles. An unavailable organization `.github` repository returned 404; the repository community profile was used to verify the effective missing files instead.

The required generic Workflow tool was not exposed in this host. Direct inspection was used; this limitation is already tracked in [ai-toolkit #9](https://github.com/jacekradko/ai-toolkit/issues/9). The investigation did not delegate agent work.

## Implementation checkpoint

The owner requested readiness work in an isolated worktree and selected MIT licensing, acceptance of outside pull requests, and GitHub-only private vulnerability reporting. Publication must wait for that reporting channel. Work started from `f00bf01` in `.worktrees/open-source-readiness` on `jacek/open-source-readiness`; the original checkout's concurrent performance work is excluded. The maintainer's automatic-main release boundary remains unchanged.

Prepared in this branch:

- #73: MIT license, copyright Jacek Radko, with public README links.
- #74: complete Sparkle 2.10.0 notices plus the project license bundled as resources. `check-licenses.sh` verifies project, Sparkle and Barlow notices byte-for-byte against their source files. The built Debug bundle passes.
- #75: current release documentation uses a generic credential inventory and no longer states that the source must stay private. The previous operational inventory is preserved in the ignored, private `build/open-source-readiness/private-release-runbook-before.md`. Git history, old issues/comments and the earlier audit remain unchanged; historical disclosure is still an owner decision before publication.
- #76: contributor build/test, fork identity, installation, local-data privacy and outside-PR instructions, with explicit ad-hoc Release limitations. Debug was built and launched by the native test host from this clean worktree, but not from a fresh macOS account.
- #65/#77: native test and credential-free packaging workflow for affected pushes/PRs; pinned/checksummed Gitleaks on all pushes/PRs; read-only tokens and no release secrets. Release signing now depends on passing secret-free preflight tests and license checks, without adding manual approval. The exact historical public-key false positive is isolated in `.gitleaksignore`; a generated fake-token negative check still fails. Dependabot covers Actions references; Sparkle/XcodeGen/Gitleaks update responsibilities are explicit in CONTRIBUTING.md.
- #78: the dry run exits after archive/cask packaging, before any appcast/signature generation. Three control-flow tests prove success without credentials, rejection of missing notices, and independence from an incomplete production-key environment. Production signature verification is retained.

Live GitHub changes were read back: default workflow permissions are now `read`, workflow approval of PR reviews is disabled, dependency alerts are enabled and automated security fixes report enabled/not paused. No branch rules, release environment approval controls, visibility or release version changed. Attempting to enable private vulnerability reporting returned HTTP 404 while the repository is private. GitHub documents the feature for public repositories, so an owner-approved transition sequence is still needed; this work does not silently relax the owner's reporting gate. Native secret scanning/push protection must also be verified at that transition; paid private Secret Protection was not enabled.

Verification so far: XcodeGen 2.46.0 generation, Debug build/resource comparison, Actionlint 1.7.12, shell syntax checks, three dry-run isolation tests and reachable-history scanning passed. The first full native run executed 158 tests and failed five assertions in one existing popover integration test. The isolated three-test shortcut suite subsequently passed without code changes. The original failure is retained in [#79](https://github.com/radkode/thermals/issues/79); an empty method-selector run is excluded from evidence. No assertions were weakened or tests skipped. Hosted CI and a real release dry-run package remain to be verified on this branch.

The CI failure investigation loaded Impeccable's native guidance. Its existing unsupported macOS metadata issue (#15) still applies; no app UI was edited. A sidecar freshness warning based on the clean worktree's file times did not establish a new visual defect and was not used to expand scope.
