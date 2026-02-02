#!/usr/bin/env bash

voeTest(){
	# dataCheck=$(curl -sL "${1}" --max-time 5)
	# if [[ -z "${dataCheck}" || "${dataCheck}" == *"File was deleted"* ]]; then
	# 	isOK=false
	# else
		isOK=true
	# fi
}


rot13() {
	tr 'A-Za-z' 'N-ZA-Mn-za-m'
}

replace_patterns() {
	sed -E 's/(@\$|\^\^|~@|%\?|\*~|!!|#&)//g'
}

shift_chars() {
	local shift="${1}"
	perl -pe "s/(.)/chr(ord(\$1)-${shift})/ge"
}

#Odszfrowywanie zaśmieconego JSONa przy pomocy perl'a - szybka akcja
deobfuscate_perl() {
	local json="${1}"
	json=$( echo "${json}" | sed 's/^\["//;s/"\]$//' )
	echo "${json}" \
		| rot13 \
		| replace_patterns \
		| base64 -d 2>/dev/null \
		| shift_chars 3 \
		| rev \
		| base64 -d 2>/dev/null
}

#Jeżeli system nie ma perl'a to robimy "ręcznie" - dużo wolniej, ale się da ;)
deobfuscate_noperl(){
	local json="${1}"
	local i tmpchar ascii_old ascii_new newchar newstring
	local shift=3
	json=$( echo "${json}" | sed 's/^\["//;s/"\]$//' )
	
	enc_string=$( echo "${json}" | rot13 | replace_patterns | base64 -d 2>/dev/null )
	
	#To leci zamiast wersji perlowej
	for ((i=0;i<${#enc_string};i++)); do
		tmpchar="${enc_string:${i}:1}"
		ascii_old=$(printf "%d" "'${tmpchar}")
		ascii_new=$(( "${ascii_old}" - "${shift}" ))
		newchar=$( printf "\x$(printf %x "${ascii_new}")" )
		newstring+="${newchar}"
	done
	echo "${newstring}" | rev | base64 -d 2>/dev/null
}

perl_check(){
	which perl >/dev/null
	if [[ $? == "0" ]]; then
		command=deobfuscate_perl
	else
		command=deobfuscate_noperl
	fi
}

voe(){
	local link="${1}"
	# echo $link
	step1=`curl -sL "${link}" | sed -n "s/^.*\(https.*\)';.*$/\1/p" | head -n1`
	# echo "step1: $step1"
	step2=`curl -sL "${step1}" | sed -n 's/^.*json">\(.*\)<\/script>/\1/p' `
	##echo $step2>/tmp/xxx

	#Sprawdzimy czym to odkodować - w zależności czy znajdzemy w systemie perl'a czy nie 
	perl_check
	json_data="$( "${command}" "${step2}")"
	#mp4=$( echo "${json_data}" | sed -n 's/^.*direct_access_url":"\(https.*\)","sdk.*$/\1/p' | tr -d '\\' ) # <- bezpośredni link do pliku mp4, pewnie da się obciąć link tylko do mp4, sprawdzimy ;>
	#m3u8=$( echo "${json_data}" | sed -n 's/^.*source":"\(https.*\)","fallback.*$/\1/p' | tr -d '\\' ) # <- link do części *.ts
	mp4="$(sed -n 's|.*direct_access_url":"\([^"]*\)".*|\1|p' <<< "$json_data" | sed 's/\\//g')"
	m3u8="$(sed -n 's|.*source":"\([^"]*\)".*|\1|p' <<< "$json_data" | sed 's/\\//g' )"
# echo $mp4
# echo $m3u8
	mainURL="${m3u8/master.*/}"
	# echo $mainURL
	partsPATH=$( curl -sL "${m3u8}" | grep ^index )
# echo $partsPATH
	curl -sL "${mainURL}${partsPATH}" | grep -v ^# | sed "s|^|${mainURL}|" > "${partsList}"
}
