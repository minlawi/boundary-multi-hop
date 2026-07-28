
packer {
  required_plugins {
    amazon = {
      version = ">= 1.0.0"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

source "amazon-ebs" "ubuntu-image" {
  profile       = "${var.aws_profile}"
  ami_name      = "${var.owner}-ubuntu-boundary-enterprise-{{timestamp}}"
  region        = "${var.aws_region}"
  instance_type = var.aws_instance_type
#   ami_groups = ["all"] # makes AMI public
  tags = {
    Name = "${var.owner}-ubuntu-boundary-enterprise-{{timestamp}}"
    BoundaryVersion = "latest"
  }
  source_ami_filter {
      filters = {
        virtualization-type = "hvm"
        name = "ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"
        // name = "ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"
        // name = "ubuntu/images/*ubuntu-bionic-18.04-amd64-server-*"
        root-device-type = "ebs"
      }
      owners = [var.ami_owner_id]
      most_recent = true
  }
  communicator = "ssh"
  ssh_username = "ubuntu"
}

build {
  sources = [
    "source.amazon-ebs.ubuntu-image"
  ]

  provisioner "shell" {
    inline = [
      "sleep 10",

      # Update system packages
      "sudo apt-get update",

      # Install required packages
      "sudo apt-get install -y wget curl unzip jq net-tools",

      # ========== Install Boundary Enterprise (Step 1 from boundary_setup.md) ==========
      "echo \"Installing Boundary Enterprise (latest version)\"",
      "# Download latest Boundary Enterprise from HashiCorp releases API",
      "wget -q \"$(curl -fsSL \"https://api.releases.hashicorp.com/v1/releases/boundary/latest?license_class=enterprise\" | jq -r '.builds[] | select(.arch == \"amd64\" and .os == \"linux\") | .url')\"",

      "# Unzip Boundary binary",
      "unzip -o *.zip",

      "# Create boundary user and group",
      "sudo adduser --system --group boundary || true",

      "# Install boundary binary",
      "sudo mv boundary /usr/local/bin/",
      "cd /usr/local/bin",
      "sudo chown boundary:boundary boundary",

      "# Create boundary.d directory structure",
      "cd /etc/",
      "sudo mkdir -p boundary.d",
      "sudo chown boundary:boundary boundary.d",

      "# Create symlink for system-wide access",
      "sudo ln -sf /usr/local/bin/boundary /usr/bin/boundary",

      "# Verify installation",
      "boundary version",

      "# Clean up downloaded files",
      "rm -f *.zip",

      # Install additional useful tools
      "sudo apt-get install -y tree htop",

      # Clean up package cache
      "sudo apt-get clean",
      "sudo apt-get autoremove -y"
    ]
  }
}