output "cart_service_role_arn" {
  description = "ARN of the cart service IAM role"
  value       = aws_iam_role.cart_service_role.arn
}

output "catalog_service_role_arn" {
  description = "ARN of the catalog service IAM role"
  value       = aws_iam_role.catalog_service_role.arn
}

output "order_service_role_arn" {
  description = "ARN of the order service IAM role"
  value       = aws_iam_role.order_service_role.arn
}

output "checkout_service_role_arn" {
  description = "ARN of the checkout service IAM role"
  value       = aws_iam_role.checkout_service_role.arn
}