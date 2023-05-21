#!/bin/bash
## v1 kaiens 20220524
##执行前需要调整一下默认的端口和密码；
##传递一个参数：需要删除的key
## v2 baider 20220526
## 说明 $1(ip:port)参数可获取任一redis集群的信息
##      $2(-1:all 0:slave 1:master) 参数指定要在哪些节点执行脚本
##      $3(要执行unlink的key)   
##      $4(如果是unlink的key删除，此值说明是带双引号的key 0:否 1:是)
## sh unlink_redis.sh 127.0.0.1:7400 -1 '\"abc*\"' 1
## sh unlink_redis.sh 127.0.0.1:7400 -1 abc* 0

v_redis="/usr/bin/redis-cli"
token="xxxyyy"
ip=${1%:*}
port=${1#*:}


error()
{
    echo "$1" 1>&2
    exit 1
}

# 检查执行环境
if [ ! -x $v_redis ]; then
  error "${v_redis}未安装或未链接到/usr/bin."
fi

if [ $2 == "-1" ]; then
   ##获取集群的所有节点信息
   NODES=$(redis-cli -c -h $ip -p $port -a $token cluster nodes 2>/dev/null|awk '{print $2}'|awk -F'@' '{print $1}')
elif [ $2 == "0" ]; then
   ##获取集群的slave节点信息
   NODES=$(redis-cli -c -h $ip -p $port -a $token cluster nodes 2>/dev/null|grep slave|awk '{print $2}'|awk -F'@' '{print $1}')
elif [ $2 == "1" ]; then
   ##获取集群的master节点信息
   NODES=$(redis-cli -c -h $ip -p $port -a $token cluster nodes 2>/dev/null|grep master|awk '{print $2}'|awk -F'@' '{print $1}')
else
   echo -e "\033[34;40m第二个参数必须为-1/0/1 (-1:all 0:slave 1:master),请重新传入参数!!!\033[0m"
   exit
fi

if [[ -z $3 ]] || [[ $3 == "*" ]]; then
   echo -e "\033[34;40m第三个参数(要执行unlink的模糊key前缀)必须不为*或空,请重新传入参数!!!\033[0m"
   exit
fi

echo -e "\033[34;40m开始循环节点执行unlink...\033[0m"
nl=$(echo "$NODES" |wc -l)
for ((i=1; i<=$nl; i++))
do
   host_port=$(echo "$NODES" |head -$i |tail -1)
   v_ip=${host_port%:*}
   v_port=${host_port#*:}
   echo -e "\033[34;40m${host_port}\033[0m"
   if [ $4 == "1" ]; then
     redis-cli -h ${v_ip} -p ${v_port} --no-auth-warning -a $token --scan --pattern "'${3}'" |sed 's/.$//'|sed 's/^/\\/'|sed 's/.$//'|sed 's/$/\\"/'|xargs -i redis-cli -h ${v_ip} -p ${v_port} --no-auth-warning -a $token unlink {}
   else
     redis-cli -h ${v_ip} -p ${v_port} --no-auth-warning -a $token --scan --pattern ${3} |xargs -i redis-cli -h ${v_ip} -p ${v_port} --no-auth-warning -a $token unlink {}
   fi
done
echo -e "\033[34;40m所有节点unlink执行完毕!!!\033[0m"
