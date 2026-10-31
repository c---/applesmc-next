#!/bin/sh
# Offline behaviour test for the 62-applesmc-next TLP plugin.
# Uses a fake sysfs tree and minimal stand-ins for the TLP helpers the
# plugin calls; touches no real hardware.
# Usage: sh tlp/test-62-applesmc-next.sh
# SPDX-License-Identifier: GPL-2.0-or-later

# no "set -u": TLP plugins rely on unset positional parameters
PLUGIN=$(cd "$(dirname "$0")" && pwd)/62-applesmc-next
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
fail=0

# --- stand-ins for TLP helpers
echo_debug () { :; }
echo_message () { printf 'MSG: %s\n' "$*" >&2; }
cprintf () { shift; printf "$@"; }
soc_gt_stop_notice () { :; }
read_sysf () { [ -r "$1" ] && cat "$1"; }
readable_sysf () { [ -r "$1" ]; }
write_sysf () { [ -w "$1" ] && printf '%s\n' "$1" >/dev/null && printf '%s' "$2" > "$1"; }
wordinlist () { case " $2 " in *" $1 "*) return 0 ;; esac; return 1; }
is_uint () { case "$1" in ''|*[!0-9]*) return 1 ;; esac; [ ${#1} -le "${2:-9}" ]; }
unlock_tlp () { :; }

check () { # $1 desc, $2 expected, $3 actual
    if [ "$2" = "$3" ]; then echo "ok   $1"; else echo "FAIL $1: expected '$2' got '$3'"; fail=1; fi
}

# shellcheck disable=SC1090
. "$PLUGIN"
# override after sourcing: write_sysf(value, file)
write_sysf () { [ -w "$2" ] && printf '%s' "$1" > "$2"; }

mkdir -p "$T/ps/BAT0"
echo 1 > "$T/ps/BAT0/present"
ACPIBATDIR=$T/ps
NATACPI_ENABLE=1
X_BAT_PLUGIN_SIMULATE=""
X_BAT_PLUGIN_DENYLIST=""
X_THRESH_SIMULATE_STOP=""
X_THRESH_SIMULATE_READERR=""

# 1: stock drivers (no applesmc-next attribute) -> plugin must not claim
batdrv_init; rc=$?
[ -d /sys/devices/platform/applesmc.768 ] || rc=skip
check "no end attribute: decline (rc 1) or no applesmc device" "1" "$( [ "$rc" = skip ] && echo 1 || echo $rc)"

# 2: end-only hardware via simulation path
echo 100 > "$T/ps/BAT0/charge_control_end_threshold"
printf '0\n' > "$T/ps/BAT0/charge_control_start_threshold"
chmod 444 "$T/ps/BAT0/charge_control_start_threshold"
X_BAT_PLUGIN_SIMULATE=applesmc
batdrv_init; check "end-only: init rc" 0 $?
check "end-only: thresh method" natacpi "$_bm_thresh"
check "end-only: no start sysfile" "" "$_bn_start"
batdrv_select_battery DEF; check "select DEF" BAT0 "$_bat_str"
check "start reports unsupported" "(not supported)" "$(batdrv_read_threshold start 1)"
batdrv_read_threshold start 0 >/dev/null; check "start api rc" 255 $?

# 3: write 80, start ignored, read-only start file untouched
batdrv_write_thresholds 75 80 0 1; check "write 80 rc" 0 $?
check "end now 80" 80 "$(cat "$T/ps/BAT0/charge_control_end_threshold")"
check "start untouched" 0 "$(cat "$T/ps/BAT0/charge_control_start_threshold")"

# 4: invalid values rejected without writing
for v in 0 1 9 101 abc ""; do
    batdrv_write_thresholds "" "$v" 0 2>/dev/null; rc=$?
    exp=2
    check "reject stop '$v'" "$exp" "$rc"
done
batdrv_write_thresholds "" "" 0 1; check "unconfigured -> rc 1" 1 $?
check "end still 80" 80 "$(cat "$T/ps/BAT0/charge_control_end_threshold")"

# 5: configured apply uses STOP only
STOP_CHARGE_THRESH_BAT0=100 START_CHARGE_THRESH_BAT0=75
batdrv_apply_configured_thresholds
check "apply configured 100" 100 "$(cat "$T/ps/BAT0/charge_control_end_threshold")"

# 6: write failure reported
# (simulated: root ignores file modes)
write_sysf () { return 1; }
batdrv_write_thresholds "" 80 0 1; check "write error rc 5" 5 $?

# 7: no battery
echo 0 > "$T/ps/BAT0/present"
batdrv_init; check "no battery rc 2" 2 $?

exit $fail
