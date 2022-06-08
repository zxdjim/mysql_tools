#!/bin/bash
## v1 baider 20220526
## 说明 $1(ip:port)参数可获取任一redis集群的信息
##      $2(-1:all 0:slave 1:master) 参数指定要在哪些节点执行脚本
##      $3(要执行的脚本路径) 如果此参数为空,则只打印出节点信息而不执行任何脚本

v_redis="/usr/bin/redis-cli"
token="yD1fVziT4svT4rtKzuN1"
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
   echo -e "\033[34;40mall:\033[0m"
elif [ $2 == "0" ]; then
   ##获取集群的slave节点信息
   NODES=$(redis-cli -c -h $ip -p $port -a $token cluster nodes 2>/dev/null|grep slave|awk '{print $2}'|awk -F'@' '{print $1}')
   echo -e "\033[34;40mslave:\033[0m"
elif [ $2 == "1" ]; then
   ##获取集群的master节点信息
   NODES=$(redis-cli -c -h $ip -p $port -a $token cluster nodes 2>/dev/null|grep master|awk '{print $2}'|awk -F'@' '{print $1}')
   echo -e "\033[34;40mmaster:\033[0m"
else
   echo -e "\033[34;40m第二个参数必须为-1/0/1 (-1:all 0:slave 1:master),请重新传入参数!!!\033[0m"
   exit
fi

if [[ ! -f $3 ]] && [[ ! -z $3 ]]; then
   echo -e "\033[34;40m第三个参数绝对路径文件名不存在,请重新传入参数(可为空,则只打印出节点信息而不执行任何脚本)!!!\033[0m"
   exit
fi

if [[ -z $3 ]]; then
   v_prt="获取所有节点信息"
else
   v_prt="执行脚本"
fi

echo -e "\033[34;40m${v_prt}开始...\033[0m"
nl=$(echo "$NODES" |wc -l)
for ((i=1; i<=$nl; i++))
do
   host_port=$(echo "$NODES" |head -$i |tail -1)
   v_ip=${host_port%:*}
   v_port=${host_port#*:}
   echo -e "\033[34;40m${host_port}\033[0m"
   if [[ -f $3 ]]; then
      redis-cli -a ${token} -c -h ${v_ip} -p ${v_port} 2>/dev/null < $3
   fi
done
echo -e "\033[34;40m${v_prt}完成!!!\033[0m"