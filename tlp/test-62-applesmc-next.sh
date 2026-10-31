#!/bin/sh
# Offline behaviour test for the 62-applesmc-next TLP plugin.
# Uses fake sysfs and stand-ins for the TLP helpers; touches no real hardware.
# Usage: sh tlp/test-62-applesmc-next.sh
# SPDX-License-Identifier: GPL-2.0-or-later

# no "set -u": TLP plugins rely on unset positional parameters
PLUGIN=$(cd "$(dirname "$0")" && pwd)/62-applesmc-next
T=$(mktemp -d) || exit 1
trap 'rm -rf "$T"' EXIT
fail=0
READ_FAIL=""
WRITE_FAIL=0
HAS_SMC=1

# Stand-ins follow the TLP 1.10.2 helpers' argument and return conventions.
echo_debug () { :; }
echo_message () { printf 'MSG: %s\n' "$*" >&2; }
cprintf () { shift; printf "$@"; }
soc_gt_stop_notice () { :; }
read_sysf () {
    [ "$1" != "$READ_FAIL" ] || return 1
    if cat "$1" 2>/dev/null; then return 0; else printf '%s' "$2"; return 1; fi
}
readable_sysf () { read_sysf "$1" >/dev/null 2>&1; }
write_sysf () {
    # Record attempts even when a write fails; root and ordinary users must
    # both detect any attempt to write the unsupported start attribute.
    printf '%s\n' "$2" >> "$T/writes"
    [ "$WRITE_FAIL" = 0 ] || return 1
    printf '%s\n' "$1" > "$2"
}
wordinlist () { case " $2 " in *" $1 "*) return 0 ;; esac; return 1; }
is_uint () { printf '%s' "$1" | grep -E -q "^[0-9]{1,$2}$"; }
unlock_tlp () { :; }

check () { # $1 description, $2 expected, $3 actual
    if [ "$2" = "$3" ]; then echo "ok   $1"; else echo "FAIL $1: expected '$2' got '$3'"; fail=1; fi
}
write_count () { wc -l < "$T/writes" | tr -d ' '; }

# shellcheck disable=SC1090
. "$PLUGIN"
# Only the hardware presence probe is substituted. The init/fallback logic
# runs unchanged, with simulation off, on every host.
batdrv_is_applesmc_next () { [ "$HAS_SMC" = 1 ]; }

mkdir -p "$T/ps/BAT0" || exit 1
: > "$T/writes"
echo 1 > "$T/ps/BAT0/present"
echo 100 > "$T/ps/BAT0/charge_control_end_threshold"
echo 0 > "$T/ps/BAT0/charge_control_start_threshold"
ACPIBATDIR=$T/ps
NATACPI_ENABLE=1
X_BAT_PLUGIN_SIMULATE=""
X_BAT_PLUGIN_DENYLIST=""
X_THRESH_SIMULATE_STOP=""
X_THRESH_SIMULATE_READERR=""

HAS_SMC=0
batdrv_init; check "non-Apple hardware declined despite end attribute" 1 $?
HAS_SMC=1
rm "$T/ps/BAT0/charge_control_end_threshold"
batdrv_init; check "Apple stock driver without end attribute declined" 1 $?
echo 100 > "$T/ps/BAT0/charge_control_end_threshold"
X_BAT_PLUGIN_DENYLIST=applesmc
batdrv_init; check "denylisted adapter declined" 1 $?
X_BAT_PLUGIN_DENYLIST=""
batdrv_init; check "Apple end-only API detected without simulation" 0 $?
check "selected adapter" applesmc "$_batdrv_selected"
check "stop-threshold method" natacpi "$_bm_thresh"
check "no start sysfile" "" "$_bn_start"
batdrv_select_battery DEF; check "select DEF" BAT0 "$_bat_str"
batdrv_select_battery BAT1; check "absent BAT1 rejected" 1 $?
batdrv_select_battery DEF
check "start reports unsupported" "(not supported)" "$(batdrv_read_threshold start 1)"
batdrv_read_threshold start 0 >/dev/null; check "start API rc" 255 $?

# Writable start file and a write-attempt log catch forbidden writes even when
# the driver would reject them. Do not rely on chmod or the test user's UID.
batdrv_write_thresholds 75 80 0 1; check "write 80 rc" 0 $?
check "end now 80" 80 "$(cat "$T/ps/BAT0/charge_control_end_threshold")"
check "start untouched" 0 "$(cat "$T/ps/BAT0/charge_control_start_threshold")"
check "no start write attempted" 0 "$(grep -c '/charge_control_start_threshold$' "$T/writes")"

before=$(write_count)
for v in 0 1 9 101 abc ""; do
    batdrv_write_thresholds "" "$v" 0 2>/dev/null; check "reject stop '$v'" 2 $?
done
batdrv_write_thresholds "" "" 0 1; check "unconfigured -> rc 1" 1 $?
check "invalid/unconfigured values attempted no writes" "$before" "$(write_count)"
check "end still 80" 80 "$(cat "$T/ps/BAT0/charge_control_end_threshold")"
batdrv_write_thresholds "" 80 0; check "unchanged threshold rc" 0 $?
check "unchanged threshold attempted no write" "$before" "$(write_count)"
batdrv_write_thresholds "" 10 0; check "minimum 10 rc" 0 $?
check "minimum stored" 10 "$(cat "$T/ps/BAT0/charge_control_end_threshold")"
batdrv_write_thresholds DEF DEF 0; check "DEF/fullcharge rc" 0 $?
check "DEF restores default 100" 100 "$(cat "$T/ps/BAT0/charge_control_end_threshold")"
batdrv_write_thresholds "" 80 0
STOP_CHARGE_THRESH_BAT0=100 START_CHARGE_THRESH_BAT0=75
batdrv_apply_configured_thresholds
check "apply configured stop only" 100 "$(cat "$T/ps/BAT0/charge_control_end_threshold")"

# Existing API plus SMC read failure stays selected and reports a read error.
READ_FAIL=$T/ps/BAT0/charge_control_end_threshold
batdrv_init; check "unreadable end API stays selected" 0 $?
check "unreadable end API retains threshold support" natacpi "$_bm_thresh"
batdrv_select_battery DEF
batdrv_read_threshold stop 0 >/dev/null; check "failed SMC read rc" 4 $?
check "failed read visible in status" "(read error)" "$(batdrv_read_threshold stop 1)"
before=$(write_count)
batdrv_write_thresholds "" 80 0 1; check "read error stops threshold write" 4 $?
check "read error attempted no write" "$before" "$(write_count)"
READ_FAIL=""
check "read error preserved limit" 100 "$(cat "$T/ps/BAT0/charge_control_end_threshold")"
X_THRESH_SIMULATE_READERR=1
batdrv_write_thresholds "" 80 0; check "TLP simulated read error rc" 4 $?
check "simulated read error attempted no write" "$before" "$(write_count)"
X_THRESH_SIMULATE_READERR=""
WRITE_FAIL=1
batdrv_write_thresholds "" 80 0 1; check "write error rc" 5 $?
check "write error preserved limit" 100 "$(cat "$T/ps/BAT0/charge_control_end_threshold")"
WRITE_FAIL=0

NATACPI_ENABLE=0
batdrv_init; check "configuration-disabled adapter stays selected" 0 $?
check "configuration-disabled status" 32 "$_natacpi"
check "configuration-disabled thresholds unavailable" none "$_bm_thresh"
NATACPI_ENABLE=1
HAS_SMC=0 X_BAT_PLUGIN_SIMULATE=applesmc
batdrv_init; check "simulation bypasses hardware probe" 0 $?
X_BAT_PLUGIN_SIMULATE=other
batdrv_init; check "other simulated plugin declined" 1 $?
HAS_SMC=1 X_BAT_PLUGIN_SIMULATE=""

mv "$T/ps/BAT0" "$T/ps/BAT1"
batdrv_init; check "BAT1-only init" 0 $?
batdrv_select_battery DEF; check "BAT1 is default when alone" BAT1 "$_bat_str"
STOP_CHARGE_THRESH_BAT1=70 START_CHARGE_THRESH_BAT1=42
batdrv_apply_configured_thresholds
check "BAT1 configuration uses BAT1 stop key" 70 "$(cat "$T/ps/BAT1/charge_control_end_threshold")"
check "BAT1 start untouched" 0 "$(cat "$T/ps/BAT1/charge_control_start_threshold")"
check "all write attempts targeted stop only" "" "$(grep -v '/charge_control_end_threshold$' "$T/writes")"
echo 0 > "$T/ps/BAT1/present"
batdrv_init; check "no battery rc" 2 $?

exit $fail
