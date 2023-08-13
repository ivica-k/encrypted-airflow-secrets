output "secret" {
  value = {
    arn  = aws_secretsmanager_secret.secret.arn
    name = aws_secretsmanager_secret.secret.name
  }
}