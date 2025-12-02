# Copyright 2023 Amazon.com, Inc. or its affiliates. All Rights Reserved.
# Licensed under the Apache License, Version 2.0.

terraform {
  required_version = "~> 1.14.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = var.region
}

resource "aws_db_subnet_group" "postgres" {
  name       = "${var.database_name}-subnet-group"
  subnet_ids = var.database_subnets
}

resource "aws_security_group" "postgres" {
  name        = "${var.database_name}-sg"
  description = "Security group for Postgres"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [var.cluster_sg_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_db_instance" "postgres" {
  identifier              = "${var.database_name}-demo"
  engine                  = "postgres"
  engine_version          = var.database_version
  instance_class          = "db.t3.micro"
  allocated_storage       = 20
  db_subnet_group_name    = aws_db_subnet_group.postgres.name
  vpc_security_group_ids  = [aws_security_group.postgres.id]
  username                = var.db_username
  password                = var.db_password
  db_name                 = var.database_name
  publicly_accessible     = false
  skip_final_snapshot     = true
  apply_immediately       = true
  backup_retention_period = 1
  multi_az                = false
  storage_encrypted       = true
}
