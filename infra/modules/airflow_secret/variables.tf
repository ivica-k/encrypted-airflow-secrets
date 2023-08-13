variable "encrypted_string" {
  type        = string
  description = "KMS-encrypted string that contains a secret."
}

variable "name" {
  type        = string
  description = <<EOT
  Name of the AWS SecretsManager secret, including the 'connections_prefix' prefix.
More info about using the SecretsManager backend for secrets and variables at
https://airflow.apache.org/docs/apache-airflow-providers-amazon/stable/secrets-backends/aws-secrets-manager.html
EOT
}