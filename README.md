# Athul MJ — DevOps Engineer

DevOps Engineer with **2.1 years** of hands-on experience building CI/CD pipelines, automating cloud infrastructure on AWS, and running production workloads for multi-tenant business platforms and industrial monitoring systems.

This repository is a working portfolio. Each file is a cleaned-up, self-contained example of patterns I use day to day. Production secrets, hostnames and client details have been removed or replaced with placeholders.

---

## Tech Stack

| Area | Tools |
|---|---|
| Cloud | AWS (EC2, S3, IAM, VPC, Security Groups) |
| CI/CD | GitHub Actions (multi-environment pipelines, approvals, matrix deploys) |
| Containers | Docker, Docker Compose |
| Infrastructure as Code | Terraform |
| Configuration Management | Ansible |
| Operating Systems | Linux (Ubuntu / Amazon Linux) |
| Databases | SQL Server |
| Web Servers / Proxies | Apache, Nginx |

---

## Projects I Have Worked On

### NORA ERP — Multi-School Platform
ERP platform that serves several schools from one shared codebase.
- Built and maintained CI/CD pipelines that deploy the .NET API through DEV, UAT and Production
- Ran the deployment model that serves several school tenants, with one environment configuration per tenant

### WMR & TWise — Oil & Gas Monitoring
Monitoring applications for oil and gas operations.
- Managed deployments and server environments for the monitoring services
- Kept Linux hosts and services stable and observable

### L&T Proximity — Driver Safety
Driver safety application.
- Automated build and release workflows
- Supported environment provisioning and production rollouts

### Billix — Billing Platform
Billing application.
- Set up containerised builds and automated deployments
- Managed SQL Server database environments

### AlTasnimBI — BI Platform
Business intelligence platform.
- Handled infrastructure and deployment pipelines for the BI application stack
- Configured the web servers and reverse proxies (Apache / Nginx)

---

## Repository Contents

```
.
├── .github/workflows/deploy.yml   # Multi-environment CI/CD pipeline
├── terraform/main.tf              # AWS infrastructure as code
├── docker-compose.yml             # Multi-service local/production stack
├── docs/architecture.md           # Infrastructure overview
└── README.md
```

### What Each File Demonstrates

**`.github/workflows/deploy.yml` — CI/CD pipeline for a .NET API**
- Build, test and publish stages with artifact handoff between jobs
- **DEV**: deploys automatically on every push to the development branch
- **UAT**: needs manual approval through a GitHub Environment protection rule
- **Production**: matrix deployment to several servers or tenants in parallel
- Secrets come from GitHub Environments, never from the repository

**`terraform/main.tf` — AWS infrastructure**
- EC2 instance provisioned with user data
- S3 bucket with versioning, encryption and public access blocked
- Security groups with least-privilege ingress rules
- IAM role and instance profile that give EC2 scoped access to S3
- Input variables and outputs, so the module can be reused across environments

**`docker-compose.yml` — Multi-service application**
- Nginx reverse proxy in front of the application
- Application service built from a Dockerfile
- Database service with a persistent volume
- Health checks, startup ordering and isolated networks

**`docs/architecture.md` — Infrastructure overview**
- How code moves from commit to production
- Environment layout (DEV / UAT / PROD) and network design
- Security, secrets handling and rollback approach

---

## Contact

- **Email:** athulmj8696@gmail.com
- **LinkedIn:** _add link_
- **GitHub:** _add link_
