#!/bin/bash
# crontab -l
# 0 */1 * * * /data/compose/clean_index.sh >> /var/log/clean_index.log 2>&1

echo "##################################### $(date "+%Y-%m-%d %H:%M:%S %z") #####################################"

ES_HOST="https://localhost:9200"

# ========= 配置区域 =========
MODE="hours"        # 取值: "days" 或 "hours"
RETAIN_DAYS=7       # 当 MODE=days 时生效，保留最近 N 天
RETAIN_HOURS=24     # 当 MODE=hours 时生效，保留最近 N 小时
# ===========================

INDEX_PREFIXES=(
  "test-applications-"
  "test-ingress-"
)

AUTH_ENABLE=true
ES_USER="elastic"
ES_PASS="esjJIV0VCGlEkzfI8mfJN6"
CA_CERT="/data/es/certs/ca/ca.crt"

CURL_OPTS=(-s)
if [[ "$AUTH_ENABLE" == "true" ]]; then
  [[ -n "$ES_USER" && -n "$ES_PASS" ]] && CURL_OPTS+=(-u "$ES_USER:$ES_PASS")
  [[ -n "$CA_CERT" ]] && CURL_OPTS+=(--cacert "$CA_CERT")
fi

# 计算保留时间的截止点
if [[ "$MODE" == "days" ]]; then
  DATE_LIMIT=$(date -d "$RETAIN_DAYS days ago" +%Y.%m.%d)
  echo "模式: 按天保留，保留最近 $RETAIN_DAYS 天内的索引（>= $DATE_LIMIT）"
elif [[ "$MODE" == "hours" ]]; then
  DATE_LIMIT=$(date -u -d "$RETAIN_HOURS hours ago" +%Y.%m.%d_%H)
  echo "模式: 按小时保留 (UTC)，保留最近 $RETAIN_HOURS 小时内的索引（>= $DATE_LIMIT）"
else
  echo "❌ 配置错误: MODE 必须是 'days' 或 'hours'"
  exit 1
fi

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

    if [[ "$MODE" == "days" ]]; then
      DATE_PART=$(echo "$index" | grep -oE '[0-9]{4}\.[0-9]{2}\.[0-9]{2}')
    else
      DATE_PART=$(echo "$index" | grep -oE '[0-9]{4}\.[0-9]{2}\.[0-9]{2}_[0-9]{2}')
    fi

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