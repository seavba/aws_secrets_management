import json
import base64
import boto3

def lambda_handler(event, context):
    #decrypts data
    session = boto3.session.Session()
    client = session.client('kms')
    encryted_string=json.dumps(event['data']).strip("\"")
    plaintext = client.decrypt(
       CiphertextBlob=bytes(base64.b64decode(encryted_string))
    )

    #serialize plaintext datat as a JSON
    secret_data  = json.loads(plaintext['Plaintext'])

    #Create sercret in secret manager
    secret_client = boto3.client('secretsmanager')
    response = secret_client.create_secret(
        Name=secret_data['environment'] + "/" + secret_data['secret_name'],
        SecretString='{ "' + secret_data['environment'] + '" : "' + secret_data['secret_name'] + '" }',
    )

    return {
        "Response": response
    }
