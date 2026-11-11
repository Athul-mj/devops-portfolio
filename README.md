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
├── .github/
│   ├── workflows/deploy.yml        # Multi-environment CI/CD pipeline (.NET API)
│   └── actions/ssh-deploy/         # Reusable deploy step: release switch + health check + rollback
├── terraform/
│   ├── main.tf                     # AWS EC2 + S3 + Security Groups + IAM
│   └── env/dev.tfvars.example
├── ansible/
│   ├── site.yml                    # Server hardening, runtime setup, release deployment
│   ├── group_vars/all.yml
│   ├── templates/                  # systemd unit + Nginx site
│   └── inventory.example.ini
├── docker-compose.yml              # Nginx → .NET API → SQL Server
├── nginx/conf.d/default.conf       # Reverse proxy config for Compose
└── docs/architecture.md            # Infrastructure overview and diagrams
```

### What Each File Demonstrates

**`.github/workflows/deploy.yml`: CI/CD pipeline for a .NET API**
- Build, test (with coverage) and publish once, then deploy that **same artifact** to every environment
- **DEV**: deploys automatically on every push to `develop`
- **UAT**: needs manual approval through a GitHub Environment protection rule
- **Production**: **matrix deployment** to several tenant servers (`max-parallel`, `fail-fast: false`)
- Per-environment secrets, a concurrency guard, and path filters so only app changes trigger a deploy
- A reusable composite action does an **atomic symlink release switch**, a health check and an **automatic rollback**

**`terraform/main.tf`: AWS infrastructure**
- EC2 (Ubuntu 24.04) with an Elastic IP, **IMDSv2 enforced** and an encrypted gp3 root volume
- S3 bucket: private, versioned, encrypted, TLS-only policy, lifecycle expiry of old versions
- Security group: public 80/443, SSH only from admin CIDRs (input validation rejects `0.0.0.0/0`)
- IAM role scoped to its own bucket, plus SSM Session Manager access
- Validated input variables, default tags, outputs (including an Ansible inventory line), and a remote state example

**`ansible/site.yml`: Server setup and service deployment**
- Baseline hardening: SSH keys only, UFW, fail2ban, unattended security upgrades
- A `deploy` user whose sudo rights cover **only** restarting the API service
- ASP.NET Core runtime, a sandboxed **systemd** unit, and an **Nginx** reverse proxy from templates
- Secrets from Ansible Vault and handlers that validate config before reloading
- `--tags deploy`: rolling release (`serial: 1`) with a health check and `block/rescue` rollback

**`docker-compose.yml`: Multi-service application**
- Nginx reverse proxy → .NET API → SQL Server 2022 with a persistent volume
- Health checks and startup ordering: the API waits for a healthy DB
- Network isolation: the DB sits on an `internal` network with no host or internet access
- Resource limits, log rotation, and required secrets loaded from `.env`

**`docs/architecture.md`: Infrastructure overview**
- How Terraform, Ansible and GitHub Actions divide the work
- Environment strategy, the CI/CD flow and server layout as diagrams
- The release and rollback mechanism, security controls, and next steps

---

## Quick Start

```bash
# Run the container stack locally
cp .env.example .env            # set a strong MSSQL_SA_PASSWORD
docker compose up -d
curl http://localhost/healthz

# Check the infrastructure code
cd terraform && terraform init -backend=false && terraform validate

# Check the playbook
cd ansible && ansible-playbook -i inventory.example.ini site.yml --syntax-check
```

---

## Contact

- **GitHub:** [github.com/Athul-mj](https://github.com/Athul-mj)
- **LinkedIn:** [linkedin.com/in/athul-mj](https://www.linkedin.com/in/athul-mj)
- **Email:** athulmj8696@gmail.com
