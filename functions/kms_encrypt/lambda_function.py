from os import environ
from boto3 import session as boto_session
from base64 import b64encode
from http import HTTPStatus
from json import dumps
from secrets import token_urlsafe

from aws_lambda_powertools.event_handler import (
    LambdaFunctionUrlResolver,
    Response,
    content_types,
)
from aws_lambda_powertools import Logger
from aws_lambda_powertools.utilities.typing import LambdaContext

LOG_LEVEL = environ.get("LOG_LEVEL", "INFO")
DEFAULT_PASSWORD_LENGTH = 20
MAX_PASSWORD_LENGTH = 4096
AWS_REGION = environ.get("AWS_REGION")
POWERTOOLS_SERVICE_NAME = "encrypt-airflow-secrets"

app = LambdaFunctionUrlResolver()
logger = Logger()

KMS_KEY_ID = environ.get("KMS_KEY_ID")
if not KMS_KEY_ID:
    exit("Please set the 'KMS_KEY_ID' environment variable")

session = boto_session.Session()
kms_client = session.client("kms", region_name=AWS_REGION)


def _kms_encrypt(value: str) -> str:
    """
    Encrypt a string using an AWS KMS key
    :param value: String to encrypt
    :return: KMS-encrypted string
    """
    cipher_blob = kms_client.encrypt(KeyId=KMS_KEY_ID, Plaintext=value).get(
        "CiphertextBlob"
    )

    return b64encode(cipher_blob).decode()


def _generate_encrypt(password_length: int) -> str:
    """
    Generate a URL-safe password that is `password_length` characters long
    :param password_length: Length of the password
    :return: KMS-encrypted string
    """

    if password_length > MAX_PASSWORD_LENGTH:
        logger.info(
            f"Requested password length '{password_length}' is bigger than '{MAX_PASSWORD_LENGTH}', defaulting to "
            f"'{MAX_PASSWORD_LENGTH}' characters"
        )
        password_length = MAX_PASSWORD_LENGTH

    elif password_length < DEFAULT_PASSWORD_LENGTH:
        logger.info(
            f"Requested password length '{password_length}' is smaller than '{DEFAULT_PASSWORD_LENGTH}', defaulting to "
            f"'{DEFAULT_PASSWORD_LENGTH}' characters"
        )
        password_length = DEFAULT_PASSWORD_LENGTH

    # on average each byte results in approximately 1.3 characters
    # https://docs.python.org/3.8/library/secrets.html#secrets.token_urlsafe
    password = token_urlsafe(int(password_length // 1.3))

    # generated password is sometimes longer than requested, so we trim it
    return password[:password_length]


@app.post("/encrypt")
def encrypt():
    try:
        data = app.current_event.json_body
        value = data["encrypt_this"]

        return Response(
            status_code=HTTPStatus.OK.value,
            content_type=content_types.APPLICATION_JSON,
            body=dumps(
                {
                    "encrypted_value": _kms_encrypt(value),
                    "message": "Encrypted a user-provided value.",
                }
            ),
        )

    except (KeyError, Exception):
        return Response(
            status_code=HTTPStatus.BAD_REQUEST.value,
            content_type=content_types.APPLICATION_JSON,
            body=dumps(
                {"message": "Payload must contain the 'encrypt_this' key-value pair."}
            ),
        )


@app.get("/generate")
def generate_encrypt():
    try:
        password_length = int(
            app.current_event.get_query_string_value(
                name="length", default_value=str(DEFAULT_PASSWORD_LENGTH)
            )
        )

        return Response(
            status_code=HTTPStatus.OK.value,
            content_type=content_types.APPLICATION_JSON,
            body=dumps(
                {
                    "encrypted_value": _kms_encrypt(_generate_encrypt(password_length)),
                    "message": f"Generated and encrypted a {password_length} character secret",
                }
            ),
        )

    except ValueError:
        return Response(
            status_code=HTTPStatus.BAD_REQUEST.value,
            content_type=content_types.APPLICATION_JSON,
            body=dumps({"message": "Value of parameter 'length' must be an integer"}),
        )


def lambda_handler(event: dict, context: LambdaContext) -> dict:
    return app.resolve(event, context)
