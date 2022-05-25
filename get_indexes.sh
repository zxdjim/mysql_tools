#!/bin/bash
## baider:20210812 修改为函数调用方式
## 此脚本用于获取相关的索引,$1=库名 $2=集合

### 最后要执行的JS脚本路径 paswd 前者生产,后者隔离
mkdir -p /data/soft
js_path=/data/soft/get_indexes.tmp
#paswd='HPVkd6DJJ3aoWXWTArt4'
paswd='#xkVox11rtTlA1@!rCNitNWAiVbwZ0'

master=$(/usr/bin/mongo -u admin -p "${paswd}" --host 127.0.0.1 --port 26060 --quiet --eval 'db.isMaster().primary')
master_ip=(${master%:*})

## -z 字符串为空
## 循环创建索引(单索引) replace(/(.*)_/,'\$1:') 把最后一个_替换为:(以防止有多个下划线不好查找)
## 注意createIndex({[fild]:1})中[]的用法:取变量内容,有点类似shell中$

##参1为空,则导出所有非系统库的所有集合索引 
if [ -z ${1} ]; then   
###循环所有库时排除4个系统库:admin,config,local,test
cat>${js_path} <<EOF
var dbNames = db.adminCommand({listDatabases:1,nameOnly:true});
for (var i=0; i < dbNames.databases.length; i++) {
    var dbName = dbNames.databases[i].name;
    if (dbName == "admin"||dbName == "config"||dbName == "local"||dbName == "test") {continue;} 
    print("use",dbName);
    var collectionList = db.getSiblingDB(dbName).getCollectionNames();
    for (var index in collectionList) {
    var collection = collectionList[index];
    var cur = db.getSiblingDB(dbName).getCollection(collection).getIndexes();
    if (cur.length == 1) {continue;}
    for (var index1 in cur) {
    var next = cur[index1];
    if (next["key"]["_id"] == '1') {continue;}
	print("try{db.getCollection(\""+collection+"\").ensureIndex("+JSON.stringify(next.key)+",{background:1,unique:"+(next.unique||false)+(next.expireAfterSeconds>0?",expireAfterSeconds:"+next.expireAfterSeconds:"")+"})}catch(e){print(e)}");}}}
EOF
##参1,2为非空,则导出相应库中集合的索引
elif [ ! -z ${1} ] && [ ! -z ${2} ]; then 
cat>${js_path} <<EOF
var dbName = "${1}";
if (dbName == "admin"||dbName == "config"||dbName == "local"||dbName == "test") {print("//system db");} else {
print("use",dbName);
var collectionList = db.getSiblingDB(dbName).getCollectionNames();
for (var index in collectionList) {
var collection = collectionList[index];
if (collection == "${2}") {
var cur = db.getSiblingDB(dbName).getCollection(collection).getIndexes();
if (cur.length == 1) {continue;}
for (var index1 in cur) {
var next = cur[index1];
if (next["key"]["_id"] == '1') {continue;}
print("try{db.getCollection(\""+collection+"\").ensureIndex("+JSON.stringify(next.key)+",{background:1,unique:"+(next.unique||false)+(next.expireAfterSeconds>0?",expireAfterSeconds:"+next.expireAfterSeconds:"")+"})}catch(e){print(e)}");}}}}
EOF
##参1非空,参2为空,则导出相应库中所有集合的索引
elif [ ! -z ${1} ] && [ -z ${2} ]; then 
cat>${js_path} <<EOF
var dbName = '${1}';
if (dbName == "admin"||dbName == "config"||dbName == "local"||dbName == "test") {print("//system db");} else {
print("use",dbName);
var collectionList = db.getSiblingDB(dbName).getCollectionNames();
for (var index in collectionList) {
var collection = collectionList[index];
var cur = db.getSiblingDB(dbName).getCollection(collection).getIndexes();
if (cur.length == 1) {continue;}
for (var index1 in cur) {
var next = cur[index1];
if (next["key"]["_id"] == '1') {continue;}
print("try{db.getCollection(\""+collection+"\").ensureIndex("+JSON.stringify(next.key)+",{background:1,unique:"+(next.unique||false)+(next.expireAfterSeconds>0?",expireAfterSeconds:"+next.expireAfterSeconds:"")+"})}catch(e){print(e)}");}}}
EOF
fi

/usr/bin/mongo -u admin -p "${paswd}" --host ${master_ip} --port 26060 --quiet < ${js_path} > ${js_path%.*}.js
rm -rf ${js_path}
