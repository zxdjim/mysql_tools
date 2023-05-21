#! /usr/bin
## 源端TIDB要开启bin_log,否则会报异常

user=root
#### 配置源和目标的IP等
source_ip=10.105.22.120
source_user=root
source_pwd=dfQWF@E45#93
source_port=4000

target_ip=10.5.37.18
target_user=root
target_pwd=dfQWF@E45#93
target_port=4000

## 要同步的schema_name,前面是源schema,后面紧跟的是目标schema
#(源和目标schema,两者可相同也可不同),task_name取源schema名称
## schema_name=('source_schema','target_schema')
schema_name=('dj_report','dj_report_new')

########################################## 开始安装及配置
## 安装TIUP软件
curl --proto '=https' --tlsv1.2 -sSf https://tiup-mirrors.pingcap.com/install.sh | sh

## 更新环境变量
source /root/.bash_profile

## 查看版本，校验是否安装成功
tiup --version

mkdir -p /data/soft && mkdir -p /data/dm/dm-deploy && mkdir -p /data/dm/dm-data

echo -e "\033[34;40m 请输入本机${user}机器密码...\033[0m"
## 安装TIDB-DM 集群
cat >/data/soft/topology.yaml <<EOF
global:
 user: "${user}"
 ssh_port: 22
 deploy_dir: "/data/dm/dm-deploy"
 data_dir: "/data/dm/dm-data"

master_servers:
 - host: 127.0.0.1

worker_servers:
 - host: 127.0.0.1
   port: 8262
 - host: 127.0.0.1
   port: 8263
 - host: 127.0.0.1
   port: 8264

monitoring_servers:
 - host: 127.0.0.1

grafana_servers:
 - host: 127.0.0.1
EOF
 
##3安装
tiup dm deploy ob-dm v5.3.0 /data/soft/topology.yaml --user root -p

#4启动集群
tiup dm start ob-dm

#5启动后查询集群状态
tiup dm display ob-dm

# 6 配置任务->配置数据源
cat >/data/soft/ds.yaml <<EOF
source-id: "tidb"
from:
  host: "${source_ip}"
  user: "${source_user}"
  password: "${source_pwd}"
  port: ${source_port}
EOF

tiup dmctl --master-addr=127.0.0.1:8261 operate-source create /data/soft/ds.yaml

### 7 配置schema的任务,这里默认就使用DB中的root用户,只是权限比较大一些,当然也可以在上下游新创建一个DM用户
#GRANT RELOAD,REPLICATION SLAVE, REPLICATION CLIENT ON *.* TO 'your_user'@'your_wildcard_of_host'
#GRANT SELECT ON db1.* TO 'your_user'@'your_wildcard_of_host';

len=${#schema_name[*]}
for((i=0;i<len-1;i+=2))
do
  source_schema=${schema_name[i]}
  target_schema=${schema_name[i+1]}
cat >/data/soft/${source_schema}.yaml <<EOF
name: ${source_schema}
task-mode: all

target-database:
  host: "${target_ip}"
  user: "${target_user}"
  password: "${target_pwd}"
  port: ${target_port}
  
mysql-instances:
  - source-id: "tidb"
    block-allow-list: "account-rule1"
    route-rules: ["route-rule1"]

block-allow-list:
  account-rule1:
    do-dbs: ["${source_schema}"]

routes:
  route-rule1:
    schema-pattern: "${source_schema}"
    target-schema:  "${target_schema}"
EOF

# 启动
tiup dmctl --master-addr=127.0.0.1:8261 start-task /data/soft/${source_schema}.yaml

done

