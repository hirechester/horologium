#!/bin/bash
# Shared by Installer's root-run preinstall and postinstall scripts.
state_directory='/private/var/run/app.ardens.horologium.installer'

console_user_id() {
  local uid
  uid=$(/usr/bin/stat -f %u /dev/console) || return 1
  case "$uid" in ''|*[!0-9]*) return 1 ;; esac
  [[ "$uid" -ge 501 && "$uid" -ne 65534 ]] || return 1
  printf '%s\n' "$uid"
}

is_running() {
  /usr/bin/pgrep -u "$1" -x Horologium >/dev/null
}
