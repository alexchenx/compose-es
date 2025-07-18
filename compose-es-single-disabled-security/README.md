## 简介
本项目可以使用docker快速构建起一个单节点的es，然后采集k8s指定namespace的日志，使用kibana进行日志查询。

如何部署：
 - 方式一：filebeat -> elasticsearch - kibana
 - 方式二：filebeat -> kafka -> logstash -> elasticsearch - kibana

如果日志量不大，可以直接选择方式一，结构简单高效，资源占用更少，当日志量大时，可能会有io问题，此时可考虑方式二。

## 使用方式
### 主机设置
1. 设置主机名
   ```bash
   hostnamectl set-hostname es-001
   ```
2. 设置系统参数
    ```bash
    echo "vm.max_map_count=262144" | sudo tee -a /etc/sysctl.conf
    sysctl -p
    ```
3. 创建所需目录并授权
    ```bash
    mkdir -p /data/es/{esdata,kibanadata,kafkadata} && chown -R 1000:1000 /data/es
    ```

### 项目设置
1. 修改 .env 文件中的有关变量
2. 如果用方式二部署，需修改 logstash.conf 中的相应配置
3. 启动服务，根据选择的部署方式来启动服务
   ```bash
   # 方式一
   docker-compose up -d elasticsearch kibana
   
   # 方式二
   docker-compose up -d kafka kafka_ui elasticsearch logstash kibana
   ```
4. 连接测试
   ```bash
   # 查看当前节点信息
   curl http://localhost:9200
   
   # 查看所有节点：
   curl http://localhost:9200/_cat/nodes
   ```
5. 访问 Kibana: http://es-001:5601/

### 采集k8s日志
1. 修改 filebeat-kubernetes.yaml ，根据部署方式进行修改。
2. 应用该文件开始采集
   ```bash
   kubectl apply -f filebeat-kubernetes.yaml
   ```

## 常用命令
```bash
# 查看所有节点
curl http://localhost:9200/_cat/nodes

# 查看所有索引
curl http://localhost:9200/_cat/indices?v

# 删除索引
curl -X DELETE http://localhost:9200/your_index_name

# 查看所有datastream
curl http://localhost:9200/_data_stream

# 删除datastream
curl -X DELETE http://localhost:9200/_data_stream/filebeat-ng-test-2025.07.07
```
