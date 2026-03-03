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
}