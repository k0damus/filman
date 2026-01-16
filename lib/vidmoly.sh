#!/usr/bin/env bash

vidmolyTest(){
	#TODO: trzeba poprawić to sprawdzanie i doodać jakiś oczekiwanie czasowe
	dataCheck=$(curl -sL "${1}" --max-time 5 -H "User-Agent: Mozilla/5.0" -H "Referer: https://vidmoly.to/")
	if [[ -z "${dataCheck}" || "${dataCheck}" == *"notice.php"* ]]; then
		isOK=false
	else
		isOK=true
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
	
	curlOpts=( "-H" "User-Agent: Mozilla/5.0" "-H" "Referer: https://vidmoly.to/" )
	app=$( curl -sL "${link}" | grep ^url | cut -d "'" -f2 )
	fullURL=$( curl -sL ${link/me/net}${app} "${curlOpts[@]}" | grep sources | sed -n 's/^.*:"\(.*\)"}.*$/\1/p' )
	mainURL=$( echo "${fullURL}" |  tr -d ',' | sed -n 's/\(^.*\)\.urlset.*/\1/p' )
	partsPATH=($( curl -sL "${fullURL}" "${curlOpts[@]}" | grep index ))
	if [[ -z "${partsPATH}" ]]; then
		partsPATH=($( curl -sL "${fullURL}" "${curlOpts[@]}" | grep index | head -n1 | sed -n 's/^.*\(https.*\)"$/\1/p'))
	fi
	if [[ "${#partsPATH[@]}" -gt 1 ]]; then
		partsPATH="${partsPATH[0]}"
	fi
	curl -sL "${partsPATH}" "${curlOpts[@]}" | grep -v ^# > "${partsList}"
}