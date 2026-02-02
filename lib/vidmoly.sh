#!/usr/bin/env bash

vidmolyTest(){
	#TODO: trzeba poprawić to sprawdzanie i doodać jakiś oczekiwanie czasowe
	data_check=$(curl -sL "${1}" --max-time 5 -H "User-Agent: Mozilla/5.0" -H "Referer: https://vidmoly.to/")
	if [[ -z "${data_check}" || "${data_check}" == *"notice.php"* ]]; then
		is_ok=false
	else
		is_ok=true
	fi	
}

vidmoly(){
	local s
	echo "Czekamy 5 sekund żeby oszukać vidmoly..."
	for ((s=5; s>0; s--)); do
		echo "${s}..."
		sleep 1
	done

	if [[ "${1}" != *"embed"* ]]; then
		link=$( echo "${1}" | sed -n 's/\(https.*\)\(.me\/w\/\)\(.*\)$/\1.to\/embed-\3.html/p')
	else
		link="${1}"
	fi
	
	curl_opts=( "-H" "User-Agent: Mozilla/5.0" "-H" "Referer: https://vidmoly.to/" )
	app=$( curl -sL "${link}" | grep ^url | cut -d "'" -f2 )
	full_url=$( curl -sL ${link/me/net}${app} "${curl_opts[@]}" | grep sources | sed -n 's/^.*:"\(.*\)"}.*$/\1/p' )
	main_url=$( echo "${full_url}" |  tr -d ',' | sed -n 's/\(^.*\)\.urlset.*/\1/p' )
	parts_path=($( curl -sL "${full_url}" "${curl_opts[@]}" | grep index ))
	if [[ -z "${parts_path}" ]]; then
		parts_path=($( curl -sL "${full_url}" "${curl_opts[@]}" | grep index | head -n1 | sed -n 's/^.*\(https.*\)"$/\1/p'))
	fi
	if [[ "${#parts_path[@]}" -gt 1 ]]; then
		parts_path="${parts_path[0]}"
	fi
	curl -sL "${parts_path}" "${curl_opts[@]}" | grep -v ^# > "${parts_list}"
}