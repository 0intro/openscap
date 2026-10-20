#!/usr/bin/env bash

. "$builddir/tests/test_common.sh"

set -e -o pipefail

function test_probes_dpkginfo_virtual_packages {
	probecheck "dpkginfo" || return 255

	local definition="${srcdir}/test_probes_dpkginfo_virtual_packages.xml"
	local result="results_virtual_packages.xml"
	[[ -f "$result" ]] && rm -f "$result"

	# The root has one installed package, real-pkg, which provides the
	# virtual package virt-pkg.
	local tmpdir
	tmpdir=$(make_temp_dir /tmp "test_offline_mode_dpkginfo")
	mkdir -p "${tmpdir}/var/lib/dpkg"
	cat > "${tmpdir}/var/lib/dpkg/status" <<'END'
Package: real-pkg
Status: install ok installed
Architecture: amd64
Version: 1.0-1
Provides: virt-pkg
END
	set_offline_chroot_dir "${tmpdir}"

	$OSCAP oval eval --results "$result" "$definition"

	set_offline_chroot_dir ""
	rm -rf "${tmpdir}"

	local item='oval_results/results/system/oval_system_characteristics/system_data/lin-sys:dpkginfo_item'
	assert_exists 1 "$item"
	assert_exists 1 "$item/lin-sys:name[text()=\"real-pkg\"]"
	assert_exists 1 "$item/lin-sys:evr[text()=\"1.0-1\"]"
	assert_exists 1 'oval_results/results/system/oval_system_characteristics/collected_objects/object[@id="oval:1:obj:2"][@flag="does not exist"]'
	assert_exists 1 'oval_results/results/system/definitions/definition[@definition_id="oval:1:def:1"][@result="true"]'
	assert_exists 1 'oval_results/results/system/definitions/definition[@definition_id="oval:1:def:2"][@result="true"]'
	return 0
}

test_init

test_run "test_probes_dpkginfo_virtual_packages" test_probes_dpkginfo_virtual_packages

test_exit
