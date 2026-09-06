# DevSecOps Pipeline

![DevSecOps Pipeline](https://github.com/Nagarajchalla/devsecops-pipeline/actions/workflows/devsecops.yml/badge.svg)

A working shift-left security pipeline built on GitHub Actions. Every stage runs on
push, every finding lands in the GitHub Security tab as SARIF, and the deploy gate
blocks on the failures that actually matter.

Built to demonstrate how I approach pipeline security: what to scan, where in the
pipeline to scan it, and — the part most pipelines get wrong — what to gate on.

## Pipeline stages

| # | Stage | Tool | Gates the build? |
|---|-------|------|------------------|
| 1 | Secrets scanning | Gitleaks | Yes — hard fail |
| 2 | SAST | Semgrep | No — reports to Security tab |
| 3 | SCA (dependencies) | Trivy | Yes — HIGH/CRITICAL, fixable only |
| 4 | IaC scanning | Checkov | No — report-only |
| 5 | Container image scan | Trivy | Yes — HIGH/CRITICAL |
| 6 | DAST | OWASP ZAP baseline | No — warns |
| 7 | Security gate | — | Blocks deploy on 1, 3, 5 |

Stages 1–4 run in parallel. Build waits on 1–3, DAST waits on the build.

## Design decisions

**Secrets scanning runs first and fails hard.** Every other finding can be triaged
next sprint. A committed credential is already public the moment it is pushed, and
rotating it is the only fix. Gitleaks runs with `fetch-depth: 0` because secrets
hide in commit history, not just the current tree.

**SCA gates on HIGH/CRITICAL with `ignore-unfixed`.** Two deliberate choices. Gating
on MEDIUM produces so much noise that developers start reaching for `--no-verify`,
and a pipeline everyone bypasses provides no security at all. Blocking on CVEs with
no available patch is worse than useless — there is no action the developer can take,
so the only possible outcome is a suppression.

**The image is scanned before it reaches a registry.** Once a vulnerable image is
pushed, something will eventually pull it. Scanning at build time means the bad
artifact never exists anywhere but the runner.

**IaC scanning is report-only here, but would gate in production.** Checkov on a
real Terraform repo needs a tuned baseline first, otherwise the first run fails on
200 pre-existing findings and the team disables it. The path is: report-only →
baseline the existing findings → gate on new ones.

**DAST runs against the real built image, not a staging URL.** The container that
gets attacked is byte-identical to the one the gate approves. ZAP findings are
filtered through `security/zap-rules.tsv`, where every `IGNORE` carries a written
reason — blanket suppression is how a DAST stage quietly stops being useful.

**Everything uploads SARIF.** Findings belong in the GitHub Security tab where they
can be tracked, assigned, and dismissed with a reason — not buried in job logs that
nobody reads after the build goes green.

## Repository layout

```
.github/workflows/devsecops.yml   The pipeline
app/                              Small Flask service - the scan target
  Dockerfile                      Non-root, slim base, healthcheck
infra/main.tf                     Terraform module for Checkov to scan
security/
  .gitleaks.toml                  Secret detection rules + allowlist
  zap-rules.tsv                   DAST alert filter, each IGNORE justified
  sonar-project.properties        Optional SonarCloud config
docs/pipeline-design.md           Longer write-up of the trade-offs
```

## Running it

Fork the repo and push. Everything runs with the default `GITHUB_TOKEN` — no
secrets, no external accounts, no paid tiers.

To swap Semgrep for SonarCloud, add `SONAR_TOKEN` as a repository secret and
enable the Sonar job. To add Snyk, add `SNYK_TOKEN`.

Run the app locally:

```bash
cd app
docker build -t devsecops-demo .
docker run -p 8080:8080 devsecops-demo
curl localhost:8080/health
```

## Notes

The application is deliberately trivial. The subject of this repository is the
pipeline, not the service it protects.

The Terraform module is written from scratch for this repo. It contains no account
IDs, ARNs, or configuration from any employer.

## Author

Nagaraj Challa — DevOps & Cloud Security Engineer
[LinkedIn](https://linkedin.com/in/nagaraj-challa)
