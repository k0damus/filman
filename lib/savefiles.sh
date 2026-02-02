#!/usr/bin/env bash

savefilesTest(){
	data_check=$( curl -sL "https://savefiles.com/dl?op=embed&file_code=${1##*/}&auto=1" -H "Referer: ${1}" -H "User-Agent: Mozilla/5.0"  )
	if [[ -z "${data_check}" || "${data_check}" == *"been deleted"* ]]; then
		is_ok=false
	else
		is_ok=true
	fi	
}

savefiles(){
	parts_path=$( curl -sL "https://savefiles.com/dl?op=embed&file_code=${1##*/}&auto=1" -H "Referer: ${1}" -H "User-Agent: Mozilla/5.0" | grep sources | sed -n 's/^.*"\(.*\)".*$/\1/p' )
	parts_link=$( curl -sL "${parts_path}" | grep index )
	main_url="${parts_link%/*}"
	curl -sL "${parts_link}" | grep -v ^# > "${parts_list}"
}