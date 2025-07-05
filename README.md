## 简介
本项目可以使用docker快速构建起一个3节点的es集群，然后采集所有k8s节点的日志，使用kibana进行日志查询。

## 使用方式
### 主机设置
1. 修改主机名
   ```bash
   hostnamectl set-hostname es01
   hostnamectl set-hostname es02
   hostnamectl set-hostname es03 
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
3. 修改.env文件中的有关变量，主要包括：ELASTIC_PASSWORD, KIBANA_PASSWORD, STACK_VERSION, ES01_HOST_IP, ES02_HOST_IP, ES03_HOST_IP
4. 在es01节点上首先启动容器 setup 用于创建证书
   ```bash
   docker-compose up -d setup 
   ```
5. 将创建的证书拷贝到es02, es03主机相同目录
   ```bash
   scp -r /data/es/certs/ es02_host:/data/es/
   scp -r /data/es/certs/ es03_host:/data/es/ 
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
7. 部署kibana, 在es01上启动kibana
   ```bash
   docker-compose up -d kibana 
   ```
   访问：http://es01_host:5601/

### 采集k8s日志
1. 在k8s的kube-system命名空间下创建TLS 证书Secret，取名为es-cert-ca，将生成的ca证书上传
2. 修改 filebeat-kubernetes.yaml ，修改文件中工作负载的环境变量 ELASTICSEARCH_HOST, ELASTICSEARCH_PORT, ELASTICSEARCH_USERNAME, ELASTICSEARCH_PASSWORD
3. 应用该文件开始采集
   ```bash
   kubectl apply -f filebeat-kubernetes.yaml
   ```
## 参考资料
官方compose：https://www.elastic.co/docs/deploy-manage/deploy/self-managed/install-elasticsearch-docker-compose

SSL配置：https://www.elastic.co/docs/reference/beats/filebeat/securing-communication-elasticsearch

多行日志：https://www.elastic.co/docs/reference/beats/filebeat/multiline-examples