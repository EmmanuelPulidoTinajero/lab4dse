# Lab 4 DSE — Architecture Decisions

Student: jose.pulido@iteso.mx

## Services
- ALB (public) -> Lambda target groups (no API Gateway)
- Lambda "direct": always reads/writes Postgres RDS directly
- Lambda "cached": cache-aside strategy against ElastiCache Redis in front of RDS
- RDS PostgreSQL: db.t3.micro, single AZ, private subnets
- ElastiCache Redis: cache.t3.micro, 1 node, cluster mode disabled, private subnets

## Data model (multi-table, for realistic join latency)
- customers(id, name, email, city, created_at)
- products(id, sku, name, category, price)
- orders(id, customer_id -> customers, status, created_at)
- order_items(id, order_id -> orders, product_id -> products, quantity, unit_price)
- reviews(id, product_id -> products, customer_id -> customers, rating, comment)
- Seed volumes: 500 customers, 200 products, 5000 orders (1-4 items each),
  3000 reviews. Chosen so the JOIN plan actually scans/aggregates meaningful
  row counts instead of resolving instantly from a tiny table.
- Indexes on orders.customer_id, order_items.order_id/product_id,
  reviews.product_id keep the query index-driven rather than full-scan, while
  still requiring real join/aggregation work per request.

## Query used for /item/{id} (order detail report)
```sql
SELECT
  o.id AS order_id, o.status, o.created_at,
  c.name AS customer_name, c.city,
  p.name AS product_name, p.category,
  oi.quantity, oi.unit_price,
  COALESCE(AVG(r.rating), 0) AS avg_rating,
  COUNT(r.id) AS review_count
FROM orders o
JOIN customers c ON c.id = o.customer_id
JOIN order_items oi ON oi.order_id = o.id
JOIN products p ON p.id = oi.product_id
LEFT JOIN reviews r ON r.product_id = p.id
WHERE o.id = $1
GROUP BY o.id, c.name, c.city, p.name, p.category, oi.quantity, oi.unit_price
ORDER BY o.created_at DESC;
```
- 5 tables, 4 joins (1 LEFT JOIN), GROUP BY + aggregation (AVG, COUNT).
- Chosen over a single-table lookup specifically so RDS latency is visible
  under load and the cache-aside win (Redis serving the pre-joined JSON
  result) is easy to demonstrate with wrk2.

## Caching strategy: cache-aside (lazy loading)
- GET /cached/item/{id}: check Redis first. On hit, return immediately (source: "cache").
  On miss, run the order-detail JOIN query against RDS, write the JSON result
  array into Redis with TTL (60s), return (source: "rds").
- POST /cached/item: creates an order + order_item row in RDS, then deletes the
  Redis key `order:{id}` for that order id so the next GET repopulates it from
  RDS with fresh data.
- GET/POST /direct/item: always goes straight to RDS with the same JOIN query,
  no cache involved. Used as the performance baseline to compare against
  /cached under load with wrk2 — this is where the multi-table join cost is
  most visible.

## Networking
- New VPC, 2 public subnets (ALB), 2 private subnets (Lambda, RDS, Redis)
- No NAT Gateway: Lambdas only need to reach RDS/ElastiCache/ALB inside the VPC
- IAM: uses the AWS Academy Learner Lab pre-existing "LabRole" for all Lambda executions
  (Learner Lab accounts cannot create new IAM roles/policies)

## Benchmark
- Tool: wrk2 (https://github.com/giltene/wrk2)
- Compare GET /direct/item/1 vs GET /cached/item/1 under identical load
  (100 req/s, 4 threads, 50 connections, 30s) to show the latency/throughput
  difference between an uncached RDS-only path and a cache-aside path.
