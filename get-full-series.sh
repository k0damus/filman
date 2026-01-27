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
       
#			 curl -sL -H "User-Agent: Mozilla/5.0" "${link}" > "${html}"
       curl -sL   -H 'accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7' -H 'accept-language: pl-PL,pl;q=0.9,en-US;q=0.8,en;q=0.7' -H 'cache-control: no-cache' -b 'user_id=968999; PHPSESSID=tovplj1qpov85avmduopt9rlrt; BKD_COOKIES=true; BKD_REMEMBER=bj1XwZJaOWEIUulB6vLcgoKS5Gz74NRm; cf_clearance=WbPFBF3UFymq.AYU9Iosuz_I9whb4CfnpfsH1gZ3Xns-1769355565-1.2.1.1-voRwkExw3sVaEz.MBguk3mYQoIzx36e3RpzVIAr77gKfDSIwPFThHudVqvuCehm09HVYHvaQgukE4PZ_K_joRQHI8zZI1DwJyvm4r44WI5SYB27z5x2ty1mGK9kq.s_QCrAd_opW39ZsT1vAiiPfaJqP65eX1Ugu4OlyXpsqO8HyzN3IY5kE7b9fWdAB1coPl28r9P.RIH.NHbSWKBF4lfVm4kCxr6i8rhjPpoBuNbk' -H 'pragma: no-cache' -H 'priority: u=0, i' -H 'sec-ch-ua: "Chromium";v="142", "Google Chrome";v="142", "Not_A Brand";v="99"' -H 'sec-ch-ua-mobile: ?0' -H 'sec-ch-ua-platform: "Linux"' -H 'sec-fetch-dest: document' -H 'sec-fetch-mode: navigate' -H 'sec-fetch-site: none' -H 'sec-fetch-user: ?1' -H 'upgrade-insecure-requests: 1' -H 'user-agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36' "${link}" > "${html}"

        series_list_filman=($( sed 's/^[\t ]*//' "${html}" | sed -n '/<span>Se/,/Komentarze/p' | sed -n 's/.*\(https:\/\/filman.cc\/e\/.*\)">\[\(s[0-9]*\)\(e[0-9]*\)\] \(.*\)<\/a>.*$/\1@_\2_\3@\4/p' | tr ' ' '_' ))
        series_title_filman=$( sed -n 's/^.*<h2>\(.*\)<\/h2>.*$/\1/p' "${html}" | sed "s/ \/ / /g;s/[:;'.]//g;s/ /_/g" )

        for episode in "${series_list_filman[@]}"; do
                
                tmp_list=($( curl -sL   -H 'accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7' -H 'accept-language: pl-PL,pl;q=0.9,en-US;q=0.8,en;q=0.7' -H 'cache-control: no-cache' -b 'user_id=968999; PHPSESSID=tovplj1qpov85avmduopt9rlrt; BKD_COOKIES=true; BKD_REMEMBER=bj1XwZJaOWEIUulB6vLcgoKS5Gz74NRm; cf_clearance=WbPFBF3UFymq.AYU9Iosuz_I9whb4CfnpfsH1gZ3Xns-1769355565-1.2.1.1-voRwkExw3sVaEz.MBguk3mYQoIzx36e3RpzVIAr77gKfDSIwPFThHudVqvuCehm09HVYHvaQgukE4PZ_K_joRQHI8zZI1DwJyvm4r44WI5SYB27z5x2ty1mGK9kq.s_QCrAd_opW39ZsT1vAiiPfaJqP65eX1Ugu4OlyXpsqO8HyzN3IY5kE7b9fWdAB1coPl28r9P.RIH.NHbSWKBF4lfVm4kCxr6i8rhjPpoBuNbk' -H 'pragma: no-cache' -H 'priority: u=0, i' -H 'sec-ch-ua: "Chromium";v="142", "Google Chrome";v="142", "Not_A Brand";v="99"' -H 'sec-ch-ua-mobile: ?0' -H 'sec-ch-ua-platform: "Linux"' -H 'sec-fetch-dest: document' -H 'sec-fetch-mode: navigate' -H 'sec-fetch-site: none' -H 'sec-fetch-user: ?1' -H 'upgrade-insecure-requests: 1' -H 'user-agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36'  "${episode%%@*}" | sed 's/^[\t ]*//' | sed -n '/<tbody>/, /<\/tbody>/p' | grep ^\<td | grep -v "center\|720" | tr -d '\n' | sed 's/$/\n/;s/<td style/\n/g' | sed -n 's/^.*data-iframe="\(.*\)"><img.*<td>\(.*\)<\/td>$/\1|\2/p' ))

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
