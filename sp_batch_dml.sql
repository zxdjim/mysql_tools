### 创建 my_tools工具类库,用于非业务调用的库
create database if not exists my_tools;

use my_tools;
DELIMITER $$
DROP FUNCTION IF EXISTS  `fn_get_table_fileds`$$
CREATE FUNCTION `fn_get_table_fileds`(v_table_schema varchar(50),v_table_name varchar(200),v_list_type varchar(10))
RETURNS varchar(4000) DETERMINISTIC
label1:BEGIN
### author:baider date:20210828
###  DEMO : SELECT fn_get_table_fileds('my_tools','t_pay_channel','AL'); 
###  v_table_schema    必填项 库名     如 'my_tools' 
###  v_table_name      必填项 表名     如't_pay_channel'
###  v_list_type       必填项 列表类型 如 'P/A/NAL/AL/NATL/ATL'

			declare v_PField                varchar(50);    ##主键列
			declare v_AField                varchar(50);    ##自增键列
		  declare v_NAFields_list         varchar(4000);  ##非主键列表
		  declare v_AFields_list          varchar(4000);  ##含主键列表
			declare v_NAFields_type_list    varchar(4000);  ##含非主键且带数据类型列表 			
			declare v_AFields_type_list     varchar(4000);  ##含主键且带数据类型列表 
					
    IF v_table_schema IS NULL OR v_table_name IS NULL OR v_list_type IS NULL 
		   OR LENGTH(TRIM(v_table_schema)) = 0 OR LENGTH(TRIM(v_table_name)) = 0 OR LENGTH(TRIM(v_list_type)) = 0 then
			 RETURN '所有参数不可为NULL或空串!!!';
			 LEAVE label1;
    end if;
		
		 IF UPPER(TRIM(v_list_type)) NOT IN ('P','A','NAL','AL','NATL','ATL') then
			 RETURN '第三个参数只可为P/A/NAL/AL/NATL/ATL 六种类型中的一种,请确认无误后再尝试!!!';
			 LEAVE label1;
    end if; 
		
			### 设置 group_concat的最大值,原值为:1024过小和sql_mode
		 set session sql_mode='';
		 SET session group_concat_max_len=102400;
	
		select UPPER(GROUP_CONCAT(if(column_key='PRI',COLUMN_NAME,null) order by ORDINAL_POSITION)) PField,
		       UPPER(GROUP_CONCAT(if(extra='auto_increment',COLUMN_NAME,null) order by ORDINAL_POSITION)) AField,
					 UPPER(GROUP_CONCAT(if(extra='auto_increment',null,COLUMN_NAME) order by ORDINAL_POSITION)) NAFields_list,
					 UPPER(GROUP_CONCAT(COLUMN_NAME order by ORDINAL_POSITION)) AFields_list,
					 UPPER(GROUP_CONCAT(if(upper(data_type) in ('TINYINT','SMALLINT','MEDIUMINT','INT','BIGINT'),CONCAT(if(extra='auto_increment',null,COLUMN_NAME),' ',data_type),
								 CONCAT(if(extra='auto_increment',null,COLUMN_NAME),' ',column_type))  order by ORDINAL_POSITION)) NAFields_type_list,
					 UPPER(GROUP_CONCAT(if(upper(data_type) in ('TINYINT','SMALLINT','MEDIUMINT','INT','BIGINT'),CONCAT(COLUMN_NAME,' ',data_type),
								 CONCAT(COLUMN_NAME,' ',column_type))  order by ORDINAL_POSITION)) AFields_type_list								 
					 into v_PField,v_AField,v_NAFields_list,v_AFields_list,v_NAFields_type_list,v_AFields_type_list 
			from information_schema.`COLUMNS` 		
			where TABLE_SCHEMA = TRIM(v_table_schema) and table_name = TRIM(v_table_name);
	
	IF upper(TRIM(v_list_type)) = 'P' THEN
	   RETURN IFNULL(v_PField,'ERROR: NO PRIMARY KEY');
	ELSEIF upper(TRIM(v_list_type)) = 'A' THEN
	   RETURN IFNULL(v_AField,'ERROR: NO auto_increment');	 
	ELSEIF upper(TRIM(v_list_type)) = 'NAL' THEN
	   RETURN  v_NAFields_list;
  ELSEIF upper(TRIM(v_list_type)) = 'AL' THEN		
     RETURN  v_AFields_list;	
  ELSEIF upper(TRIM(v_list_type)) = 'NATL' THEN	
     RETURN  v_NAFields_type_list;	
  ELSEIF upper(TRIM(v_list_type)) = 'ATL' THEN		 	
     RETURN  v_AFields_type_list;	
  END IF;

END $$
DELIMITER ;

use my_tools;
delimiter $$
drop PROCEDURE IF EXISTS sp_batch_dml$$
CREATE PROCEDURE `sp_batch_dml`(v_dml_type char(1),
                                v_schema_source varchar(100), v_table_source varchar(100),v_schema_target varchar(100), v_table_target varchar(100),
                                v_i_flist varchar(10), v_u_flist varchar(500), v_field varchar(100), 
								v_where varchar(500), v_sub_qry varchar(2000), v_add_where bit, 
								v_batch_cnt int, v_sleep_sec decimal(4,2),
								v_debug varchar(5))
label1:BEGIN
### author:baider date:20210825
### 功能说明: 此过程小批量按指定的条件操作记录(第一个参数指定:i/I:插入,u/U:更新,d/D:删除)
### DEMO: CALL my_tools.sp_batch_dml('i','my_tools','t_user','my_tools','t_user_bak','AL',null,'A','LAST_UPDATED_TIME < "2019-11-01"',null,0,10000,0.01,null);
### DEMO: CALL my_tools.sp_batch_dml('u','my_tools','t_user',null,null,null,'status=1','A','LAST_UPDATED_TIME < "2019-11-01"',null,0,10000,0.01,null);
### DEMO: CALL my_tools.sp_batch_dml('d','my_tools','t_user',null,null,null,null,'A','LAST_UPDATED_TIME < "2019-11-01"',null,0,10000,0.01,null);
### 带子查询的例子,前一参数用[]占位
### DEMO: CALL my_tools.sp_batch_dml('i','my_tools','t_rebuild_next_table_init','my_tools','t_diff','AL',null,'a','tid < 20 and tid in[]','select tid from t_rebuild_next_table_init',1,10000,0.01,'debug');
### DEMO: CALL my_tools.sp_batch_dml('u','my_tools','t_rebuild_next_table_init',null,null,null,'IS_ENABLE=1','A','tid < 20 and tid in[]','select tid from t_rebuild_next_table_init',1,10000,0.01,'debug');
### DEMO: CALL my_tools.sp_batch_dml('d','my_tools','t_rebuild_next_table_init',null,null,null,null,'A','tid < 20 and tid in[]','select tid from t_rebuild_next_table_init',1,10000,0.01,'debug');
### v_dml_type      必填项   需要进行操作的类型单一字符(i/I:插入,u/U:更新,d/D:删除)
### v_schema_source 必填项   需要操作的源库名
### v_table_source  必填项   需要操作的源表名
### v_schema_target 非必填项 插入(删除和更新无用)需要操作的目标库名
### v_table_target  非必填项 插入(删除和更新无用)需要操作的目标表名
### v_i_flist       非必填项 插入(删除和更新无用):用于源和目标表中字段列表,即insert into和SELECT后面的列表('AL','NAL'分别代表带种子列表和不带种子列表)
### v_u_flist       非必填项 更新(删除和插入无用):用于SET 后面的更新列表,请注意不要带【SET】关键字 
### v_field         必填项   需要用于批次中源表的过滤字段名('A','P',分别代表取本表的种子或主键,或者其他具体字段名)                    
### v_where         非必填项 需要操作的源表的过滤条件(可为空,代表批量操作全表),请注意不要带【WHERE】关键字,如果有IN 从句的子查询请用[]占位,用后一参数替换之
### v_sub_qry       非必填项 (目前只支持一个子查询)用于源表中过滤条件后的子查询(没有则空),用临时表来保存中间结果集,用于替换v_where中的[]占位符
### v_add_where     非必填项 需要操作的源表的批量过程条件中是否还需要加此前一参数的条件 0:否 1:是	
### v_batch_cnt     必填项   每一批次要处理的数量(根据具体情况,不可太大,建议:1W-10W)
### v_sleep_sec     必填项   批次间休眠时间秒数带2位小数,不可为空或0,不可太大,建议:10.00以内
### v_debug         非必填项 当输入debug(大小写均可)时,将是调试模式,只打印语句而不真正的执行

  declare v_len_where int default 1;
  declare v_cnt       int default 0;
  if v_dml_type is null or length(trim(v_dml_type)) = 0 or (upper(v_dml_type)!='I' and upper(v_dml_type)!='U' and upper(v_dml_type)!='D') then
		SELECT CONCAT('ERROR:  (第1个参数)操作类型必须为i/I/u/U/d/D之一且不可为空!!!') as result;
		leave label1;
	end if;	
  if v_schema_source is null or length(trim(v_schema_source)) = 0 or v_table_source is null or length(trim(v_table_source)) = 0 then
		SELECT CONCAT('ERROR:  (第2.3个参数)源库名或源表名不可为空!!!') as result;
		leave label1;
	end if;
  select count(*) into v_cnt from information_schema.tables where table_schema=trim(v_schema_source) and table_name=trim(v_table_source);
  if v_cnt = 0 then
		SELECT CONCAT('ERROR:  (第2.3个参数)源库名或源表名不存在!!!') as result;
		leave label1;  
  end if;
  if upper(v_dml_type)='I' then	
	  if v_schema_target is null or length(trim(v_schema_target)) = 0 or v_table_target is null or length(trim(v_table_target)) = 0 then
			SELECT CONCAT('ERROR:  (第4.5个参数)目标库名或目标表名不可为空!!!') as result;
			leave label1;
		end if;
	  select count(*) into v_cnt from information_schema.tables where table_schema=trim(v_schema_target) and table_name=trim(v_table_target);
	  if v_cnt = 0 then
			SELECT CONCAT('ERROR:  (第4.5个参数)目标库名或目标表名不存在!!!') as result;
			leave label1;  
	  end if;			
	  if v_i_flist is null or length(trim(v_i_flist)) = 0 then
			SELECT CONCAT('ERROR:  (第6个参数)插入列表类型不可为空!!!') as result;
			leave label1;
		end if;
  end if;
  if upper(v_dml_type)='U' then	
	  if v_u_flist is null or length(trim(v_u_flist)) = 0 then
			SELECT CONCAT('ERROR:  (第7个参数)更新列表类型不可为空!!!') as result;
			leave label1;
		end if;		
  end if;  
  if v_field is null or length(trim(v_field)) = 0 then
		SELECT CONCAT('ERROR:  (第8个参数)依据的字段不可为空!!!') as result;
		leave label1;
	end if;	
  if v_where is null or length(trim(v_where)) = 0  then
        if length(trim(v_sub_qry)) > 0 or v_sub_qry is not null then
			SELECT CONCAT('温馨提示:  (第9个参数)当前参数为空时,第10个参数也必须为空!!!') as result;
			leave label1;		   
		end if;
		SELECT CONCAT('温馨提示:  (第9个参数)过滤条件为空将操作此表所有数据(默认)!!!') as result;
		SET v_where = ' ';
		SET v_len_where = 0;
	end if;
  if position('[]' in v_where) > 0 and (v_sub_qry is null or length(trim(v_sub_qry)) = 0 or position(' from ' in v_sub_qry) = 0)  then
		SELECT CONCAT('温馨提示:  (第10个参数)当第9个参数含有[]占位符时,本参数必须不为空且必须含有from关键字的子查询!!!') as result;
        leave label1;
	end if;	
  if length(trim(v_where)) > 0 and position('[]' in v_where) = 0 and v_sub_qry is not null then
		SELECT CONCAT('温馨提示:  (第10个参数)当第9个参数不含有[]占位符时,本参数必须为空!!!') as result;
        leave label1;
	end if;		
  if v_batch_cnt is null or length(trim(v_batch_cnt)) = 0 or v_batch_cnt <= 0 then
		SELECT CONCAT('ERROR:  (第12个参数)一批次的数量不可为空或非正数!!!') as result;
		leave label1;
	end if;	
  if v_sleep_sec is null or length(trim(v_sleep_sec)) = 0 or v_sleep_sec = 0 or v_sleep_sec = 0.00 then
		SELECT CONCAT('ERROR:  (第13个参数)批次间休眠时间秒数带2位小数,不可为空或0!!!') as result;
		leave label1;
	end if;
begin
    ### 设置库名.表名变量
	declare v_schema_table_source varchar(200) default concat(trim(v_schema_source),'.',trim(v_table_source));
	declare v_schema_table_target varchar(200) default concat(trim(v_schema_target),'.',trim(v_table_target));	
	declare v_sql      varchar(500);  ## 保存v_where 值或为空
	declare v_desc varchar(100);      ## 保存描述操作的类型
	declare v_dml_sql  varchar(2000); ## 保存类型后面操作的部分脚本	
	declare v_fl_source  varchar (2000);
	declare v_FID     varchar(50) DEFAULT '';
	declare v_cur_minID bigint(20) default 1;
	declare v_cur_maxID bigint(20) default 10000;
	
	### 取出要用来进行批量操作的字段,建议是种子字段
    if upper(trim(v_field)) ='A' then 
		 select my_tools.fn_get_table_fileds(v_schema_source, v_table_source, 'A') into v_FID;
    elseif upper(trim(v_field)) ='P' then 
	   select '温馨提示(3秒):字段非数值型时,可能本过程会报异常,如发生请选择其他字段再试!' `result`;
	   select my_tools.fn_get_table_fileds(v_schema_source, v_table_source, 'P') into v_FID;
	   select sleep(3);
	else
	   select trim(v_field) into v_FID;	
       select '温馨提示(3):字段非数值型时,可能本过程会报异常,如发生请选择其他字段再试!' `result`;
       select sleep(3);	   
	end if;
    IF LEFT(v_FID,6) = 'ERROR:' THEN
	   SELECT CONCAT('错误提示:因为没找到所要字段,本次批量操作数据失败!!!') as result;
	   leave label1;
	END IF;
    select count(*) into v_cnt from information_schema.columns where table_schema=trim(v_schema_source) and table_name=trim(v_table_source) and column_name=trim(v_FID);
    if v_cnt = 0 then
		SELECT CONCAT('ERROR:  (第8个参数)依据的字段不存在!!!') as result;
		leave label1;
    end if;
  
	IF v_len_where = 0 then
    set @SQL = concat('SELECT MAX(',v_FID,'),MIN(',v_FID,') into @max_id, @min_id from ',v_schema_table_source,';');
		set v_sql = '';
	ELSE
		##有子查询时,需要用临时表把中间结果保存,同时替换原来的子查询,提升性能(当内存临时表较大时可使用 Engine = Memory)
		IF position('[]' in v_where) > 0 and length(trim(v_sub_qry)) > 0 then
			DROP TEMPORARY TABLE if exists my_tools.tmp_sub_qry;
			set @SQL=concat('CREATE TEMPORARY TABLE my_tools.tmp_sub_qry as(',replace(v_sub_qry,' from ',' as tmp_id from '),');');
			PREPARE STMT FROM @SQL;
			EXECUTE STMT;
			DEALLOCATE PREPARE STMT;
			create index idx_id on my_tools.tmp_sub_qry(tmp_id);
			set v_where = replace(v_where,'[]','(select tmp_id from my_tools.tmp_sub_qry)');					
		END IF;

	    set @SQL = concat('SELECT MAX(',v_FID,'),MIN(',v_FID,') into @max_id, @min_id from ',v_schema_table_source,' WHERE ',trim(v_where),';');
		set v_sql = concat(' and ',trim(v_where));
	END IF;
	
	PREPARE STMT FROM @SQL;
	EXECUTE STMT;
	DEALLOCATE PREPARE STMT;

    if v_add_where+0 = 0 or not v_add_where then
       set v_sql = '';
	end if;

    if upper(v_dml_type)='U' then
	   set v_desc='更新';
	   set v_dml_sql = concat('UPDATE ',v_schema_table_source,' SET ',trim(v_u_flist));
	elseif upper(v_dml_type)='D' then 
	   set v_desc='删除';
	   set v_dml_sql = concat('DELETE FROM ',v_schema_table_source);
	else
	   ###构造源和目标表的字段列表(AL:带种子的字段列表,NAL:不带种子的字段列表)
       select my_tools.fn_get_table_fileds(v_schema_source, v_table_source, v_i_flist) into v_fl_source;
	   set v_desc='插入';
	   set v_dml_sql = concat('INSERT IGNORE INTO ',v_schema_table_target,'(',v_fl_source, ') SELECT ', v_fl_source, ' FROM ', v_schema_table_source);
	end if;	

	set v_cur_minID = @min_id;
	if v_cur_minID + (v_batch_cnt - 1) >= @max_id then
	   set v_cur_maxID = @max_id;
	else
	   set v_cur_maxID = v_cur_minID + (v_batch_cnt - 1);
	end if;	

  SELECT CONCAT('开始',v_desc,' 【',v_schema_table_source,'】表中过滤条件为: ',trim(v_where),' 的数据...') AS RESULT;
  if upper(trim(v_debug))='DEBUG' then
     select concat(v_dml_sql,' WHERE ',v_FID,' between ',v_cur_minID,' and ',v_cur_maxID,v_sql,';') as sql_result;
  else
	  while v_cur_minID <= @max_id do
			SELECT CONCAT('正在',v_desc,':【',v_schema_table_source,'】表中 ',v_FID,' 为【',v_cur_minID,'】至【',v_cur_maxID,'】的记录!') AS RESULT;
			set @SQL = concat(v_dml_sql,' WHERE ',v_FID,' between ',v_cur_minID,' and ',v_cur_maxID,v_sql,';');
			PREPARE STMT FROM @SQL;
			EXECUTE STMT;
			DEALLOCATE PREPARE STMT;
			commit;
			select sleep(v_sleep_sec);
			set v_cur_minID = v_cur_minID + v_batch_cnt;

			if v_cur_maxID + v_batch_cnt >= @max_id then
			   set v_cur_maxID = @max_id;
			else
			   set v_cur_maxID = v_cur_maxID + v_batch_cnt;
			end if;		
	  end while;
  end if;
  SELECT CONCAT('结束',v_desc,' 【',v_schema_table_source,'】表中过滤条件为: ',trim(v_where),' 的数据!!!') AS RESULT;
  
  ### 最后手工清理一次临时表
  DROP TEMPORARY TABLE if exists my_tools.tmp_sub_qry;
 end;	
end $$
delimiter ;

######################################### 以下是可选项
### v_i_flist       非必填项 插入(删除和更新无用):用于源和目标表中字段列表,即insert into和SELECT后面的列表('AL','NAL'分别代表带种子列表和不带种子列表)
### v_u_flist       非必填项 更新(删除和插入无用):用于SET 后面的更新列表,请注意不要带【SET】关键字 
use my_tools;
drop table if exists t_move_data_init;
CREATE TABLE  `t_move_data_init` (
  `ID`                 int NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `is_bak`             bit(1) not null default b'1'  COMMENT '重要参数:删除前是否需要备份, 0:否 1:是(默认)',
  `is_add_condition`   bit(1) not null default b'1'  COMMENT '重要参数:在批次间是否需要再加上过滤参数, 0:不需要,1:需要(默认)',   
  `source_schema`      varchar(50) NOT NULL COMMENT '源库名',
  `source_table`       varchar(200) NOT NULL COMMENT '源表名',
  `target_schema`      varchar(50) NULL COMMENT '(执行删除时不需要)目标库名',
  `target_table`       varchar(200) NULL COMMENT '(执行删除时不需要)目标表名',	
  `i_flist`            varchar(10)  NULL default 'AL' COMMENT '插入(删除和更新无用)时源和目标表中字段列表类型,默认为AL',
  `u_flist`            varchar(500) NULL default null COMMENT '更新(删除和插入无用)时用于SET 后面的更新列表,请注意不要带【SET】关键字',  
  `field_name`         varchar(50) NOT NULL default 'A' COMMENT '批次的用于源表中过滤字段名(单字段)或字段类型(种子A或关键字P)',	
  `where_condition`    varchar(2000) NOT NULL COMMENT '用于源表中过滤条件(不需要加where关键字),用{}占位符,用后面时间替换;用[]占位符时,用后面子查询替换',
  `sub_qry`            varchar(2000) NULL default NULL COMMENT '用于源表中过滤条件后的子查询(没有则空),用临时表来保存中间结果集,可替换条件列的[]',
  `where_days`         smallint NOT NULL COMMENT '需要操作的天数,可替换条件列的{}',
  `batch_cnt`          int NOT NULL default 10000 COMMENT '每批次需要处理的量',	
  `sleep_sec`          decimal(4,2) NOT NULL default 0.01 COMMENT '批次间需要休眠的秒数',
  `start_time`         datetime null default null COMMENT '开始时间(每次开启任务前更新此值)',
  `end_time`           datetime null default null COMMENT '结束时间(每次结束任务后更新此值)',
  `bak_status`         tinyint NOT NULL default 0 COMMENT '备份状态 0:初始 1:开始 2:结束',
  `del_status`         tinyint NOT NULL default 0 COMMENT '删除状态 0:初始 1:开始 2:结束',
  `debug`              varchar(5) NULL            COMMENT  '当内容为(不区别大小写):DEBUG时打开调试模式,其他情况则是正常模式',
  `is_enable`          bit(1) not null default b'1'  COMMENT '0:禁用,1:启用',
  `creation_by`        varchar(30) DEFAULT 'sys' COMMENT '创建人',
  `creation_time`      datetime DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  PRIMARY KEY (`ID`)
) ENGINE=InnoDB COMMENT='需要迁移历史数据配置表(插入+删除,也支持只删除)';


INSERT INTO my_tools.t_move_data_init(is_bak,is_add_condition,source_schema,source_table,target_schema,target_table,field_name,where_condition,sub_qry,where_days,batch_cnt,sleep_sec)
   VALUES (0,0,'panda_rcs','match_event_info',NULL,NULL,'event_time','event_time<{}',NULL,30,10000000,0.01);
INSERT INTO my_tools.t_move_data_init(is_bak,is_add_condition,source_schema,source_table,target_schema,target_table,field_name,where_condition,sub_qry,where_days,batch_cnt,sleep_sec)
   VALUES (0,0,'panda_rcs','rcs_monitor_data',NULL,NULL,'A','create_time < date_format(NOW()-INTERVAL 15 DAY,"%Y-%m-%d 00:00:00")',NULL,15,10000,0.01);
INSERT INTO my_tools.t_move_data_init(is_bak,is_add_condition,source_schema,source_table,target_schema,target_table,field_name,where_condition,sub_qry,where_days,batch_cnt,sleep_sec)
   VALUES (0,0,'panda_rcs','rcs_monitor_mq_info',NULL,NULL,'A','crt_time < date_format(NOW()-INTERVAL 30 DAY,"%Y-%m-%d 00:00:00")',NULL,30,10000,0.01);

INSERT INTO my_tools.t_move_data_init(is_bak,is_add_condition,source_schema,source_table,target_schema,target_table,field_name,where_condition,sub_qry,where_days,batch_cnt,sleep_sec)
   VALUES (0,0,'panda_rcs','rcs_lock',NULL,NULL,'A','crt_time < date_format(NOW()-INTERVAL 15 DAY,"%Y-%m-%d 00:00:00")',NULL,15,10000,0.01);
INSERT INTO my_tools.t_move_data_init(is_bak,is_add_condition,source_schema,source_table,target_schema,target_table,i_flist,field_name,where_condition,sub_qry,where_days,batch_cnt,sleep_sec)
   VALUES (1,0,'panda_rcs','t_order_detail_ext','panda_rcs','t_order_detail_ext_bak','NAL','A','max_accept_time<{}',NULL,7,10000,0.01);

INSERT INTO my_tools.t_move_data_init(is_bak,is_add_condition,source_schema,source_table,target_schema,target_table,field_name,where_condition,sub_qry,where_days,batch_cnt,sleep_sec)
   VALUES (0,1,'panda_rcs','rcs_match_collection',NULL,NULL,'A','match_id in (select id from panda_rcs.standard_match_info where match_status in(3, 4)) and create_time < date_format(NOW()-INTERVAL 7 DAY,"%Y-%m-%d 00:00:00")',NULL,7,50000,0.01);
INSERT INTO my_tools.t_move_data_init(is_bak,is_add_condition,source_schema,source_table,target_schema,target_table,i_flist,field_name,where_condition,sub_qry,where_days,batch_cnt,sleep_sec)
   VALUES (1,1,'panda_rcs','rcs_order_basketball_matrix','panda_rcs','rcs_order_basketball_matrix_bak','NAL','A','match_id in(select id from panda_rcs.standard_match_info where match_status in(3, 4) and begin_time<{})',NULL,30,10000,0.01);
INSERT INTO my_tools.t_move_data_init(is_bak,is_add_condition,source_schema,source_table,target_schema,target_table,i_flist,field_name,where_condition,sub_qry,where_days,batch_cnt,sleep_sec)
   VALUES (1,1,'panda_rcs','rcs_predict_basketball_matrix','panda_rcs','rcs_predict_basketball_matrix_bak','NAL','A','match_id in(select id from panda_rcs.standard_match_info where match_status in(3, 4) and begin_time<{})',NULL,30,10000,0.01);
INSERT INTO my_tools.t_move_data_init(is_bak,is_add_condition,source_schema,source_table,target_schema,target_table,i_flist,field_name,where_condition,sub_qry,where_days,batch_cnt,sleep_sec)
   VALUES (1,1,'panda_rcs','rcs_predict_forecast','panda_rcs','rcs_predict_forecast_bak','NAL','A','match_id in(select id from panda_rcs.standard_match_info where match_status in(3, 4) and begin_time<{})',NULL,30,10000,0.01);
INSERT INTO my_tools.t_move_data_init(is_bak,is_add_condition,source_schema,source_table,target_schema,target_table,i_flist,field_name,where_condition,sub_qry,where_days,batch_cnt,sleep_sec)
   VALUES (1,1,'panda_rcs','rcs_predict_forecast_play','panda_rcs','rcs_predict_forecast_play_bak','NAL','A','match_id in(select id from panda_rcs.standard_match_info where match_status in(3, 4) and begin_time<{})',NULL,30,10000,0.01);


DELIMITER $$
drop procedure if exists sp_move_data$$
create procedure sp_move_data()
begin
### DEMO: call my_tools.sp_move_data;
### 调用则根据配置表中的选项进行迁移:插入和删除过期数据
### 注意bit位操作 使用变量时[+0]才可以正常转化成十进制,否则是空值异常   (v_add_condition->> v_add_condition+0)
### add by TY-baider  2021-06-24


		declare done int default false;
        declare v_id               int;           ## 主键ID		
		declare v_bak              bit(1);        ## 重要参数:删除前是否需要备份, 0:否 1:是(默认)
		declare v_add_condition    bit(1);        ## 在批次间是否需要再加上过滤参数, 0:不需要,1:需要(默认)
		declare v_source_schema    varchar(50);   ## 源库名
		declare v_source_table     varchar(200);  ## 源表名		
		declare v_target_schema    varchar(50);   ## (执行删除时不需要)目标库名
		declare v_target_table     varchar(200);  ## (执行删除时不需要)目标表名 	
        declare v_i_flist          varchar(10);   ## 插入(删除和更新无用)时源和目标表中字段列表类型,默认为AL
        declare v_u_flist          varchar(500);  ## 更新(删除和插入无用)时用于SET 后面的更新列表,请注意不要带【SET】关键字  		
		declare v_field_name       varchar(50);   ## 批次的用于源表中过滤字段名(单字段)或字段类型(种子A或关键字P)	
		declare v_where_condition  varchar(2000); ## 用于源表中过滤条件(不需要加where关键字),用{}占位符,用后面时间替换;用[]占位符时,用后面子查询替换
		declare v_sub_qry          varchar(2000); ## 用于源表中过滤条件后的子查询(没有则空),用临时表来保存中间结果集,可替换条件列的[]
		declare v_where_days       smallint;      ## 需要操作的天数,可替换条件列的{}
		declare v_batch_cnt        int;           ## 每批次需要处理的量	
		declare v_sleep_sec        decimal(4,2);  ## 批次间需要休眠的秒数
		declare v_bak_status       tinyint;       ## 备份状态 0:初始 1:开始 2:结束
		declare v_del_status       tinyint;       ## 删除状态 0:初始 1:开始 2:结束
        declare v_previous_date    bigint;        ## 把N天前的日期转化为 bigint
        declare v_debug            varchar(5);    ## 当输入debug(大小写均可)时,将是调试模式,只打印语句而不真正的执行		
		DECLARE my_cur CURSOR for SELECT id,is_bak,is_add_condition,source_schema,source_table,target_schema,target_table,i_flist,i_flist,field_name,
		                                 where_condition,sub_qry,where_days,batch_cnt,sleep_sec,bak_status,del_status,debug
		                          FROM my_tools.t_move_data_init where is_enable = 1;
	  DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = true;
		
	  open my_cur;
		read_loop:loop
	  fetch my_cur into  v_id,v_bak,v_add_condition,v_source_schema,v_source_table,v_target_schema,v_target_table,v_i_flist,v_u_flist,v_field_name,
	                     v_where_condition,v_sub_qry,v_where_days,v_batch_cnt,v_sleep_sec,v_bak_status,v_del_status,v_debug;
				IF done then                    
					leave read_loop;
				END IF;
								
				IF v_bak+0=1 and v_bak_status=1 THEN
				   SELECT CONCAT('温馨提示:上一次备份还没有结束,所以本次被跳过!') AS result;
				   ITERATE read_loop;
				END IF;

                ### 检测一波表是否存在
				select count(*) into @v_cnt from information_schema.tables where table_schema=v_source_schema and table_name = v_source_table;
                IF @v_cnt = 0 then
				   SELECT CONCAT('温馨提示:源 库名.表名=【',v_source_schema,'.',v_source_table,'】不存在,将进行下一轮循环!') AS result;
				   ITERATE read_loop;				
				END IF;

				### 开始操作时更新开始时间
				update my_tools.t_move_data_init set start_time = now() where id = v_id;
                set v_previous_date = unix_timestamp(date_format(now()-interval v_where_days day, '%Y-%m-%d 00:00:00'))*1000;				
                ##开始备份操作
				IF v_bak+0=1 then
				    select count(*) into @v_cnt from information_schema.tables where table_schema=v_target_schema and table_name = v_target_table;
					IF @v_cnt = 0 then
					   SELECT CONCAT('温馨提示:目标 库名.表名=【',v_target_schema,'.',v_target_table,'】不存在,将进行下一轮循环!') AS result;
					   ITERATE read_loop;				
					END IF;

				    ### 开始备份时给做个开始的标记
					update my_tools.t_move_data_init set bak_status = 1 where id = v_id;
		            set v_where_condition = replace(v_where_condition,'{}',v_previous_date);
					set v_sub_qry = replace(v_sub_qry,'{}',v_previous_date);
					
					select '温馨提示: 休息3S后,开始插入数据...' result;
					select sleep(3);  ## 休眠一下				
					call my_tools.sp_batch_dml('i',v_source_schema, v_source_table, v_target_schema, v_target_table, v_i_flist, v_u_flist,
									              v_field_name, v_where_condition, v_sub_qry, v_add_condition+0, v_batch_cnt, v_sleep_sec, v_debug);

					
					### 结束备份时更新标记
					update my_tools.t_move_data_init set bak_status = 2 where id = v_id;
					select '温馨提示: 插入数据完成!!! 休息3S' result;
					select sleep(3);  ## 休眠一下
				END IF;
				
				select '温馨提示: 休息3S后,开始删除数据... ' result;
				select sleep(3);  ## 休眠一下
				
				### 再次检测一次是否可以进行删除操作
				select bak_status into @bak_status from my_tools.t_move_data_init where id = v_id;
				IF v_bak+0=1 and @bak_status=1 THEN
				   SELECT CONCAT('温馨提示:上一次备份还没有结束,所以本次被跳过!') AS result;
				   ITERATE read_loop;
				END IF;
				
				### 再次进行一次替换,以防止只做删除操作
				set v_where_condition = replace(v_where_condition,'{}',v_previous_date);
				set v_sub_qry = replace(v_sub_qry,'{}',v_previous_date);
	            ### 开始删除时给做个开始的标记(不管上次是否成功删除,本次继续开始新的删除任务)
				update my_tools.t_move_data_init set del_status = 1 where id = v_id;
			    call my_tools.sp_batch_dml('d',v_source_schema, v_source_table, v_target_schema, v_target_table, v_i_flist, v_u_flist,
									              v_field_name, v_where_condition, v_sub_qry, v_add_condition+0, v_batch_cnt, v_sleep_sec, v_debug);				
			  select '温馨提示: 删除数据完成!!!' result;
              ### 结束删除时更新标记和结束时间 
              update my_tools.t_move_data_init set del_status = 2,end_time = now() where id = v_id;

			  ## 如果游标中间有查询结果为NULL,则会自动设置 done = 1 或TRUE,导致游标提前结束循环.所以最后要重新设置一次为FALSE
			  SET done = false;

		end loop;		
	  close my_cur;
	  
end $$
DELIMITER ;


use my_tools;
DELIMITER $$
DROP FUNCTION IF EXISTS  `fn_get_is_master`$$
CREATE FUNCTION `fn_get_is_master`()
RETURNS bit DETERMINISTIC
BEGIN
###  DEMO : SELECT fn_get_is_master(); 
###  此函数用于判断当前服务器是否主库 返回值 0:否  1:是
###  author : baider      date: 2021-06-25

## 以下2张关于复制主从同步的表位于 performance_schema
## replication_connection_status          此表记录的是从库IO线程的连接状态信息
## replication_connection_configuration   此表记录从库用于连接到主库的配置参数,该表中存储的配置信息在执行change master语句时会被修改

## replication_connection_status与replication_connection_configuration 表相比，其表中的记录变更更频繁
## 由于维护导致STOP SLAVE等操作,前者更敏感,可能导致查询出来的从库成了主库,从而执行了此过程(导致主从同步异常)

	select count(*) into @is_slave	from performance_schema.replication_connection_configuration;
    if @is_slave = 0 then 
       ### 主库
	   return 1;
    else
	   ### 从库
	   return 0;
    end if;	
	
END $$
DELIMITER ;

DELIMITER $$
drop EVENT IF EXISTS `ty_se_move_data`;
CREATE EVENT  `ty_se_move_data`
ON SCHEDULE EVERY 1 day  #执行周期，还有天、月等等 
STARTS concat(date_format(now(),'%Y-%m-%d'),' 07:00:00')
ON COMPLETION PRESERVE
ENABLE
COMMENT 'moving old data'
DO BEGIN
   
	select fn_get_is_master()+0 into @is_master;
    if @is_master = 1 then 
       CALL sp_move_data;
    else
	   select '当前是从库不需要执行此过程!' result;
    end if;	

END$$
DELIMITER ;  