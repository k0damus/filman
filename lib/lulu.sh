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
	#Inicjacja pustych zmiennych
	data=()
	pfx=()
	sfx=()
	tkn=()
	rev=()

#	data=($( curl -sL "${1}" | sed -n 's/^.*sp|\(.*\)|sources.*$/\1/p' | tr "|" " "))
	IFS=" " read -r -a data <<< "$( curl -sL "${1}" | sed -n 's/^.*sp|\(.*\)|sources.*$/\1/p' | tr "|" " "  )"

#	Dla prostoty późniejszego obrabiania odwracamy kolejność elementów macierzy
	for (( i=( "${#data[@]}" - 1 ); i>=0; i-- )) do
		rev+=( "${data[i]}" )
	done


# Domyślnie tniemy tablicę do 8 elementu
	cut_len=8

# Chyba, że mamy link CDN, to wtedy nie XD Zaś musimy se wyliczyć jak ciąć ;)
	if [[ "${rev[1]}" =~ cdn ]] ; then
		cut_len=9
		parts_link(){
			echo "https://${pfx[0]}.${pfx[1]}-${pfx[2]}.org/${pfx[3]}/${pfx[4]}/${pfx[5]}/${pfx[6]}/master.m3u8?t=${token_string}&s=${sfx[0]}&e=${sfx[1]}&f=${sfx[2]}&i=0.3&sp=0"
		}
	else
		parts_link() {
			echo "https://${pfx[0]}.${pfx[1]}.org/${pfx[2]}/${pfx[3]}/${pfx[4]}/${pfx[5]}/master.m3u8?t=${token_string}&s=${sfx[0]}&e=${sfx[1]}&f=${sfx[2]}&i=0.3&sp=0"
		}
  fi

#	Dane do zbudowania linku: pfx - prefixy, sfx - suffixy, tkn - dane tokenów

#	Prefixy to zawsze 8 pierwszych elementów, chyba, że mamy do czynienia z CDN to wtedy jest ich 9. Teoretycznie element 7 i 8 (lub 8 i 9) możnaby olać, bo to 'master' i 'm3u8'. Ale niech se już zostanie jak jest ;)
	pfx=( "${rev[@]:0:${cut_len}}" )

#	Sufixy: 3 ostatnie elementy
	sfx=( "${rev[@]:( ${#rev[@]} - 3)}" )

#	Tokeny - to wszystko pomiędzy ${pfx} i ${sfx}. Tylko tutaj musimy sobie obliczyć ile tych elementów jest. Po kolei robimy tak:
#	 - obcinamy naszą tablicę wejściową o 8 (lub 9) pierwszych elementów
#	 - obliczamy długość nowopowstałej tablicy
#	 - wybieramy z niej elementy: od 0 czyli pierwszego elementu tokena, do (dl_tablicy - 3), bo 3 ostatnie elementy już są w drugim kroku

	tkn=( "${rev[@]:${cut_len}}" )
	tkn_len="${#tkn[@]}"
	tkn=( "${tkn[@]:0:( ${tkn_len} - 3 ) }" )

#	Łączymy te tokeny w całość przy pomocy znaku -
	token_string=$( IFS='-'; echo "${tkn[*]}" )


#	Tokeny:	t - ciąg tokenów - może mieć długość 1, 2 albo 3 (a może nawet 4?) stringów -> wtedy trzeba je połączyć myślnikiem
#						s - unix timestamp, prawdopodobnie to moment kliknięcia w główny link
#						e - expiration time? chyba zawsze ustawione na 8h = 28800s, nie widziałem, żeby było inaczej, ale niech zostanie jako zmienna
#						f - ID pliku
#						i - nie mam pojęcia - arbitralnie ustawione na 0.3
#						sp - jak wyżej - arbitralnie ustawione na 0

#	Tworzymy link
	parts_link=$(parts_link)

##########
# Debug XD
#	echo "PFX: ${pfx[@]}"
#	echo "SFX: ${sfx[@]}"
#	echo "TKN: ${token_string}"
#	parts_link=$(parts_link)
#	echo "LINK: ${parts_link}"
#	exit 1
##########

# Lecimy dalej
	parts_path=$( curl -sL "${parts_link}" | grep index )

	curl -sL "${parts_path}" | grep -v ^# > "${parts_list}"

#	Patrzymy czy potrzebny jest klucz szyfrujący
	response=$(curl -sL "${parts_path}")
	if echo "${response}" | grep -q "enc"; then
		key_url=$(echo "${response}" | grep enc | cut -d '"' -f2)
		curl -sL "${key_url}" -o "${tmp_dir}/encryption.key"
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

