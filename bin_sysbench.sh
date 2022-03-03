#! /bash/bin
# 自动化安装 sysbench 

mkdir -p /data/soft && cd /data/soft
wget https://github.com/akopytov/sysbench/archive/master.zip
yum -y install make automake libtool pkgconfig libaio-devel mysql-devel vim-common unzip
unzip master.zip

cd sysbench-master/
./autogen.sh
./configure

make -j && make install

## sysbench --test=fileio --file-total-size=4G --file-test-mode=rndrw --time=300 --max-requests=0
## sysbench --test=fileio --num-threads=10 --file-total-size=2G --file-test-mode=rndrw --report-interval=1 --run