#!/usr/bin/env bash

vidmolyTest(){
	data_check=$(curl -sL "${1/net\/w/biz\/e}" --max-time 5 -H "User-Agent: Mozilla/5.0")
	if [[ -z "${data_check}" || "${data_check}" == *"notice.php"* ]]; then
		is_ok=false
	else
		is_ok=true
	fi	
}

vidmoly(){
	link="${link/net\/w/biz\/e}"
	curl_opts=( "-H" "User-Agent: Mozilla/5.0" "-H" "Referer: https://vidmoly.to/" )
	m3u8=$( curl -sL "${link}" | grep m3u8 | cut -d "'" -f2 )
	parts_path=$( curl -sL "${m3u8}" | grep ^https | head -n1 )
	curl -sL "${parts_path}" "${curl_opts[@]}" | grep -v ^# > "${parts_list}"
}
