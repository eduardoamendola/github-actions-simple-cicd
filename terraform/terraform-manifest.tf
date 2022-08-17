# ------------
# Main Config
# ------------
# -- Terraform Provider
terraform {
  required_version = "1.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "4.26"
    }
  }
}

# -- AWS Provider
provider "aws" {
  region = "ap-southeast-2"
}

# -- Useful aws_region data
data "aws_region" "current" {}

# -----------
# Networking
# -----------

# -- VPC
resource "aws_vpc" "XapoVPC" {
  cidr_block = "192.168.0.0/24"

  tags = {
    Name = "XapoVPC"
  }
}

# -- Subnet
resource "aws_subnet" "XapoSubnet" {
  vpc_id            = aws_vpc.XapoVPC.id
  availability_zone = data.aws_region.current.name
  cidr_block        = "192.168.0.0/25"

  tags = {
    Name = "XapoSubnet"
  }
}

# --------------------
# EFS
# --------------------

# -- EFS Security Group
resource "aws_security_group" "XapoEFS_SG" {
  name        = "XapoEFS_SG"
  description = "XapoEFS Security Group"

  vpc_id                 = aws_vpc.XapoVPC.id
  revoke_rules_on_delete = false

  tags = {
    Name = "XapoEFS_SG"
  }
}

# -- EFS Outbound Security Group Rule 
resource "aws_security_group_rule" "XapoEFS_outbound_SG" {
  security_group_id = aws_security_group.XapoEFS_SG.id
  cidr_blocks = [
    aws_vpc.XapoVPC.cidr_block
  ]

  type      = "egress"
  protocol  = "tcp"
  from_port = 2049
  to_port   = 2049
}

# -- EFS Inbound Security Group Rule
resource "aws_security_group_rule" "XapoEFS_inbound_SG" {
  security_group_id = aws_security_group.XapoEFS_SG.id
  cidr_blocks = [
    aws_vpc.XapoVPC.cidr_block
  ]

  type      = "ingress"
  protocol  = "tcp"
  from_port = 2049
  to_port   = 2049
}

# -- EFS
resource "aws_efs_file_system" "XapoEFS" {
  tags = {
    Name = "XapoEFS"
  }
}

# -- EFS Mount Target
resource "aws_efs_mount_target" "XapoEFS_Target" {
  file_system_id = aws_efs_file_system.XapoEFS.id
  subnet_id      = aws_subnet.XapoSubnet.id
  security_groups = [
    aws_security_group.XapoEFS_SG.id
  ]
}

# ------------
# ECS
# ------------

resource "aws_ecs_cluster" "XapoECS_Cluster" {
  name = "XapoECS_Cluster"
}

resource "aws_ecs_service" "XapoECS_Service" {
  name            = "xapo-ecs-service"
  cluster         = aws_ecs_cluster.XapoECS_Cluster.id
  task_definition = aws_ecs_task_definition.XapoECS_Task.arn
  desired_count   = 2
  launch_type     = "EC2"

  network_configuration {
    subnets = [
    aws_subnet.XapoSubnet.id]
  }
}

# -- Task Definition
resource "aws_ecs_task_definition" "XapoECS_Task" {
  family = "xapo-ecs-task"

  // Mapping all exposed ports from bitcoin container (8332 8333 18332 18333 18444)
  container_definitions = <<DEFINITION
[
  {
      "memory": 512,
      "portMappings": [
          {
              "hostPort": 8332,
              "containerPort": 8332,
              "protocol": "tcp"
          },
          {
              "hostPort": 8333,
              "containerPort": 8333,
              "protocol": "tcp"
          },
          {
              "hostPort": 18332,
              "containerPort": 18332,
              "protocol": "tcp"
          },
          {
              "hostPort": 18333,
              "containerPort": 18333,
              "protocol": "tcp"
          },
          {
              "hostPort": 18444,
              "containerPort": 18444,
              "protocol": "tcp"
          }
      ],
      "essential": true,
      "mountPoints": [
          {
              "containerPath": "/home/bitcoin/.bitcoin",
              "sourceVolume": "bitcoin-data-storage"
          }
      ],
      "name": "${var.DockerImage}",
      "image": "${var.DockerImage}"
  }
]
DEFINITION

  volume {
    name = "bitcoin-data-storage"

    efs_volume_configuration {
      file_system_id = aws_efs_file_system.XapoEFS.id
      root_directory = "/bitcoin_data"
    }
  }
}

# ---------------------------------------------------------------------------------------------------------------------
#  Docker Image to be deployed
# ---------------------------------------------------------------------------------------------------------------------
variable "DockerImage" {
  description = "Image that will be used in Task Definition. Format: owner/image:version"
  type        = string
}