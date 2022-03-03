#! /bin/bash

# $1=源文件   $2=目标文件

if [ ! -f "$1" ] || [ ! -f "$2" ]; then
   echo "源文件和目标文件必须为文件!"
   exit 0
fi

### 先要对2个文件进行一次排序然后去重(生成一个新文件)再对比
new_file(){
fl=$(echo "${1%%.*}")
ext=$(echo "${1##*.}")
f_new="${fl}_new.${ext}"
sort $1|uniq > "${f_new}"
}

new_file "$1"
source=${f_new}
new_file "$2"
target=${f_new}

echo -e "\033[34;40m 参数依次为[源文件] [目标文件]\n 开始对比源文件和目标文件完全差异(如下所列)...\033[0m"
for i in $(cat ${target})
do
  fd=$(grep -E "^${i}$" "${source}")
  if [ -z "${fd}" ]; then
    echo $i
  fi	
done
echo -e "\033[34;40m 结束对比源文件和目标文件完全差异!!!\033[0m"