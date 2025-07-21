#!/bin/bash
# crontab -l
# 10 8 * * * bash /data/compose/clean_index.sh >> /var/log/clean_index.log 2>&1

echo "##################################### $(date "+%Y-%m-%d %H:%M:%S %z") #####################################"

ES_HOST="http://localhost:9200"
RETAIN_DAYS=1

INDEX_PREFIXES=(
  "test-applications-"
  "test-ingress-"
)

AUTH_ENABLE=false
ES_USER="elastic"
ES_PASS="your_password"
CA_CERT="/path/to/ca.crt"

CURL_OPTS=(-s)
if [[ "$AUTH_ENABLE" == "true" ]]; then
  [[ -n "$ES_USER" && -n "$ES_PASS" ]] && CURL_OPTS+=(-u "$ES_USER:$ES_PASS")
  [[ -n "$CA_CERT" ]] && CURL_OPTS+=(--cacert "$CA_CERT")
fi

DATE_LIMIT=$(date -d "$RETAIN_DAYS days ago" +%Y.%m.%d)
echo "保留最近 $RETAIN_DAYS 天内的索引（>= $DATE_LIMIT）"

for PREFIX in "${INDEX_PREFIXES[@]}"; do
  echo ""
  echo "正在处理前缀：$PREFIX"

  INDICES_INFO=$(curl "${CURL_OPTS[@]}" "$ES_HOST/_cat/indices/${PREFIX}*?h=index,store.size" | sort)

  if [[ -z "$INDICES_INFO" ]]; then
    echo "没有匹配前缀 $PREFIX 的索引"
    continue
  fi

  while read -r line; do
    index=$(echo "$line" | awk '{print $1}')
    size=$(echo "$line" | awk '{print $2}')

    DATE_PART=$(echo "$index" | grep -oE '[0-9]{4}\.[0-9]{2}\.[0-9]{2}')
    if [[ -z "$DATE_PART" ]]; then
      echo "跳过非日期型索引: $index"
      continue
    fi

    if [[ "$DATE_PART" < "$DATE_LIMIT" ]]; then
      echo -n "删除索引: $index (大小: $size) "
      curl "${CURL_OPTS[@]}" -X DELETE "$ES_HOST/$index"
      echo
    else
      echo "保留索引: $index (大小: $size)"
    fi
  done <<< "$INDICES_INFO"
done

echo -e "\nDone.\n"
