#!/bin/bash
# baider: 20210805
# 用于循环强制删除大数据文件  $1 传入要删除的文件路径


if [ -z "$1" ]; then
   echo -e "\033[34;40m 请传入要删除的文件路径,请确认后再执行!!!\033[0m"
   exit 0
fi

if [ ! -f "$1" ]; then
   echo -e "\033[34;40m 传入的文件不存在,请确认后再执行!!!\033[0m"
   exit 0
fi

if [ -d "$1" ]; then
   echo -e "\033[34;40m 传入的参数不能是目录,请确认后再执行!!!\033[0m"
   exit 0
fi

# printf("%.0f\n",$1) 向上取整
# printf("%d\n",$1)   向下取整(只取到整数,丢掉小数)
file_size=$(du -sh "$1"|grep G|cut -d"G" -f1|awk '{printf("%d\n",$1)}')
if [ -z "${file_size}" ]; then
   echo -e "\033[34;40m 小于1G的文件将直接使用rm命令删除!!!\033[0m"
   exit 0
fi


## 循环缩减大文件大小
for i in $(seq ${file_size} -1 0)
do
    truncate --size=${i}G "$1"
	echo -e "\033[34;40m 当前文件大小为:【${i}G】\033[0m"
	sleep 0.1s
done


## 最后调用rm -rf 删除
rm -rf $1
echo -e "\033[34;40m 已成功执行删除文件:【${1}】\033[0m"
