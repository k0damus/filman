#!/usr/bin/env bash
search=()

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

for file in "${SCRIPT_DIR}"/lib/*.sh; do
	[[ -f "${file}" ]] && source "${file}"
	search+=($( basename "${file}" .sh ))
done
#search_list - do użycia w grepie jako wyrażenie regularne w funkcji vodCheck
search_list=$(printf "%s|" "${search[@]}" | sed 's/|$//')
vod_regex=$(IFS='|'; echo "${search_list[*]}")


#Wyedytuj linię poniżej według własnych potrzeb 
#out_dir=TU-WPISZ-SWOJĄ-ŚCIEŻKĘ-DO-ZAPISU-POBRANYCH-VIDEO
#filman_dir=TU-WPISZ-SWOJĄ-ŚCIEŻKĘ-DO-OBRÓBKI-PLIKÓW-TYMCZASOWYCH

out_dir="${HOME}"/minidlna/torrent/complete
filman_dir='/tmp/filman'
user_media_type=''
req_check=()

req=('/usr/bin/curl' '/usr/bin/openssl')

for r in "${req[@]}"; do
	[[ ! -f "${r}" ]] && req_check+=("${r}");
done

if [[ "${#req_check[@]}" -gt 0 ]]; then
	echo "Brak tych programów: ${req_check[*]} Zainstaluj."
	exit 1
fi

if [[ ! -d "${out_dir}" ]]; then
	echo "Katalog ${out_dir} nie istnieje!"
	exit 1
fi

while getopts ":p:t:" opt; do
	case "${opt}" in
		p) path="${OPTARG}" ;;
		t) user_media_type="${OPTARG}" ;;
		:) echo "Opcja -${OPTARG} wymaga argumentu." ; exit 1 ;;
		?) echo "Niewłaściwa opcja: -${OPTARG}." ; exit 1 ;;
	esac
done

if [[ -z "${path}" ]] ; then
	echo "Brak / za malo danych."
	echo "Użycie: ./ripvid.sh -p <sciezka_do_katalogu_z_plikiem/plikami>"
	exit 1
fi

case "${user_media_type}" in
	n|N) echo "Wybrano opcję: Napisy." && media_type='Napisy' ;;
	p|P) echo "Wybrano opcję: PL." && media_type='PL' ;;
	d|D) echo "Wybrano opcję: Dubbing." && media_type='Dubbing' ;;
	e|E) echo "Wybrano opcję: ENG." && media_type='ENG' ;;
	*)   echo "Wybrano opcję: Lektor." && media_type='Lektor' ;;
esac

#Na początek: łapiemy CTRL + C i usuwamy nasz katalog w razie czego
cleanup() {
	echo
	echo "Sprzątamy..."
	rm -rf "${filman_dir}"
	echo
	exit 1
}

# trap "cleanup" SIGINT SIGTERM

#Tworzmy katalog tymczasowy do ściągania części filmu / odcinka serialu
make_dir(){
	mkdir -p "${filman_dir}"/"${1}"_temp
	tmp_dir="${filman_dir}/${1}_temp"
	touch "${tmp_dir}"/parts.txt
	parts_list="${tmp_dir}"/parts.txt
}

#Sprawdzamy z którego serwisu możemy pobrać dany film, tzn. czy w ogóle są dostępne linki.
vodCheck(){
	local movies
	movies=($(cut -d '@' -f 3-  < "${file}" | sort -u  ))
	lines=()
	for m in "${movies[@]}"; do
		#tu tworzymy tablicę z wszystkimi wynikami pasującymi do: nazwa serialu + typ video + szukany vod
		test_line=($( grep "${m}" "${file}" | grep "${media_type}" | grep -E "${vod_regex}" ))
		#tutaj iterujemy po całej tablicy i wykonujemy wstępne sprawdzenie czy video wogóle istnieje na tym vod czy nie zostało usunięte
		if [[ "${test_line}" ]]; then
			for line in "${test_line[@]}"; do
				test_vod=$( echo "${line}" | sed -n 's/^.*\/\/\([^.]*\)\..*$/\1/p' )
				#lulu może być "lulu" ablo "luluvdo", więc zmieniamy
				[[ "${test_vod}" =~ lulu ]] && test_vod='lulustream'
				test_link=$( echo "${line}" | cut -d "@" -f1 )
				#testujemy
				echo "Sprawdzam: ${test_link}"
				"${test_vod}"Test "${test_link}"
				#Jeśli nie mamy błędu to dopisujemy do ostatecznej tablicy lines()
				if [[ "${is_ok}" = true ]]; then
					line="${test_vod}@${line}"
					lines+=( "${line}" )
				fi
			done
		else
			echo "Brak źródeł dla tego filmu dla wybranej wersji: ${media_type}"
			echo "Dostępne możliwości do wyboru to: "
			versions=($( awk -F'@' '{ print $2 }' "${1}" | sort -u ))
			echo "${versions[@]}"
		fi
	done

	#sortujemy wynik
	lines=($( printf "%s\n" "${lines[@]}" | sort -u | tr '\n' ' '))
}



#Obsługa pobrania fragmentów filmu
getVideo(){
  if [ -s "${parts_list}" ]; then
    ilosc=$(wc -l < "${parts_list}")
    echo "Do pobrania ${ilosc} części."

    <"${parts_list}" xargs -n3 -P50 bash -c '
    	url="${1}"
    	outfile="${2}"
		vod="${3}"
    	part=$(basename "${outfile}" .ts)
    	echo "Pobieram część ${part} z '"${ilosc}"'"
		if [ "${vod}" == "vidmoly" ]; then
      		curl -sL -H "User-Agent: Mozilla/5.0" -H "Referer: https://vidmoly.to/" "${url}" -o "${outfile}"
		elif [ "${vod}" == "lulustream" ]; then
	  		curl -sL -H "Referer: https://luluvdo.com/" "${url}" -o "${outfile}"
	  	else
	  		curl -sL "${url}" -o "${outfile}"
	  	fi
	  	' _

		if [ -f "${tmp_dir}"/encryption.key ]; then
			lulustreamDecrypt
		fi

	else
		echo "Plik ${parts_list} wygląda na pusty!"
	fi
}

#Zapis do odpowiednich katalogów z podziałem na film/serial
saveVideo(){
	if ls "${tmp_dir}"/*.ts >/dev/null 2>&1; then
		if [[ -z "${series_check}" ]]; then
			cat $(ls "${tmp_dir}"/*.ts) > "${out_dir}"/"${title}"/"${title}".ts 
			echo "Film zapisany w ${out_dir}/${title}/${title}.ts"
		else
	    	cat "${tmp_dir}"/*.ts > "${out_dir}/${series_title}/${season_number}/${full_episode_title}.ts"
    		echo "Film zapisany w ${out_dir}/${series_title}/${season_number}/${full_episode_title}.ts"
		fi
	else
		echo "Brak plików *.ts w ${tmp_dir}"
	fi

}

#CZĘŚĆ GŁÓWNA
#####################################################
#Tutaj zaczynamy imprezę robiąc porządki jeśli trzeba
rm -rf "${filman_dir}" >/dev/null 2>&1 && mkdir -p "${filman_dir}"

for file in "${path}"*; do

	sed -i "s/'/_/g" "${file}" #xargs się pruje o apostrofy ', to je wypierdolimy'

	vodCheck "${file}"

	for data_line in "${lines[@]}"; do

		series_check=$( grep 'Serial' <<< "${data_line}" )

		if [[ -z "${series_check}" ]]; then
			pattern='^([a-z]*)@([^@]*)@.*@(.*)'
			if [[ "${data_line}" =~ $pattern ]]; then
				my_vod="${BASH_REMATCH[1]}"
				link="${BASH_REMATCH[2]}"
				title="${BASH_REMATCH[3]}"
			fi

			is_there=$( ls "${out_dir}/${title}/${title}".* 2>/dev/null )

			if [[ "${is_there}" ]]; then
				echo "Plik ${is_there##*/} już istnieje: ${is_there}"
			else
				make_dir "${title}"
				mkdir -p "${out_dir}/${title}"
				echo "Pobieram ${title} z ${my_vod}..."
				if [[ "${my_vod}" == 'vidoza' || "${my_vod}" == 'streamtape' ]] ; then
					"${my_vod}" "${link}"
				else
					"${my_vod}" "${link}"
					#Taka mała magia, żeby mieć fajne dane wejściowe do xargs
					awk -v dir="${tmp_dir}" -v vod="${my_vod}" '{printf "%s %s/%03d.ts %s\n", $0, dir, NR, vod}' "${parts_list}" > "${parts_list}.tmp" && mv -f "${parts_list}.tmp" "${parts_list}"
					getVideo
					saveVideo
				fi
			fi

		else			
			pattern='^([a-z]*)@(.*)@.*@Serial@(.*)@_(s[0-9]{2})_(e[0-9]{2,})@(.*$)'
			if [[ "${data_line}" =~ $pattern ]]; then
				my_vod="${BASH_REMATCH[1]}"
				link="${BASH_REMATCH[2]}"
				series_title="${BASH_REMATCH[3]}"
				season_number="${BASH_REMATCH[4]}"
				episode_number="${BASH_REMATCH[5]}"
				episode_title="${BASH_REMATCH[6]}"
				full_episode_title="[$season_number$episode_number]_$episode_title"
			fi

			is_there=$( ls "${out_dir}/${series_title}/${season_number}/${full_episode_title}".* 2>/dev/null )

			if [[ "${is_there}" ]]; then
				echo "Plik ${is_there##*/} już istnieje: ${is_there}"
			else
				make_dir "${episode_title}"
				mkdir -p "${out_dir}/${series_title}/${season_number}"
				echo "Pobieram ${series_title} - ${episode_title} z ${my_vod}..."
				if [[ "${my_vod}" == 'vidoza' || "${my_vod}" == 'streamtape' ]] ; then
					"${my_vod}" "${link}"
				else
					"${my_vod}" "${link}"
					#Taka mała magia, żeby mieć fajne dane wejściowe do xargs
					awk -v dir="${tmp_dir}" -v vod="${my_vod}" '{printf "%s %s/%03d.ts %s\n", $0, dir, NR, vod}' "${parts_list}" > "${parts_list}.tmp" && mv -f "${parts_list}.tmp" "${parts_list}"
					getVideo
					saveVideo
				fi
				rm -rf "${tmp_dir}"
			fi
		fi

	done

done

rm -rf "${filman_dir}" >/dev/null 2>&1
