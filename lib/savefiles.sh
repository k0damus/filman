#!/usr/bin/env bash

savefilesTest(){
	dataCheck=$( curl -sL "https://savefiles.com/dl?op=embed&file_code=${1##*/}&auto=1" -H "Referer: ${1}" -H "User-Agent: Mozilla/5.0"  )
	if [[ -z "${dataCheck}" || "${dataCheck}" == *"been deleted"* ]]; then
		isOK=false
	else
		isOK=true
	fi	
}

savefiles(){
	partsPATH=$( curl -sL "https://savefiles.com/dl?op=embed&file_code=${1##*/}&auto=1" -H "Referer: ${1}" -H "User-Agent: Mozilla/5.0" | grep sources | sed -n 's/^.*"\(.*\)".*$/\1/p' )
	partsLINK=$( curl -sL "${partsPATH}" | grep index )
	mainURL="${partsLINK%/*}"
	curl -sL "${partsLINK}" | grep -v ^# > "${partsList}"
}