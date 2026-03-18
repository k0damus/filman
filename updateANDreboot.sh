#!/usr/bin/env bash
log_file="/root/update/update.log"
update_note="/root/update/i-was-updated.txt"
update_time="2026-03-16 01:00:00"

mkdir -p /root/update
touch "${log_file}"

log() {
    printf "[%s] %s\n" "$(date '+%Y-%m-%d %H:%M:%S')" "${1}" >> "${log_file}"
}

if [[ ! -z "${1}" ]]; then
        log "[INFO] I'm back online :)"
        log "[INFO] Removing crontab tasks file: /etc/cron.d/update_run"
        rm /etc/cron.d/update_run >/dev/null 2>&1
        log "[INFO] ========== UPDATE PROCESS CLOSE =========="
        exit 0
fi

#hey, wasn't i updated already? ;)
check_update_note() {
    if [[ -f "${update_note}" ]]; then
        log "[INFO] Update note exists, nothing to do. Exiting."
        log "[INFO] ========== UPDATE PROCESS CLOSE =========="
        exit 0
    fi
}

#get time in unix epoch
get_ts() {
    date --date="${1}" +"%s"
}

#name speaks for itself
compare_dates() {
    local now_ts update_ts
    now_ts=$(get_ts "now")
    update_ts=$(get_ts "${update_time}")

    if (( now_ts < update_ts )); then
        log "[INFO] Not yet, it's too early. Exiting."
        log "[INFO] ========== UPDATE PROCESS CLOSE =========="
        exit 0
    else
        log "[INFO] Time threshold met. Running update."
    fi
}

#go check if there's anything to update
check_updates() {
    if dnf check-update >/dev/null; then
        log "[INFO] No updates available. Exiting."
        log "[INFO] ========== UPDATE PROCESS CLOSE =========="
        exit 0
    else
        # exit=100 => we have packages to update
        if [[ $? -eq 100 ]]; then
            log "[INFO] Updates available. Running: dnf upgrade -y --refresh --allowerasing "
        else
            log "[ERROR] dnf check-update returned an unexpected error."
            log "[INFO] ========== UPDATE PROCESS CLOSE =========="
            exit 1
        fi
    fi
}

#ruuuuunnn that update xD
run_update() {
    if dnf upgrade -y --refresh --allowerasing; then
        log "[INFO] Upgrade successful."
        echo "Updated at: $(date '+%Y-%m-%d %H:%M:%S')" > "${update_note}"
    else
        log "[ERROR] Upgrade failed. Exiting."
        log "[INFO] ========== UPDATE PROCESS CLOSE =========="
        exit 1
    fi
}

#do we need a reboot, man?
#if yes we need to check if the other machine is online
#we do a reboot only if it is online
reboot_check() {
        needs-restarting -r >/dev/null 2>&1
        if [[ $? -eq 1 ]]; then
                log "[INFO] Reboot required. Checking if our neighbour server is online."
        else
                log "[INFO] Reboot not required. All should be fine now. Exiting."
                log "[INFO] ========== UPDATE PROCESS CLOSE =========="
                exit 0
        fi
}

#check if other host is reachable
#reboot only if it is responding to ping
host_check_and_reboot(){
        local host

        if [[ $(hostname) == 'blg-tst-d02' ]]; then
            host='blg-tst-d01.europe.phoenixcontact.com'
        fi

        while ! ping -c 1 "${host}" >/dev/null 2>&1 ; do
                log "[INFO] Host ${host} is not responding to ping yet. Waiting for it to become online to perform reboot."
                sleep 10
        done

        log "[INFO] Host ${host} is responding to ping, continue with rebooting."
        log "[INFO] All cron entries related to this job will be removed after reboot."
        /usr/sbin/reboot
}

main() {
    log "[INFO] ========== UPDATE PROCESS START =========="
    check_update_note
    compare_dates
    check_updates
    run_update
    reboot_check
    host_check_and_reboot
}

main


exit 0
echo -e "*/5 * * * * root /usr/bin/flock -n /root/update/updater.lock /bin/bash /root/update/runme\n@reboot root /bin/bash /root/update/runme x" > /etc/cron.d/update_run
