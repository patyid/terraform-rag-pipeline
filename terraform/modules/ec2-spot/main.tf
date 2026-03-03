# 
# MÓDULO: EC2 Spot Instance
# 

data "aws_ami" "this" {
  most_recent = true
  owners      = var.ami_owners

  filter {
    name   = "name"
    values = [var.ami_name_pattern]
  }

  filter {
    name   = "architecture"
    values = [var.ami_architecture]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

resource "aws_instance" "this" {
  ami                    = data.aws_ami.this.id
  instance_type          = var.instance_type
  iam_instance_profile   = var.iam_instance_profile
  vpc_security_group_ids = var.vpc_security_group_ids
  subnet_id              = var.subnet_id
  key_name               = var.key_name

  # Spot Instance Configuration
  instance_market_options {
    market_type = "spot"
    spot_options {
      spot_instance_type             = var.spot_instance_type
      instance_interruption_behavior = var.interruption_behavior
      max_price                      = var.spot_max_price
    }
  }

  # Root Volume
  dynamic "root_block_device" {
    for_each = var.root_volume_enabled ? [1] : []
    content {
      volume_size           = var.root_volume_size
      volume_type           = var.root_volume_type
      encrypted             = var.root_volume_encrypted
      delete_on_termination = var.root_volume_delete_on_termination
      iops                  = var.root_volume_iops
      throughput            = var.root_volume_throughput
    }
  }

  # User Data
  user_data                   = var.user_data
  user_data_replace_on_change = var.user_data_replace_on_change

  # Metadata Options (IMDSv2 recomendado para segurança)
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = var.require_imdsv2 ? "required" : "optional"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "enabled"
  }

  # Monitoring
  monitoring = var.detailed_monitoring

  tags = merge(
    {
      Name = "${var.name_prefix}-instance"
    },
    var.tags
  )

  lifecycle {
    create_before_destroy = true
  }
}