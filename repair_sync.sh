#!/bin/bash
## 用于Got fatal error 1236 from master when reading data from binary log: 'Cannot replicate because the master purged required binary logs. 
## Replicate the missing transactions from elsewhere, or provision a new slave from backup. Consider increasing the master's binary log expiration period.
## To find the missing transactions, see the master's error log or the manual for GTID_SUBTRACT  异常报表,修复主从关系

if [[ "$#" -lt 4 ]]; then
   echo -e "\033[34;40m 必须传入4个以上参数,请确认后再执行!!!\033[0m"
   exit 0
fi

source_ip=${1%%:*}
source_port=${1##*:}
target_ip=${3%%:*}
target_port=${3##*:}
user=root
psswd="3ut7vth79nvNNFiCmyvX"
repl_pwd="2KjhoejznA298vJHvcQk"
mid_psswd="Rt57qHm8Xp91aFo3uExD"

v_source=(mysql -u${user} -p${psswd}  -h${source_ip} -P${source_port} -e "select @@global.gtid_purged\G;" 2>/dev/null|sed "s/@@global.gtid_purged: //g"|sed "1d")
if [[ ${v_source} ]]; then
   s_array=(${v_source//,/ })
   for s_var in ${s_array[@]}
   do
   v_target=(mysql -u${user} -p${psswd}  -h${target_ip} -P${target_port} -e "select @@global.gtid_executed\G;" 2>/dev/null|sed "s/@@global.gtid_executed: //g"|sed "1d")
   if [[ ${v_target} ]]; then
      t_array=(${v_target//,/ })
      for t_var in ${t_array[@]}
      do
	     if [[ ${s_var} == ${t_var} ]]; then
		    v_list="${v_list}${s_var},"
		 else
		    s_2=$(${s_var##*:}|cut -d'-')
		    if [[ ${s_var%%:*} == ${t_var%%:*} ]] && [[ ${s_var%%:*} == ${t_var%%:*} ]]  
			
		 fi
	  done
   fi
   done
fi
