#!/usr/bin/env bash
html='/tmp/html-data'
outdir='/tmp/series'

rm -f "${html}" "${outdir}"/links > /dev/null 2>&1

[ ! -d "${outdir}" ] && mkdir "${outdir}"

while getopts ":l:" opt; do
        case "${opt}" in
                l) link="${OPTARG}" ;;
                :) echo "Opcja -${OPTARG} wymaga argumentu." ; exit 1 ;;
                ?) echo "Niewłaściwa opcja: -${OPTARG}." ; exit 1 ;;
        esac
done

#sstatus_code=$(curl --head --silent --output /dev/null --write-out '%{http_code}' -H "User-Agent: Mozilla/5.0" "$link")

#status_code=$(curl --head --silent --output /dev/null --write-out '%{http_code}' -H "User-Agent: Mozilla/5.0" "$link")

#[ "${status_code}" -ne  200 ] && echo "Błąd! Coś nie tak z linkiem." &&  exit 1


if [[ "${link}" == *"filman"* ]]; then
       
	curl -sL -H "User-Agent: Mozilla/5.0" "${link}" > "${html}"
       
        series_list_filman=($( sed 's/^[\t ]*//' "${html}" | sed -n '/<span>Se/,/Komentarze/p' | sed -n 's/.*\(https:\/\/filman.cc\/e\/.*\)">\[\(s[0-9]*\)\(e[0-9]*\)\] \(.*\)<\/a>.*$/\1@_\2_\3@\4/p' | tr ' ' '_' ))
        series_title_filman=$( sed -n 's/^.*<h2>\(.*\)<\/h2>.*$/\1/p' "${html}" | sed "s/ \/ / /g;s/[:;'.]//g;s/ /_/g" )

        for episode in "${series_list_filman[@]}"; do
                
                tmp_list=($( curl -sL -H "User-agent: Mozilla/5.0"  "${episode%%@*}" | sed 's/^[\t ]*//' | sed -n '/<tbody>/, /<\/tbody>/p' | grep ^\<td | grep -v "center\|720" | tr -d '\n' | sed 's/$/\n/;s/<td style/\n/g' | sed -n 's/^.*data-iframe="\(.*\)"><img.*<td>\(.*\)<\/td>$/\1|\2/p' ))

                for entry in "${tmp_list[@]}"; do
                        vod_link=$( echo "${entry%|*}" | base64 -d | cut -d '"' -f4 | tr -d '\\' )
                        echo "${vod_link}@${entry#*|}@Serial@${series_title_filman}@${episode#*@}" >> "${outdir}"/links
                done

        done


else

        curl -sL -H "User-Agent: Mozilla/5.0" "${link}" > "${html}"

        series_title_zaluknij=$( sed -n 's/^.*<span class="hidden-seo">\(.*\)<\/span>.*$/\1/p' "${html}" | sed "s/ \/ / /g;s/[:;'.]//g;s/ /_/g" )
        series_list_zaluknij=($( sed 's/^[\t ]*//' "${html}" | sed -n '/<h4>Odcinki/,/Komentarze/p' | sed -n 's/.*\(https:\/\/zaluknij.cc\/.*\)">\[\(s[0-9]*\)\(e[0-9]*\)\] \(.*\)<\/a>.*$/\1@_\2_\3@\4/p' | tr ' ' '_'))

        for episode in "${series_list_zaluknij[@]}"; do
                
                tmp_list=($( curl -sL -H "User-Agent: Mozilla/5.0" "${episode%%@*}" | sed 's/^[\t ]*//' | sed -n '/<tbody>/, /<\/tbody>/p' | grep "<td\|data" | grep -v "center\|style"  | tr -d '\r\n' | sed 's/data/\ndata/g'| sed -n 's/^.*data-iframe="\(.*\)"><td>\(.*\)<\/td><.*$/\1|\2/p' | sed '/^$/d;s/ /_/g' ))

                for entry in "${tmp_list[@]}"; do
                        vod_link=$( echo "${entry%|*}" | base64 -d | cut -d '"' -f4 | tr -d '\\' )
                        echo "${vod_link}@${entry#*|}@Serial@${series_title_zaluknij}@${episode#*@}" >> "${outdir}"/links
                done

        done


fi
echo "Gotowe! Linki zapisane w ${outdir}/links"
