data "google_kms_secret" "prometheus_bearer_token" {
  crypto_key = "${data.google_kms_crypto_key.kubernetes.id}"
  ciphertext = "CiQATnQLDZ4FrZxoK/wFgjh3Fz1CaN/KxgHa/5qWZVv5+dleM4gSggIAVDGmoJvIeZcCxjbUIDWGqxDg3CVMBeHcCZDjFSQQGqd0CphQDOKB1P23SLYkV1/Ov4Qanz1RnDrVHgbnYpeDMVY0eBNzpKu+Scg8toPdXXQtSgxiEzN7P657ME2hl+Fvjo7mp7YDFnt1JXEusF6ksx0Ttor1RxQ73k553Fj9c5sn/kD/oN/5OMCqeCiOXcFinCNv7s5UaGze5xNO4/YzsBF+gyBc4jFLoORrvFffqv/YByH5M9iUnYQeEohvl0lM+xyFO6KjAUjaJj6CcB2LF+fLU8aTxEaijJEYlewWhgbOfl8ExhXV/qMvL9Aj61naOklVCu52RXgtMecmvBOjTzo="
}

data "google_kms_secret" "gateway_jwt_secret" {
  crypto_key = "${data.google_kms_crypto_key.kubernetes.id}"
  ciphertext = "CiQATnQLDdcOnpvP/bIky0kL9IqpWQ+FXEZnWCsMcLthybVMjGgSQQBUMaagEQnybjHAhNNmXJpPf5Qz7INYWLVnl7qNz9fU5HF+db96OdCySiQgUc8ezjM7a9CBWGmqd0Uxp77CDhRb"
}
