#!/usr/bin/env bash

vidozaTest(){
	data_check=$(curl -sL "${1}" --max-time 5)
	if [[ -z "${data_check}" || "${data_check}" == *"File was deleted"* ]]; then
		is_ok=false
	else
		is_ok=true
	fi
}

vidoza(){
	curlOpts=''
	video_url=$( curl -sL "${1}" | grep sourcesCode | cut -d '"' -f2 )

	if [[ "${series_title}" ]] && [[ "${season_number}" ]] && [[ "${episode_title}" ]]; then
		curl "${video_url}" -H "User-Agent: Mozilla/5.0" -o "${out_dir}"/"${series_title}"/"${season_number}"/"${full_episode_title}".mp4
		echo "Film zapisany w ${out_dir}/${series_title}/${season_number}/${full_episode_title}.mp4"
	else
		[[ ! -d "${out_dir}"/"${title}" ]] && mkdir -p "${out_dir}"/"${title}"
		curl "${video_url}" -H "User-Agent: Mozilla/5.0" -o "${out_dir}"/"${title}"/"${title}".mp4
		echo "Film zapisany w ${out_dir}/${title}/${title}.mp4"
	fi
}