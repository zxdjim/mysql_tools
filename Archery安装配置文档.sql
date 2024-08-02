安装
安装Python和virtualenv
从1.9.0版本开始，将不再支持python3.7及以下版本，手动安装也将使用3.9版本作为样例，移除yum安装方式

# 安装依赖
yum install libffi-devel wget gcc make zlib-devel openssl openssl-devel ncurses-devel openldap-devel gettext bzip2-devel xz-devel

mkdir -p /data/soft

cd /data/soft
wget "https://www.python.org/ftp/python/3.9.10/Python-3.9.10.tar.xz"
tar -xvJf Python-3.9.10.tar.xz
# 编译
cd Python-3.9.10
./configure prefix=/usr/local/python3
make && make install

cd ../
ln -fs /usr/local/python3/bin/python3 /usr/bin/python3
ln -fs /usr/local/python3/bin/pip3 /usr/bin/pip3
# virtualenv
pip3 install virtualenv -i https://mirrors.ustc.edu.cn/pypi/web/simple/
ln -fs /usr/local/python3/bin/virtualenv /usr/bin/virtualenv


安装Archery
准备虚拟环境

virtualenv venv4archery --python=python3
source venv4archery/bin/activate

安装MongoDB驱动(需要使用MongoDB的按需安装)

cd /data/soft

wget -c https://fastdl.mongodb.org/linux/mongodb-linux-x86_64-rhel70-3.6.20.tgz
tar -xvf mongodb-linux-x86_64-rhel70-3.6.20.tgz
\cp -f mongodb-linux-x86_64-rhel70-3.6.20/bin/mongo /usr/bin/


下载最新release包，安装依赖库
cd /data/soft

wget "https://github.com/hhyo/archery/archive/v1.8.5.tar.gz"
tar -xzvf v1.8.5.tar.gz
# 安装系统依赖
yum install gcc gcc-c++ python-devel mysql-devel openldap-devel gettext -y

yum install unixODBC-devel unixODBC -y

mv Archery-1.8.5 /usr/local/archery
# 安装依赖库
cd /usr/local/archery
pip3 install -r requirements.txt -i https://mirrors.ustc.edu.cn/pypi/web/simple/


安装Inception(MySQL审核、查询校验和数据脱敏)
项目地址：https://github.com/hanchuanchuan/goInception

git clone https://github.com/hanchuanchuan/goInception.git
cd goInception
go build -o goInception tidb-server/main.go

#修改config.toml 指向archery数据库

./goInception -config=config/config.toml

准备MySQL、Redis实例
- MySQL推荐版本>=5.7
- Redis提供任务队列和缓存
安装mysql、redis （略）

修改配置

cd /usr/local/archery/archery


基础配置 vim settings.py 

DATABASES = {
'default': {
'ENGINE': 'django.db.backends.mysql',
'NAME': 'archery', # 数据库名称
'USER': 'root', # 数据库用户
'PASSWORD': '', # 数据库密码
'HOST': 'localhost', # 数据库HOST，如果是docker启动并且关联，可以使用容器名连接
'PORT': '6606', # 数据库端口
'OPTIONS': {
'init_command': "SET sql_mode='STRICT_TRANS_TABLES'", # SQL_MODE，为了兼容select * group by，可以按需调整
'charset': 'utf8mb4'
},
'TEST': {
'NAME': 'test_archery',
'CHARSET': 'utf8mb4',
},
}
}





# 缓存配置
CACHES = {
"default": {
"BACKEND": "django_redis.cache.RedisCache",
"LOCATION": "redis://127.0.0.1:7000/0",
"OPTIONS": {
"CLIENT_CLASS": "django_redis.client.DefaultClient",
"PASSWORD": ""
}
},
"dingding": {
"BACKEND": "django_redis.cache.RedisCache",
"LOCATION": "redis://127.0.0.1:7000/1",
"OPTIONS": {
"CLIENT_CLASS": "django_redis.client.DefaultClient",
"PASSWORD": ""
}
}
}



# 数据库初始化
python3 manage.py makemigrations sql
python3 manage.py migrate

# 数据初始化
python3 manage.py dbshell < sql/fixtures/auth_group.sql
python3 manage.py dbshell < src/init_sql/mysql_slow_query_review.sql

# 创建管理用户
python3 manage.py createsuperuser





#启动脚本

start_archery.sh

#!/bin/sh

DIR=/usr/local/archery
cd ${DIR}
virtualenv venv4archery --python=python3
source venv4archery/bin/activate

python3 manage.py qcluster &
#启动服务
python3 manage.py runserver 0.0.0.0:9123 --insecure &



#工具插件的安装

#安装soar

wget https://github.com/XiaoMi/soar/releases/download/0.9.0/soar.linux-amd64 -O soar
chmod a+x soar
mv soar /usr/local/bin

#测试
echo 'select * from film' | /usr/local/bin/soar



#安装SQLAdvisor

git clone https://github.com/Meituan-Dianping/SQLAdvisor.git
yum install cmake libaio-devel libffi-devel glib2 glib2-devel
wget https://downloads.percona.com/downloads/percona-release/percona-release-1.0-27/redhat/percona-release-1.0-27.noarch.rpm
rpm -ivh percona-release-1.0-27.noarch.rpm
yum install Percona-Server-shared-56 -y

cd SQLAdvisor/
cmake -DBUILD_CONFIG=mysql_release -DCMAKE_BUILD_TYPE=debug -DCMAKE_INSTALL_PREFIX=/usr/local/sqlparser ./
make

make install

cd sqladvisor/

cmake -DCMAKE_BUILD_TYPE=debug ./
make
cp sqladvisor /usr/local/bin/


注意事项:
1.工单如果想执行管理sql ,需要使用有root角色的用户,如admin99, (admin99有root角色,而admin没有)
2.管理语句示例 db.getCollection("rb_sys_event").deleteOne({ "rbeventid" :148 })
