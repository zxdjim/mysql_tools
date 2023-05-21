#! /bin/bash
## 下载安装 tidb-toolkit工具及配置importer和lightning toml配置文件
## 然后运行import(后端工具)及lightning(前端工具)进行TIDB的还原


## tidb_ip:要导入tidb的IP地址
## 端口/用户名/密码等变量
## tipd_ip:要导入tipd的IP地址 
tidb_ip=10.5.37.18
tidb_port=4000
tidb_user=root
tidb_pwd="dfQWF@E45#93"
tipd_ipport=10.5.37.20:2379

## tikv-importer 监听地址(创建到tidb中),默认用8287的端口
tikv_importer_ip=${tidb_ip}:8287

## ds_dir 要导入的数据源路径
ds_dir=/data/tidb_bak/20220125_164951

mkdir -p /data/soft && cd /data/soft
if [[ ! -e tidb-toolkit-v4.0.2-linux-amd64.tar.gz ]]; then
  wget https://download.pingcap.org/tidb-toolkit-v4.0.2-linux-amd64.tar.gz
  tar -xvf tidb-toolkit-v4.0.2-linux-amd64.tar.gz
  ln -sb /data/soft/tidb-toolkit-v4.0.2-linux-amd64/bin/dumpling /usr/bin/
  ln -sb /data/soft/tidb-toolkit-v4.0.2-linux-amd64/bin/tidb-lightning /usr/bin/
  ln -sb /data/soft/tidb-toolkit-v4.0.2-linux-amd64/bin/tikv-importer /usr/bin/
fi

cat >/data/soft/tidb-toolkit-v4.0.2-linux-amd64/bin/tikv-importer.toml <<EOF
# 日志文件。
log-file = "tikv-importer.log"
# 日志等级：trace、debug、info、warn、error、off。
log-level = "info"
[server]
# tikv-importer 监听的地址，tidb-lightning 需要连到这个地址进行数据写入。
addr = "${tikv_importer_ip}"
# gRPC 服务器的线程池大小。
grpc-concurrency = 16
[metric]
# 给 Prometheus 客户端的推送任务名称。
job = "tikv-importer"
# 给 Prometheus 客户端的推送间隔。
interval = "15s"
# Prometheus Pushgateway 地址。
address = ""
[rocksdb]
# 最大的背景任务并发数。
max-background-jobs = 32
[rocksdb.defaultcf]
# 数据在刷新到硬盘前能存于内存的容量上限。
write-buffer-size = "1GB"
# 存于内存的写入缓冲最大数量。
max-write-buffer-number = 8
# 各个压缩层级使用的算法。
# 第 0 层的算法用于压缩 KV 数据。
# 第 6 层的算法用于压缩 SST 文件。
# 第 1 至 5 层的算法目前忽略。
compression-per-level = ["lz4", "no", "no", "no", "no", "no", "lz4"]
[rocksdb.writecf]
# (同上)
compression-per-level = ["lz4", "no", "no", "no", "no", "no", "lz4"]
[import]
# 存储引擎文档 (engine file) 的文件夹路径。
import-dir = "/mnt/ssd/data.import/"
# 处理 gRPC 请求的线程数量。
num-threads = 16
# 导入任务并发数。
num-import-jobs = 24
# 预处理 Region 最长时间。
#max-prepare-duration = "5m"
# 把要导入的数据切分为这个大小的 Region。
#region-split-size = "512MB"
# 流管道窗口大小，管道满时会阻塞流。
#stream-channel-window = 128
# 引擎文档同时打开的最大数量。
max-open-engines = 8
# Importer 上传至 TiKV 的最大速度 (bytes per second)。
#upload-speed-limit = "512MB"
# 目标 store 可用空间的最小比率：store_available_space / store_capacity.
# 如果目标存储空间的可用比率低于下值，Importer 将会暂停上传 SST 来为 PD 提供足够时间进行 regions 负载均衡。
min-available-ratio = 0.05
EOF

cat >/data/soft/tidb-toolkit-v4.0.2-linux-amd64/bin/tidb-lightning.toml <<EOF
#配置文件模版
[lightning]
# 用于调试和 Prometheus 监控的 HTTP 端口。输入 0 关闭。
pprof-port = 8289
# 开始导入前先检查集群版本是否支持。
#check-requirements = true
# 控制同时处理的最大引擎数量。
# 每张表被分割为一个用于储存索引的“索引引擎”和若干存储行数据的“数据引擎”。
# 这两项设置控制同时处理每种引擎的最大数量。设置会影响 tikv-importer 的内存和
# 磁盘用量。两项数值之和不能超过 tikv-importer 的 max-open-engines 的设定。
index-concurrency = 2
table-concurrency = 6
# 转换数据的并发数，默认为逻辑 CPU 数量，不需要配置。
# 混合部署的情况下可以配置为逻辑 CPU 的 75% 大小。
#region-concurrency =
# 最大的 I/O 并发数。I/O 并发量太高时，会因硬盘内部缓存频繁被刷新而增加 I/O 等待时间，
# 导致缓存未命中和降低读取速度。因应不同的存储介质，此参数可能需要调整以达到最佳效率。
io-concurrency = 5
# 日志
level = "info"
file = "tidb-lightning.log"
max-size = 128 # MB
max-days = 28
max-backups = 14
[checkpoint]
# 启用断点续传。
# 导入时，Lightning 会记录当前进度。
# 若 Lightning 或其他组件异常退出，在重启时可以避免重复再导入已完成的数据。
enable = true
# 存储断点的数据库名称。
schema = "tidb_lightning_checkpoint"
# 存储断点的方式
#  - file：存放在本地文件系统（要求 v2.1.1 或以上）
#  - mysql：存放在兼容 MySQL 的数据库服务器
driver = "file"
# 断点的存放位置
# 若 driver = "file"，此参数为断点信息存放的文件路径。
# 如果不设置改参数则默认为“/tmp/CHECKPOINT_SCHEMA.pb”。
# 若 driver = "mysql"，此参数为数据库连接参数 (DSN)，格式为“用户:密码@tcp(地址:端口)/”。
# 默认会重用 [tidb] 设置目标数据库来存储断点。
# 为避免加重目标集群的压力，建议另外使用一个兼容 MySQL 的数据库服务器。
#dsn = "/tmp/tidb_lightning_checkpoint.pb"
# 导入成功后是否保留断点。默认为删除。
# 保留断点可用于调试，但有可能泄漏数据源的元数据。
# keep-after-success = false
[tikv-importer]
# tikv-importer 的监听地址，需改成 tikv-importer 服务器的实际地址。
addr = "${tikv_importer_ip}"
[mydumper]
# 文件读取区块大小。
read-block-size = 65536 # 字节 (默认 = 64 KB)
#（源数据文件）单个导入区块大小的最小值。
# Lightning 根据该大小将一张大表分割为多个数据引擎文件。
batch-size = 107_374_182_400 # 字节 (默认 100 GiB)
# 引擎文件要按序导入。因为是并行处理，多个数据引擎几乎同时被导入，
# 这样形成的处理队列会造成资源浪费。因此，Lightning 稍微增大了前几个
# 区块的大小，从而合理分配资源。该参数也决定了向上扩展（scale up）因
# 数，代表在完全并发下“导入”和“写入”过程的持续时间比。这个值也可以通过
# 计算 1 GB 大小单张表的（导入时长/写入时长）得到。精确的时间可以在日志
# 里看到。如果“导入”更快，区块大小差异就会更小；比值为 0 则说明区块大小
# 是一致的。取值范围是（0 <= batch-import-ratio < 1）。
batch-import-ratio = 0.75
# mydumper 源数据目录。
data-source-dir = "${ds_dir}"
# 如果 no-schema 设置为 true，tidb-lightning 将直接去 tidb-server 获取表结构信息，
# 而不是根据 data-source-dir 的 schema 文件来创建库/表，
# 适用于手动创建表或者 TiDB 本来就有表结构的情况。
no-schema = false
# 指定包含 CREATE TABLE 语句的表结构文件的字符集。只支持下列选项：
#  - utf8mb4：表结构文件必须使用 UTF-8 编码，否则 Lightning 会报错
#  - gb18030：表结构文件必须使用 GB-18030 编码，否则 Lightning 会报错
#  - auto：（默认）自动判断文件编码是 UTF-8 还是 GB-18030，两者皆非则会报错
#  - binary：不尝试转换编码
# 注意，此参数不影响 Lightning 读取数据文件。
character-set = "auto"
# 配置如何解析 CSV 文件。
[mydumper.csv]
# 字段分隔符，应为单个 ASCII 字符。
separator = ','
# 引用定界符，可为单个 ASCII 字符或空字符串。
delimiter = '"'
# CSV 文件是否包含表头。
# 如果为 true，第一行导入时会被跳过。
header = true
# CSV 是否包含 NULL。
# 如果 `not-null` 为 true，CSV 所有列都不能解析为 NULL。
not-null = false
# 如果 `not-null` 为 false（即 CSV 可以包含 NULL），
# 为以下值的字段将会被解析为 NULL。
null = '\N'
# 是否解析字段内反斜线转义符。
backslash-escape = true
# 如果有行以分隔符结尾，删除尾部分隔符。 
trim-last-separator = false
[tidb]
# 目标集群的信息。tidb-server 的监听地址，填一个即可。
host = "${tidb_ip}"
port = ${tidb_port}
user = "${tidb_user}"
password = "${tidb_pwd}"
# 表架构信息在从 TiDB 的“状态端口”获取。
status-port = 10080
# pd-server 的监听地址，填一个即可。
pd-addr = "${tipd_ipport}"
# tidb-lightning 引用了 TiDB 库，而它自己会产生一些日志。此设置控制 TiDB 库的日志等级。
log-level = "error"
# 设置 TiDB 会话变量，提升 CHECKSUM 和 ANALYZE 的速度。各参数定义可参阅
# https://pingcap.com/docs-cn/sql/statistics/#%E6%8E%A7%E5%88%B6-analyze-%E5%B9%B6%E5%8F%91%E5%BA%A6
build-stats-concurrency = 20
distsql-scan-concurrency = 100
index-serial-scan-concurrency = 20
checksum-table-concurrency = 16
# 导完数据以后可以自动进行校验和 (CHECKSUM)、压缩 (Compact) 和分析 (ANALYZE) 的操作。
# 生产环境建议都设为 true
# 执行顺序是: CHECKSUM -> ANALYZE。
[post-restore]
# 如果设置为 true，会对每个表逐个做 `ADMIN CHECKSUM TABLE <table>` 操作。
checksum = true
# 如果设置为 false，会在导入每张表后做一次 level-1 Compact。
level-1-compact = false
# 如果设置为 false，会在导入过程结束时对整个 TiKV 集群执行一次全量 Compact。
compact = false
# 如果设置为 true，会对每个表逐个做 `ANALYZE TABLE <table>` 操作。
analyze = true
# 设置背景周期性动作。
# 支持的单位：h（时）、m（分）、s（秒）。
[cron]
# Lightning 自动刷新导入模式周期。需要比 TiKV 对应的设定值短。
switch-mode = "5m"
# 每经过这段时间，在日志打印当前进度。
log-progress = "5m"
# 表库过滤设置。详情见《TiDB-Lightning 表库过滤》。
#[black-white-list]
# ...
EOF

cd /data/soft/tidb-toolkit-v4.0.2-linux-amd64/bin

cat >/data/soft/tidb-toolkit-v4.0.2-linux-amd64/bin/start.sh <<EOF
#!/usr/bin

rm -rf /tmp/*
nohup ./tikv-importer -C tikv-importer.toml > nohup.out &
nohup ./tidb-lightning -config tidb-lightning.toml > nohup.out &
EOF

## 运行 tikv-importer 及 tidb-lightning
nohup ./tikv-importer  -C tikv-importer.toml > nohup.out &
nohup ./tidb-lightning -config tidb-lightning.toml > nohup.out &
