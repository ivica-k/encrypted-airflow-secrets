data "aws_caller_identity" "current" {}

resource "aws_kms_key" "this" {
  description             = "KMS key used to encrypt MWAA connections"
  deletion_window_in_days = 30
}

resource "aws_kms_alias" "this" {
  name          = "alias/${local.name_prefix}-key"
  target_key_id = aws_kms_key.this.id
}
