#!/usr/bin/env bash

lulustreamTest(){
	data_check=$(curl -sL "${1}" --max-time 5 -H "User-Agent: Mozilla/5.0")
	if [[ -z "${data_check}" || "${data_check}" == *"been deleted"* ]]; then
		is_ok=false
	else
		is_ok=true
	fi		
}

lulustream(){
	if grep -q sources < <( curl -sL "${1}" ); then 
		link=$( curl -sL "${1}" | grep sources | cut -d '"' -f2  )
		main_url=$( echo "${link}" | sed -n 's/\(^.*\)\/master.*$/\1/p' )
		parts_path=$( curl -sL "${link}" -H "Referer: https://luluvdo.com/" | grep index | sed -n 's/^.*\(https.*index-v1-a1.*\)$/\1/p')
		curl -sL "${parts_path}" -H "Referer: https://luluvdo.com/" | grep -v ^"#" > "${parts_list}" #### a czmuż to nie działa? oO
		#patrzymy czy potrzebny jest klucz szyfrujący
		response=$(curl -sL "${parts_path}")
		if echo "${response}" | grep -q "enc"; then
			key_url=$(echo "${response}" | grep enc | cut -d '"' -f2)
			curl -sL "${key_url}" -o "${tmp_dir}/encryption.key"
		fi

	else
		echo "Nie mogę znaleźć linku do źródeł."
	fi
}

lulustreamDecrypt(){
	for f in "${tmp_dir}"/*.ts; do
		NUM=$(echo "${f}" | grep -oP '\d+(?=\.ts)'  | tr -d '0' )
		NAME=${f##*/}
		IV=$(printf "%032x" "$NUM")
		echo "Odszyfrowywanie ${f}."
		openssl aes-128-cbc -d -in "${f}" -out "${tmp_dir}"/dec-"${NAME}" -nosalt -iv "${IV}" -K "$(xxd -p "${tmp_dir}"/encryption.key | tr -d '\n')"
		#Po zdekodowaniu nadpisujemy oryginał
		mv "${tmp_dir}"/dec-"${NAME}" "${f}"
	done
}