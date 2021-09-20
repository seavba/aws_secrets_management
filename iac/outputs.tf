output "api_url" {
  value = "curl -X PUT -H 'Accept:*/*' -H 'Content-Type:application/octet-stream' --data-binary @${var.encrypted_file} ${aws_api_gateway_deployment.secrets_api_deployment.invoke_url}"
}

output "encrypt_command" {
  value = "aws kms encrypt  --key-id ${aws_kms_key.secret_key.key_id} --plaintext fileb:///${var.credentials_file} --output text  --query CiphertextBlob | base64 --decode  > ${var.encrypted_file}"
}
