#!/usr/bin/env bash

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

	if [ "${seriesTitle}" ] && [ "${seasonNumber}" ] && [ "${episodeTitle}" ]; then
		curl -L "${videoURL}" -o "${outDir}"/"${seriesTitle}"/"${seasonNumber}"/"${fullEpisodeTitle}".mp4
		echo "Film zapisany w ${outDir}/${seriesTitle}/${seasonNumber}/${fullEpisodeTitle}.mp4"
	else
		[ ! -d "${outDir}"/"${title}" ] && mkdir -p "${outDir}"/"${title}"
		curl -L "${videoURL}" -o "${outDir}"/"${title}"/"${title}".mp4
		echo "Film zapisany w ${outDir}/${title}/${title}.mp4"
	fi
}