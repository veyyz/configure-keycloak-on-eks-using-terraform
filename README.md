# configure-keycloak-on-eks-using-terraform
This repository contains Terraform code to provision AWS infrastructure deploy Keycloak to Elastic Kubernetes Service (EKS).

## Version pins for the demo stack
- Terraform 1.14.x with the AWS provider v5
- terraform-aws-modules/eks v20.x on Kubernetes 1.30
- terraform-aws-modules/vpc v5.x
- RDS Postgres (single instance) for faster demo provisioning
- Helm charts pinned for repeatability: AWS Load Balancer Controller 1.10.0 (controller v2.10.0), external-dns 1.14.4, cert-manager 1.14.4, Keycloak 26.x

### To setup and preview resources with Terraform
Run Command
```shell
make plan
```

### To deploy the AWS Services with Terraform
Run command
```shell
make apply

```
### To update kube-config
Run command
```shell
make update-kube-config
```

### To deploy Keycloak to EKS
Run command
```shell
make deploy-keycloak
```

### To delete all resource with Terraform
Run command
```shell
make destroy
```