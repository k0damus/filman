#!/usr/bin/env bash

vidozaTest(){
	data_check=$(curl -sL "${1}" --max-time 5)
	if [[ -z "${data_check}" || "${data_check}" == *"file was deleted"* ]]; then
		is_ok=false
	else
		is_ok=true
	fi
}

vidoza(){
	curlOpts=''
	video_url=$( curl -sL "${1}" | grep sourcesCode | cut -d '"' -f2 )
}