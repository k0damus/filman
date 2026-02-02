#!/usr/bin/env bash

vidozaTest(){
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

	if [[ "${seriesTitle}" ]] && [[ "${seasonNumber}" ]] && [[ "${episodeTitle}" ]]; then
		curl "${videoURL}" -o "${outDir}"/"${seriesTitle}"/"${seasonNumber}"/"${fullEpisodeTitle}".mp4
		echo "Film zapisany w ${outDir}/${seriesTitle}/${seasonNumber}/${fullEpisodeTitle}.mp4"
	else
		[[ ! -d "${outDir}"/"${title}" ]] && mkdir -p "${outDir}"/"${title}"
		curl "${videoURL}" -o "${outDir}"/"${title}"/"${title}".mp4
		echo "Film zapisany w ${outDir}/${title}/${title}.mp4"
	fi
}