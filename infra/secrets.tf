module "sftp_conn" {
  source = "./modules/airflow_secret"

  name             = "airflow/connections/sftp"
  encrypted_string = "AQICAHjTAGlNShkkcAYzHl8C2qXs7fs5x9gByXim/PPuwt+TuwGhmhBNcePnQmhjrTgozm6rAAAAnTCBmgYJKoZIhvcNAQcGoIGMMIGJAgEAMIGDBgkqhkiG9w0BBwEwHgYJYIZIAWUDBAEuMBEEDNsuSPfnG5HJDqrVrAIBEIBW9d2tlJEaC82prgTFdnPnEXx4kKbhdGICAbFZe63P7fuq87AJLiXMSkC4ZgHPVABkupemD6j2QN4EEEUcHr0BBYGlYJ1WugtRltUnLU8TVWkLDUsSfDs="
}

module "db_conn" {
  source = "./modules/airflow_secret"

  name             = "airflow/connections/db"
  encrypted_string = "AQICAHjTAGlNShkkcAYzHl8C2qXs7fs5x9gByXim/PPuwt+TuwH8pYZHik8Cx0AZDM+ECML8AAAAnzCBnAYJKoZIhvcNAQcGoIGOMIGLAgEAMIGFBgkqhkiG9w0BBwEwHgYJYIZIAWUDBAEuMBEEDP+6yJG8621GrlLhOwIBEIBYNXpiL2u3Ca9oR1gbXYc/SQNZxHgqk7V7WvIr0EUADuwWhg6PFC4PyD3+1Oi/YKmtoflyL7aB49I62MJYaMLGYgwILcruu4RTXlGStvRXwF2a8zaxroJDDw=="
}