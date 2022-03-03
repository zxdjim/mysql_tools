#!/bin/bash
#baider:20210806
#用于自动化安装mysql 8.0.X服务 第一参数为版本号,第二参数为端口号

if [ ! "$1" ]; then
 echo -e "\033[34;40m 请传入版本号,再重新执行!!!\033[0m"
 exit 1
fi

if [ ! "$2" ]; then
 echo -e "\033[34;40m 请传入端口号,再重新执行!!!\033[0m"
 exit 1
fi

echo -e "\033[34;40m 脚本开始执行...\033[0m"
mdb=$(rpm -qa |grep mariadb)
rpm -e --allmatches --nodeps $mdb 2>/dev/null 

### 只检测是否存在mysql
if [ ! -d /usr/local/mysql ]; then
#1.文件下载
echo -e "\033[34;40m 【1.文件下载...】\033[0m"
mkdir -p /data/soft && cd /data/soft
wget --no-check-certificate https://dev.mysql.com/get/Downloads/MySQL-8.0/mysql-$1-el7-x86_64.tar.gz

if [[ ! -e mysql-$1-el7-x86_64.tar.gz ]]; then
  echo "mysql-$1-el7-x86_64.tar.gz 文件不存在,请上传此文件或下载"
  exit 1
fi

#2.解压移动及创建目录
echo -e "\033[34;40m 【2.解压移动及创建目录...】\033[0m"
tar -zxvf mysql-$1-el7-x86_64.tar.gz
mv ./mysql-$1-el7-x86_64 /usr/local/mysql


#3.创建数据库用户：
echo -e "\033[34;40m 【3.创建数据库用户...】\033[0m"
groupadd mysql
useradd -r -g mysql -s /bin/false mysql
fi


if [ ! -f /usr/local/mysql/mysql$2.cnf ]; then
#4 创建mysql配置文件
echo -e "\033[34;40m 【4.创建mysql端口号($2) 配置文件...】\033[0m"
cat >/usr/local/mysql/mysql$2.cnf <<EOF
[client]
port	= $2
socket	= /data/mysql_$2/mysql.sock

[mysql]
prompt="\u@mysqldb \R:\m:\s [\d]> "
no-auto-rehash
socket	= /data/mysql_$2/mysql.sock

[mysqld]
user	= mysql
port	= $2
mysqlx_port = 1${2}
basedir	= /usr/local/mysql
datadir	= /data/mysql_$2
socket	= /data/mysql_$2/mysql.sock
pid-file = /data/mysql_$2/mysqldb.pid
character-set-server = utf8mb4

collation-server = utf8mb4_0900_as_cs
#collation-server = utf8mb4_bin
skip_name_resolve = 1
#
default-authentication-plugin=mysql_native_password
#是否不区分大小写(0:否 1:是)
lower-case-table-names = 1
autocommit = 1
group_concat_max_len = 10240
default-time-zone='+8:00'

range_optimizer_max_mem_size=0
innodb_adaptive_hash_index=0
innodb_status_output=0
information_schema_stats_expiry=0
event_scheduler=1
## 不限制mysqld在任意目录的导入导出
secure_file_priv=''
#############主从复制
sql_mode='STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION'
gtid-mode=on
enforce-gtid-consistency=on
log-slave-updates=on
slave-parallel-type=LOGICAL_CLOCK
slave-parallel-workers=8
log_bin_trust_function_creators=1
###################关闭binlog
#skip-log-bin

open_files_limit    = 65535
back_log = 1024
max_connections = 20000
max_connect_errors = 1000000
table_open_cache = 25000
table_definition_cache = 25000
table_open_cache_instances = 64
thread_stack = 512K
external-locking = FALSE
max_allowed_packet = 128M
sort_buffer_size = 4M
join_buffer_size = 4M
thread_cache_size = 768
interactive_timeout = 28800
wait_timeout = 28800
tmp_table_size = 2G
max_heap_table_size = 2G
slow_query_log = 1
log_timestamps = SYSTEM
slow_query_log_file = /data/mysql_$2/slow.log
log-error = /data/mysql_$2/error.log
long_query_time = 2
log_queries_not_using_indexes =1
log_throttle_queries_not_using_indexes = 60
min_examined_row_limit = 10000
log_slow_admin_statements = 1
log_slow_slave_statements = 1
server-id = ${2}0
log-bin = /data/mysql_$2/mybinlog
sync_binlog = 1
binlog_cache_size = 4M
max_binlog_cache_size = 2G
max_binlog_size = 1G
master_info_repository = TABLE
relay_log_info_repository = TABLE
log_slave_updates
slave-rows-search-algorithms = 'INDEX_SCAN,HASH_SCAN'
binlog_format = row
binlog_checksum = 1
#relay-log=/data/mysql_$2/$2-relay-bin
relay_log_recovery = 1
relay-log-purge = 1
key_buffer_size = 32M
read_buffer_size = 8M
read_rnd_buffer_size = 4M
bulk_insert_buffer_size = 64M
myisam_sort_buffer_size = 128M
myisam_max_sort_file_size = 10G
myisam_repair_threads = 1
lock_wait_timeout = 3600
explicit_defaults_for_timestamp = 1
innodb_thread_concurrency = 0
innodb_sync_spin_loops = 100
innodb_spin_wait_delay = 30

transaction_isolation = READ-COMMITTED
innodb_buffer_pool_size = 200G
innodb_buffer_pool_instances = 4
innodb_buffer_pool_load_at_startup = 1
innodb_buffer_pool_dump_at_shutdown = 1
innodb_data_file_path = ibdata1:1G:autoextend
innodb_temp_data_file_path=ibtmp1:12M:autoextend:max:50G
innodb_flush_log_at_trx_commit = 1
innodb_log_buffer_size = 32M
innodb_log_file_size = 2G
innodb_log_files_in_group = 2
innodb_max_undo_log_size = 4G
innodb_undo_directory = /data/mysql_$2/undolog
innodb_undo_log_truncate=ON
innodb_undo_tablespaces=3 
innodb_purge_rseg_truncate_frequency = 20

# 根据您的服务器IOPS能力适当调整
# 一般配普通SSD盘的话，可以调整到 10000 - 20000
# 配置高端PCIe SSD卡的话，则可以调整的更高，比如 50000 - 80000
innodb_io_capacity = 10000
innodb_io_capacity_max = 15000
innodb_flush_sync = 0
innodb_flush_neighbors = 0
innodb_write_io_threads = 24
innodb_read_io_threads = 24
innodb_purge_threads = 4
innodb_page_cleaners = 4
innodb_open_files = 65535
innodb_max_dirty_pages_pct = 75
innodb_flush_method = O_DIRECT
innodb_lru_scan_depth = 4000
innodb_checksum_algorithm = crc32
innodb_lock_wait_timeout = 10
innodb_rollback_on_timeout = 1
innodb_print_all_deadlocks = 1
innodb_file_per_table = 1
innodb_online_alter_log_max_size = 4G
innodb_stats_on_metadata = 0


# some var for MySQL 8
log_error_verbosity = 3
innodb_print_ddl_logs = 1
binlog_expire_logs_seconds = 86400
#innodb_dedicated_server = 0

innodb_status_file = 1
#注意: 开启 innodb_status_output & innodb_status_output_locks 后, 可能会导致log-error文件增长较快
innodb_status_output = 0
innodb_status_output_locks = 0

#performance_schema
performance_schema = 1
performance_schema_instrument = '%memory%=on'
performance_schema_instrument = '%lock%=on'

#innodb monitor
innodb_monitor_enable="module_innodb"
innodb_monitor_enable="module_server"
innodb_monitor_enable="module_dml"
innodb_monitor_enable="module_ddl"
innodb_monitor_enable="module_trx"
innodb_monitor_enable="module_os"
innodb_monitor_enable="module_purge"
innodb_monitor_enable="module_log"
innodb_monitor_enable="module_lock"
innodb_monitor_enable="module_buffer"
innodb_monitor_enable="module_index"
innodb_monitor_enable="module_ibuf_system"
innodb_monitor_enable="module_buffer_page"
innodb_monitor_enable="module_adaptive_hash"

[mysqldump]
quick
max_allowed_packet = 128M
EOF

fi


if [ ! -d /data/mysql_$2 ]; then
mkdir -p /data/mysql_$2
lb=$(rpm -qa|grep libaio)
if [ ! "$lb" ]; then
  yum install -y libaio
fi 
#5.初始化数据库:
echo -e "\033[34;40m 【5.初始化数据库...】\033[0m"
cd /usr/local/mysql/bin
./mysqld --defaults-file=/usr/local/mysql/mysql$2.cnf --initialize --user=mysql

chown -R mysql:mysql /data/mysql_$2

#6.启动mysql服务: -sb 覆盖软链接
echo -e "\033[34;40m 【6.启动mysql服务...】\033[0m"
ln -sb /usr/local/mysql/bin/mysqld_safe   /usr/bin/
ln -sb /usr/local/mysql/bin/mysql         /usr/bin/
ln -sb /usr/local/mysql/bin/mysqladmin    /usr/bin/
ln -sb /usr/local/mysql/bin/mysqld        /usr/bin/
ln -sb /usr/local/mysql/bin/mysqldump     /usr/bin/
ln -sb /usr/local/mysql/bin/mysqlbinlog   /usr/bin/
ln -sb /usr/local/mysql/bin/mysqldumpslow /usr/bin/

### 取出临时密码前把前后的空格删除
tmp_pwd=$(cat /data/mysql_$2/error.log | grep 'temporary password'|cut -d":" -f5-10|awk '{gsub(/^\s+|\s+$/,"");print}')
nohup mysqld_safe --defaults-file=/usr/local/mysql/mysql$2.cnf 2>/dev/null &

echo "请进入mysql后马上修改临时密码,其值为${tmp_pwd}"
fi

echo -e "\033[34;40m 脚本结束!!!\033[0m"
