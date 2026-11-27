data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-kernel-6.1-x86_64"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

resource "aws_instance" "web" {
  ami                    = data.aws_ami.al2023.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public["a"].id
  vpc_security_group_ids = [aws_security_group.web.id]
  iam_instance_profile   = "LabInstanceProfile"

  user_data_replace_on_change = true

  metadata_options {
    http_tokens = "required"
  }

  root_block_device {
    encrypted             = true
    volume_size           = 8
    volume_type           = "gp3"
    delete_on_termination = true
  }

  user_data = <<-EOT
    #!/bin/bash
    set -euo pipefail
    dnf -y install nginx
    cat > /usr/share/nginx/html/index.html <<'HTML'
    <html>
    <body>
      <h1>ACS730 Assignment 1</h1>
      <p>Environment: ${var.environment}</p>
      <p>Application version: ${var.app_version}</p>
    </body>
    </html>
    HTML
    systemctl enable --now nginx
  EOT

  depends_on = [aws_route_table_association.public]

  tags = merge(local.common_tags, {
    Name = "${local.name}-web"
  })
}
