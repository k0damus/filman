#!/usr/bin/env bash
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
	exit 10
fi

if [ ! -d "${outDir}" ]; then
	echo "Katalog ${outDir} nie istnieje!"
	exit 11
fi

while getopts ":p:t:" opt; do
	case "${opt}" in
		p) path="${OPTARG}" ;;
		t) mType="${OPTARG}" ;;
		:) echo "Opcja -${OPTARG} wymaga argumentu." ; exit 12 ;;
		?) echo "Niewłaściwa opcja: -${OPTARG}." ; exit 13 ;;
	esac
done

if [ -z "${path}" ] ; then
	echo "Brak / za malo danych."
	echo "Użycie: ./ripvid.sh -p <sciezka_do_katalogu_z_plikiem/plikami>"
	exit 14
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
	echo "Sprzątamy..."
	rm -rf "${fTmp}"
	exit 1
}

trap "cleanup" SIGINT SIGTERM

#FUNKCJE

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
		testLine=($( grep "${m}" "${file}" | grep "${mediaType}" | grep -E "streamtape|savefiles|vidoza|vidmoly|lulu" )) #| head -n 1 ))
		#tutaj iterujemy po całej tablicy i wykonujemy wstępne sprawdzenie czy video wogóle istnieje na tym vod czy nie zostało usunięte
		if [ "${testLine}" ]; then
			for line in "${testLine[@]}"; do
				testVod=$( echo "${line}" | sed -n 's/^.*\/\/\([^.]*\)\..*$/\1/p' )
				#lulu może być "lulu" ablo "luluvdo", więc zmieniamy
				[ "${testVod}" == "lulu" ] && testVod='luluvdo'
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
}

#Obsługa pobierania z różnych VOD (napierw TEST później funkcja wybierająca właściwe pliki)
streamtapeTest(){
	dataCheck=$(curl -sL "${1}" --max-time 5)
	if [[ -z "${dataCheck}" || "${dataCheck}" == *"Video not found"* ]]; then
		isOK=false
	else
		isOK=true
	fi
}

streamtape(){
	if [[ "${1}" != *"/e/"* ]]; then
		link=$( echo "${1}" | sed 's/com\/v\//com\/e\//')
	fi

	videoID=$( echo "${link}" | cut -d '/' -f5 )
	videoURL=$( curl -sL "${link}" | grep "'botlink'" | sed -n "s/.*\(\&expires.*\)'.*/\1/p" | sed "s/^/https:\/\/streamtape.com\/get_video?id=${videoID}/;s/$/\&stream=1/" )
	curlOpts=''

	if [ "${seriesTitle}" ] && [ "${seasonNumber}" ] && [ "${episodeTitle}" ]; then
		curl -L "${videoURL}" -o "${outDir}"/"${seriesTitle}"/"${seasonNumber}"/"${fullEpisodeTitle}".mp4
		echo "Film zapisany w ${outDir}/${seriesTitle}/${seasonNumber}/${fullEpisodeTitle}.mp4"
	else
		[ ! -d "${outDir}"/"${title}" ] && mkdir -p "${outDir}"/"${title}"
		curl -L "${videoURL}" -o "${outDir}"/"${title}"/"${title}".mp4
		echo "Film zapisany w ${outDir}/${title}/${title}.mp4"
	fi
}

vidozaTest(){
	#[[ -z $(curl -sL "${1}" --max-time 5 | grep 'File was deleted') ]] && isOK=true || isOK=false
	dataCheck=$(curl -sL "${1}" --max-time 5)
	if [[ -z "${dataCheck}" || "${dataCheck}" == *"File was deleted"* ]]; then
		isOK=false
	else
		isOK=true
	fi
}

vidoza(){
	curlOpts=''
	videoURL=$( curl -sL "${1}" | grep sourcesCode | cut -d '"' -f2 )

	if [ "${seriesTitle}" ] && [ "${seasonNumber}" ] && [ "${episodeTitle}" ]; then
		curl "${videoURL}" -o "${outDir}"/"${seriesTitle}"/"${seasonNumber}"/"${fullEpisodeTitle}".mp4
		echo "Film zapisany w ${outDir}/${seriesTitle}/${seasonNumber}/${fullEpisodeTitle}.mp4"
	else
		[ ! -d "${outDir}"/"${title}" ] && mkdir -p "${outDir}"/"${title}"
		curl "${videoURL}" -o "${outDir}"/"${title}"/"${title}".mp4
		echo "Film zapisany w ${outDir}/${title}/${title}.mp4"
	fi
}

vidmolyTest(){
	#[[ -z $(curl -sL "${1}" --max-time 5 -H "User-Agent: Mozilla/5.0" -H "Referer: https://vidmoly.to/" | grep 'notice.php') ]] && isOK=true || isOK=false
	dataCheck=$(curl -sL "${1}" --max-time 5 -H "User-Agent: Mozilla/5.0" -H "Referer: https://vidmoly.to/")
	if [[ -z "${dataCheck}" || "${dataCheck}" == *"notice.php"* ]]; then
		isOK=false
	else
		isOK=true
	fi	
}

vidmoly(){
	if [[ "${1}" != *"embed"* ]]; then
		link=$( echo "${1}" | sed -n 's/\(https.*\)\(.me\/w\/\)\(.*\)$/\1.to\/embed-\3.html/p')
	fi

	curlOpts=( "-H" "User-Agent: Mozilla/5.0" "-H" "Referer: https://vidmoly.to/" )
	fullURL=$( wget "${link}" -qO- | grep sources: | cut -d '"' -f2 )
	mainURL=$( echo "${fullURL}" |  tr -d ',' | sed -n 's/\(^.*\)\.urlset.*/\1/p' )
	partsPATH=$( curl -sL "${fullURL}" "${curlOpts[@]}" | grep index | head -n1 )
	curl -sL "${partsPATH}" "${curlOpts[@]}" | sed -n 's/^.*\(seg.*$\)/\1/p' > "${partsList}"
}

lulustreamTest(){
	#[[ -z $(curl -sL "${1}" --max-time 5 -H "User-Agent: Mozilla/5.0" | grep 'been deleted') ]] && isOK=true || isOK=false
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
		partsPATH=$( curl -sL "${link}" | grep index )
		curl -sL "${partsPATH}" | sed -n 's/^.*\(seg.*$\)/\1/p' > "${partsList}"
		#curl -sL $(curl -sL "${partsPATH}" | grep enc | cut -d '"' -f2) > "${tmpDir}"/encryption.key
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

savefilesTest(){
	input_test=$( curl -sL "https://savefiles.com/dl?op=embed&file_code=${1##*/}&auto=1" -H "Referer: ${1}"  )
	#[[ -z $(curl -sL "${input_test}" --max-time 5 -H "User-Agent: Mozilla/5.0" | grep 'been deleted') ]] && isOK=true || isOK=false
	dataCheck=$(curl -sL "${input_test}" --max-time 5 -H "User-Agent: Mozilla/5.0")
	if [[ -z "${dataCheck}" || "${dataCheck}" == *"been deleted"* ]]; then
		isOK=false
	else
		isOK=true
	fi	

}
savefiles(){
	partsPATH=$( curl -sL "https://savefiles.com/dl?op=embed&file_code=${1##*/}&auto=1" -H "Referer: ${1}" | grep hls | sed -n 's/^.*\(https.*\)"}].*$/\1/p' )
	partsLINK=$( curl -sL "${partsPATH}" | grep index )
	mainURL="${partsLINK%/*}"
	curl -sL "${partsLINK}" | grep ^https | cut -d '/' -f 8- > "${partsList}"
}
#Obsługa pobrania POJEDYNCZEGO filmu
getVideo(){
	if [ "$( cat "${partsList}" )" ] ; then
		ilosc=$( wc -l < "${partsList}" )
		count=1;
			while read -r line ; do
				nazwa=$(printf "%03d" "${count}");
				echo "Pobieram część ${count} z ${ilosc}"
				curl -sL "${mainURL}"/"${line}" "${curlOpts[@]}" -o "${tmpDir}"/"${nazwa}".ts
				count=$((count+1))
			done<"${partsList}"

		if [ -f "${tmpDir}"/encryption.key ]; then
			lulustreamDecrypt
		fi

		cat $(ls "${tmpDir}"/*.ts) > "${outDir}"/"${title}"/"${title}".ts 
		echo "Film zapisany w ${outDir}/${title}/${title}.ts"
	else
		echo "Plik ${partsList} wygląda na pusty!"
	fi
}

#Obsługa pobierania seriali - ładuje filmy do ładnej struktury katalogów, wedle schematu:
getSeries(){
	if [ "$( cat "${partsList}" )" ] ; then
		ilosc=$( wc -l < "${partsList}" )
		count=1;
			while read line ; do
					nazwa=$(printf "%03d" "${count}");
					echo "Pobieram część ${count} z ${ilosc}"
					curl -sL "${mainURL}"/"${line}" "${curlOpts[@]}" -o "${tmpDir}"/"${nazwa}".ts
					count=$((count+1))
			done<"${partsList}"
		
		if [ -f "${tmpDir}"/encryption.key ]; then
			lulustreamDecrypt
		fi

		cat $(ls "${tmpDir}"/*.ts) > "${outDir}"/"${seriesTitle}"/"${seasonNumber}"/"${fullEpisodeTitle}".ts
		echo "Film zapisany w ${outDir}/${seriesTitle}/${seasonNumber}/${fullEpisodeTitle}.ts"
	else
		echo "Plik ${partsList} wygląda na pusty!"
	fi
}

#CZĘŚĆ GŁÓWNA
#####################################################
#Tutaj zaczynamy imprezę robiąc porządki jeśli trzeba
rm -rf "${fTmp}" >/dev/null 2>&1 && mkdir -p "${fTmp}"

for file in "${path}"*; do

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
				if [[ "${myVod}" == 'vidoza' || "${myVod}" == 'streamtape' ]] ; then
					"${myVod}" "${link}"
				else
					"${myVod}" "${link}"
					getVideo
				fi
			fi

		else			
			pattern='^([a-z]*)@(.*)@.*@Serial@(.*)@_(s[0-9]{2})_(e[0-9]{2})@(.*$)'
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
				if [[ "${myVod}" == 'vidoza' || "${myVod}" == 'streamtape' ]] ; then
					"${myVod}" "${link}"
				else
					"${myVod}" "${link}"
					getSeries
				fi
				rm -rf "${tmpDir}"
			fi
		fi

	done

done

#rm -rf "${fTmp}" >/dev/null 2>&1