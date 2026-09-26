-- wrk2 script: GET requests against the direct (RDS only) Lambda path.
-- Hits a multi-table JOIN query (orders/customers/order_items/products/reviews)
-- for a given order id, so RDS latency under load is clearly visible.
-- Usage: wrk -t4 -c50 -d30s -R100 -s benchmark/direct.lua http://<alb-dns>/direct/item/1

wrk.method = "GET"
