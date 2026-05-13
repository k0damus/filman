#!/usr/bin/env bash

vidaraTest(){
	#TODO: trzeba poprawić to sprawdzanie i doodać jakiś oczekiwanie czasowe
	data_check=$(curl -sL "${1}" --max-time 5 -H "User-Agent: Mozilla/5.0" )
	if [[ -z "${data_check}" || "${data_check}" == *"notice.php"* ]]; then
		is_ok=false
	else
		is_ok=true
	fi	
}

vidara(){
	
	curl_opts=( "-H" "User-Agent: Mozilla/5.0" )
    filecode=$( echo "${link##*/}" )
	m3u8=$( curl -sL 'https://vidara.so/api/stream' --data-raw '{"filecode":"'"${filecode}"'","device":"web"}' | grep -o 'https://[^"]*' | head -n1 )
    main_url=$( echo "${m3u8}" | sed -n 's/\(^.*\/\)master.*$/\1/p' )
	parts_path=$( curl -sL "${m3u8}" | grep ^index )
    curl -L "${main_url}"/"${parts_path}" | grep -v ^# | sed "s|^|$main_url|g" > "${parts_list}"
}


