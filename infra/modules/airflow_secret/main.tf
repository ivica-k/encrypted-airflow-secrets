data "aws_kms_secrets" "secret" {
  secret {
    name    = "secret"
    payload = var.encrypted_string
  }
}

resource "aws_secretsmanager_secret" "secret" {
  name = var.name
}

resource "aws_secretsmanager_secret_version" "string" {
  secret_id     = aws_secretsmanager_secret.secret.id
  secret_string = data.aws_kms_secrets.secret.plaintext["secret"]
}
