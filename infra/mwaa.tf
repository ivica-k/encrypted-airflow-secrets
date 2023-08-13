locals {
  mwaa_name = "${local.name_prefix}-mwaa"
}

resource "aws_s3_bucket" "this" {
  bucket = "${local.name_prefix}-bucket"
}

resource "aws_s3_object" "object" {
  bucket = aws_s3_bucket.this.bucket
  key    = "dags/example_dag.py"
  source = "dags/example_dag.py"

  etag = filemd5("dags/example_dag.py")
}

data "aws_iam_policy_document" "mwaa" {
  statement {
    actions = [
      "airflow:PublishMetrics"
    ]

    effect = "Allow"

    resources = [
      "arn:aws:airflow:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:environment/${local.mwaa_name}"
    ]
  }

  statement {
    actions = [
      "s3:ListAllMyBuckets"
    ]

    effect = "Deny"

    resources = [
      "*",
    ]
  }

  statement {
    actions = [
      "s3:*"
    ]

    effect = "Allow"

    resources = [
      "${aws_s3_bucket.this.arn}",
      "${aws_s3_bucket.this.arn}/*",
    ]
  }

  statement {
    actions = [
      "logs:CreateLogStream",
      "logs:CreateLogGroup",
      "logs:PutLogEvents",
      "logs:GetLogEvents",
      "logs:GetLogRecord",
      "logs:GetLogGroupFields",
      "logs:GetQueryResults",
      "logs:DescribeLogGroups",
    ]

    effect = "Allow"

    resources = [
      "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:airflow-${local.mwaa_name}-*"
    ]
  }

  statement {
    actions = [
      "logs:DescribeLogGroups"
    ]

    effect = "Allow"

    resources = [
      "*"
    ]
  }

  statement {
    actions = [
      "sqs:ChangeMessageVisibility",
      "sqs:DeleteMessage",
      "sqs:GetQueueAttributes",
      "sqs:GetQueueUrl",
      "sqs:ReceiveMessage",
      "sqs:SendMessage",
    ]

    effect = "Allow"

    resources = [
      "arn:aws:sqs:${data.aws_region.current.name}:*:airflow-celery-*"
    ]
  }

  statement {
    actions = [
      "ecs:RunTask",
      "ecs:DescribeTasks",
      "ecs:RegisterTaskDefinition",
      "ecs:DescribeTaskDefinition",
      "ecs:ListTasks",
    ]

    effect = "Allow"

    resources = [
      "*"
    ]
  }

  statement {
    actions = [
      "iam:PassRole"
    ]

    effect = "Allow"

    condition {
      test     = "StringLike"
      values   = ["ecs-tasks.amazonaws.com"]
      variable = "iam:PassedToService"
    }

    resources = [
      "*"
    ]
  }

  statement {
    actions = [
      "kms:Decrypt",
      "kms:DescribeKey",
      "kms:GenerateDataKey*",
      "kms:Encrypt",
      "kms:PutKeyPolicy"
    ]

    effect = "Allow"

    condition {
      test = "StringEquals"
      values = [
        "sqs.${data.aws_region.current.name}.amazonaws.com",
        "s3.${data.aws_region.current.name}.amazonaws.com",
      ]
      variable = "kms:ViaService"
    }

    resources = [
      "*"
    ]
  }

  statement {
    actions = [
      "secretsmanager:GetResourcePolicy",
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret",
      "secretsmanager:ListSecretVersionIds"
    ]

    effect = "Allow"

    resources = [
      "arn:aws:secretsmanager:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:secret:airflow/*"
    ]
  }

  statement {
    actions = [
      "secretsmanager:ListSecrets"
    ]

    effect = "Allow"

    resources = [
      "*"
    ]
  }

}

data "aws_iam_policy_document" "mwaa_assume_role" {
  statement {
    principals {
      type = "Service"
      identifiers = [
        "airflow.amazonaws.com",
        "airflow-env.amazonaws.com",
        "ecs-tasks.amazonaws.com"
      ]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "mwaa" {
  name               = "${local.name_prefix}-role"
  assume_role_policy = data.aws_iam_policy_document.mwaa_assume_role.json
  path               = "/service-role/"
}

resource "aws_iam_policy" "mwaa" {
  name   = "${local.name_prefix}-policy"
  policy = data.aws_iam_policy_document.mwaa.json
}

resource "aws_iam_role_policy_attachment" "this" {
  policy_arn = aws_iam_policy.mwaa.arn
  role       = aws_iam_role.mwaa.name
}

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "${local.name_prefix}-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["${data.aws_region.current.name}a", "${data.aws_region.current.name}b", "${data.aws_region.current.name}c"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  enable_nat_gateway = true
}

data "http" "myip" {
  url = "https://ifconfig.me"
}

# allow the public IP of your machine to connect
resource "aws_security_group" "allow_my_machine" {
  name   = "${local.name_prefix}-secgp"
  vpc_id = module.vpc.vpc_id

  ingress {
    from_port = 443
    to_port   = 443
    protocol  = "tcp"
    cidr_blocks = [
      "${data.http.myip.response_body}/32"
    ]
  }

  ingress {
    from_port = 0
    to_port   = 65535
    self      = true
    protocol  = "tcp"
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

# get two out of three subnets randomly - MWAA needs only 2
resource "random_shuffle" "mwaa_subnets" {
  input        = module.vpc.private_subnets
  result_count = 2
}

resource "aws_mwaa_environment" "this" {
  airflow_configuration_options = {
    "core.load_default_connections" = false,
    "core.load_examples"            = false,
    "webserver.dag_default_view"    = "tree",
    "webserver.dag_orientation"     = "TB",
    "secrets.backend"               = "airflow.providers.amazon.aws.secrets.secrets_manager.SecretsManagerBackend",
    "secrets.backend_kwargs"        = "{\"connections_prefix\": \"airflow/connections\",\"variables_prefix\": \"airflow/variables\"}"
  }

  airflow_version    = "2.6.3"
  dag_s3_path        = "dags/"
  execution_role_arn = aws_iam_role.mwaa.arn
  name               = local.mwaa_name
  environment_class  = "mw1.small"
  min_workers           = 1
  max_workers           = 1
  webserver_access_mode = "PUBLIC_ONLY"

  network_configuration {
    security_group_ids = [aws_security_group.allow_my_machine.id]
    subnet_ids         = random_shuffle.mwaa_subnets.result
  }

  logging_configuration {
    dag_processing_logs {
      enabled   = true
      log_level = "INFO"
    }

    scheduler_logs {
      enabled   = true
      log_level = "INFO"
    }

    task_logs {
      enabled   = true
      log_level = "INFO"
    }

    webserver_logs {
      enabled   = true
      log_level = "ERROR"
    }

    worker_logs {
      enabled   = true
      log_level = "INFO"
    }
  }

  source_bucket_arn = aws_s3_bucket.this.arn
}