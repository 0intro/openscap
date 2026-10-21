#!/bin/bash

# In PROBE_OFFLINE_CHROOT mode, the memory check of a probe must read /proc
# of the scanner, whatever /proc of the scanned root holds. The runlevel
# probe runs in that mode. The root holds 150 services in 7 runlevels, so
# the object has 1050 items, past the 1000 items after which the probe
# checks its memory.

set -e -o pipefail

. "$builddir/tests/test_common.sh"

probecheck "runlevel" || exit 255

root=$(make_temp_dir /tmp offline_memory_check)
result=$(mktemp)
trap 'rm -rf -- "${root:?}" "$result"' EXIT

mkdir -p "$root/etc/rc.d/init.d"
touch "$root/etc/redhat-release"
for i in $(seq 0 6); do
	mkdir "$root/etc/rc$i.d"
done
for i in $(seq 1 150); do
	touch "$root/etc/rc.d/init.d/service$i"
done

set_chroot_offline_test_mode "$root" || exit 255

sc='/oval_results/results/system/oval_system_characteristics/'

# The root has no /proc.
$OSCAP oval eval --results "$result" "$srcdir/offline_memory_check.oval.xml"
assert_exists 1 $sc'collected_objects/object[@flag="complete"]'
assert_exists 1050 $sc'system_data/unix-sys:runlevel_item'

# /proc of the root claims that the scanner fills the memory.
mkdir -p "$root/proc/self"
printf '%s\n' 'MemTotal: 1 kB' 'MemFree: 0 kB' 'Buffers: 0 kB' 'Cached: 0 kB' \
	'Active: 0 kB' 'Inactive: 0 kB' >"$root/proc/meminfo"
printf '%s\n' 'VmHWM: 1048576 kB' 'VmRSS: 1048576 kB' 'VmData: 1048576 kB' \
	'VmStk: 132 kB' 'VmExe: 4 kB' 'VmLib: 4096 kB' 'VmLck: 0 kB' >"$root/proc/self/status"
$OSCAP oval eval --results "$result" "$srcdir/offline_memory_check.oval.xml"
assert_exists 1 $sc'collected_objects/object[@flag="complete"]'
assert_exists 1050 $sc'system_data/unix-sys:runlevel_item'

unset_chroot_offline_test_mode
