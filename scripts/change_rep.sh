#!/bin/bash
# Description: 批量一次性将现在已存在的索引（不含以.开头的隐藏索引）副本数改为0

ES_USER=elastic
ES_PASS=esjJIV0VCGlEkzfI8mfJN6

for index in $(curl -s -u${ES_USER}:${ES_PASS} --cacert /data/es/certs/ca/ca.crt https://localhost:9200/_cat/indices?h=index | grep -v '^\.'); do
    echo -n "${index}: "
    curl -s -X PUT -u${ES_USER}:${ES_PASS} --cacert /data/es/certs/ca/ca.crt \
        -H "Content-Type: application/json" \
        -d '{"index":{"number_of_replicas":0}}' \
        https://localhost:9200/"$index"/_settings
    echo
done