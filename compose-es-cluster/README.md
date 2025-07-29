## 简介
本项目可以使用docker快速构建起一个3节点的es集群，然后采集所有k8s节点的日志，使用kibana进行日志查询。

## 使用方式
### 主机设置
1. 修改主机名
   ```bash
   hostnamectl set-hostname es-001
   hostnamectl set-hostname es-002
   hostnamectl set-hostname es-003 
   ```
2. 修改系统参数
    ```bash
    echo "vm.max_map_count=262144" | sudo tee -a /etc/sysctl.conf
    sysctl -p
    ```
3. 创建所需目录并授权
    ```bash
    # 在所有主机上执行
    mkdir -p /data/es/esdata && chown -R 1000:1000 /data/es
    
    # 只在es01主机上执行
    mkdir -p /data/es/kibanadata && chown -R 1000:1000 /data/es
    ```

### 项目设置
1. 克隆本项目
    ```bash
    git clone https://github.com/alexchenx/compose-es.git 
    ```
2. 进入compose-es-cluster目录，或者将该目录拷贝到指定的位置
    ```bash
    cd compose-es/compose-es-cluster 
    ```
3. 修改 .env 文件中的有关变量，主要包括：
   - ELASTIC_PASSWORD
   - KIBANA_PASSWORD
   - STACK_VERSION
   - ES01_HOST_IP
   - ES02_HOST_IP
   - ES03_HOST_IP
4. 在es01节点上首先启动容器 setup 用于创建证书
   ```bash
   docker-compose up -d setup 
   ```
5. 将创建的证书拷贝到es02, es03主机相同目录
   ```bash
   scp -r /data/es/certs/ es-002:/data/es/
   scp -r /data/es/certs/ es-003:/data/es/ 
   ```
6. 部署elasticsearch, 分别在3台主机上执行：
   ```bash
   # es01执行
   docker-compose up -d es01
   # es02执行
   docker-compose up -d es02
   # es03执行
   docker-compose up -d es03 
   ```
7. 连接测试
   ```bash
   # 查看当前节点信息
   curl --cacert /data/es/certs/ca/ca.crt -uelastic:esjJIV0VCGlEkzfI8mfJN6 https://localhost:9200
   
   # 查看所有节点：
   curl --cacert /data/es/certs/ca/ca.crt -uelastic:esjJIV0VCGlEkzfI8mfJN6 https://localhost:9200/_cat/nodes
   ```
8. 部署kibana, 在es01上启动kibana
   ```bash
   docker-compose up -d kibana 
   ```
   访问：http://es-001:5601/

### 采集k8s日志
1. 在k8s的kube-system命名空间下创建TLS 证书Secret，取名为 es-cert-ca，将生成的ca证书上传
2. 修改 filebeat-kubernetes.yaml ，修改文件中工作负载的环境变量:
   - ELASTICSEARCH_HOST
   - ELASTICSEARCH_PORT
   - ELASTICSEARCH_USERNAME
   - ELASTICSEARCH_PASSWORD
3. 应用该文件开始采集
   ```bash
   kubectl apply -f filebeat-kubernetes.yaml
   ```

## 常用命令
```bash
# 查看所有节点
curl --cacert /data/es/certs/ca/ca.crt -uelastic:esjJIV0VCGlEkzfI8mfJN6 https://localhost:9200/_cat/nodes

# 查看所有索引
curl --cacert /data/es/certs/ca/ca.crt -uelastic:esjJIV0VCGlEkzfI8mfJN6 https://localhost:9200/_cat/indices?v

# 删除索引
curl -X DELETE --cacert /data/es/certs/ca/ca.crt -uelastic:esjJIV0VCGlEkzfI8mfJN6 https://localhost:9200/your_index_name

# 查看所有datastream
curl --cacert /data/es/certs/ca/ca.crt -uelastic:esjJIV0VCGlEkzfI8mfJN6 https://localhost:9200/_data_stream

# 删除datastream
curl -X DELETE --cacert /data/es/certs/ca/ca.crt -uelastic:esjJIV0VCGlEkzfI8mfJN6 https://localhost:9200/_data_stream/filebeat-ng-test-2025.07.07
```

## 注意点
es在创建索时会以UTC时区来进行日期分隔，比如: 
 - test-applications-2025.07.07
 - test-applications-2025.07.08
 - test-applications-2025.07.09

这会导致一个问题 test-applications-2025.07.09 这个索引实际上是在北京时间的早上 2025.07.09 08:00 创建的，也就意味着你想查询 2025.07.09 08:00 前的数据，需要在索引 test-applications-2025.07.08 中去查询。

 - 如果是直接在 Kibana Discover 中查询，直接选择时间段就行，Kibana 默认使用时区为浏览器时区，不用管背后是用的哪个索引。
 - 如果是在索引列表中查询则需要注意上述问题。
 - 但如果是要按日期删除前一日的索引，这就会导致当日会丢失08:00之前的数据。


## 参考资料
官方compose：https://www.elastic.co/docs/deploy-manage/deploy/self-managed/install-elasticsearch-docker-compose

SSL配置：https://www.elastic.co/docs/reference/beats/filebeat/securing-communication-elasticsearch

多行日志：https://www.elastic.co/docs/reference/beats/filebeat/multiline-examples

## 异常

查询时出现异常:

```bash
The length [1233766] of field [message] in doc[2]/index[.ds-filebeat-9.0.3-2025.07.05-000001] exceeds the [index.highlight.max_analyzed_offset] limit [1000000]. To avoid this error, set the query parameter [max_analyzed_offset] to a value less than index setting [1000000] and this will tolerate long field values by truncating them.
```

解决：

```bash
PUT .ds-filebeat-9.0.3-2025.07.05-000001/_settings
{
  "index.highlight.max_analyzed_offset": 10000000
}
```

继续报错：

```bash
Can't store an async search response larger than [10485760] bytes. This limit can be set by changing the [search.max_async_search_response_size] setting.
```

解决：

```bash
PUT _cluster/settings
{
  "persistent": {
    "search.max_async_search_response_size": "50mb"
  }
}
```

## 优化
我的3节点es集群都是4C8G的机器，磁盘iops 3000, 吞吐量 125，通过监控发现io读基本占满3000，cpu以及负载都比较高。

将jvm参数从-Xms1g -Xmx1g改为了-Xms2g -Xmx2g，iops降低了些，但是读吞吐量打满了125

将jvm参数修改为了-Xms4g -Xmx4g，iops读依然会被打满，吞吐量也会打满

还是要加一层kafka来作为缓冲，还可以保证当es集群故障时，日志不丢失，但需要同时增加kafka和logstash相应需要的资源也更多。

### 设置默认副本数为0
es默认会有1个主分片，1个副分片，一共会有2份数据，虽然对数据安全有有保障，但如果数据量大，对存储压力很大，且对存储的io读压力很大。

修改默认副本数为0，新创建的索引将会执行此规则：
```bash
PUT _index_template/default-no-replicas
{
    "index_patterns": ["test-*"],
    "template": {
        "settings": {
            "number_of_replicas": "0"
        }
    },
    "priority": 1
}
```
对当前索引设置副本为0：
```bash
PUT test-applications-2025.07.16/_settings
{
    "index": {
        "number_of_replicas": 0
    }
}
```

### 设置刷新频率
每写一次默认 1s 刷新，导致频繁磁盘 flush。
```bash
PUT your-index-pattern*/_settings
{
  "index": {
    "refresh_interval": "30s"
  }
}
```
可以和设置默认副本数为0同时设置：
```json
{
  "index": {
    "number_of_replicas": "0",
    "refresh_interval": "30s"
  }
}
```
### 移动索引到指定节点
集群运行过程中可能会出现某个节点安置了多个索引，其他节点就比较闲，这时我们可以手动将指定的索引移动到闲一点的节点，分担压力。
#### 手动方式
```bash
POST _cluster/reroute
{
  "commands": [
    {
      "move": {
        "index": "your-index-name",
        "shard": 0,
        "from_node": "es-node-1",
        "to_node": "es-node-2"
      }
    }
  ]
}
```
#### 自动方式
GET _cluster/settings?include_defaults=true
检查 "cluster.routing.allocation.enable": "all" 则为启用状态。
但实际上可能仍然不均衡。
 - all：默认，允许所有迁移。
 - primaries：只允许主分片分配。
 - new_primaries：仅允许新创建索引的主分片分配。
 - none：禁止所有分片的自动分配（包括迁移、恢复等）。
```bash
# 关闭集群分片自动分配
PUT _cluster/settings
{
  "persistent": {
    "cluster.routing.allocation.enable": "none"
  }
}
```




手动触发自动均衡：
```bash
POST _cluster/reroute?pretty
```
这不会改变设置，而是让集群立刻评估是否有需要迁移的分片。


临时排除当前负载高的节点
```bash
PUT _cluster/settings
{
  "transient": {
    "cluster.routing.allocation.exclude._name": "es02"
  }
}
```
注意：此操作会排空指定节点上的索引，直至其他节点无法接收。

恢复设置
```bash
PUT _cluster/settings
{
  "transient": {
    "cluster.routing.allocation.exclude._name": ""
  }
}
```