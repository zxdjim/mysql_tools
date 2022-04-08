#!/bin/bash
#author:pis

current_dt=`date +%Y%m%d`
delete_dt=`date -d "7 days ago" +%Y%m%d`
cetus_logs_dir="/usr/local/cetus/logs"
log_name="cetus"

cp ${cetus_logs_dir}/${log_name}.log ${cetus_logs_dir}/${log_name}_${current_dt}.log
cat /dev/null > ${cetus_logs_dir}/${log_name}.log

rm -rf ${cetus_logs_dir}/${log_name}_${delete_dt}.log

