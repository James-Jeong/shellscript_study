#/bin/sh
#$1 = file path
#$2 = method name

if [ $# -ne 2 ] ; then
	echo "need argument
	ex> $0 <file_path> <method_name>
	"
	exit
fi

is_method_found=""
method_list=("invite" "message" "register" "subscribe" "notify" "prack" "option" "ack" "bye" "update")
for METHOD in ${method_list[@]};
do
	if [[ "$2" == "$METHOD" ]];then
		is_method_found="y"
		break
	fi
done

if [ -z $is_method_found ];then
	echo "! Not supported the method : $2"
	echo "F"
	exit
fi
method_name=$(echo $2 | tr '[a-z]' '[A-Z]')


# @ Get current sip trace file names
uas_log_file=$ACCEPT_REPORT_PATH"/"$1"/uas.temp"
if [ ! -f $uas_log_file ];then
	echo "! Wrong path or Not found : $uas_log_file"
	echo "F"
	exit
fi

uac_log_file=$ACCEPT_REPORT_PATH"/"$1"/uac.temp"
if [ ! -f $uac_log_file ];then
	echo "! Wrong path or Not found : $uac_log_file"
	echo "F"
	exit
fi


uas_wrong_count=0
uac_wrong_count=0


# @ Get uacip & uacport
source ${ACCEPT_TEST_PATH}/"$1"/common_info.csv
uac_ip=$in_ip


# @@@ UAC

# @ Find the Register's locations
via_locs=$(awk -v cur_loc="$cur_loc" -v uac_info="$uac_ip" -v method="$method_name" 'NR>=cur_loc { if (($1==method) && (getline > 0) && (index($0, uac_info) != 0)) {
			printf("%s,", NR)
		}}' $uac_log_file)
#echo $via_locs

list_via_locs=()
for (( i=1; ; i++ ))
do
	via_loc=$(echo $via_locs | cut -d ',' -f $i )
	if [ -z $via_loc ];then
		break
	fi
	list_via_locs+=($via_loc)
done

len_list_via_locs=${#list_via_locs[*]}
#echo $len_list_via_locs
if [ $len_list_via_locs -eq 0 ];then
	echo "! Not found the method's message in uac"
	echo "F"
	exit
fi

# @ Find the 200 OK's locations
ok_locs=$(awk 'NR>=(reg_loc-2) { if ((index($0, "200") != 0) && (index($0, "OK") != 0)) { 
			printf("%s,", NR)
		}}' $uac_log_file)
#echo $ok_locs

list_ok_locs=()
for (( i=1; ; i++ ))
do
	ok_loc=$(echo $ok_locs | cut -d ',' -f $i )
	if [ -z $ok_loc ];then
		break
	fi
	list_ok_locs+=($ok_loc)
done

len_list_ok_locs=${#list_ok_locs[*]}
#echo $len_list_ok_locs
if [ $len_list_ok_locs -eq 0 ];then
	echo "! Not found 200 OK message in uac"
	echo "F"
	exit
fi

if [ ${len_list_via_locs} -ne ${len_list_ok_locs} ];then
	echo "! Wrong match : $method_name & 200 OK"
	echo "F"
	exit
fi


# @ Find the Register messages & Compare Call-ID for each of the messages
uac_list_callid=()
wrong_count=0

# @ Method
count=0
for LOC in ${list_via_locs[@]};
do
#	echo "LOC : $LOC"
	result=$(awk -v reg_loc="${LOC}" -v method="$method_name" 'NR>=(reg_loc-2) { if ($1==method) { 
			for(i=1; i <= 50; i++) {
				if(index($1, "Call-ID") != 0){
					break;
				}
				getline;
			}
			printf("%s", $2); exit
		}}' $uac_log_file)

	if [ -z $result ];then
		break
	fi

	if [ $count -gt 0 ];then
		temp_count=$(($count-1))
#		echo "temp_count : $temp_count"
		if [[ "${uac_list_callid[$temp_count]}" != "$result" ]];then
			wrong_count=$(($wrong_count+1))
			echo "${uac_list_callid[$temp_count]}"
			echo "$result"
			break
		fi
	fi

	uac_list_callid+=($result)
#	echo "callid : ${uac_list_callid[$count]}"
#	echo ""
	count=$(($count+1))
done

# @ 200 OK
for LOC in ${list_ok_locs[@]};
do
#	echo "LOC : $LOC"
	result=$(awk -v reg_loc="${LOC}" 'NR>=(reg_loc-2) { if (index($1, "Call-ID") != 0) { 
			printf("%s", $2); exit
		}}' $uac_log_file)

	if [ -z $result ];then
		break
	fi

	if [ $count -gt 0 ];then
		temp_count=$(($count-1))
#		echo "temp_count : $temp_count"
		if [[ "${uac_list_callid[$temp_count]}" != "$result" ]];then
			wrong_count=$(($wrong_count+1))
			echo "${uac_list_callid[$temp_count]}"
			echo "$result"
			break
		fi
	fi

	uac_list_callid+=($result)
#	echo "callid : ${uac_list_callid[$count]}"
#	echo ""
	count=$(($count+1))
done



# @@@ UAS

# @ Find the Register's locations
via_locs=$(awk -v cur_loc="$cur_loc" -v uac_info="$uac_ip" -v method="$method_name" 'NR>=cur_loc { if ($1==method) {
			for(i=1; i <= 10; i++) {
				if(index($0, uac_info) != 0){
					break;
				}
				getline;
			}
			printf("%s,", NR)
		}}' $uas_log_file)
#echo $via_locs

list_via_locs=()
for (( i=1; ; i++ ))
do
	via_loc=$(echo $via_locs | cut -d ',' -f $i )
	if [ -z $via_loc ];then
		break
	fi
	list_via_locs+=($via_loc)
done

len_list_via_locs=${#list_via_locs[*]}
#echo $len_list_via_locs
if [ $len_list_via_locs -eq 0 ];then
	echo "! Not found the method's message in uas"
	echo "F"
	exit
fi

# @ Find the 200 OK's locations
ok_locs=$(awk 'NR>=(reg_loc-2) { if ((index($0, "200") != 0) && (index($0, "OK") != 0)) { 
			printf("%s,", NR)
		}}' $uas_log_file)
#echo $ok_locs

list_ok_locs=()
for (( i=1; ; i++ ))
do
	ok_loc=$(echo $ok_locs | cut -d ',' -f $i )
	if [ -z $ok_loc ];then
		break
	fi
	list_ok_locs+=($ok_loc)
done

len_list_ok_locs=${#list_ok_locs[*]}
#echo $len_list_ok_locs
if [ $len_list_ok_locs -eq 0 ];then
	echo "! Not found 200 OK message in uas"
	echo "F"
	exit
fi

if [ ${len_list_via_locs} -ne ${len_list_ok_locs} ];then
	echo "! Wrong match : $method_name & 200 OK"
	echo "F"
	exit
fi


# @ Find the Register messages & Compare Call-ID for each of the messages
uas_list_callid=()
wrong_count=0

# @ Method
count=0
for LOC in ${list_via_locs[@]};
do
#	echo "LOC : $LOC"
	result=$(awk -v reg_loc="${LOC}" -v method="$method_name" 'NR>=(reg_loc-2) { if ($1==method) { 
			for(i=1; i <= 50; i++) {
				if(index($1, "Call-ID") != 0){
					break;
				}
				getline;
			}
			printf("%s", $2); exit
		}}' $uas_log_file)

	if [ -z $result ];then
		break
	fi

	if [ $count -gt 0 ];then
		temp_count=$(($count-1))
#		echo "temp_count : $temp_count"
		if [[ "${uas_list_callid[$temp_count]}" != "$result" ]];then
			wrong_count=$(($wrong_count+1))
			echo "prev : ${uas_list_callid[$temp_count]}"
			echo "cur : $result"
			break
		fi
	fi

	uas_list_callid+=($result)
#	echo "callid : ${uas_list_callid[$count]}"
#	echo ""
	count=$(($count+1))
done

# @ 200 OK
for LOC in ${list_ok_locs[@]};
do
#	echo "LOC : $LOC"
	result=$(awk -v reg_loc="${LOC}" 'NR>=(reg_loc-2) { if (index($1, "Call-ID") != 0) { 
			printf("%s", $2); exit
		}}' $uas_log_file)

	if [ -z $result ];then
		break
	fi

	if [ $count -gt 0 ];then
		temp_count=$(($count-1))
#		echo "temp_count : $temp_count"
		if [[ "${uas_list_callid[$temp_count]}" != "$result" ]];then
			wrong_count=$(($wrong_count+1))
			echo "${uas_list_callid[$temp_count]}"
			echo "$result"
			break
		fi
	fi

	uas_list_callid+=($result)
#	echo "callid : ${uas_list_callid[$count]}"
#	echo ""
	count=$(($count+1))
done



# @ Compare each call-id of the uac & the uas
if [ $wrong_count -eq 0 ];then
	if [[ "${uac_list_callid[0]}" != "${uas_list_callid[0]}" ]];then
		wrong_count=$(($wrong_count+100))
	fi
fi



# @ Check whether uas_wrong_count is not 0 
if [ $wrong_count -eq 0 ];then
	echo "S"
else
	echo "! wrong count : $wrong_count"
	echo "F"
fi

rm $uac_log_file $uas_log_file
