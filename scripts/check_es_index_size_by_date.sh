#!/bin/bash

# 用法: ./check_es_index_size_by_date.sh 2025.07.28

ES_HOST="https://localhost:9200"
ES_USER="elastic"
ES_PASS="esjJIV0VCGlEkzfI8mfJN6"
CA_CERT="/data/es/certs/ca/ca.crt"

DATE="$1"

if [ -z "$DATE" ]; then
  echo "❌ 请提供日期，例如：2025.07.28"
  exit 1
fi

# 查询指定日期索引的 store.size
BYTES=$(curl -s -u "$ES_USER:$ES_PASS" --cacert "$CA_CERT" \
  "$ES_HOST/*$DATE*/_stats/store" | jq '.["_all"].primaries.store.size_in_bytes')

if [ -z "$BYTES" ] || [ "$BYTES" == "null" ]; then
  echo "📭 没有找到包含日期 $DATE 的索引，或 ES 请求失败"
  exit 1
fi

# 字节转换为 GB / TB
GB=$(awk "BEGIN {printf \"%.2f\", $BYTES / 1073741824}")
TB=$(awk "BEGIN {printf \"%.2f\", $BYTES / 1099511627776}")

echo "📅 日期：$DATE"
echo "📦 总大小：$BYTES 字节"
echo "📦 ≈ $GB GB"
echo "📦 ≈ $TB TB"
