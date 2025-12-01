# Keycloak on EKS modernization plan (demo deployment only)

This plan focuses solely on getting a current Keycloak version running on EKS for a demo. It keeps scope, cost, and complexity low while using repeatable Terraform + Helm steps that can be promoted later if needed.

## Stage 0: Baseline hygiene for the demo
- Record current versions for EKS, AWS Load Balancer Controller, and Keycloak.
- Ensure Terraform state has a remote backend and CI can run `terraform plan`/`apply` for reproducibility.
- Capture a basic smoke test: Keycloak pod ready, `/health/ready` reachable, and admin login works. Use `./demo-smoke.sh` with
  `DEMO_URL` set to the demo hostname to validate the running deployment.

## Stage 1: Minimal platform currency
- Bump the EKS cluster to the latest version supported by the Keycloak Helm chart and AWS Load Balancer Controller (tracked as `cluster_version = "1.30"` for the demo) with one small managed node group sized for the demo.
- Install or upgrade only the AWS Load Balancer Controller (no extra CSI add-ons yet) and pin the controller Helm chart version in Terraform so demo deployments stay deterministic even if annotations change (demo pins: `alb_controller_chart_version = "1.8.0"`, `alb_controller_image_tag = "v1.8.2"`). Ensure the Helm release also upgrades the controller CRDs (TargetGroupBinding, IngressClass parameters, BackendProtocolVersion) by enabling the service mutator hook and using the v1.8 IAM policy (`AWSLoadBalancerControllerIAMPolicy.json`) with an IRSA-annotated service account. **Keep the IRSA service account name aligned with the Helm value (`serviceAccount.name = "aws-load-balancer-controller"`) so the v1.8 policy matches the controller identity.**
- Verify core add-ons (VPC CNI, CoreDNS, KubeProxy) are healthy after the version bump.

## Stage 2: Demo-friendly secrets and configuration (no CSI)
- Replace plaintext credentials in `terraform.tfvars` with temporary SSM/Secrets Manager parameters referenced by Terraform variables, but avoid CSI mounts for the demo.
- Provide a single demo variable file with small instance sizes and minimal toggles (e.g., replicas = 1, no autoscaling).
- Keep the demo database minimal: single-AZ, small instance class (e.g., `db.t3.micro`) sized only for basic Keycloak use (no load testing).
- Surface secrets to Keycloak via Kubernetes Secrets managed by Terraform, not CSI:
  - **Demo default (Option A):** Terraform creates a `keycloak` namespace plus `kubernetes_secret` objects `keycloak-admin-credentials` (keys: `username`, `password`) and `keycloak-db-credentials` (keys: `username`, `password`, `database`). Helm values should reference these names directly.
  - Option B: Terraform creates the Secret, and Helm values point to the pre-created secret name (`existingSecret`).
- Ensure Terraform-managed Secrets are created before the Helm release runs so Keycloak pulls credentials from the right source.

**Current plaintext secret footprint to clean up (demo scope)**
- Legacy Kubernetes manifest `terraform/manifest/keycloak.yml` (now replaced by the Helm release) embedded admin and database credentials (`KEYCLOAK_ADMIN_PASSWORD`, `DB_USERNAME`, `DB_PASSWORD`) and a manual DB endpoint placeholder.
- Terraform variables and defaults (`terraform/variables.tf`, `terraform/terraform.tfvars`) carry database and Keycloak admin passwords in plain text, along with manual certificate and domain placeholders.

## Stage 3: Keycloak deployment refresh for demo
- Replace static manifests with the Keycloak Helm chart managed by Terraform `helm_release` (do not use the Keycloak Operator for the demo). The demo pins the Bitnami chart (`keycloak_chart_version`) and Keycloak image tag (`keycloak_image_tag`) and sources admin/DB credentials from Terraform-managed Kubernetes Secrets.
- Use a single demo values file (`terraform/values/keycloak-demo.yaml`) tuned for the demo: one replica, small CPU/memory requests, public ingress, and the `start` command (not `start-dev`). Include minimal routing values so ALB → Keycloak works consistently:
  - `proxy: edge`
  - `hostname: <demo-domain>`
  - `hostname-strict: true`
  - `hostname-strict-https: true`
  - enable health endpoints
- Pin the Keycloak image tag in Helm values (avoid `latest`) to keep demo pulls deterministic.
- Template the DB endpoint and credentials from Terraform outputs/parameters into chart values, pulling the credentials from the Kubernetes Secret created in Stage 2 (no CSI mounts). Ensure the Helm release depends on the secret/namespace creation.
- Define basic readiness/liveness probes and enable metrics/health endpoints needed for the smoke test.

## Stage 4: Lightweight ingress and TLS
- Configure Ingress annotations using the AWS Load Balancer Controller v1.8 schema (avoid legacy blog-era annotations) for a public ALB with an ACM certificate. Minimum demo-friendly annotations:
  - `alb.ingress.kubernetes.io/scheme: internet-facing`
  - `alb.ingress.kubernetes.io/target-type: ip`
  - `alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}, {"HTTPS": 443}]'`
  - `alb.ingress.kubernetes.io/certificate-arn: <arn>`
  - `alb.ingress.kubernetes.io/ssl-redirect: '443'`
  - `alb.ingress.kubernetes.io/group.name: keycloak-demo`
  - `alb.ingress.kubernetes.io/ssl-policy: ELBSecurityPolicy-TLS13-1-2-2021-06`
  - `alb.ingress.kubernetes.io/load-balancer-attributes: access_logs.s3.enabled=true,access_logs.s3.bucket=<bucket>,access_logs.s3.prefix=<prefix>`
- Enforce HTTPS-only via redirect and ensure the ALB target group health checks align with Keycloak probes.
- Validate with `kubectl get ingress` and a curl against the hosted URL for the demo realm.

## Execution pattern for each stage
1. Create a branch and run `terraform plan` and Helm `--dry-run` for the stage changes.
2. Apply to the demo environment; capture `kubectl` and ALB validation evidence plus the smoke test results.
3. Iterate until the smoke test passes; tag the state with the deployed versions and values.

This keeps the modernization narrowly focused on a functional, low-cost demo deployment of the latest Keycloak on EKS while cleaning up plaintext secrets and ensuring basic TLS ingress.
