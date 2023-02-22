#!/bin/bash
## v1 baider 20220526
## 说明 $1(ip:port)参数可获取任一redis集群的信息
##      $2(-1:all 0:slave 1:master) 参数指定要在哪些节点执行脚本
##      $3倒序后取cid类型 0:top n 1:字节数 n
##      $4类型后的n值

v_redis="/usr/bin/redis-cli"
token="xxxyyyy"
ip=${1%:*}
port=${1#*:}
v_info="client list"

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
   echo -e "all"
elif [ $2 == "0" ]; then
   ##获取集群的slave节点信息
   NODES=$(redis-cli -c -h $ip -p $port -a $token cluster nodes 2>/dev/null|grep slave|awk '{print $2}'|awk -F'@' '{print $1}')
   echo -e "slave"
elif [ $2 == "1" ]; then
   ##获取集群的master节点信息
   NODES=$(redis-cli -c -h $ip -p $port -a $token cluster nodes 2>/dev/null|grep master|awk '{print $2}'|awk -F'@' '{print $1}')
   echo -e "master"
else
   echo -e "第二个参数必须为-1/0/1 (-1:all 0:slave 1:master),请重新传入参数!!!"
   exit
fi


if [[ -z $3 ]] || [ $3 -ne 0 -a $3 -ne 1 ] ; then
      echo -e "第3个参数必须传入且为数字(0/1),请重新传入参数!!!"
   exit
fi

if [[ -z $4 ]] || [ $4 -le 0 ]; then
      echo -e "第4个参数必须传入且大于0,请重新传入参数!!!"
   exit
fi

echo -e "${v_prt}开始..."
nl=$(echo "$NODES" |wc -l)
for ((i=1; i<=$nl; i++))
do
   host_port=$(echo "$NODES" |head -$i |tail -1)
   v_ip=${host_port%:*}
   v_port=${host_port#*:}
   echo -e "${host_port}"
   redis-cli -a ${token} -c -h ${v_ip} -p ${v_port} ${v_info} 2>/dev/null|grep -i "omem=[0-9]"|cut -d' ' -f 1,16|sort -k 2.6nr -t " " > sort_temp.sql
   if [ $3 == "0" ]; then
      head -n $4 sort_temp.sql|cut -d' ' -f 1 > sort.sql
      sed -i "s/id=/CLIENT KILL ID /g" `grep "id=" -rl sort.sql`
   elif [ $3 == "1" ]; then
      cat /dev/null > sort.sql
      while read line
      do
         v_id=`echo   ${line}|cut -d " " -f 1|cut -d "=" -f 2`
         v_omem=`echo ${line}|cut -d " " -f 2|cut -d "=" -f 2`
         if [ ${v_omem} -lt $4 ]; then
            break 1
         else
            echo "CLIENT KILL ID ${v_id}" >> sort.sql
         fi
      done < sort_temp.sql
   fi
   redis-cli -a ${token} -c -h ${v_ip} -p ${v_port} 2>/dev/null < sort.sql  
done
echo -e "${v_prt}完成!!!"

