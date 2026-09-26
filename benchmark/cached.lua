-- wrk2 script: GET requests against the cached (ElastiCache + RDS) Lambda path.
-- Same multi-table JOIN order-detail query as benchmark/direct.lua, but served
-- from Redis on cache hit to show the latency contrast under load.
-- Usage: wrk -t4 -c50 -d30s -R100 -s benchmark/cached.lua http://<alb-dns>/cached/item/1

wrk.method = "GET"
