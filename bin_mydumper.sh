#!/bash/bin
# 记得在命令结束后手动kill掉mydumper进程(带-D守护参数时需要).

# YUM安装

## 配置最新的mysql YUM源仓库
cat >> /etc/yum.repos.d/mysql-community.repo <<EOF
# Enable to use MySQL 8.0
[mysql80-community]
name=MySQL 8.0 Community Server
baseurl=http://repo.mysql.com/yum/mysql-8.0-community/el/7/x86_64/
enabled=0
gpgcheck=0
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-mysql
EOF

## 安装最新的mysql-community-devel(否则在myloader 导入JSON表文件时报错) 
yum --enablerepo=mysql80-community install mysql-community-devel
#yum -y install https://github.com/maxbube/mydumper/releases/download/v0.11.1-6/mydumper-0.11.1-6.el7.x86_64.rpm

yum -y  install glib2-devel  zlib-devel pcre-devel zlib gcc-c++ gcc cmake
mkdir -p /data/soft && cd /data/soft
wget https://github.com/maxbube/mydumper/archive/refs/tags/v0.11.5.tar.gz
tar -xvf v0.11.5.tar.gz
cd mydumper-0.11.5/
cmake . && make && make install
ln -sb /usr/local/bin/mydumper /usr/bin/mydumper
ln -sb /usr/local/bin/myloader /usr/bin/myloader

#安装完成后生成两个二进制文件mydumper和myloader位于/usr/local/bin目录下

# 部分参数说明
# -B, --database 需要备份的库
# -T, --tables-list 需要备份的表，用,分隔
# -t, --threads 使用的线程数量，默认4 
# -o, --outputdir 输出目录
# -l, --long-query-guard 长查询，默认60s
# --kill-long-queries kill掉长时间执行的查询(instead of aborting)
# -D, --daemon 启用守护进程模式
# -F, --chunk-filesize        将表按大小分块时，指定的块大小，单位是 MB
# -m, --no-schemas            不备份表结构
# --tz-utc                    跨时区是使用的选项，不解释了
# --skip-tz-utc               同上
# -v, --verbose               输出信息模式, 0 = silent, 1 = errors, 2 = warnings, 3 = info, 默认为 2
# –innodb-optimize-keys 这个是快速索引创建功能
# --rows：将表分成块，每一块的数据行数。
# --where Dump only selected records.
# -t：指定线程的数量。
# --trx-consistency-only：如果只使用事务表，例如InnoDB，那么使用此选项将使锁定最小化
# -d, --no-data  Do not dump table dat
# -R(存储过程)   -E(定时器) -G, --triggers

## myloader 参数 -e 为开启binlog,否则默认导入是不启用binlog的

# mydumper -u dba -p dba@123 -h 127.0.0.1 -P 6636 -t 10 -F 32  -l 7200 --skip-tz-utc --kill-long-queries --trx-consistency-only -v 3 \
# --regex '^(?!(mysql|sys|information_schema|performance_schema|METRICS_SCHEMA|proxy_heart_beat|test))' -o /data/bak
# myloader -u dba -p dba@123 -h 127.0.0.1 -P 6636 -t 10 -v 3 -e -B tybss_report -d /data/bak
