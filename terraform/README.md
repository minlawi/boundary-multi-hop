# Self-Managed Boundary on AWS

A complete setup for running HashiCorp Boundary workers with multi-hop security architecture on AWS.

---

## The Problem: Traditional SSH is Painful

| Issue | Traditional SSH | Boundary Solution |
|-------|----------------|-------------------|
| **Keys everywhere** | Private keys copied to each engineer's laptop | No SSH keys needed - Boundary handles auth |
| **Key rotation** | nightmare - change keys on all servers | Rotate once in Boundary, applies everywhere |
| **Audit trail** | Hard to track who did what | Full session logging and recording |
| **Temporary access** | Share keys, then forget to revoke | Time-based access that expires automatically |
| **Server sprawl** | SSH directly to every server | Workers route traffic centrally |
| **Credential management** | Passwords/keys scattered | Credentials injected at session time |

### What Boundary Does Differently

```
Traditional SSH:             Boundary:
You ──SSH──→ Server         You ──Boundary──→ Worker ──SSH──→ Server
↓                              ↓
Key stays on laptop            No keys, just authentication
```

**Think of Boundary as:**
- A secure gatekeeper for your servers
- SSH without managing SSH keys
- A way to say "let person X access server Y for 2 hours" - and it just works

#### A Simple Story

**Monday morning:** A contractor needs access to your production database server.

**Traditional SSH way:**
1. Generate SSH key for contractor
2. Copy key to production server
3. Contractor does their work
4. **Oops - someone forgets to remove the key**
5. Key stays there indefinitely ⚠️

**Boundary way:**
1. "Give contractor 4 hours access to prod-db"
2. Contractor connects through Boundary
3. After 4 hours, access **automatically disappears** ✅

**Same scenario, different outcome:** Boundary handles the cleanup for you.

---

## The Solution: What Gets Created

This setup creates two connected networks (VPCs) with Boundary workers providing multi-hop access to isolated targets.

![Boundary Multi-Hop Architecture](../boundary-multi-hop.jpeg)

### Components Explained

| Component | Purpose | Access |
|-----------|---------|--------|
| **Bastion** | Entry point for SSH | Your IP only |
| **Intermediary Worker** | Boundary worker (middle layer) | From bastion |
| **Intermediary Target** | Isolated server | From intermediary worker only |
| **Egress Worker** | Boundary worker (exit layer) | From intermediary worker |
| **Egress Target** | Final destination | From egress worker only |

---

## Quick Summary: When & Why

**Best for:** Teams with multiple servers, audit requirements, or temporary access needs

**Traditional SSH works better when:** Single developer, simple setup, quick direct access

**Benefits vs Complexity:**

| Boundary Gives You | Trade-off |
|--------------------|-----------|
| No SSH keys to manage | Extra infrastructure to run |
| Centralized access control | Initial setup complexity |
| Session audit trails | Dependency on Boundary availability |
| Time-based access expires | Network complexity for multi-hop |

---

## How to Deploy

### Prerequisites

- **Terraform** >= 1.0
- **Packer** >= 1.0
- **AWS CLI** configured
- **HCP Boundary cluster** with Cluster ID
- **Your IP address** for SSH access

---

### Step 1: Build AMI with Packer

This creates a custom Amazon Machine Image with Boundary already installed.

```bash
cd packer
```

Edit `variables.pkrvars.hcl` with your settings:
```hcl
owner        = "your-name"
aws_profile  = "your-aws-profile"
aws_region   = "us-east-1"
```

Build the image:
```bash
packer build -var-file="variables.pkrvars.hcl" aws_linux_image.pkr.hcl
```

Copy the AMI ID from the output - you'll need it for Terraform.

---

### Step 2: Deploy Infrastructure with Terraform

```bash
cd ../terraform
```

**Copy and edit settings:**
```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:
```hcl
aws_region                  = "us-east-1"
environment                 = "dev"
allowed_ssh_cidr            = "YOUR.IP/32"           # Important!
hcp_boundary_cluster_id     = "your-cluster-id"      # From HCP
hcp_worker_cidr             = "10.0.0.0/8"
intermediary_worker_ami_id  = "ami-from-packer"      # AMI from Step 1
egress_worker_ami_id        = "ami-from-packer"      # Same AMI
```

**Deploy:**
```bash
terraform init
terraform plan
terraform apply    # Type 'yes' to confirm
```

---

## After Deployment

### Connect to Bastion

```bash
ssh -i ./keys/boundary-key-dev.pem ubuntu@<BASTION-PUBLIC-IP>
```

### Authorize Workers in HCP Boundary

Each worker generates an auth token. Retrieve and authorize them:

```bash
# On intermediary worker
sudo cat /etc/boundary.d/worker/auth_request_token

# On egress worker
sudo cat /etc/boundary.d/worker/auth_request_token
```

Add these tokens in your HCP Boundary console to authorize the workers.

---

## Reference

### File Structure

```
.
├── packer/                          # AMI builder
│   ├── aws_linux_image.pkr.hcl      # Packer template
│   ├── variables.pkr.hcl            # Variable definitions
│   └── variables.pkrvars.hcl        # Your settings
│
└── terraform/                       # Infrastructure
    ├── main.tf                      # Main config
    ├── vpc.tf                       # Network setup
    ├── security_groups.tf           # Firewall rules
    ├── ec2.tf                       # Server instances
    ├── variables.tf                 # Variable definitions
    ├── outputs.tf                   # Output values
    ├── terraform.tfvars             # Your settings
    └── templates/                   # Worker setup scripts
```

### Settings Reference

| Setting | What It Does | Default |
|---------|--------------|---------|
| `aws_region` | AWS region | us-east-1 |
| `environment` | Environment name | dev |
| `allowed_ssh_cidr` | Your IP for SSH access | *(set your IP)* |
| `hcp_boundary_cluster_id` | Your HCP Boundary cluster | *(required)* |
| `hcp_worker_cidr` | HCP worker network | 10.0.0.0/8 |
| `instance_type` | Server size | t3.micro |
| `intermediary_worker_ami_id` | AMI from Packer | *(from Step 1)* |
| `egress_worker_ami_id` | AMI from Packer | *(from Step 1)* |

### Security Checklist

- [ ] **Set your IP in `allowed_ssh_cidr`** - Don't leave it as 0.0.0.0/0
- [ ] **Private key in `./keys/` is never committed** - Already in .gitignore
- [ ] **Intermediary-target subnet has no internet** - Isolated by design
- [ ] **Auth tokens are sensitive** - Keep them secure
- [ ] **HCP Boundary cluster configured** - Before deploying workers

### Troubleshooting

| Problem | Solution |
|---------|----------|
| Worker not starting | `sudo journalctl -u boundary-worker.service -f -o cat | jq` |
| Script errors | `sudo cat /var/log/cloud-init-output.log` |
| VPC connection issues | Check route tables include peering routes |
| SSH not working | Verify security groups, NAT Gateway status, instance profiles |

### Clean Up

```bash
cd terraform
terraform destroy
```

This removes all AWS resources and your local private key.
