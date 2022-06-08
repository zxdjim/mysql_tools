#!/bin/bash
#baider:20210806
#用于自动化安装redis服务
## $1 端口号 比如 7000等
## $2 版本号 比如 5.0.6/6.2.0等
## $3 0:非持久化 1:混合持久化(AOF和RDB模式)
##demo  sh create_redis_bin.sh 7000 5.0.6 1

passwd="yD1fVziT4svT4rtKzuN1"

if [ $# != 3 ]; then
   echo -e "\033[34;40m 传入的参数必须是3个,请检查后重试!!!\033[0m"
   exit 1
fi

if [ ! "$1" ]; then
   echo -e "\033[34;40m 第一个参数请传入端口号,再重试!!!\033[0m"
   exit 1
fi
if [ $3 == "0" ]; then
   AddConf='save ""\nappendonly no'
elif [ $3 == "1" ]; then
   AddConf='save 900 1\nsave 300 10\nsave 60 10000\nappendonly yes'
else
   echo -e "\033[34;40m 第三个参数是否持久化请输入0(否)或1(是)后,再重试!!!\033[0m"
   exit 1
fi

echo -e "\033[34;40m 脚本开始执行...\033[0m"

if [ ! -e /data/soft/redis-${2}.tar.gz ]; then
	#1.文件下载
	echo -e "\033[34;40m 【1.文件下载...】\033[0m"
	mkdir -p /data/soft && cd /data/soft
	wget http://download.redis.io/releases/redis-${2}.tar.gz
	tar -zxvf redis-${2}.tar.gz
fi

if [ ! -d /usr/local/redis ]; then
	echo -e "\033[34;40m 【2.开始安装...】\033[0m"
	#2.开始安装
	yum -y install gcc gcc-c++ libstdc++-devel && make MALLOC=libc
	cd redis-${2} && make && make install PREFIX=/usr/local/redis

	echo -e "\033[34;40m 【3.内核参数修改...】\033[0m"
#3.内核参数修改
cat >>/etc/sysctl.conf<<EOF
##内核参数修改
vm.overcommit_memory=1
net.core.somaxconn = 511
EOF
cat >>/etc/rc.local <<EOF
echo never > /sys/kernel/mm/transparent_hugepage/enabled
echo never > /sys/kernel/mm/transparent_hugepage/defrag
EOF
fi

if [ ! -d /data/redis_$1 ]; then
	echo -e "\033[34;40m 【4.创建数据目录...】\033[0m"
	#4.创建数据目录&配置文件
	mkdir -p /data/redis_$1
fi

## 关闭redis持久化(save "" 关闭RDB持久化,appendonly no关闭AOF持久化)
##config set save ""
##config set appendonly no

echo -e "\033[34;40m 【5.参数修改......】\033[0m"
cat >/usr/local/redis/${1}.conf << EOF
bind 0.0.0.0
protected-mode yes
port ${1}
tcp-backlog 511
timeout 0
tcp-keepalive 300
daemonize yes
supervised no
pidfile "/var/run/redis_${1}.pid"
loglevel notice
logfile "/data/redis_${1}/${1}.log"
databases 16
always-show-logo yes
EOF
echo -e ${AddConf}>>/usr/local/redis/${1}.conf
cat >>/usr/local/redis/${1}.conf << EOF
appendfilename "appendonly.aof"
stop-writes-on-bgsave-error yes
rdbcompression yes
rdbchecksum yes
dbfilename "dump.rdb"
dir "/data/redis_${1}"
replica-serve-stale-data yes
replica-read-only yes
repl-diskless-sync no
repl-diskless-sync-delay 5
repl-disable-tcp-nodelay no
replica-priority 100
#lazyfree-lazy-eviction no
#lazyfree-lazy-expire no
#lazyfree-lazy-server-del no
replica-lazy-flush no
## appendfsync值为:always(性能最糟),no(性能最好,从不同步),everysec(最多每秒调用一次fsync)
appendfsync everysec
no-appendfsync-on-rewrite no
auto-aof-rewrite-percentage 100
auto-aof-rewrite-min-size 4gb
aof-load-truncated yes
aof-use-rdb-preamble yes
lua-time-limit 5000
cluster-enabled yes
cluster-config-file "nodes-${1}.conf"
cluster-node-timeout 50000
slowlog-log-slower-than 10000
slowlog-max-len 128
#### maxmemory(10G) 惰性删除过期keys  allkeys-lru：淘汰整个键值中最久未使用的键值
maxmemory 10737418240
maxmemory-policy allkeys-lru
lazyfree-lazy-eviction yes
lazyfree-lazy-expire yes
lazyfree-lazy-server-del yes
latency-monitor-threshold 0
notify-keyspace-events ""
hash-max-ziplist-entries 512
hash-max-ziplist-value 64
list-max-ziplist-size -2
list-compress-depth 0
set-max-intset-entries 512
zset-max-ziplist-entries 128
zset-max-ziplist-value 64
hll-sparse-max-bytes 3000
stream-node-max-bytes 4096
stream-node-max-entries 100
activerehashing yes
client-output-buffer-limit normal 0 0 0
client-output-buffer-limit replica 1024mb 256mb 300
client-output-buffer-limit pubsub 1024mb 128mb 300
hz 50
dynamic-hz yes
aof-rewrite-incremental-fsync yes
rdb-save-incremental-fsync yes
maxclients 60000
masterauth "${passwd}"
requirepass "${passwd}"
rename-command FLUSHALL ""
rename-command FLUSHDB  ""
rename-command KEYS     ""
EOF

v_netstat=$(netstat -nltp|grep redis|grep ":${1}")
if [ -z ${v_netstat} ]; then
	echo -e "\033[34;40m 【6.启动redis...】\033[0m"
	#6.启动redis
	cd /usr/local/redis
	./bin/redis-server ${1}.conf &
	ln -sb /usr/local/redis/bin/redis-cli /usr/bin
fi

echo -e "\033[34;40m 【7.启动redis完成,脚本结束】\033[0m"

#8.最后所有节点安装好后创建集群
#redis-cli --cluster create 10.105.11.4:7000 10.105.11.4:7001 10.105.11.5:7000 10.105.11.5:7001 10.105.11.6:7000 10.105.11.6:7001 -a yD1fVziT4svT4rtKzuN1 --cluster-replicas 1
