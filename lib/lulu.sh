#!/usr/bin/env bash

lulustreamTest(){
	dataCheck=$(curl -sL "${1}" --max-time 5 -H "User-Agent: Mozilla/5.0")
	if [[ -z "${dataCheck}" || "${dataCheck}" == *"been deleted"* ]]; then
		isOK=false
	else
		isOK=true
	fi		
}

lulustream(){
	if grep -q sources < <( curl -sL "${1}" ); then 
		link=$( curl -sL "${1}" | grep sources | cut -d '"' -f2  )
		mainURL=$( echo "${link}" | sed -n 's/\(^.*\)\/master.*$/\1/p' )
		partsPATH=$( curl -sL "${link}" -H "Referer: https://luluvdo.com/" | grep index | sed -n 's/^.*\(https.*index-v1-a1.*\)$/\1/p')
		curl -sL "${partsPATH}" -H "Referer: https://luluvdo.com/" | grep -v ^"#" > "${partsList}" #### a czmuż to nie działa? oO
		#patrzymy czy potrzebny jest klucz szyfrujący
		response=$(curl -sL "${partsPATH}")
		if echo "${response}" | grep -q "enc"; then
			key_url=$(echo "${response}" | grep enc | cut -d '"' -f2)
			curl -sL "${key_url}" -o "${tmpDir}/encryption.key"
		fi

	else
		echo "Nie mogę znaleźć linku do źródeł."
	fi
}

lulustreamDecrypt(){
	for f in "${tmpDir}"/*.ts; do
		NUM=$(echo "${f}" | grep -oP '\d+(?=\.ts)'  | tr -d '0' )
		NAME=${f##*/}
		IV=$(printf "%032x" "$NUM")
		echo "Odszyfrowywanie ${f}."
		openssl aes-128-cbc -d -in "${f}" -out "${tmpDir}"/dec-"${NAME}" -nosalt -iv "${IV}" -K "$(xxd -p "${tmpDir}"/encryption.key | tr -d '\n')"
		#Po zdekodowaniu nadpisujemy oryginał
		mv "${tmpDir}"/dec-"${NAME}" "${f}"
	done
}