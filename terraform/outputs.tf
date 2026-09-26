output "alb_dns_name" {
  value = aws_lb.main.dns_name
}

output "rds_endpoint" {
  value = aws_db_instance.postgres.address
}

output "redis_endpoint" {
  value = aws_elasticache_cluster.redis.cache_nodes[0].address
}

output "direct_url" {
  value = "http://${aws_lb.main.dns_name}/direct/item"
}

output "cached_url" {
  value = "http://${aws_lb.main.dns_name}/cached/item"
}
