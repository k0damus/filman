#!/usr/bin/env bash

voeTest(){
	# data_check=$(curl -sL "${1}" --max-time 5)
	# if [[ -z "${data_check}" || "${data_check}" == *"File was deleted"* ]]; then
	# 	is_ok=false
	# else
		is_ok=true
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
	local i tmp_char ascii_old ascii_new new_char new_string
	local shift=3
	json=$( echo "${json}" | sed 's/^\["//;s/"\]$//' )
	
	enc_string=$( echo "${json}" | rot13 | replace_patterns | base64 -d 2>/dev/null )
	
	#To leci zamiast wersji perlowej
	for ((i=0;i<${#enc_string};i++)); do
		tmp_char="${enc_string:${i}:1}"
		ascii_old=$(printf "%d" "'${tmp_char}")
		ascii_new=$(( "${ascii_old}" - "${shift}" ))
		new_char=$( printf "\x$(printf %x "${ascii_new}")" )
		new_string+="${new_char}"
	done
	echo "${new_string}" | rev | base64 -d 2>/dev/null
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
	step1=`curl -sL "${link}" | sed -n "s/^.*\(https.*\)';.*$/\1/p" | head -n1`
	step2=`curl -sL "${step1}" | sed -n 's/^.*json">\(.*\)<\/script>/\1/p' `

	#Sprawdzimy czym to odkodować - w zależności czy znajdzemy w systemie perl'a czy nie 
	perl_check
	json_data="$( "${command}" "${step2}")"
	#mp4=$( echo "${json_data}" | sed -n 's/^.*direct_access_url":"\(https.*\)","sdk.*$/\1/p' | tr -d '\\' ) # <- bezpośredni link do pliku mp4, pewnie da się obciąć link tylko do mp4, sprawdzimy ;>
	#m3u8=$( echo "${json_data}" | sed -n 's/^.*source":"\(https.*\)","fallback.*$/\1/p' | tr -d '\\' ) # <- link do części *.ts
	mp4="$(sed -n 's|.*direct_access_url":"\([^"]*\)".*|\1|p' <<< "$json_data" | sed 's/\\//g')"
	m3u8="$(sed -n 's|.*source":"\([^"]*\)".*|\1|p' <<< "$json_data" | sed 's/\\//g' )"
	main_url="${m3u8/master.*/}"
	parts_path=$( curl -sL "${m3u8}" | grep ^index )
	curl -sL "${main_url}${parts_path}" | grep -v ^# | sed "s|^|${main_url}|" > "${parts_list}"
}
