output "vpc_id" {
  description = "The ID of the VPC"
  value       = aws_vpc.this.id
}

output "vpc_cidr_block" {
  description = "The CIDR block of the VPC"
  value       = aws_vpc.this.cidr_block
}

output "vpc_arn" {
  description = "The ARN of the VPC"
  value       = aws_vpc.this.arn
}

output "public_subnet_ids" {
  description = "List of public subnet IDs"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "List of private subnet IDs"
  value       = aws_subnet.private[*].id
}

output "public_subnet_cidrs" {
  description = "List of public subnet CIDR blocks"
  value       = aws_subnet.public[*].cidr_block
}

output "private_subnet_cidrs" {
  description = "List of private subnet CIDR blocks"
  value       = aws_subnet.private[*].cidr_block
}

output "internet_gateway_id" {
  description = "The ID of the Internet Gateway"
  value       = aws_internet_gateway.this.id
}

output "nat_gateway_ids" {
  description = "List of NAT Gateway IDs"
  value       = aws_nat_gateway.this[*].id
}

output "nat_gateway_public_ips" {
  description = "List of public Elastic IPs of NAT Gateways"
  value       = aws_eip.nat[*].public_ip
}

output "public_route_table_id" {
  description = "ID of the public route table"
  value       = aws_route_table.public.id
}

output "private_route_table_ids" {
  description = "List of private route table IDs"
  value       = aws_route_table.private[*].id
}

output "availability_zones" {
  description = "List of availability zones used"
  value       = data.aws_availability_zones.available.names
}

output "network_configuration" {
  description = "Complete network configuration"
  value = {
    vpc_id             = aws_vpc.this.id
    vpc_cidr           = aws_vpc.this.cidr_block
    public_subnets     = aws_subnet.public[*].id
    private_subnets    = aws_subnet.private[*].id
    internet_gateway   = aws_internet_gateway.this.id
    nat_gateways       = aws_nat_gateway.this[*].id
    availability_zones = data.aws_availability_zones.available.names
  }
}

output "dns_configuration" {
  description = "VPC DNS configuration"
  value = {
    enable_dns_support   = aws_vpc.this.enable_dns_support
    enable_dns_hostnames = aws_vpc.this.enable_dns_hostnames
  }
}