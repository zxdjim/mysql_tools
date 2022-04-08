#!/bin/bash
#author:pis
#删除mysql slow.log error.log

current_dt=`date +%Y%m%d`
#删除30天前的日志
delete_dt=`date -d "7 days ago" +%Y%m%d`

mysql_ports=(6656)
for mysql_port in  ${mysql_ports[*]}
do
mysql_logs_dir="/data/mysql_${mysql_port}"
mysql_logs_bak="/data/mysqllogsbak/${mysql_port}"

if [ ! -x $mysql_logs_dir ]; then
  echo "数据库 ${mysql_port} 不存在"
  continue
fi

#创建日志备份目录
if [ ! -x $mysql_logs_bak ]; then
  mkdir -p $mysql_logs_bak
fi


log_name="slow"
cp ${mysql_logs_dir}/${log_name}.log ${mysql_logs_bak}/${log_name}_${current_dt}.log
cat /dev/null > ${mysql_logs_dir}/${log_name}.log
rm -rf ${mysql_logs_bak}/${log_name}_${delete_dt}.log

log_name="error"
cp ${mysql_logs_dir}/${log_name}.log ${mysql_logs_bak}/${log_name}_${current_dt}.log
cat /dev/null > ${mysql_logs_dir}/${log_name}.log
rm -rf ${mysql_logs_bak}/${log_name}_${delete_dt}.log

done



