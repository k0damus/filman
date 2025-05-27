#!/usr/bin/env bash
#set -u
#set -e
#Wyedytuj linię poniżej według własnych potrzeb 
outDir="${HOME}"/minidlna/torrent/complete
fTmp='/tmp/filman'
reqCheck=()

req=('/usr/bin/curl' '/usr/bin/openssl')

for r in "${req[@]}"; do
	[ ! -f "${r}" ] && reqCheck+=("${r}");
done

if [ "${#reqCheck[@]}" -gt 0 ]; then
	printf "%s <- Brak tych programów. Zainstaluj.\n" "${reqCheck[@]}";
	exit 10
fi

if [ ! -d "${outDir}" ]; then
	printf "Katalog %s nie istnieje!\n" "${outDir}";
	exit 11
fi

while getopts ":p:t:" opt; do
	case "${opt}" in
		p) path="${OPTARG}" ;;
		t) mType="${OPTARG}" ;;
		:) printf "Opcja -%s wymaga argumentu.\n" "${OPTARG}" ; exit 12 ;;
		?) printf "Niewłaściwa opcja: -%s.\n" "${OPTARG}" ; exit 13 ;;
	esac
done

if [ -z "${path}" ] ; then
	printf "Brak / za malo danych.\n"
	printf "Użycie: ./ripvid.sh -p <sciezka_do_katalogu_z_plikiem/plikami>\n"
	exit 14
fi

case "${mType}" in
	n|N) printf "Wybrano opcję: Napisy.\n" && mediaType='Napisy' ;;
	p|P) printf "Wybrano opcję: PL.\n" && mediaType='PL' ;;
	d|D) printf "Wybrano opcję: Dubbing.\n" && mediaType='Dubbing' ;;
	e|E) printf "Wybrano opcję: ENG.\n" && mediaType='ENG' ;;
	*)   printf "Wybrano opcję: Lektor.\n" && mediaType='Lektor' ;;
esac

#Na początek: łapiemy CTRL + C i usuwamy nasz katalog w razie czego
cleanup() {
	printf "\nSprzątamy...\n"
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
				testVod=$( printf "%s" "${line}" | sed -n 's/^.*\/\/\([^.]*\)\..*$/\1/p' )
				#lulu może być "lulu" ablo "luluvdo", więc zmieniamy
				[ "${testVod}" == "lulu" ] && testVod='luluvdo'
				testLink=$( printf "%s" "${line}" | cut -d "@" -f1 )
				#testujemy
				"${testVod}"Test "${testLink}"
				#Jeśli nie mamy błędu to dopisujemy do ostatecznej tablicy lines()
				if [ "${isOK}" = true ]; then
					line="${testVod}@${line}"
					lines+=( "${line}" )
				fi
			done
		else
			printf "Brak źródeł dla tego filmu dla wybranej wersji: %s \n" "${mediaType}"
			printf "Dostępne możliwości do wyboru to: \n"
			versions=($( awk -F'@' '{ print $2 }' "${1}" | sort -u ))
			printf "[%s] \n" "${versions[@]}"
		fi
	done
}

#Obsługa pobierania z różnych VOD (napierw TEST później funkcja wybierająca właściwe pliki)
:<<'voeOFF'
voeTest(){
	[[ -z $( curl -sL "${1}" | grep '404 - Not found' ) ]] && isOK=true || isOK=false
}

voe(){
	curlOpts=''
	followUp=$( curl -sL "${link}" | sed -n "s/^.*\(https.*\)'.*$/\1/p" | head -n 1 )
	fullURL=$( curl -sL "${followUp}" | grep "hls':" | cut -d "'" -f4 | base64 -d)
	mainURL=$( printf "%s" "${fullURL}" | sed -n 's/\(^.*\)\/master.*$/\1/p')
	partsPATH=$( curl -sL "${fullURL}" | grep ^index ) 
	curl -sL "${mainURL}"/"${partsPATH}" | grep -v ^# > "${partsList}"
}
voeOFF

streamtapeTest(){
	[[ -z $(curl -sL "${1}" | grep 'Video not found') ]] && isOK=true || isOK=false
}

streamtape(){
	if [[ "${1}" != *"/e/"* ]]; then 
		link=$( printf "%s" "${1}" | sed 's/com\/v\//com\/e\//')
	fi

	videoID=$( printf "%s" "${link}" | cut -d '/' -f5 )
	videoURL=$( curl -sL "${link}" | grep "'botlink'" | sed -n "s/.*\(\&expires.*\)'.*/\1/p" | sed "s/^/https:\/\/streamtape.com\/get_video?id=${videoID}/;s/$/\&stream=1/" )
	curlOpts=''

	if [ "${seriesTitle}" ] && [ "${seasonNumber}" ] && [ "${episodeTitle}" ]; then
		curl -L "${videoURL}" -o "${outDir}"/"${seriesTitle}"/"${seasonNumber}"/"${fullEpisodeTitle}".mp4
		printf "\n\nFilm zapisany w %s/%s/%s/%s.mp4 \n\n" "${outDir}" "${seriesTitle}" "${seasonNumber}" "${fullEpisodeTitle}"
	else
		[ ! -d "${outDir}"/"${title}" ] && mkdir -p "${outDir}"/"${title}"
		curl -L "${videoURL}" -o "${outDir}"/"${title}"/"${title}".mp4
		printf "\n\nFilm zapisany w %s/%s/%s.mp4 \n\n" "${outDir}" "${title}" "${title}"
	fi	
}

vidozaTest(){
	[[ -z $(curl -sL "${1}" | grep 'File was deleted') ]] && isOK=true || isOK=false
}

vidoza(){
	curlOpts=''
	videoURL=$( curl -sL "${1}" | grep sourcesCode | cut -d '"' -f2 )

	if [ "${seriesTitle}" ] && [ "${seasonNumber}" ] && [ "${episodeTitle}" ]; then
		curl "${videoURL}" -o "${outDir}"/"${seriesTitle}"/"${seasonNumber}"/"${fullEpisodeTitle}".mp4
		printf "\n\nFilm zapisany w %s/%s/%s/%s.mp4 \n\n" "${outDir}" "${seriesTitle}" "${seasonNumber}" "${fullEpisodeTitle}"
	else
		[ ! -d "${outDir}"/"${title}" ] && mkdir -p "${outDir}"/"${title}"
		curl "${videoURL}" -o "${outDir}"/"${title}"/"${title}".mp4
		printf "\n\nFilm zapisany w %s/%s/%s.mp4 \n\n" "${outDir}" "${title}" "${title}"
	fi
}

vidmolyTest(){
	[[ -z $(curl -sL "${1}" -H "User-Agent: Mozilla/5.0" -H "Referer: https://vidmoly.to/" | grep 'notice.php') ]] && isOK=true || isOK=false
}

vidmoly(){
	if [[ "${1}" != *"embed"* ]]; then 
		link=$( printf "%s" "${1}" | sed -n 's/\(https.*\)\(.me\/w\/\)\(.*\)$/\1.to\/embed-\3.html/p')
	fi

	curlOpts=( "-H" "User-Agent: Mozilla/5.0" "-H" "Referer: https://vidmoly.to/" )
	fullURL=$( wget "${link}" -qO- | grep sources: | cut -d '"' -f2 )
	mainURL=$( printf "%s" "${fullURL}" |  tr -d ',' | sed -n 's/\(^.*\)\.urlset.*/\1/p' )
	partsPATH=$( curl -sL "${fullURL}" "${curlOpts[@]}" | grep index | head -n1 )
	curl -sL "${partsPATH}" "${curlOpts[@]}" | sed -n 's/^.*\(seg.*$\)/\1/p' > "${partsList}"
}

luluvdoTest(){
	[[ -z $(curl -sL "${1}" -H "User-Agent: Mozilla/5.0" | grep 'been deleted') ]] && isOK=true || isOK=false
}

luluvdo(){

	if grep -q sources < <( curl -sL "${1}" ); then 

		link=$( curl -sL "${1}" | grep sources | cut -d '"' -f2  )

		mainURL=$( printf "%s" "${link}" | sed -n 's/\(^.*\)\/master.*$/\1/p' )
		partsPATH=$( curl -sL "${link}" | grep index )
		curl -sL "${partsPATH}" | sed -n 's/^.*\(seg.*$\)/\1/p' > "${partsList}"
		curl -sL $(curl -sL "${partsPATH}" | grep enc | cut -d '"' -f2) > "${tmpDir}"/encryption.key
		
	else

		printf "Nie mogę znaleźć linku do źródeł.\n"

	fi

}

luluvdoDecrypt(){
	for f in "${tmpDir}"/*.ts; do
		NUM=$(echo "${f}" | grep -oP '\d+(?=\.ts)'  | tr -d '0' )
		NAME=${f##*/}
		IV=$(printf "%032x" "$NUM")
		printf "Odszyfrowywanie %s.\n" "${f}"
		openssl aes-128-cbc -d -in "${f}" -out "${tmpDir}"/dec-"${NAME}" -nosalt -iv "${IV}" -K "$(xxd -p "${tmpDir}"/encryption.key | tr -d '\n')"
		#Po zdekodowaniu adpisujemy oryginał
		mv "${tmpDir}"/dec-"${NAME}" "${f}"
	done
}

savefilesTest(){
	input_test=$( curl -sL "https://savefiles.com/dl?op=embed&file_code=${1##*/}&auto=1" -H "Referer: ${1}"  )
	[[ -z $(curl -sL "${input_test}" -H "User-Agent: Mozilla/5.0" | grep 'been deleted') ]] && isOK=true || isOK=false
}
savefiles(){
	partsPATH=$( curl -sL "https://savefiles.com/dl?op=embed&file_code=${1##*/}&auto=1" -H "Referer: ${1}" | grep hls | sed -n 's/^.*\(https.*\)"}].*$/\1/p' )
	# echo $partsPATH
	# e_and_srv=($( echo "${input_data}" | sed -n 's/^.*file|100|\(.*\)|.*|\([a-z0-9]*\)|setCurrent.*$/\1 \2/p'  ))
	# main_url=($( echo "${input_data}" | sed -n 's/^.*srv|\(.*|\)sources.*$/\1/p' | tr '|' '\n' | tac  | tr '\n' ' ' ))
	# token_tmp=($( echo "${main_url[@]}" | sed -n 's/^.*m3u8 \(.*\) 43200$/\1/p' ))

	# if [ "${#token_tmp[@]}" -gt 1 ]; then
	# 	IFS=-;
	# 	token=$( echo "${token_tmp[*]}" )
	# 	unset IFS
	# else
	# 	token="${token_tmp[@]}"
	# fi

	# s=$( echo "${input_data}" | sed -n 's/^.*|view|\(.*\)|video_ad|.*$/\1/p' )
	# v=$( echo "${input_data}" | sed -n 's/^.*|ls|\(.*\)|vvplay|.*$/\1/p' )
	
	# all=( "${main_url[0]}" "${main_url[1]}" "${e_and_srv[0]}" "${main_url[2]}" "${token}" "${s}" "${main_url[1]}" "${v}" "${e_and_srv[1]}" )
	
	# partsPATH="https://${all[0]}.savefiles.com/${all[1]}/01/${all[2]}/,${all[3]},.urlset/master.m3u8?t=${all[4]}&s=${all[5]}&e=${all[6]}&v=${all[7]}&srv=${all[8]}&i=0.0&sp=0"
	# curl -sL "${partsPATH}" # | grep index
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
				printf "Pobieram część %s z %s\n" "${count}" "${ilosc}"
				curl -sL "${mainURL}"/"${line}" "${curlOpts[@]}" -o "${tmpDir}"/"${nazwa}".ts
				count=$((count+1))
			done<"${partsList}"

		if [ -f "${tmpDir}"/encryption.key ]; then
			luluvdoDecrypt
		fi

		cat $(ls "${tmpDir}"/*.ts) > "${outDir}"/"${title}"/"${title}".ts 
		printf "\n\nFilm zapisany w %s/%s/%s.ts \n\n" "${outDir}" "${title}" "${title}"
	else
		printf "Plik %s wygląda na pusty!\n" "${partsList}"
	fi
}

#Obsługa pobierania seriali - ładuje filmy do ładnej struktury katalogów, wedle schematu:
getSeries(){
	if [ "$( cat "${partsList}" )" ] ; then
		ilosc=$( wc -l < "${partsList}" )
		count=1;
			while read line ; do
					nazwa=$(printf "%03d" "${count}");
					printf "Pobieram część %s z %s\n" "${count}" "${ilosc}"
					curl -sL "${mainURL}"/"${line}" "${curlOpts[@]}" -o "${tmpDir}"/"${nazwa}".ts
					count=$((count+1))
			done<"${partsList}"
		
		if [ -f "${tmpDir}"/encryption.key ]; then
			luluvdoDecrypt
		fi
		
		cat $(ls "${tmpDir}"/*.ts) > "${outDir}"/"${seriesTitle}"/"${seasonNumber}"/"${fullEpisodeTitle}".ts 
		printf "\n\nFilm zapisany w %s/%s/%s/%s.ts \n\n" "${outDir}" "${seriesTitle}" "${seasonNumber}" "${fullEpisodeTitle}"
	else
		printf "Plik %s wygląda na pusty!\n" "${partsList}"
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
				printf "Plik ${isThere##*/} już istnieje: %s \n" "${isThere}"
			else
				make_dir "${title}"
				mkdir -p "${outDir}/${title}"
				printf "Pobieram %s z %s...\n\n" "${title}" "${myVod}"
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
				printf "Plik ${isThere##*/} już istnieje: %s \n" "${isThere}"
			else
				make_dir "${episodeTitle}"
				mkdir -p "${outDir}/${seriesTitle}/${seasonNumber}"
				printf "Pobieram %s - %s z %s...\n\n" "${seriesTitle}" "${episodeTitle}" "${myVod}"
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


rm -rf "${fTmp}" >/dev/null 2>&1
