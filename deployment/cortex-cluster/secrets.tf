data "google_kms_secret" "prometheus_bearer_token" {
  crypto_key = "${data.google_kms_crypto_key.kubernetes.id}"
  ciphertext = "encrypted_secret_string_goes_here"
}

data "google_kms_secret" "gateway_jwt_secret" {
  crypto_key = "${data.google_kms_crypto_key.kubernetes.id}"
  ciphertext = "encrypted_secret_string_goes_here"
}
