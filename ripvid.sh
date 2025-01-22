#!/usr/bin/env bash
#set -u
#set -e
#Wyedytuj linię poniżej według własnych potrzeb 
outDir="${HOME}"/minidlna/torrent/complete
fTmp='/tmp/filman'
reqCheck=()

req=('/usr/bin/curl')

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
	printf "Użycie: ./ripvid.sh -f <sciezka_do_katalogu_z_plikiem/plikami>\n"
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

#Sprawdzamy z którego serwisu możemy pobrać dany film, tzn. czy w ogóle są dostępne linki. Preferowane voe. Wybieramy tyko pierwszy link ze znalezionych i dopisujemy do lines().
vodCheck(){
	movies=($( cat "${file}" | cut -d '@' -f 3- | sort -u  ))
	lines=()
	for m in "${movies[@]}"; do
	tempLine=($( cat "${file}" | grep "${m}" | grep "${mediaType}" | grep -E "voe|vidoza|vidmoly" | head -n 1 ))
		if [ ! -z $tempLine ]; then
			myVod=$( printf "%s" "${tempLine}" | sed -n 's/^.*\/\/\(.*\)\..*$/\1/p' )
			link=$( printf "%s" "${tempLine}" | cut -d "@" -f1 )
			lines+=( "${tempLine}" )
		else
			printf "Brak źródeł dla wybranej wersji: %s \n" "${mediaType}"
			printf "Dostępne możliwości do wyboru to: \n"
			versions=($( awk -F'@' '{ print $2 }' "${1}" | sort -u ))
			printf "[%s] \n" "${versions[@]}"
			break
		fi
	done
}

#Obsługa pobierania z różnych VOD
voe(){
	curlOpts=''
	followUp=$( curl -sL "${link}" | sed -n "s/^.*\(https.*\)'.*$/\1/p" | head -n 1 )
	fullURL=$( curl -sL "${followUp}" | grep "hls':" | cut -d "'" -f4 | base64 -d)
	mainURL=$( printf "%s" "${fullURL}" | sed -n 's/\(^.*\)\/master.*$/\1/p')
	partsPATH=$( curl -sL "${fullURL}" | grep ^index ) 
	curl -sL "${mainURL}"/"${partsPATH}" | grep -v ^# > "${partsList}"
}

vidoza(){
	curlOpts=''
	[[ $(curl -sL "${link}" | grep 'File was deleted') ]] && printf "Wygląda na to, że plik został usunięty.\n" && exit 100
	videoURL=$( curl -sL "${link}" | grep sourcesCode | cut -d '"' -f2 )
	if [ ! -z "${seriesTitle}" ] && [ ! -z "${seasonNumber}" ] && [ ! -z "${episodeTitle}" ]; then
		curl "${videoURL}" -o "${outDir}"/"${seriesTitle}"/"${seasonNumber}"/"${fullEpisodeTitle}".mp4
		printf "\n\nFilm zapisany w %s/%s/%s/%s.mp4 \n\n" "${outDir}" "${seriesTitle}" "${seasonNumber}" "${fullEpisodeTitle}"
	else
		[ ! -d "${outDir}"/"${title}" ] && mkdir -p "${outDir}"/"${title}"
		curl "${videoURL}" -o "${outDir}"/"${title}"/"${title}".mp4
		printf "\n\nFilm zapisany w %s/%s/%s.mp4 \n\n" "${outDir}" "${title}" "${title}"
	fi
}

#WIP
lulu(){
	curlOpts=( "-H" "User-Agent: Mozilla/5.0" )
	#echo $link
	fullURL=$( curl -sL "${link}" "${curlOpts[@]}" | grep sources | cut -d '"' -f2)
	#echo "fullURL: " $fullURL
	mainURL=$( printf "%s" "${fullURL}" | sed -n 's/\(^.*\)\/master.*$/\1/p' )
	#echo "mainURL: " $mainURL
	partsPATH=$( curl -sL "${fullURL}" | grep index )
	#echo "partsPATH: " $partsPATH
	curl -sL "${partsPATH}" | sed -n 's/^.*\(seg.*$\)/\1/p' > "${partsList}"
}

vidmoly(){
	curlOpts=( "-H" "User-Agent: Mozilla/5.0" "-H" "Referer: https://vidmoly.to/" )
	fullURL=$( wget "${link}" -qO- | grep sources: | cut -d '"' -f2 )
	mainURL=$( printf "%s" "${fullURL}" |  tr -d ',' | sed -n 's/\(^.*\)\.urlset.*/\1/p' )
	partsPATH=$( curl -sL "${fullURL}" "${curlOpts[@]}" | grep index | head -n1 )
	curl -sL "${partsPATH}" "${curlOpts[@]}" | sed -n 's/^.*\(seg.*$\)/\1/p' > "${partsList}"
}

#Obsługa pobrania POJEDYNCZEGO filmu
getVideo(){
	if [ ! -z  "$( cat "${partsList}" )" ] ; then
		ilosc=$( cat "${partsList}" | wc -l )
		count=1;
			while read line ; do
				nazwa=$(printf "%03d" "${count}");
				printf "Pobieram część %s z %s\n" "${count}" "${ilosc}"
				curl -sL "${mainURL}"/"${line}" "${curlOpts[@]}" -o "${tmpDir}"/"${nazwa}".ts
				count=$((count+1))
			done<"${partsList}"

		cat $(ls "${tmpDir}"/*.ts) > "${outDir}"/"${title}"/"${title}".ts 
		printf "\n\nFilm zapisany w %s/%s/%s.ts \n\n" "${outDir}" "${title}" "${title}"
	else
		printf "Plik %s wygląda na pusty!\n" "${partsList}"
		exit 20
	fi
}

#Obsługa pobierania seriali - ładuje filmy do ładnej struktury katalogów, wedle schematu:
#${outDir}/Tytul:
#- s01
#  	- [s01e01].tytul.mp4/ts
#	- [s01e02].tytul.mp4/ts
#	- ...
# - s02
#	- [s02e01].tytul.mp4/ts
#	- [s02e02].tytul.mp4/ts
#	- ...
getSeries(){
	if [ ! -z  "$( cat "${partsList}" )" ] ; then
		ilosc=$( cat "${partsList}" | wc -l )
		count=1;

			while read line ; do
					nazwa=$(printf "%03d" "${count}");
					printf "Pobieram część %s z %s\n" "${count}" "${ilosc}"
					curl -sL "${mainURL}"/"${line}" "${curlOpts[@]}" -o "${tmpDir}"/"${nazwa}".ts
					count=$((count+1))
			done<"${partsList}"

		cat $(ls "${tmpDir}"/*.ts) > "${outDir}"/"${seriesTitle}"/"${seasonNumber}"/"${fullEpisodeTitle}".ts 
		printf "\n\nFilm zapisany w %s/%s/%s/%s.ts \n\n" "${outDir}" "${seriesTitle}" "${seasonNumber}" "${fullEpisodeTitle}"
	else
		printf "Plik %s wygląda na pusty!\n" "${partsList}"
		exit 21
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

			pattern='^.*Film@(.*)'
			if [[ "${dataLine}" =~ $pattern ]]; then
				title="${BASH_REMATCH[1]}"
			fi

			isThere=$( ls "${outDir}/${title}/${title}".* 2>/dev/null )

			if [ ! -z "${isThere}" ]; then
				printf "Plik ${isThere##*/} już istnieje: %s \n" "${isThere}"
			else
				make_dir "${title}"
				mkdir -p "${outDir}/${title}"
				printf "Pobieram %s z %s...\n\n" "${title}" "${myVod}"
				if [ "${myVod}" == 'vidoza' ] ; then
					"${myVod}"
				else
					"${myVod}"
					getVideo
				fi
			fi

		else

			pattern='^.*Serial@(.*)@_(s[0-9]{2})_(e[0-9]{2})@(.*$)'
			if [[ "${dataLine}" =~ $pattern ]]; then
				seriesTitle="${BASH_REMATCH[1]}"
				seasonNumber="${BASH_REMATCH[2]}"
				episodeNumber="${BASH_REMATCH[3]}"
				episodeTitle="${BASH_REMATCH[4]}"
				fullEpisodeTitle="["$seasonNumber$episodeNumber"]_"$episodeTitle
			fi
			
			isThere=$( ls "${outDir}/${seriesTitle}/${seasonNumber}/${fullEpisodeTitle}".* 2>/dev/null )

			if [ ! -z "${isThere}" ]; then
				printf "Plik ${isThere##*/} już istnieje: %s \n" "${isThere}"
			else
				make_dir "${episodeTitle}"
				cp "${file}" "${tmpDir}"
				mkdir -p "${outDir}/${seriesTitle}/${seasonNumber}"
				printf "Pobieram %s - %s z %s...\n\n" "${seriesTitle}" "${episodeTitle}" "${myVod}"
				if [ "${myVod}" == 'vidoza' ] ; then
					"${myVod}"
				else
					"${myVod}"
					getSeries
				fi
				rm -rf "${tmpDir}"
			fi
		fi

	done

done

#No i robimy porządki na koniec
rm -rf "${fTmp}" >/dev/null 2>&1
