#!/bin/bash
#### 生成一条条的SQL脚本的JS格式
#### $1:DB名称(不可为空) $2:集合名称(不可为空)  $3:过滤条件(不可为空) 用单引号括起来,如果过滤条件中有$请用双引号括起来
xrar="/usr/local/rar"

if [ -z $1 ]; then
   echo "数据库名称不可为空"
   exit 1
fi
if [ -z $2 ]; then
   echo "集合名称不可为空"
   exit 1
fi
if [ -z $3 ]; then
   echo "过滤字符串不可为空"
   exit 1
fi

if [ ! -x $xrar ]; then
   echo "${xrar}未安装或未链接到/usr/bin."
   exit 1
fi

db_name=$1
coll_name=$2
filter=$3
qry=tmp_mongo.txt
result=result_mongo.txt
passwd=HPVkd6
ip_port='10.105.11.18:26060'

cat > ${qry} <<EOF
"use ${db_name}"
db.getSiblingDB("${db_name}").getCollection("${coll_name}").find(${filter}).forEach(function(item){ 
   print('db.getCollection("${coll_name}").insert('+tojson(item)+');');});
EOF
mongo -u admin -p ${passwd} --authenticationDatabase admin ${ip_port} --quiet < ${qry} >> ${result}
rm -rf ${result%.*}.rar
rar a ${result%.*}.rar ${result}
sz ${result%.*}.rar
