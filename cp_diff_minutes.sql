### 0 创建一个用来存放原始数据的表
use my_tools;
drop table if exists t_diff;
create table t_diff(code varchar(20),t1 varchar(50),t2 varchar(50));

### 1 清理垃圾数据
delete from t_diff where code ='' or t1='';
update t_diff set t2=null where t2='';

### 2 修改四五六月为04,05,06
update t_diff set t1=replace(t1,'六月','06'),t2=replace(t2,'六月','06');
update t_diff set t1=replace(t1,'五月','05'),t2=replace(t2,'五月','05');
update t_diff set t1=replace(t1,'四月','04'),t2=replace(t2,'四月','04');

### 3 修改上午时间 12:->00其他时间不变
update t_diff set t1=replace(t1,'12:','00:') where right(t1,2)='上午' and substring(t1,10,2)=12;
update t_diff set t1=replace(t1,'上午','') where right(t1,2)='上午';
update t_diff set t2=replace(t2,'12:','00:') where right(t2,2)='上午' and substring(t2,10,2)=12;
update t_diff set t2=replace(t2,'上午','') where right(t2,2)='上午';

### 4 修改下午时间 非12:时间要加12小时,12:保持不变
update t_diff set t1=replace(t1,concat(substring_index(SUBSTRING_INDEX(t1,' ',-2),':',1),':'),concat(substring_index(SUBSTRING_INDEX(t1,' ',-2),':',1)+12,':')) where right(t1,2)='下午' and substring(t1,10,2)!=12;
update t_diff set t1=replace(t1,'下午','') where right(t1,2)='下午';
update t_diff set t2=replace(t2,concat(substring_index(SUBSTRING_INDEX(t2,' ',-2),':',1),':'),concat(substring_index(SUBSTRING_INDEX(t2,' ',-2),':',1)+12,':')) where right(t2,2)='下午' and substring(t2,10,2)!=12;
update t_diff set t2=replace(t2,'下午','') where right(t2,2)='下午';
update t_diff set t1=rtrim(t1),t2=rtrim(t2);

### 5 把年前面+20调整为4位数字,同时把秒补上为:00
update t_diff set t1=concat(left(t1,6),'20',substring_index(t1,'/',-1)),t2=concat(left(t2,6),'20',substring_index(t2,'/',-1));
update t_diff set t1=concat(t1,':00'),t2=concat(t2,':00');

### 6 生成新表用来存放格式化好的数据
drop table if exists t_diff_new;
create table t_diff_new(code varchar(20),t1 DATETIME,t2 DATETIME);
insert into t_diff_new 
select code, concat(substring_index(SUBSTRING_INDEX(t1,'/',-1),' ',1),'-',right(SUBSTRING_INDEX(t1,'/',2),2),'-',SUBSTRING_INDEX(t1,'/',1),' ',SUBSTRING_INDEX(t1,' ',-1)),
concat(substring_index(SUBSTRING_INDEX(t2,'/',-1),' ',1),'-',right(SUBSTRING_INDEX(t2,'/',2),2),'-',SUBSTRING_INDEX(t2,'/',1),' ',SUBSTRING_INDEX(t2,' ',-1)) from t_diff;

select code `关键字`,t1 `反馈时间`,t2 `解决时间`,TIMESTAMPDIFF(minute,t1,t2) `时间差(分钟M)` from t_diff_new;