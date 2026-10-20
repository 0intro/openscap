#!/usr/bin/env bash

. $builddir/tests/test_common.sh

set -e -o pipefail

function perform_test {
	probecheck "sysctl" || return 255
	[ $(uname) == "Linux" ] || return 255

	result=`mktemp`
	stderr=`mktemp`
	hostname="fake.host.name.me"

	tmpdir=$(make_temp_dir /tmp "test_offline_mode_sysctl")
	mkdir -p "${tmpdir}/proc/sys/kernel"
	echo "${hostname}" > "${tmpdir}/proc/sys/kernel/hostname"
	set_offline_chroot_dir "${tmpdir}"

	$OSCAP oval eval --results $result $srcdir/test_sysctl_probe.oval.xml 2>$stderr

	set_offline_chroot_dir ""
	rm -rf "${tmpdir}"

	# The probe reads the running kernel alone, so under a probe root it
	# reports its object not applicable, and says so, whatever
	# <root>/proc/sys holds.
	[[ "$(cat "$stderr")" == "W: oscap: Requested offline mode is not supported by sysctl probe." ]]
	assert_exists 1 '/oval_results/results/system/definitions/definition[@definition_id="oval:oscap:def:1"][@result="not applicable"]'
	assert_exists 1 '/oval_results/results/system/tests/test[@test_id="oval:oscap:tst:1"][@result="not applicable"]'
	assert_exists 1 '/oval_results/results/system/oval_system_characteristics/collected_objects/object[@id="oval:oscap:obj:1"][@flag="not applicable"]'
	assert_exists 0 '/oval_results/results/system/oval_system_characteristics/system_data/unix-sys:sysctl_item'

	rm $result
	rm $stderr
}

perform_test
