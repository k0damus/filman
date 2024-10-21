#!/usr/bin/env bash
set -u
set -e
#Edytuj poniższą linię dostosowując do własnych potrzeb 
outDir="${HOME}"/minidlna/torrent/complete
fUser=REDACTED
fPass=REDACTED
#Zmienne: pliki i inne pomocnicze rzeczy
fTmp='/tmp/filman'
cookie='/tmp/filman/cookie.txt'
fRaw='/tmp/filman/raw.html'
fSeriesRaw='/tmp/filman/seriesraw.html'
fLinks='/tmp/filman/links.txt'
sLinksTmp='/tmp/filman/series_links_tmp.txt'
sLinksSel='/tmp/filman/series_links_selected.txt'
typesAvailable=''
seasonsAvailable=''
seriesTitle=''
seasonNumber=''
episodeTitle=''
mType=''
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

while getopts ":l:t:" opt; do
	case "${opt}" in
		l) link="${OPTARG}" ;;
		t) mType="${OPTARG}" ;;
		:) printf "Opcja -%s wymaga argumentu.\n" "${OPTARG}" ; exit 12 ;;
		?) printf "Niewłaściwa opcja: -%s.\n" "${OPTARG}" ; exit 13 ;;
	esac
done

if [ -z "${link}" ] ; then
	printf "Brak / za malo danych.\n"
	printf "Użycie: ./getvid.sh -l <link_do_strony_z_filmem/serialem_w_serwisie_filman.cc> -t <[lL]ektor / [nN]apisy>\n"
	printf "Parametr opcjonalny:\n"
	printf " -t <typ> - Jeśli parametr zostanie pominięty to pobrana zostanie wersja z lektorem. \n"
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
#Sprawdzamy czy jest dostępna wersja filmu jaką sobie wybraliśmy. Jeśli nie - wyświetlamy odpowiednie info.
typesCheck(){
	typesAvailable=($( cat "${1}"  | sed 's/^[\t ]*//' | sed -n '/<tbody>/, /<\/tbody>/p' | grep ^\<td | grep -v "center" | tr '\n' ' ' | sed 's/<td /\n<td /g' | grep 720 | sed 's/<[^>]*>//g' | sed -n 's/^.*\(PL\|ENG\|Lektor\|Napisy\|Dubbing\).*$/\1/p' | sort -u ))
	printf "Dostępne opcje: %s.\n" "${typesAvailable[*]}"
	exit 15
}

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
	vods=( 'vidoza' 'voe' 'dood' 'lulu' 'vidmoly' )
	for v in "${vods[@]}"; do
		isThere=$( grep "${v}" "${1}" | head -n 1 )
		if [ ! -z $isThere ]; then
			myVod="${v}"
			link="${isThere}"
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
		curl "${videoURL}" -o "${outDir}"/"${seriesTitle}"/"${seasonNumber}"/"${episodeTitle}".mp4
        printf "\n\nFilm zapisany w %s/%s/%s/%s.mp4 \n\n" "${outDir}" "${seriesTitle}" "${seasonNumber}" "${episodeTitle}"
	else
		[ ! -d "${outDir}"/"${title}" ] && mkdir -p "${outDir}"/"${title}"
		curl "${videoURL}" -o "${outDir}"/"${title}"/"${title}".mp4
        printf "\n\nFilm zapisany w %s/%s/%s.mp4 \n\n" "${outDir}" "${title}" "${title}"
	fi
}

dood(){
	curlOpts="-H 'Referer: $( printf "%s" "${link}" | sed 's/dood.yt/d0000d.com/g' )'"
	passUrl=$( curl -sL "${link}" | sed -n 's/.*\(\/pass\_md5\/[-0-9a-z\/]*\).*$/\1/p')
	tokenUrl=$( printf "%s" "${passUrl}" | cut -d '/' -f4 )
	tempUrl=$( curl -sL $( printf "https://d0000d.com%s" "${passUrl}" ) "${curlOpts}" )
	randomString=$( cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 10 | head -n 1 )
	validUrl=$( printf "%s%s?token=%s&expiry=$(date +%s)" "${tempUrl}" "${randomString}" "${tokenUrl}" )

	if [ ! -z "${seriesTitle}" ] && [ ! -z "${seasonNumber}" ] && [ ! -z "${episodeTitle}" ]; then
		curl -L "${validUrl}" "${curlOpts}" -o "${outDir}"/"${seriesTitle}"/"${seasonNumber}"/"${episodeTitle}".ts
		printf "\n\nFilm zapisany w %s/%s/%s/%s.ts \n\n" "${outDir}" "${seriesTitle}" "${seasonNumber}" "${episodeTitle}"
	else
		[ ! -d "${outDir}"/"${title}" ] && mkdir -p "${outDir}"/"${title}"
		curl -L "${validUrl}" "${curlOpts}" -o "${outDir}"/"${title}"/"${title}".ts
		printf "\n\nFilm zapisany w %s/%s/%s.ts \n\n" "${outDir}" "${title}" "${title}"
	fi
}

lulu(){
	curlOpts=''
	fullURL=$( curl -sL "${link}" | grep sources | cut -d '"' -f2)
	mainURL=$( printf "%s" "${fullURL}" | sed -n 's/\(^.*\)\/master.*$/\1/p' )
	partsPATH=$( curl -sL "${fullURL}" | grep index )
	curl -sL "${partsPATH}" | sed -n 's/^.*\(seg.*$\)/\1/p' > "${partsList}"
}

vidmoly(){
	curlOpts='-H "Referef: https://vidmoly.to/"'
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

		cat $(ls "${tmpDir}"/*.ts) > "${outDir}"/"${seriesTitle}"/"${seasonNumber}"/"${episodeTitle}".ts 
		printf "\n\nFilm zapisany w %s/%s/%s/%s.ts \n\n" "${outDir}" "${seriesTitle}" "${seasonNumber}" "${episodeTitle}"
	else
		printf "Plik %s wygląda na pusty!" "${partsList}"
		exit 21
	fi
}



#CZĘŚĆ GŁÓWNA
#####################################################
#Tutaj zaczynamy imprezę robiąc porządki jeśli trzeba
rm -rf "${fTmp}" >/dev/null 2>&1 && mkdir -p "${fTmp}"

#Logowanie do filmana
curl -L -c "${cookie}" -H 'User-Agent: Chrome/129.0.0.0' 'https://filman.cc/logowanie' --data-raw "login=${fUser}&password=${fPass}&remember=on&submit=" >/dev/null
curl -L -c "${cookie}" -b "${cookie}" -H 'User-Agent: Chrome/129.0.0.0' "${link}" > "${fRaw}"

#Sprawdzamy czy to nie jest aby strona z serialem.
#Na tej podstawie sobie oszacujemy, czy link prowadzi do serialu czy do pojedynczego filmu
seasons_available=$( cat "${fRaw}" | sed -n 's/.*Sezon \([0-9]\{1,\}\).*$/\1/p' | wc -l )

if [ "${seasons_available}" == 0 ]; then
	#Jeśli to nie serial to wyciągamy tytuł
	title=$( cat "${fRaw}" | grep 'og:title' | cut -d '"' -f4 | sed "s/ \/ / /g;s/[:;'.]//g;s/ /_/g" )
	#A następnie linki dodostępnych VOD
	cat "${fRaw}" | sed 's/^[\t ]*//' | sed -n '/<tbody>/, /<\/tbody>/p' | grep ^\<td | grep -v "center" | tr '\n' ' ' | sed 's/<td /\n<td /g' | grep 720 | grep "${mediaType}" | grep -v IVO | cut -d '"' -f10 | base64 -d | sed 's/}{/}\n{/g' | sed 's/\\//g' | cut -d '"' -f4 > "${fLinks}"
	#Sprawdzamy czy w ogóle mamy linki do wybranej wersji
	if [ -z "$(cat "${fLinks}")" ] ; then
		printf "Brak źródeł dla wybranej wersji: %s.\n" "${mediaType}"
		typesCheck "${fRaw}"
		exit 15
	fi
else
	#Jeżeli to jednak serial, to najpierw szukamy tytułu
	title=$( cat "${fRaw}" | grep 'og:title' | cut -d '"' -f4 | sed "s/ \/ / /g;s/[:;'.]//g;s/ /_/g" )
	#Potem wyciągamy linki do wszytkich epizodów
	cat "${fRaw}" | sed 's/^[\t ]*//' | sed -n '/<span>Se/,/Komentarze/p' | sed -n 's/.*\(https.*serial-online.*\)">\(.*\)<\/a>.*$/\1;\2/p' | sed 's/ /_/g' > "${sLinksTmp}"
	#Wybór sezonu do ściągnięcia - pytamy użytkownika
	while true; do
		read -p "Ilość znalezionych sezonów serialu: ${seasons_available}. Podaj, który sezon pobrać (1 - ${seasons_available}) lub wpisz w albo W żeby ściągnąć wszystkie sezony: " get_season_no
		#Sprawdzamy czy to co podał jest w ogóle liczbą/cyfrą ORAZ czy mieści się w dostępnym przedziale ilości sezonów (od 1 do ILOŚC_DOSĘPNYCH_SEZONÓW)
		if [[ "${get_season_no}" =~ ^[0-9]+$ ]] && [ "${get_season_no}" -le "${seasons_available}" ]; then 
			#Dodatkowo sprawdzamy czy jest to liczba większa równa bądź większa niż 10, żeby odpowiednio sformatować grepa do wyszukiwania sezonów
			if [ "${get_season_no}" -ge 10 ]; then 
				season_wanted=${get_season_no}
			else
				season_wanted=0${get_season_no}
			fi
			printf "Ściągam sezon: %s.\n" "${get_season_no}"
			#O tego grepa chodzi, tu wyszukujemy sezony z wszystkich dostępnych i zmieniamy nazwy plików, żeby dalej nie rzeźbić za bardzo w kodzie
			cat "${sLinksTmp}" | grep "s${season_wanted}" > "${sLinksSel}" && rm "${sLinksTmp}"
			#I wychodzimy z tej pętli
			break
		#Jeśli użytkownik wybrał opcję ściągnięcia wszystkiego, to po prostu zmieniamy nazwy plików i lecimy dalej
		elif [[ "${get_season_no}" == [wW] ]]; then
			printf "Ściągam wszystkie sezony.\n"
			mv "${sLinksTmp}" "${sLinksSel}"
			break
		#A jak nic nie podał, to będziemy wyświetlać pytanie aż do skutku
		else
			printf ""
		fi
	done

	#Następnie w pętli wyszukujemy linki VOD dla każdego odcinka i zapisujemy je do folderu /tmp/filman do pliku o nazwie: serial.tytulSerialu.tytulOdcinka.txt
	printf "Szukam odnośników do odcinków...\n"
        while read line; do
                seriesTmpName=$( printf "serial.%s.%s.txt" "${title}" $(printf "%s" "${line}" | cut -d ';' -f2) )
                curl -sL -c "${cookie}" -b "${cookie}" $(printf "%s" "${line}" | cut -d ';' -f1) > "${fSeriesRaw}"
				cat "${fSeriesRaw}" | sed 's/^[\t ]*//' | sed -n '/<tbody>/, /<\/tbody>/p' | grep ^\<td | grep -v "center" | tr '\n' ' ' | sed 's/<td /\n<td /g' | grep 720 | grep "${mediaType}" | grep -v IVO | cut -d '"' -f10 | base64 -d | sed 's/}{/}\n{/g' | sed 's/\\//g' | cut -d '"' -f4 > "${fTmp}"/"${seriesTmpName}"
		#Sprawdzamy czy mamy linki do wybranej wersji
		if [ -z "$( cat "${fTmp}"/"${seriesTmpName}" )" ] ; then
				printf "Brak źródeł dla wybranej wersji: %s dla: %s.\n" "${mediaType}" "${seriesTmpName}"
				typesCheck "${fSeriesRaw}"
		fi
        done<"${sLinksSel}"
fi

#Sprawdzamy czy ISTNIEJE plik z linkami do serialu
if [ ! -f "${sLinksSel}" ]; then
	#Jeśli nie to ściągamy film
	make_dir "${title}"	#Tworzymy katalog tymczasowy
	vodCheck "${fLinks}"	#Szukamy dostępnego vod
	printf "Pobieram %s z %s...\n\n" "${title}" "${myVod}"	#Informujemy skąd będziemy ściągać
		if [ "${myVod}" == 'dood' ] || [ "${myVod}" == 'vidoza' ] ; then	#Jeśli wybrany/znaleziony vod to dood albo vidoza, to odpalamy tylko jego funkcję, bo ponieważ stamtąd ściągamy nieco inaczej
			"${myVod}"
		else								#A jeśli nie, to odpalamy funkcję konkretnego vod, a potem getVideo
			"${myVod}"
			getVideo						#Funkcja do pobierania pojedynczego filmu
		fi
else
	#Jeśli są dane serialowe to robimy to poniżej    
	for s in $( ls "${fTmp}" | grep 'serial\.' ); do
		if [ ! -z  "$( cat "${fTmp}"/"${s}" )" ] ; then
			seriesTitle=$( printf "%s/%s" "${fTmp}" "${s}" | cut -d '.' -f2 ) #Wybieramy tytul serialu
			episodeTitle=$( printf "%s/%s" "${fTmp}" "${s}" | cut -d '.' -f3 ) #Wybieramy tytul odcinka
			seasonNumber=$( printf "%s" "${episodeTitle}" | sed -n 's/^\[\([sS][0-9]\{1,2\}\).*$/\1/p') #Wybieramy znacznik sezonu w postaci: sXX / SXX
			[ ! -d "${outDir}"/"${seriesTitle}"/"${seasonNumber}" ] && mkdir -p "${outDir}"/"${seriesTitle}"/"${seasonNumber}" #Tworzymy katalog: $outDir/seriesTitle/seasonNumber, jeżeli nie istnieje.
			if [ ! -f "${outDir}/${seriesTitle}/${seasonNumber}/${episodeTitle}"* ] ; then #Sprawdzamy czy plik: $outDir/seriesTitle/seasonNumber/episodeTitle.ts istnieje. Jeżeli nie to odpalamy procedurę ściągania.

				make_dir "${episodeTitle}"		#Tworzymy folder tymczasowy dla odcinka
				mv "${fTmp}"/"${s}" "${tmpDir}"		#Wrzucamy tam plik z linkami do odcinka
				vodCheck "${tmpDir}"/"${s}"		#Wybieramy vod

				printf "Pobieram %s z %s...\n\n" "${episodeTitle}" "${myVod}"	#Informujemy skąd będziemy ściągać
				if [ "${myVod}" == 'dood' ] || [ "${myVod}" == 'vidoza' ] ; then	#Jeśli wybrany/znaleziony vod to dood albo vidoza, to odpalamy tylko jego funkcję, bo ponieważ stamtąd ściągamy nieco inaczej
					"${myVod}"
				else
					"${myVod}"
					getSeries	#Zmodyfikowana funkcja getVideo, aby odpowiednio zapisywać odcinki w strukturze katalogów.
				fi
				rm -rf "${tmpDir}"	#Wywalamy tymczasowy katalog dla odcinka
			fi
		fi
	done
fi

#No i robimy porządki na koniec
rm -rf "${fTmp}"
