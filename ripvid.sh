#!/usr/bin/env bash
search=()

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

for file in "${SCRIPT_DIR}"/lib/*.sh; do
	[[ -f "${file}" ]] && source "${file}"
	search+=($( basename "${file}" .sh ))
done
#search_list - do użycia w grepie jako wyrażenie regularne w funkcji vodCheck
search_list=$(printf "%s|" "${search[@]}" | sed 's/|$//')


#Wyedytuj linię poniżej według własnych potrzeb 
outDir="${HOME}"/minidlna/torrent/complete
fTmp='/tmp/filman'
mType=''
reqCheck=()

req=('/usr/bin/curl' '/usr/bin/openssl')

for r in "${req[@]}"; do
	[ ! -f "${r}" ] && reqCheck+=("${r}");
done

if [ "${#reqCheck[@]}" -gt 0 ]; then
	echo "Brak tych programów: ${reqCheck[*]} Zainstaluj."
	exit 1
fi

if [ ! -d "${outDir}" ]; then
	echo "Katalog ${outDir} nie istnieje!"
	exit 1
fi

while getopts ":p:t:" opt; do
	case "${opt}" in
		p) path="${OPTARG}" ;;
		t) mType="${OPTARG}" ;;
		:) echo "Opcja -${OPTARG} wymaga argumentu." ; exit 1 ;;
		?) echo "Niewłaściwa opcja: -${OPTARG}." ; exit 1 ;;
	esac
done

if [ -z "${path}" ] ; then
	echo "Brak / za malo danych."
	echo "Użycie: ./ripvid.sh -p <sciezka_do_katalogu_z_plikiem/plikami>"
	exit 1
fi

case "${mType}" in
	n|N) echo "Wybrano opcję: Napisy." && mediaType='Napisy' ;;
	p|P) echo "Wybrano opcję: PL." && mediaType='PL' ;;
	d|D) echo "Wybrano opcję: Dubbing." && mediaType='Dubbing' ;;
	e|E) echo "Wybrano opcję: ENG." && mediaType='ENG' ;;
	*)   echo "Wybrano opcję: Lektor." && mediaType='Lektor' ;;
esac

#Na początek: łapiemy CTRL + C i usuwamy nasz katalog w razie czego
cleanup() {
	echo
	echo "Sprzątamy..."
	rm -rf "${fTmp}"
	echo
	exit 1
}

# trap "cleanup" SIGINT SIGTERM

#Tworzmy katalog tymczasowy do ściągania części filmu / odcinka serialu
make_dir(){
	mkdir -p "${fTmp}"/"${1}"_temp
	tmpDir="${fTmp}/${1}_temp"
	touch "${tmpDir}"/parts.txt
	partsList="${tmpDir}"/parts.txt
}

#Sprawdzamy z którego serwisu możemy pobrać dany film, tzn. czy w ogóle są dostępne linki.
vodCheck(){
	movies=($(cut -d '@' -f 3-  < "${file}" | sort -u  ))
	lines=()
	for m in "${movies[@]}"; do
		#tu tworzymy tablicę z wszystkimi wynikami pasującymi do: nazwa serialu + typ video + szukany vod
		testLine=($( grep "${m}" "${file}" | grep "${mediaType}" | grep -E \"${search_list}\" ))
		#tutaj iterujemy po całej tablicy i wykonujemy wstępne sprawdzenie czy video wogóle istnieje na tym vod czy nie zostało usunięte
		if [ "${testLine}" ]; then
			for line in "${testLine[@]}"; do
				testVod=$( echo "${line}" | sed -n 's/^.*\/\/\([^.]*\)\..*$/\1/p' )
				#lulu może być "lulu" ablo "luluvdo", więc zmieniamy
				[[ "${testVod}" =~ lulu ]] && testVod='lulustream'
				testLink=$( echo "${line}" | cut -d "@" -f1 )
				#testujemy
				echo "Sprawdzam: ${testLink}"
				"${testVod}"Test "${testLink}"
				#Jeśli nie mamy błędu to dopisujemy do ostatecznej tablicy lines()
				if [ "${isOK}" = true ]; then
					line="${testVod}@${line}"
					lines+=( "${line}" )
				fi
			done
		else
			echo "Brak źródeł dla tego filmu dla wybranej wersji: ${mediaType}"
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
  if [ -s "${partsList}" ]; then
    ilosc=$(wc -l < "${partsList}")
    echo "Do pobrania ${ilosc} części."

    <"${partsList}" xargs -n3 -P50 bash -c '
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

		if [ -f "${tmpDir}"/encryption.key ]; then
			lulustreamDecrypt
		fi

	else
		echo "Plik ${partsList} wygląda na pusty!"
	fi
}

#Zapis do odpowiednich katalogów z podziałem na film/serial
saveVideo(){
	if ls "${tmpDir}"/*.ts >/dev/null 2>&1; then
		if [ -z "${seriesCheck}" ]; then
			cat $(ls "${tmpDir}"/*.ts) > "${outDir}"/"${title}"/"${title}".ts 
			echo "Film zapisany w ${outDir}/${title}/${title}.ts"
		else
	    	cat "${tmpDir}"/*.ts > "${outDir}/${seriesTitle}/${seasonNumber}/${fullEpisodeTitle}.ts"
    		echo "Film zapisany w ${outDir}/${seriesTitle}/${seasonNumber}/${fullEpisodeTitle}.ts"
		fi
	else
		echo "Brak plików *.ts w ${tmpDir}"
	fi

}

#CZĘŚĆ GŁÓWNA
#####################################################
#Tutaj zaczynamy imprezę robiąc porządki jeśli trzeba
rm -rf "${fTmp}" >/dev/null 2>&1 && mkdir -p "${fTmp}"

for file in "${path}"*; do

	sed -i "s/'/_/g" "${file}" #xargs się pruje o apostrofy ', to je wypierdolimy'

	vodCheck "${file}"

	for dataLine in "${lines[@]}"; do

		seriesCheck=$( grep 'Serial' <<< "${dataLine}" )

		if [ -z "${seriesCheck}" ]; then
			pattern='^([a-z]*)@([^@]*)@.*@(.*)'
			if [[ "${dataLine}" =~ $pattern ]]; then
				myVod="${BASH_REMATCH[1]}"
				link="${BASH_REMATCH[2]}"
				title="${BASH_REMATCH[3]}"
			fi

			isThere=$( ls "${outDir}/${title}/${title}".* 2>/dev/null )

			if [ "${isThere}" ]; then
				echo "Plik ${isThere##*/} już istnieje: ${isThere}"
			else
				make_dir "${title}"
				mkdir -p "${outDir}/${title}"
				echo "Pobieram ${title} z ${myVod}..."
				if [[ "${myVod}" == 'vidoza' || "${myVod}" == 'streamtape' || "${myVod}" == 'bigshare' ]] ; then
					"${myVod}" "${link}"
				else
					"${myVod}" "${link}"
					#Taka mała magia, żeby mieć fajne dane wejściowe do xargs
					awk -v dir="${tmpDir}" -v vod="${myVod}" '{printf "%s %s/%03d.ts %s\n", $0, dir, NR, vod}' "${partsList}" > "${partsList}.tmp" && mv -f "${partsList}.tmp" "${partsList}"
					getVideo
					saveVideo
				fi
			fi

		else			
			pattern='^([a-z]*)@(.*)@.*@Serial@(.*)@_(s[0-9]{2})_(e[0-9]{2,})@(.*$)'
			if [[ "${dataLine}" =~ $pattern ]]; then
				myVod="${BASH_REMATCH[1]}"
				link="${BASH_REMATCH[2]}"
				seriesTitle="${BASH_REMATCH[3]}"
				seasonNumber="${BASH_REMATCH[4]}"
				episodeNumber="${BASH_REMATCH[5]}"
				episodeTitle="${BASH_REMATCH[6]}"
				fullEpisodeTitle="["$seasonNumber$episodeNumber"]_"$episodeTitle
			fi

			isThere=$( ls "${outDir}/${seriesTitle}/${seasonNumber}/${fullEpisodeTitle}".* 2>/dev/null )

			if [ "${isThere}" ]; then
				echo "Plik ${isThere##*/} już istnieje: ${isThere}"
			else
				make_dir "${episodeTitle}"
				mkdir -p "${outDir}/${seriesTitle}/${seasonNumber}"
				echo "Pobieram ${seriesTitle} - ${episodeTitle} z ${myVod}..."
				if [[ "${myVod}" == 'vidoza' || "${myVod}" == 'streamtape' || "${myVod}" == 'bigshare' ]] ; then
					"${myVod}" "${link}"
				else
					"${myVod}" "${link}"
					#Taka mała magia, żeby mieć fajne dane wejściowe do xargs
					awk -v dir="${tmpDir}" -v vod="${myVod}" '{printf "%s %s/%03d.ts %s\n", $0, dir, NR, vod}' "${partsList}" > "${partsList}.tmp" && mv -f "${partsList}.tmp" "${partsList}"
					getVideo
					saveVideo
				fi
				# rm -rf "${tmpDir}"
			fi
		fi

	done

done

# rm -rf "${fTmp}" >/dev/null 2>&1