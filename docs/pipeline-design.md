# Pipeline design notes

Longer form reasoning behind the choices in `.github/workflows/devsecops.yml`.

## Why stage order matters

The stages are ordered by *cost of a late catch*, not by how fast they run.

A leaked secret found in production costs a credential rotation, an audit entry,
and possibly a breach notification. A MEDIUM-severity dependency CVE found in
production costs a ticket. So secrets scanning goes first and blocks; dependency
scanning goes later and blocks selectively.

Stages 1–4 run in parallel because none of them depend on a build artifact. This
keeps total wall-clock time close to the slowest single stage rather than the sum.
Developers tolerate a five-minute pipeline. At fifteen minutes they start batching
commits, and batched commits make every failure harder to bisect.

## The gating philosophy

A security gate has exactly one job: stop bad artifacts from shipping. It fails
that job in two directions.

**Too loose** and vulnerable code ships. Obvious.

**Too tight** and something worse happens: the pipeline gets bypassed. Someone adds
a `continue-on-error`, or a blanket suppression file, or an admin merge. The gate
still shows green on the dashboard while enforcing nothing. This failure mode is
more common than the first one and much harder to detect, because everything looks
fine.

So the gate blocks on three things only:

- **Secrets** — unfixable after the fact, zero false-positive tolerance justified
- **Fixable HIGH/CRITICAL dependency CVEs** — actionable, bounded volume
- **Image scan failures** — last checkpoint before an artifact leaves the runner

SAST, IaC, and DAST report without blocking. They produce findings that need human
triage, and a stage that requires judgement should not have the power to block a
release at 6pm on a Friday.

## `ignore-unfixed` is not a shortcut

Blocking on a CVE with no upstream patch gives the developer three options: pin to
a vulnerable older version, suppress the finding, or bypass the pipeline. All three
are worse than shipping with a tracked, unfixable CVE.

The correct handling for unfixable CVEs is inventory and monitoring — know you have
it, get alerted when a patch lands — not a build gate. That belongs in a
vulnerability management process, not in CI.

## What is missing, and why

This repo demonstrates the pipeline. A production version would add:

- **Signed images and provenance** (cosign, SLSA attestation) so the deploy stage
  can verify the artifact came from this pipeline and not a developer laptop
- **A baselined Checkov policy** with the existing findings accepted and new ones
  gated
- **Runtime scanning** — image scanning catches CVEs known at build time; a base
  image goes stale the day after it is built
- **Secrets management integration** (AWS Secrets Manager, External Secrets
  Operator) so no credential exists in a manifest to be scanned in the first place
- **Policy as code** at admission (OPA Gatekeeper or Kyverno) — CI gating only
  covers what goes through CI, and cluster admission covers everything

The last point is the important one. A CI gate is a control on one path. Anything
applied directly to a cluster bypasses it entirely, which is why cluster-side
admission policy matters more than pipeline gating once a platform has more than
one team deploying to it.
