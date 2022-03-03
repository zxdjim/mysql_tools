#!/bin/bash
#by pis
## baider:20210810 修改为函数调用方式
#脚本执行时间放在0点后面执行,避免脚本执行跨天
##修改为直接删除某天前的数据

### 最后要执行的JS脚本路径 (paswd 前者为生产,后者为隔离)
js_path=/data/script/del_old_mongo.js
#paswd='HPVkd6DJJ3aoWXWTArt4'
paswd='#xkVox11rtTlA1@!rCNitNWAiVbwZ0'

master=$(/usr/bin/mongo -u admin -p "${paswd}" --host 127.0.0.1 --port 26060 --quiet --eval 'db.isMaster().primary')
master_ip=(${master%:*})

echo "/////////js开始处理删除过期数据/////////" > ${js_path}
 
function del_mongo()
{
	echo "use ${1}" >> ${js_path}
	fts=(${2})
	len=${#fts[*]}
	len_idx=$((len-1))
	for i in $(seq 0 5 ${len_idx})
	do
        j0=$((i))
		j1=$((i+1))
		j2=$((i+2))
		j3=$((i+3))
		j4=$((i+4))
		del=$((fts[j3]+fts[j4]))
		if [ "${fts[j2]}" == "0" ]; then
		   del_end_time=$(date -d "$(date +'%Y-%m-%d 00:00:00' --date='-'${fts[j3]}' day')" +%s)"000"
		else
		   del_end_time='"'$(date +'%Y-%m-%d 00:00:00' --date='-'${fts[j3]}' day')'"'
		fi
		if [ "${fts[j4]}" != "0" ]; then
			bak_date=$(date +%Y%m%d --date="-${fts[j3]} day")
			del_date=$(date +%Y%m%d --date="-${del} day")
			echo 'db.'${fts[j0]}'.aggregate([{$match:{"'${fts[j1]}'":{$lt:'${del_end_time}'}}},{$out:"'${fts[j0]}'_'${bak_date}'"}])'>>${js_path}
			echo 'db.'${fts[j0]}'_'${del_date}'.drop()'>>${js_path}
		fi
		echo 'db.'${fts[j0]}'.deleteMany({"'${fts[j1]}'":{$lt:'${del_end_time}'}})' >> ${js_path}
		echo '  ' >> ${js_path}
	done
	echo '/////////////////////////////' >> ${js_path}
}


## filters=(集合名称 过滤字段名称 字段类型 当前集合保留的天数 备份保留的天数) 字段类型: 0-时间戳(timestamp) 1-时间字符串("YYYY-MM-DD HH:MI:SS")  
## bc 库
filters=('original_match_market cd  0 7 7' 'bc_all_data st  1 3 7' 'original_match_stat cd 0 7 7'  
         'original_match_status cd  0 7 7')
del_mongo bc "${filters[*]}"

## bc_panda 库  'rh_match_market     createTime 0 3 7'                          'rh_match_result modifyTime 0 3 7'
filters=('rh_competition_info thirdSportTournamentDTO.createTime 0 30 7' 'rh_match_info thirdMatchInfoDTO.beginTime 0 30 7' 'rh_match_event  matchEventInfoDTO.eventTime 0 3 7'
         'rh_match_stat       modifyTime 0 3 7'
         'rh_match_status     thirdMatchStatusDTO.modifyTime 0 3 7')
del_mongo bc_panda "${filters[*]}"

## sr 库
filters=('sr_fix_matchInfo                beginTime  0 90 0' 'sr_fix_matchInfo_history modifyTime  0 90 0' 'sr_live_matchStatus modifyTime 0 30 0'  
         'sr_live_eventStatisticsInfo_uof modifyTime 0 30 0' 'sr_live_eventInfo_bmk    createTime  0 7  7' 'sr_live_marketOdds  createTime 0 7  7'
		 'sr_live_betSettlement           createTime 0 30 0' 'sr_live_betStatus        createdTime 0 30 0' 'sr_live_marketCashOut saveTime 0 7  7')
del_mongo sr "${filters[*]}"

## sr_panda 库 
filters=('sr_panda_fix_marketCategory modifyTime 0 30 0' 'sr_panda_fix_marketOutCome    modifyTime 0 30 0' 'sr_panda_fix_tournament               modifyTime 0 30 0'
         'sr_panda_fix_season         createTime 0 30 0' 'sr_panda_fix_matchInfo        modifyTime 0 30 0' 'sr_panda_fix_outright_matchInfo       modifyTime 0 30 0'
         'sr_panda_fix_playerProfile  modifyTime 0 30 0' 'sr_panda_live_matchStatus_uof modifyTime 0 30 0' 'sr_panda_live_eventStatisticsInfo_uof modifyTime 0 30 0'		 
         'sr_panda_live_eventInfo_bmk createTime 1  7 7' 'sr_panda_live_marketOdds      modifyTime 0 7  7' 'sr_panda_live_betSettlement           modifyTime 0 30 0'
		 'sr_panda_live_betStatus     modifyTime 0 30 0' 'sr_panda_live_marketCashOut   modifyTime 0 7  7')
del_mongo sr_panda "${filters[*]}"

## bg 库
filters=('bg_full_processmessage         modifyTime 0 7 0' 'bg_live_marketodds              CreateTime 1 7 0' 'bg_full_fixture                 CreateTime 1 30 0' 
         'bg_live_baseball_matchsummary  CreateTime 1 7 0' 'bg_live_basketball_matchdetails CreateTime 1 7 0' 'bg_live_basketball_matchsummary CreateTime 1 7 0'
		 'bg_live_event_feedgame         CreateTime 1 7 0' 'bg_live_football_matchdetails   CreateTime 1 7 0' 'bg_live_football_matchsummary   CreateTime 1 7 0'
		 'bg_live_icehockey_matchdetails CreateTime 1 7 0' 'bg_live_icehockey_matchsummary  CreateTime 1 7 0' 'bg_live_multisport_matchstate   CreateTime 1 7 0' 
         'bg_live_prematchfeed           CreateTime 1 7 0' 'bg_live_resultset               CreateTime 1 7 0' 'bg_live_tennis_matchdetails     CreateTime 1 7 0'
		 'bg_live_tennis_matchsummary    CreateTime 1 7 0' 'bg_live_volleyball_matchdetails CreateTime 1 7 0' 'bg_live_volleyball_matchsummary CreateTime 1 7 0'
		 'bg_live_badminton_matchdetails CreateTime 1 7 0' 'bg_live_badminton_matchsummary  CreateTime 1 7 0' 'bg_live_baseball_matchdetails   CreateTime 1 7 0'
		 'bg_live_baseball_matchsummary  CreateTime 1 7 0' 'bg_live_coverage                CreateTime 1 30 0' 'bg_toler_live_putRetryInfo     expireTime 0 7 0')
del_mongo bg "${filters[*]}"

## bg_panda 库
filters=('rh_match_event       modifyTime 0 7  0' 'rh_match_marketodds        modifyTime 0 7 0' 'rh_match_result     modifyTime 0 7 0' 
         'rh_match_status      modifyTime 0 7  0' 'bg_fix_matchinfo           CreateTime 1 7 0' 'rh_global_status    modifyTime 0 7 0'
		 'bg_live_coverage     CreateTime 1 30 0' 'bg_live_event_feedgame     CreateTime 1 7 0' 'bg_live_marketodds  CreateTime 1 7 0' 
         'bg_live_prematchfeed CreateTime 1 7  0' 'bg_toler_live_putRetryInfo expireTime 0 7 0' 'rh_market_status    modifyTime 0 7 0')
del_mongo bg_panda "${filters[*]}"

#########################
## gr 库
filters=('gr_events beginTime 0 1 3' 'gr_event_result createTime 0 1 3' 'gr_eventInfo_odds_value beginTime 0 1 3' 'gr_original_message beginTime 0 3 3')
del_mongo gr "${filters[*]}"

## gr_panda 库
filters=('rh_event_matchInfo object.beginTime 0 1 3' 'rh_third_match_market   modifyTime 0 2 3' 'rh_market_match_results modifyTime 0 1 3' 
         'rh_video_replay    modifyTime       0 1 3' 'rh_natch_statisticsInfo modifyTime 0 1 3' 'rh_team_ranking         modifyTime 0 1 3')
del_mongo gr_panda "${filters[*]}"
		 
## rb 库
filters=('rb_event_error createTimeStamp 0 7 0' 'rb_event_info createTimeStamp 0 7 0' 'rb_fix_matchinfo      createTimeStamp  0 7 0'
         'rb_message     createTimeStamp 0 7 0' 'rb_statistics createTimeStamp 0 7 0' 'replay_matchid_manager modifyTime      0 7 0')
del_mongo rb "${filters[*]}"

## filters=(集合名称 过滤字段名称 字段类型 当前集合保留的天数 备份保留的天数) 字段类型: 0-时间戳(timestamp) 1-时间字符串("YYYY-MM-DD HH:MI:SS")  

## rb_panda 库
filters=('rb_fix_matchinfo createTimeStamp 0 7 0' 'rh_match_event modifyTime 0 7 0' 'rh_match_info       modifyTime 0 7 0'
         'rh_match_status  modifyTime      0 7 0' 'rh_match_team  modifyTime 0 7 0' 'rh_match_tournament modifyTime 0 7 0')
del_mongo rb_panda "${filters[*]}"

## tx 库
filters=('tx_match matchTime 0 7 7' 'tx_all_odds matchTime 0 7 7' 'tx_odds matchTime 0 7 7')
del_mongo tx "${filters[*]}"

## tx_panda 库
filters=('rh_match_info   thirdMatchInfoDTO.beginTime 0 7 7' 'rh_match_market     modifyTime 0 7 7' 'multiple_ds_marketodds matchTime 0 7 7'
         'rh_match_status modifyTime                  0 7 7' 'rh_odds_field_cache matchTime  0 7 7' 'tx_match               matchTime 0 3 3')
del_mongo tx_panda "${filters[*]}"

## panda_report 库
filters=('standard_market_odds  modify_time    0 7  0' 'third_market_odds       modify_time    0 7  0'
         'third_market_odds_all dataSourceTime 0 15 7' 'third_market_status_all dataSourceTime 0 15 7')
del_mongo panda_report "${filters[*]}"

echo "/////////js结束处理删除过期数据/////////" >> ${js_path}

echo -e "\033[34;40m 开始删除过期数据...\033[0m"
echo "///////// 开始处理删除过期数据,当前时间: "`date +'%Y-%m-%d %T'` >> ${js_path}
/usr/bin/mongo -u admin -p "${paswd}" --host ${master_ip} --port 26060 --quiet < ${js_path}
echo "///////// 结束处理删除过期数据,当前时间: "`date +'%Y-%m-%d %T'` >> ${js_path}
echo -e "\033[34;40m 结束删除过期数据!!!\033[0m"