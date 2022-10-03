#!/bin/bash
#auth:baider
## 当主库异常时或想手工切换主从时候手工执行脚本重建主从关系
## sh rebuild_sync.sh 10.105.11.50:6606 0/1 10.105.11.7:6606 0/1
## 参数一为源IP和端口                   新主库
## 参数二为新主库是否要清理旧的主从关系 0-否,1-是
## 参数三为目标IP和端口                 新从库
## 参数四为是否要重新克隆               0-否,1-是

if [[ "$#" != "4" ]]; then
   echo -e "\033[34;40m 必须传入4个参数,请确认后再执行!!!\033[0m"
   exit 0
fi

source_ip=${1%%:*}
source_port=${1##*:}
target_ip=${3%%:*}
target_port=${3##*:}
user=root
psswd="3ut7vth79nvNNFiCmyvX"
repl_pwd="2KjhoejznA298vJHvcQk"

if [[ $2 == "1" ]]; then
  echo -e "\033[34;40m等待5秒后,开始清理【${1}】旧的主从关系...\033[0m"
  sleep 5
  mysql -u${user} -p${psswd}  -h${source_ip} -P${source_port} -e "stop slave;reset slave all;"
  echo -e "\033[34;40m完成清理【${1}】旧的主从关系!!!\033[0m"
fi

if [[ $4 == "1" ]]; then
  echo -e "\033[34;40m等待5秒后,开始主库的克隆...\033[0m"
  sleep 5
  mysql -u${user} -p${psswd}  -h${target_ip} -P${target_port} -e "SET GLOBAL clone_valid_donor_list = '${source_ip}:${source_port}';"
  mysql -uclone   -pclone@123 -h${target_ip} -P${target_port} -e "clone instance from 'clone'@'${source_ip}':${source_port} identified by 'clone@123';"
  echo -e "\033[34;40m完成主库的克隆!!!\033[0m"
  ### 这里休眠时间一定要长一些,保证MYSQL服务能正常重启成功
  sleep 200
fi

echo -e "\033[34;40m准备开始:新主库【${1}】,新从库【${3}】\033[0m"
echo -e "\033[34;40m等待5秒后,开始调整新的主从关系...\033[0m"
sleep 5
mysql -u${user} -p${psswd} -h${target_ip} -P${target_port} -e \
"stop slave;reset slave all;change master to MASTER_HOST='${source_ip}', MASTER_PORT=${source_port}, MASTER_USER ='repl',MASTER_PASSWORD='${repl_pwd}',MASTER_AUTO_POSITION =1;start slave;"
echo -e "\033[34;40m完成调整新的主从关系!!!\033[0m"

sleep 5
echo -e "\033[34;40m查询一次新的主从延迟情况...\033[0m"
mysql -u${user} -p${psswd} -h${target_ip} -P${target_port} -e "show slave status \G" 2>/dev/null|grep "Yes\|Second" --color
