#/bin/sh
#$1 = file path

if [ $# -ne 1 ] ; then
	echo "need argument
	ex> $0 <file_path>
	"
	exit
fi


# @ Get uas & uac res file name + current sip trace file names
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

is_uac_res=""
is_uas_res=""

uas_res_file=$ACCEPT_REPORT_PATH"/"$1"/uas.res"
if [ -f $uas_res_file ];then
	is_uas_res="y"
fi

uac_res_file=$ACCEPT_REPORT_PATH"/"$1"/uac.res"
if [ -f $uac_res_file ];then
	is_uac_res="y"
fi

uas_wrong_count=0
uac_wrong_count=0


# @ Get uacip & uacport
source ${ACCEPT_TEST_PATH}/"$1"/info.csv
uac_ip=$in_ip

# @ Get uac hostname
uac_hostname=$(awk -F ';' '{print $3}' ${ACCEPT_TEST_PATH}/"$1"/caller.csv)
uac_hostname=$(echo $uac_hostname | cut -c 1-)

# @ Verify uac->ibcf invite via header
result=$(awk '{ if (index($0, "INVITE") != 0) {
			for (i=1; i<50; i++) {
				if (index($1, "Via") != 0) {
					printf("%s", $3); exit
				}
				getline;
			}
			exit
		}}' $uac_log_file)

if [ -z $result ];then
	echo "! Not found Via header in INVITE of uac"
	echo "F"
	exit
fi

result_uac_hostname=$(echo $result | cut -d ';' -f 1 | cut -d ':' -f 1)

#	echo "# uac -> ibcf invite via : $result"

if [[ "$result_uac_hostname" != "$uac_hostname" ]];then
	echo "! uac->ibcf invite wrong hostname"
	uac_wrong_count=$(($uac_wrong_count+1))
fi

# @ Verify ibcf->uac 100 Trying via header
result=$(awk '{ if (index($0, "Trying") != 0) {
			for (i=1; i<50; i++) {
				if (index($1, "Via") != 0) {
					if (index($0, ";received=") != 0) {
						printf("%s", $3); exit
					}
				}
				getline;
			}
			exit
		}}' $uac_log_file)

if [ -z $result ];then
	echo "! Not found received in uac 100 Trying of tmp"
	echo "F"
	exit
fi

result_uac_ip=$(echo $result | cut -d ';' -f 3 | cut -d '=' -f 2 | rev | cut -c 2- | rev)
result_uac_hostname=$(echo $result | cut -d ';' -f 1 | cut -d ':' -f 1)

#	echo "# ibcf -> uac 100 Trying via : $result"

if [[ "$result_uac_ip" != "$uac_ip" ]];then
	echo "! ibcf->uac 100 Trying wrong ip"
	uac_wrong_count=$(($uac_wrong_count+2))
fi

if [[ "$result_uac_hostname" != "$uac_hostname" ]];then
	echo "! ibcf->uac 100 Trying wrong hostname"
	uac_wrong_count=$(($uac_wrong_count+3))
fi

# @ Verify ibcf->uas invite's second via header
result=$(awk '{ if (index($0, "INVITE") != 0) {
			for (i=1; i<50; i++) {
				if (index($1, "Via") != 0) {
					if (index($0, ";received=") != 0) {
						printf("%s", $3); exit
					}
				}
				getline;
			}
			exit
		}}' $uas_log_file)

if [ -z $result ];then
	echo "! Not found received in uas invite of tmp"
	echo "F"
	exit
fi

result_uac_ip=$(echo $result | cut -d ';' -f 3 | cut -d '=' -f 2 | rev | cut -c 2- | rev)
result_uac_hostname=$(echo $result | cut -d ';' -f 1 | cut -d ':' -f 1)

#	echo "# ibcf -> uas invite via : $result"

if [[ "$result_uac_ip" != "$uac_ip" ]];then
	echo "! ibcf->uas invite received wrong ip"
	uas_wrong_count=$(($uas_wrong_count+1))
fi

if [[ "$result_uac_hostname" != "$uac_hostname" ]];then
	echo "! ibcf->uas invite wrong hostname"
	uas_wrong_count=$(($uas_wrong_count+2))
fi



# @ Check whether uas_wrong_count is not 0 
if [ $uas_wrong_count -eq 0 ] && [ $uac_wrong_count -eq 0 ];then
	echo "S"
else
	echo "! uac wrong count : $uac_wrong_count"
	echo "! uas wrong count : $uas_wrong_count"
	echo "F"
fi

rm $uac_log_file $uas_log_file
