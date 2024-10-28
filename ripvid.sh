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
	printf "%s <- Brak tych programów. Zainstaluj.\n" "${reqCheck[*]}";
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
trap "rm -rf ${fTmp}" SIGINT SIGTERM

#FUNKCJE

#Tworzmy katalog tymczasowy do ściągania części filmu / odcinka serialu
make_dir(){
	mkdir -p "${fTmp}"/"${1}"_temp
	tmpDir="${fTmp}/${1}_temp"
	touch "${tmpDir}"/parts.txt
	partsList="${tmpDir}"/parts.txt
}

#Sprawdzamy z którego serwisu możemy pobrać dany film. Preferowana jest vidoza.
#Funkcja sprawdza po kolei czy dane serwis znajduje się na liście z linkami do filmu
#Jeśli istnieje to wybiera dany link do pobierania o przypisuje do zmiennej link ORAZ myVod - to wyjaśnione poniżej. Tu następuje wyjście z pętli.
#Jeśli nie istnieje to szuka następnego z listy vods, aż do skutku.
#vidoza - najszybsze pobieranie
#voe - najpopularniejszy?
#dood - jw. ale ograniczone pobieranie
vodCheck(){
	#Lista w preferowanej kolejności serwisów - do edycji wedle potrzeb
	vods=( 'vidoza' 'voe' 'lulu' 'vidmoly' )
	for v in "${vods[@]}"; do
		dataLine=$( grep "${mediaType}" "${1}" | grep "${v}" | head -n 1 )
		if [ ! -z $dataLine ]; then
			myVod="${v}"
			link=$( printf "%s" "${dataLine}" | cut -d "@" -f1 )
			break
		fi
	done
}

#Obsługa pobierania z różnych VOD
voe(){
	curlOpts=''
	followUp=$( curl -sL "${link}" | sed -n "s/^.*\(https.*\)'.*$/\1/p" | head -n 1 ) #1. Obejście, żeby z linka voe dostać się do właściwej strony voe.
	fullURL=$( curl -sL "${followUp}" | grep nodeDetails | cut -d '"' -f4) #2. Z wyniku tego wyżej wyciągamy właściwy link do listy m3u8.
	mainURL=$( printf "%s" "${fullURL}" | sed -n 's/\(^.*\)\/master.*$/\1/p') #3. Link do segmentów to  2 części: link główny + linki do segmentów. Tutaj robimy część główną - z wyniku z poprzeniego polecenia.
	partsPATH=$( curl -sL "${fullURL}" | grep ^index ) #4. Wyszukujemy link do "playlisty".
	curl -sL "${mainURL}"/"${partsPATH}" | grep -v ^# > "${partsList}" #5. Łącząc wyniki kroku (3) i (4) mamy link do playlisty, z której wybieramy segmenty.
}

vidoza(){
	curlOpts=''
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

#Aktualnie pobranie linku do filmu wymaga dodatkowego softu, nie chcemy tego tutaj
#dood(){
#	curlOpts="-H 'Referer: $( printf "%s" "${link}" | sed 's/dood.yt/d0000d.com/g' )'"
#	passUrl=$( curl -sL "${link}" | sed -n 's/.*\(\/pass\_md5\/[-0-9a-z\/]*\).*$/\1/p')
#	tokenUrl=$( printf "%s" "${passUrl}" | cut -d '/' -f4 )
#	tempUrl=$( curl -sL $( printf "https://d0000d.com%s" "${passUrl}" ) "${curlOpts}" )
#	randomString=$( cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 10 | head -n 1 )
#	validUrl=$( printf "%s%s?token=%s&expiry=$(date +%s)" "${tempUrl}" "${randomString}" "${tokenUrl}" )
#
#	if [ ! -z "${seriesTitle}" ] && [ ! -z "${seasonNumber}" ] && [ ! -z "${episodeTitle}" ]; then
#		curl -L "${validUrl}" "${curlOpts}" -o "${outDir}"/"${seriesTitle}"/"${seasonNumber}"/"${fullEpisodeTitle}".ts
#		printf "\n\nFilm zapisany w %s/%s/%s/%s.ts \n\n" "${outDir}" "${seriesTitle}" "${seasonNumber}" "${fullEpisodeTitle}"
#	else
#		[ ! -d "${outDir}"/"${title}" ] && mkdir -p "${outDir}"/"${title}"
#		curl -L "${validUrl}" "${curlOpts}" -o "${outDir}"/"${title}"/"${title}".ts
#		printf "\n\nFilm zapisany w %s/%s/%s.ts \n\n" "${outDir}" "${title}" "${title}"
#	fi
#}

lulu(){
	curlOpts=''
	fullURL=$( curl -sL "${link}" | grep sources | cut -d '"' -f2)
	mainURL=$( printf "%s" "${fullURL}" | sed -n 's/\(^.*\)\/master.*$/\1/p' )
	partsPATH=$( curl -sL "${fullURL}" | grep index )
	curl -sL "${partsPATH}" | sed -n 's/^.*\(seg.*$\)/\1/p' > "${partsList}"
}

vidmoly(){
	curlOpts='-H "Referer: https://vidmoly.to/"'
	fullURL=$( wget "${link}" -qO- | grep sources: | cut -d '"' -f2 )
	mainURL=$( printf "%s" "${fullURL}" |  tr -d ',' | sed -n 's/\(^.*\)\.urlset.*/\1/p' )
	partsPATH=$( curl -sL "${fullURL}" "${curlOpts}" | grep index )
	curl -sL "${partsPATH}" "${curlOpts}" | sed -n 's/^.*\(seg.*$\)/\1/p' > "${partsList}"
}

#Obsługa pobrania POJEDYNCZEGO filmu
getVideo(){
	if [ ! -z  "$( cat "${partsList}" )" ] ; then
		ilosc=$( cat "${partsList}" | wc -l )
		count=1;
			while read line ; do
		        nazwa=$(printf "%03d" "${count}");
				printf "Pobieram część %s z %s\n" "${count}" "${ilosc}"
				curl -sL "${mainURL}"/"${line}" "${curlOpts}" -o "${tmpDir}"/"${nazwa}".ts
		        count=$((count+1))
			done<"${partsList}"

		mkdir "${outDir}"/"${title}"
		cat $(ls "${tmpDir}"/*.ts) > "${outDir}"/"${title}"/"${title}".ts 
    	printf "\n\nFilm zapisany w %s/%s/%s.ts \n\n" "${outDir}" "${title}" "${title}"
	else
		printf "Plik %s wygląda na pusty!" "${partsList}"
		exit 20
	fi
}

#Obsługa pobierania seriali - ładuje filmy do wcześniej przygotowanej struktury katalogów, wedle schematu:
#${outDir}/Tytul:
#- s01
#  	- [s01e01].tytul.mp4/mpg
#	- [s01e02].tytul.mp4/mpg
#	- ...
# - s02
#	- [s02e01].tytul.mp4/mpg
#	- [s02e02].tytul.mp4/mpg
#	- ...
getSeries(){
	if [ ! -z  "$( cat "${partsList}" )" ] ; then
		ilosc=$( cat "${partsList}" | wc -l )
		count=1;

			while read line ; do
					nazwa=$(printf "%03d" "${count}");
					printf "Pobieram część %s z %s\n" "${count}" "${ilosc}"
					curl -sL "${mainURL}"/"${line}" "${curlOpts}" -o "${tmpDir}"/"${nazwa}".ts
					count=$((count+1))
			done<"${partsList}"

		cat $(ls "${tmpDir}"/*.ts) > "${outDir}"/"${seriesTitle}"/"${seasonNumber}"/"${fullEpisodeTitle}".ts 
		printf "\n\nFilm zapisany w %s/%s/%s/%s.ts \n\n" "${outDir}" "${seriesTitle}" "${seasonNumber}" "${fullEpisodeTitle}"
	else
		printf "Plik %s wygląda na pusty!" "${partsList}"
		exit 21
	fi
}



#CZĘŚĆ GŁÓWNA
#####################################################
#Tutaj zaczynamy imprezę robiąc porządki jeśli trzeba
rm -rf "${fTmp}" >/dev/null 2>&1 && mkdir -p "${fTmp}"

for file in "${path}"*; do
seriesCheck=$( grep 'Serial' "${file}" )
#mType=($( awk -F'@' '{ print $2 }' | sort -u ))



if [ -z "${seriesCheck}" ]; then

	vodCheck "${file}"

	pattern='^.*Film@(.*)'
        if [[ "${dataLine}" =~ $pattern ]]; then
               title="${BASH_REMATCH[1]}"
        else
                printf "Nie znaleziono danych dla %s. Prawdopodobnie brak źródeł dla wersji: %s" "${title}" "${mediaType}"
                exit 30
        fi

	make_dir "${title}"
	printf "Pobieram %s z %s...\n\n" "${title}" "${myVod}"
	if [ "${myVod}" == 'dood' ] || [ "${myVod}" == 'vidoza' ] ; then
		"${myVod}"
	else
		"${myVod}"
		getVideo
	fi

else
	vodCheck "${file}"

	pattern='^.*Serial@(.*)@_(s[0-9]{2})_(e[0-9]{2})@(.*$)'
	if [[ "${dataLine}" =~ $pattern ]]; then
		seriesTitle="${BASH_REMATCH[1]}"
                seasonNumber="${BASH_REMATCH[2]}"
                episodeNumber="${BASH_REMATCH[3]}"
                episodeTitle="${BASH_REMATCH[4]}"
		fullEpisodeTitle="["$seasonNumber$episodeNumber"]_"$episodeTitle
	else
		printf "Nie znaleziono danych dla %s. Prawdopodobnie brak źródeł dla wersji: %s" "${fullEpisodeTitle}" "${mediaType}"
		exit 30
	fi
	
	[ ! -d "${outDir}"/"${seriesTitle}"/"${seasonNumber}" ] && mkdir -p "${outDir}"/"${seriesTitle}"/"${seasonNumber}"

	if [ ! -f "${outDir}/${seriesTitle}/${seasonNumber}/${fullEpisodeTitle}"* ] ; then

		make_dir "${episodeTitle}"
		cp "${file}" "${tmpDir}"
		printf "Pobieram %s - %s z %s...\n\n" "${seriesTitle}" "${episodeTitle}" "${myVod}"
		if [ "${myVod}" == 'dood' ] || [ "${myVod}" == 'vidoza' ] ; then
			"${myVod}"
		else
			"${myVod}"
			getSeries
		fi
	rm -rf "${tmpDir}"
	fi
fi


done
#No i robimy porządki na koniec
rm -rf "${fTmp}"
