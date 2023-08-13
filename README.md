# encrypted-airflow-secrets

This repository contains the source code for a proof-of-concept implementation of how to
manage Airflow secrets through Terraform and keep them committed to a code repository.

More about the solution in the [blog post](https://dev.to/aws-builders/manage-airflow-connections-with-terraform-4hof).

## Architecture diagram

Encrypt the connection string
![](./img/encrypt.png)

Use the encrypted connection string to create an Airflow connection 
![](./img/terraform_airflow.png)

## Sequence diagram

```mermaid
sequenceDiagram
    User->>Lambda: Encrypt this string
    Lambda->>KMS: Encrypt this string
    KMS-->>Lambda: Encrypted string
    Lambda-->>User: Encrypted string
    User->>Terraform: Use encrypted string with 'airflow_secrets' module
    Terraform->>KMS: Decrypt
    KMS-->>Terraform: Decrypted string
    Terraform->>SecretsManager: Create Airflow connection with decrypted string
    MWAA->>SecretsManager: Read Airflow connections
```