#!/usr/bin/env python 
# encoding: utf-8 
# 直接把 common\y\s\b表数据迁移到tybss_new_bak；

"""
@author: kaiens
@file: del_tybss_order_5n.py
@time: 2020/10/15 22:19

"""
import pymysql
import datetime
import time
import logging

# 获取连接
def get_conn():
    conn = None
    try:
        conn = pymysql.connect(
            host="127.0.0.1",
            port=3306,
            user="root",
            passwd="xxxaaaa",
            database="tybss_merchant_common",
            charset="utf8"
        )
    except Exception as err:
        logging.error(err)
    return conn


# 查询语句执行
def get_data(sql):
    conn = get_conn()
    cur = conn.cursor()
    cur.execute(sql)
    data = cur.fetchall()
    conn.close()
    return data

##返回下个月1号
def get_next_month(pt_month):
    next_month = ""
    if int(str(pt_month)[4:]) == 12 :
        next_month = str(int(str(pt_month)[:4]) + 1) + "0101"
    else :
        next_month = str(int(pt_month) + 1) + "01"
    logging.info('分区日期：' + next_month )
    return next_month

# xday 天前的pdate 返回 'yyyymmdd'
def get_pdate_begin(xday):
    now_time = datetime.datetime.now()
    step_time = datetime.timedelta(days=xday)
    yes_time = now_time - step_time
    pdate = yes_time.strftime('%Y%m%d')
    return pdate


# xday 天前的时间戳 返回 1585843200 精确到秒
# 毫秒时间错需要乘 1000
def get_timestamp_begin(xday):
    now_time = datetime.datetime.now()
    step_time = datetime.timedelta(days=xday)
    yes_time = now_time - step_time
    pdate = yes_time.strftime('%Y%m%d')
    timeArray = time.strptime(pdate, "%Y%m%d")
    timeStamp = int(time.mktime(timeArray))
    return timeStamp


##从零时表获取order_no
def get_order_no(tstamp,limitnum = 40000):
    sql = '''SELECT order_no \
    FROM tybss_merchant_common.t_order WHERE order_status in (1,2,4,5) and modify_time < %s limit %d''' % (tstamp,limitnum)
    logging.info(sql)
    order_cid = get_data(sql)
    var1 = "\'aa\'"
    for one in order_cid:
        var1 = var1 + "," + "'" + str(one[0]) + "'"
    ##logging.info("取出的order_no:" + var1)
    return var1


# 按照赛事id获取需要删除的id v0
# limitnum 一次查询多少个id出来 默认40000
def get_cid(db_name,tb_name,str_order):
    sql = '''SELECT id
    FROM %s.%s WHERE order_no in (%s) ''' % (db_name,tb_name,str_order)
    logging.info(tb_name + '按照order_no取出数据id...')
    cid = get_data(sql)
    return cid

# 按照赛事id获取需��删除的id v1
# limitnum 一次查询多少个id出来 默认40000
def get_com_id(db_name,tb_name,vid,str_order):
    sql = '''SELECT %s
    FROM %s.%s WHERE order_no in (%s) ''' % (vid,db_name,tb_name,str_order)
    logging.info(tb_name + '按照order_no取出数据id...')
    id = get_data(sql)
    return id

###id组装,把id拼接为一串：
# id组装,zknum 多少个id分成一组,默认5000
def data_zk(cids,zknum = 5000):
    var1 = "-999"
    i = 0
    list = []
    if len(cids) > 0:
        for one in cids:
            var1 = var1 + "," + str(one[0])
            i = i + 1
            if (i == zknum):
                list.append(var1)
                var1 = "-999"
                i = 0
        list.append(var1)
        return list
    else:
        return 0


# 数据备份，放到tb_bigtable_statistic_his表中
def data_bak(db_name_bak,tb_name_bak,pt_month,db_name,tb_name,cidlist):
    #print("开始时间:", time.strftime("%Y-%m-%d %H:%M:%S", time.localtime()))
    conn = get_conn()
    cur = conn.cursor()
    if cidlist == 0 :
        logging.info(tb_name + '当天无数据')
    else:
        for cids in cidlist:
            try:
                sql = '''insert IGNORE into %s.%s \
        select %s,t.* from %s.%s t \
        where t.id in( %s )''' % (db_name_bak,tb_name_bak,pt_month,db_name,tb_name,cids)
                ##print(sql)
                sql_db='''use %s; ''' %(db_name_bak)
                cur.execute(sql_db)
                cur.execute(sql)
                conn.commit()

            except Exception as err:
                logging.error(err)
                logging.error(tb_name + ':备份失败！！！')
                conn.rollback()
                conn.close()
                exit(99)
        conn.close()


# 删除数据v0
def del_data(db_name,tb_name,cidlist):
    conn = get_conn()
    cur = conn.cursor()
    if cidlist == 0:
        logging.info(tb_name + ':无数据需要删除')
    else:
        for cids in cidlist:
            try:
                sql = '''delete from %s.%s \
        where id in ( %s )''' %(db_name,tb_name,cids)
                cur.execute(sql)
                conn.commit()

            except Exception as err:
                logging.error(err)
                logging.error(tb_name + ':删除数据失败！！！')
                conn.rollback()
                conn.close()
                exit(99)
        conn.close()

# 删除数据v1
def del_com_data(db_name,tb_name,vid,cidlist):
    conn = get_conn()
    cur = conn.cursor()
    if cidlist == 0:
        logging.info(tb_name + ':无数据需要删除')
    else:
        for cids in cidlist:
            try:
                sql = '''delete from %s.%s \
        where %s in ( %s )''' %(db_name,tb_name,vid,cids)
                cur.execute(sql)
                conn.commit()

            except Exception as err:
                logging.error(err)
                logging.error(tb_name + ':删除数据失败！！！')
                conn.rollback()
                conn.close()
                exit(99)
        conn.close()

##检查并添加对应的分区
def add_partiton_range(db_name,tb_name,pt_month):
    conn = get_conn()
    cur = conn.cursor()
    ##查询表是否有对应的分区：
    sql_pt = '''SELECT PARTITION_NAME FROM INFORMATION_SCHEMA.PARTITIONS
WHERE TABLE_SCHEMA = '%s' and TABLE_NAME = '%s'; ''' %(db_name,tb_name)
    ##print(sql_pt)
    pt_list = get_data(sql_pt)
    pt_range = get_next_month(pt_month)
    ##print(pt_list)
    flag = True
    for one in pt_list:

        ##判读是否有这个分区：
        if str(one[0])[3:] == pt_month:
            flag = False
            ##print(flag)

    sql = '''
ALTER TABLE %s.%s add partition(partition pt_%s values less than (%s)) ; 
    ''' %(db_name,tb_name,pt_month,pt_range)
    
    ##分区不存在��创建
    if flag :
        logging.info('添加分区:' + sql)
        sql_db='''use %s; ''' %(db_name)
        cur.execute(sql_db)
        cur.execute(sql)
    conn.close()


def move_data(xday):

    pdate = get_pdate_begin(xday)     ##20200916，参数为29的情况：
    logging.info("pdate" + pdate)
    pdate_1 = get_pdate_begin(xday+1)   ##20200915
    logging.info("pdate_1" + pdate_1)
    tstamp = get_timestamp_begin(xday) * 1000   ##过滤
    logging.info("数据时间戳：" + str(tstamp))
    pt_month = pdate_1[:6]
    logging.info("数据的月份：" + pt_month)

    begin_time =  int(time.mktime(time.localtime()))
    ##添加需要的分区
    add_partiton_range('tybss_new_bak','t_order_detail_his',pt_month)
    add_partiton_range('tybss_new_bak','t_settle_his',pt_month)
    add_partiton_range('tybss_new_bak','t_order_his',pt_month)
    ##add_partiton_range('tybss_new_bak',tb_name_bak,pt_month)

    while(True):
        ##time.sleep(4)
        time.sleep(3)
        ##取出需要删除的order
        order_source = get_order_no(tstamp,5000)

        if order_source == "\'aa\'":
            ##print("当天无数据...................")
            logging.info("备份结束!!!")
            break

        id_2 = get_cid('tybss_merchant_common','t_order_detail',order_source)
        cidlist_2 = data_zk(id_2,5000)
        data_bak('tybss_new_bak','t_order_detail_his',pdate_1,'tybss_merchant_common','t_order_detail',cidlist_2)
        del_data('tybss_merchant_common','t_order_detail',cidlist_2)
        

        id_3 = get_cid('tybss_merchant_common','t_settle',order_source)
        cidlist_3 = data_zk(id_3,5000)
        data_bak('tybss_new_bak','t_settle_his',pdate_1,'tybss_merchant_common','t_settle',cidlist_3)
        del_data('tybss_merchant_common','t_settle',cidlist_3)

        id_4 = get_cid('tybss_merchant_common','t_order_internationalize',order_source)
        cidlist_4 = data_zk(id_4,5000)
        ##data_bak('tybss_merchant_common','t_order_internationalize_old',pdate_1,'tybss_merchant_common','t_order_internationalize',cidlist_4)
        del_data('tybss_merchant_common','t_order_internationalize',cidlist_4)
        
        id_5 = get_cid('tybss_merchant_common','t_order_check',order_source)
        cidlist_5 = data_zk(id_5,5000)
        del_data('tybss_merchant_common','t_order_check',cidlist_5)

        id_6 = get_cid('tybss_merchant_common','t_order_check_risk',order_source)
        cidlist_6 = data_zk(id_6,5000)
        del_data('tybss_merchant_common','t_order_check_risk',cidlist_6)

        id_7 = get_com_id('tybss_merchant_common','t_dj_order','dj_id',order_source)
        cidlist_7 = data_zk(id_7,5000)
        del_com_data('tybss_merchant_common','t_dj_order','dj_id',cidlist_7) 
        
        ###必须把t_order放在最后，预防程序中断重启关联数据没有删除：
        id_1 = get_cid('tybss_merchant_common','t_order',order_source)
        cidlist_1 = data_zk(id_1,5000)
        data_bak('tybss_new_bak','t_order_his',pdate_1,'tybss_merchant_common','t_order',cidlist_1)
        del_data('tybss_merchant_common','t_order',cidlist_1)

        #休息设置
        current_time = int(time.mktime(time.localtime()))
        if (current_time - begin_time) > 600 :
            logging.info('休息12秒。。。')
            time.sleep(16)
            begin_time = int(time.mktime(time.localtime()))



if __name__ == '__main__':

    ##初始化日志模块：
    LOG_FORMAT = "%(asctime)s - %(levelname)s - %(message)s"
    DATE_FORMAT = "%Y/%m/%d %H:%M:%S %p"
    logging.basicConfig(filename='/data/script/mydel_c_bak.log', level=logging.INFO, format=LOG_FORMAT, datefmt=DATE_FORMAT)

    logging.info('del_tybss_bak_4n: 脚本开始运行')

    move_data(7)

    logging.info('del_tybss_bak_4n: 脚本运行结束')
