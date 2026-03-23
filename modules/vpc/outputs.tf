output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.this.id
}

output "vpc_cidr_block" {
  description = "VPC IPv4 CIDR"
  value       = aws_vpc.this.cidr_block
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = aws_subnet.private[*].id
}

output "nat_gateway_ids" {
  description = "NAT gateway IDs (empty if NAT disabled)"
  value       = aws_nat_gateway.this[*].id
}

output "internet_gateway_id" {
  description = "Internet gateway ID"
  value       = try(aws_internet_gateway.this[0].id, null)
}
