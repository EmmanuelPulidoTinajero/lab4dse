#!/usr/bin/env bash
set -euo pipefail

if [ -z "${ALB_DNS:-}" ]; then
  echo "Set ALB_DNS env var to your ALB DNS name (terraform output alb_dns_name)" >&2
  exit 1
fi

RATE="${RATE:-20}"
THREADS="${THREADS:-2}"
CONNECTIONS="${CONNECTIONS:-10}"
DURATION="${DURATION:-15s}"

echo "=== BENCHMARK: /direct (no cache, always hits RDS) ==="
wrk -t"${THREADS}" -c"${CONNECTIONS}" -d"${DURATION}" -R"${RATE}" \
  -s benchmark/direct.lua "http://${ALB_DNS}/direct/item/1"

echo
echo "=== BENCHMARK: /cached (ElastiCache cache-aside in front of RDS) ==="
wrk -t"${THREADS}" -c"${CONNECTIONS}" -d"${DURATION}" -R"${RATE}" \
  -s benchmark/cached.lua "http://${ALB_DNS}/cached/item/1"
