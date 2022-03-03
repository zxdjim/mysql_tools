#! /bash/bin
## 批量修改文件名称

if [ -z "$1" ]; then
   echo -e "\033[34;40m 第一个参数路径不可为空,请确认后再执行!!!\033[0m"
   exit 0
fi

if [ ! -d "$1" ]; then
   echo -e "\033[34;40m 第一个参数路径文件夹不存在,请确认后再执行!!!\033[0m"
   exit 0
fi

if [ -z "$2" ]; then
   echo -e "\033[34;40m 请传入原库名,请确认后再执行!!!\033[0m"
   exit 0
fi

if [ -z "$3" ] || [ "$2" == "$3" ]; then
   echo -e "\033[34;40m 请传入新库名且新旧库名不可一样,请确认后再执行!!!\033[0m"
   exit 0
fi

cd ${1}
dd=$(ls -l|cut -d ":" -f2|cut -d" " -f2)
for i in ${dd}
do
   h1=${i%%.*}
   h2=${i#*.}
   if [ ${h1} == "$2" ]; then
      sed -i "s/SET NAMES binary/SET NAMES utf8mb4/g" `grep "SET NAMES binary" -rl ${1}`
      mv ${h1}"."${h2} "${3}."${h2}
   fi
done

## mv ty_report-schema-create.sql ty_report_bak-schema-create.sql
