#!/usr/bin/env bash

streamtapeTest(){
	data_check=$(curl -sL "${1}" --max-time 5)
	if [[ -z "${data_check}" || "${data_check}" == *"Video not found"* ]]; then
		is_ok=false
	else
		is_ok=true
	fi
}

streamtape(){
	if [[ "${1}" != *"/e/"* ]]; then
		link=$( echo "${1}" | sed 's/com\/v\//com\/e\//')
	fi

	video_id=$( echo "${link}" | cut -d '/' -f5 )
	video_url=$( curl -sL "${link}" | grep "'botlink'" | sed -n "s/.*\(\&expires.*\)'.*/\1/p" | sed "s/^/https:\/\/streamtape.com\/get_video?id=${video_id}/;s/$/\&stream=1/" )

	if [[ "${series_title}" ]] && [[ "${season_number}" ]] && [[ "${episode_title}" ]]; then
		curl "${video_url}" -H "User-Agent: Mozilla/5.0" -o "${out_dir}"/"${series_title}"/"${season_number}"/"${full_episode_title}".mp4
		echo "Film zapisany w ${out_dir}/${series_title}/${season_number}/${full_episode_title}.mp4"
	else
		[[ ! -d "${out_dir}"/"${title}" ]] && mkdir -p "${out_dir}"/"${title}"
		curl "${video_url}" -H "User-Agent: Mozilla/5.0" -o "${out_dir}"/"${title}"/"${title}".mp4
		echo "Film zapisany w ${out_dir}/${title}/${title}.mp4"
	fi
}