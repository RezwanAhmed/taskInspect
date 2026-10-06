# ADR-0006: Free-Tier Providers for Initial Deployment

- **Status:** Accepted
- **Date:** 2026-10-05

## Context

Phase 8 originally planned AWS for all three pieces of cloud
infrastructure: S3 (evidence storage, ADR-0005), RDS (PostgreSQL,
ADR-0002) and EC2/ECS (where the backend runs), plus CloudWatch for
logs. AWS has no permanent free tier for a solo project at this stage,
and some AWS free-tier allowances are time-limited or credit-based
rather than always free.

The project owner wants to:
1. Get the backend actually running in the cloud at no cost while the
   project is still a personal/portfolio project with no real traffic.
2. Keep the option to move to AWS later without rewriting anything,
   since AWS experience (IAM, VPC, CloudWatch, the breadth of its
   service catalog) has real value for job interviews and is a
   separate goal from "ship the project."
3. Learn AWS specifically through separate, dedicated practice, not
   necessarily by running TaskInspect's production infrastructure on
   it from day one.

## Decision

Deploy on **free-tier, S3/Postgres/Docker-compatible providers**
instead of AWS, keeping every integration point an environment
variable so the move to AWS later is a configuration change, not a
code change.

- **Evidence storage (replaces task 8.1):** **Cloudflare R2** instead
  of AWS S3. R2 exposes an S3-compatible API; the backend's
  `filestorage` module (ADR-0005) already supports a configurable
  `S3_ENDPOINT` for exactly this kind of substitution, so no backend
  code changes. Free tier: 10 GB storage, no egress fees.
- **Database (replaces task 8.9):** **Neon** instead of AWS RDS. Neon
  is standard PostgreSQL reachable over the normal Postgres wire
  protocol; Flyway migrations and `ddl-auto=validate` (ADR-0002) work
  unchanged. Free tier: a serverless Postgres project with no
  time-limited expiry.
- **Backend hosting (replaces task 8.10):** **Google Cloud Run**
  instead of AWS EC2/ECS. Cloud Run runs the existing Dockerfile
  (task 8.8) as-is; no AWS-specific deployment config is introduced in
  its place. Free tier: a generous monthly request quota, pay-per-use
  beyond it.
- **Logging/monitoring (task 8.11):** deferred. Cloud Run's built-in
  logs cover basic needs for now; revisit if/when either real traffic
  arrives or the project moves to AWS.
- **AWS literacy** (IAM, VPC, CloudWatch, certifications) is pursued
  separately, outside this project's deployment, so it does not block
  shipping.

## Alternatives Considered

| Option | Pros | Cons |
|--------|------|------|
| **AWS (S3 + RDS + EC2/ECS)** (original plan) | One account for everything; the most recognized cloud platform; IAM/VPC experience has interview value. | No permanent free tier for this project's stage; real cost risk if forgotten; account/billing setup overhead before any task can start. |
| **Cloudflare R2 + Neon + Google Cloud Run** (chosen) | Free at this project's scale; S3-compatible / standard Postgres / standard Docker, so no code changes and an easy later move to AWS; three well-established, maintained platforms. | Three dashboards instead of one; CloudWatch-equivalent monitoring deferred; still need to learn AWS specifically through separate practice for interview purposes. |
| **Ubicloud** (open source, cheaper-than-AWS compute + Postgres) | Open source, can self-host; cited 3-10x cost savings over AWS for compute/Postgres. | No free tier for the managed service; no S3-compatible storage offering; self-hosting shifts the "where do I run a server" question rather than answering it. |
| **Excloud** (Mumbai-based, S3-compatible, pay-as-you-go) | Very low pay-as-you-go pricing; S3-compatible storage; good latency for South/Southeast Asia. | No free tier — pays from the first byte; smaller/newer provider, less track record than AWS or the chosen providers. |
| **Self-hosted (own VPS/hardware)** | Full control; potentially free if hardware is already owned. | Backend/DB/storage all become the project owner's operational responsibility (patching, backups, uptime); no managed-service experience gained either. |

## Consequences

- `STORAGE_TYPE`, `S3_ENDPOINT`, `S3_BUCKET`, the S3 credentials, and
  `DATABASE_URL` are the only settings that change between this setup
  and a future AWS deployment. No application code is AWS-specific
  today, so none needs to change later either.
- Migrating to AWS later is: copy R2 objects to S3 (same API), dump
  and restore the Neon database into RDS (same Postgres), and run the
  existing Docker image on EC2/ECS/App Runner instead of Cloud Run.
- Task 8.11 (CloudWatch) has no direct equivalent in this setup; it is
  deferred rather than replaced, and will most likely only matter once
  either real production traffic or an actual AWS migration happens.
- Tasks 8.1, 8.9 and 8.10 in `PROGRESS.md` are implemented against
  these providers; their AWS equivalents are not done and would need
  to be picked up again if/when the project migrates.
