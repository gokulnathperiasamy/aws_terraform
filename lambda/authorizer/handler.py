import json
import os
import boto3

client = boto3.client("secretsmanager")

SECRET_ARN = os.environ["SECRET_ARN"]
_cached_key = None


def handler(event, context):
    token = event.get("headers", {}).get("x-api-key", "")
    method_arn = event.get("methodArn", "*")

    if token and token == _get_secret_key():
        return _policy("Allow", method_arn)

    return _policy("Deny", method_arn)


def _get_secret_key():
    global _cached_key
    if _cached_key:
        return _cached_key
    secret = client.get_secret_value(SecretId=SECRET_ARN)
    _cached_key = json.loads(secret["SecretString"])["api_key"]
    return _cached_key


def _policy(effect, resource):
    # Wildcard to api-id level so cached policy covers all routes
    # methodArn format: arn:aws:execute-api:region:account:api-id/stage/METHOD/resource
    api_base = "/".join(resource.split("/")[:2])  # arn:...:api-id/stage
    wildcard_arn = api_base + "/*/*"
    return {
        "principalId": "user",
        "policyDocument": {
            "Version": "2012-10-17",
            "Statement": [{"Action": "execute-api:Invoke", "Effect": effect, "Resource": wildcard_arn}],
        },
    }
