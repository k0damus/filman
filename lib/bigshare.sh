#!/usr/bin/env bash

bigshareTest(){
	dataCheck=$(curl -sL "${1}" --max-time 5 -H "User-Agent: Mozilla/5.0")
	if [[ -z "${dataCheck}" || "${dataCheck}" == *"File not found"* ]]; then
		isOK=false
	else
		isOK=true
	fi	
}

bigshare(){
	videoURL=$( curl -sL "${1}" -H "User-Agent: Mozilla/5.0"  | grep url: | sed -n "s/^.*'\(.*\)'.*$/\1/p" )

	if [[ "${seriesTitle}" ]] && [[ "${seasonNumber}" ]] && [[ "${episodeTitle}" ]]; then
		curl "${videoURL}" -H "User-Agent: Mozilla/5.0" -o "${outDir}"/"${seriesTitle}"/"${seasonNumber}"/"${fullEpisodeTitle}".mp4
		echo "Film zapisany w ${outDir}/${seriesTitle}/${seasonNumber}/${fullEpisodeTitle}.mp4"
	else
		[[ ! -d "${outDir}"/"${title}" ]] && mkdir -p "${outDir}"/"${title}"
		curl "${videoURL}" -H "User-Agent: Mozilla/5.0" -o "${outDir}"/"${title}"/"${title}".mp4
		echo "Film zapisany w ${outDir}/${title}/${title}.mp4"
	fi
}