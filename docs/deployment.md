# TaskInspect — Deployment

How the backend reaches production, and where each piece runs.
Decisions and alternatives considered are in
[ADR-0006](decisions/0006-free-tier-providers-for-initial-deployment.md);
this document is the practical how-to.

## Cloud services

| Piece | Service | Notes |
|-------|---------|-------|
| Database | [Neon](https://neon.tech) (PostgreSQL) | Project `taskinspect`, region `ap-southeast-1`. Direct endpoint, not the pooled one - the backend already pools its own connections (HikariCP); Neon's PgBouncer pooler is for many short-lived serverless connections and can conflict with Flyway's advisory locks. |
| Evidence storage | [Cloudflare R2](https://developers.cloudflare.com/r2/) (S3-compatible) | Bucket `taskinspect-evidence`. Standard storage class (the free tier only applies there). Reached through the same `S3_ENDPOINT`-configurable `filestorage` module AWS S3 was designed for (ADR-0005) - swapping providers is a config change, not a code change. |
| Backend hosting | [Google Cloud Run](https://cloud.google.com/run) | Service `backend`, project `taskinspect`, region `asia-southeast1`. Runs the existing `backend/Dockerfile` (task 8.8) unchanged. |
| Push notifications | [Firebase Cloud Messaging](https://firebase.google.com/docs/cloud-messaging) | Project `taskinspect`. The backend authenticates as Cloud Run's own attached service account (see below) - no credentials file in production. |
| Image registry | Google [Artifact Registry](https://cloud.google.com/artifact-registry) | Repository `backend`, same project/region as Cloud Run. |

AWS (S3, RDS, EC2/ECS, CloudWatch) is the designed migration target if
this ever needs to move - see ADR-0006 for why free-tier providers were
chosen instead, and what moving back would involve.

## Environment variables in production

Set directly as Cloud Run environment variables (`gcloud run deploy
--env-vars-file=...` or the Cloud Run console), never committed to the
repository. Same variable names as `.env.example`, with production
values:

- `SPRING_PROFILES_ACTIVE=prod`
- `DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USERNAME`, `DB_PASSWORD` - from
  Neon's connection string; `DB_SSLMODE=require` (Neon requires SSL;
  local Docker Postgres does not, hence the setting instead of a
  hardcoded value)
- `STORAGE_TYPE=s3`, `S3_BUCKET`, `S3_REGION=auto`, `S3_ENDPOINT`,
  `S3_PATH_STYLE=true`, `S3_ACCESS_KEY`, `S3_SECRET_KEY` - from the R2
  API token (`S3_REGION=auto` is R2's region placeholder, not a real
  AWS region; `S3_PATH_STYLE=true` because R2's generic account
  endpoint needs the bucket name in the URL path)
- `PUSH_TYPE=fcm` - **no `GOOGLE_APPLICATION_CREDENTIALS` is set in
  production.** `FirebaseConfig` falls back to
  `GoogleCredentials.getApplicationDefault()`, which on Cloud Run
  resolves to the service's own attached identity automatically. That
  identity needs the `roles/firebasecloudmessaging.admin` IAM role
  granted once (an IAM change, done outside the app/CI - see below).
- `JWT_SECRET`, `ADMIN_EMAIL`, `ADMIN_PASSWORD`, `ADMIN_FULL_NAME` -
  generated fresh for production, never the local-dev values from
  `.env`. `ADMIN_PASSWORD` can be removed from the running service
  after the first start, same as local dev.

## Deploying

### Manually (what the first deploy used)

```bash
gcloud config set project taskinspect
gcloud config set run/region asia-southeast1
gcloud auth configure-docker asia-southeast1-docker.pkg.dev
docker build -t asia-southeast1-docker.pkg.dev/taskinspect/backend/api:latest backend
docker push asia-southeast1-docker.pkg.dev/taskinspect/backend/api:latest
gcloud run deploy backend \
  --image=asia-southeast1-docker.pkg.dev/taskinspect/backend/api:latest \
  --region=asia-southeast1 --allow-unauthenticated --port=8080 \
  --min-instances=0 --max-instances=3 --memory=512Mi \
  --env-vars-file=<path to a local, uncommitted YAML file of the variables above>
```

### From CI (tasks 10.4/10.6)

`.github/workflows/backend.yml`'s `deploy` job does the same build,
push and `gcloud run deploy` on every push to `main`, using the
repository secret `GCP_SA_KEY` (a service account key with Artifact
Registry Writer, Cloud Run Admin, and Service Account User on the
runtime service account). It skips cleanly - the rest of the workflow
still passes - until that secret is added. Environment variables stay
set on the Cloud Run service itself, never in the workflow file, so a
code deploy from CI never touches them.

## One-time IAM setup (not in CI, not in the app)

Two IAM changes happen outside both the app and CI, done directly with
an account that has the right permissions:

1. **Push notifications**: grant the Cloud Run service's own identity
   permission to send FCM messages.
   ```bash
   gcloud projects add-iam-policy-binding taskinspect \
     --member="serviceAccount:<project-number>-compute@developer.gserviceaccount.com" \
     --role="roles/firebasecloudmessaging.admin"
   ```
2. **CI deploys**: create a service account for `GCP_SA_KEY` (Artifact
   Registry Writer + Cloud Run Admin + Service Account User), generate
   a key, add it as the `GCP_SA_KEY` repository secret.

## Verifying a deployment

```bash
curl https://<service-url>/actuator/health
```

Expect `{"groups":["liveness","readiness"],"status":"UP"}`. The very
first request(s) after a cold start can briefly show
`readiness: OUT_OF_SERVICE` - a timing race between the "Started"
log line and the readiness indicator updating, not a real failure;
it settles within a few seconds and every request after that is `UP`.

## Logs and monitoring

Cloud Run's own logs (`gcloud run services logs read backend
--region=asia-southeast1`) cover this for now. Task 8.11 (an AWS
CloudWatch equivalent) is deferred per ADR-0006 - revisit once there
is either real traffic or a move to AWS.
