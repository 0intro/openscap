#!/usr/bin/env bash

# Test that SCE runs scripts in OSCAP_PROBE_ROOT, the root of the system the
# probes assess.

. "$builddir/tests/test_common.sh"

set -e -o pipefail

# copy_program copies the program at path, and the libraries ldd lists for
# it, to the same paths under root.
function copy_program {
	local path="$1"
	local root="$2"
	local lib

	mkdir -p "$root$(dirname "$path")"
	cp -L "$path" "$root$path"
	for lib in $(ldd "$path" | grep -o '/[^ ]*'); do
		mkdir -p "$root$(dirname "$lib")"
		cp -L "$lib" "$root$lib"
	done
	return 0
}

# rule_result prints the XPath of the result of rule n.
function rule_result {
	local n="$1"
	local want="$2"

	echo "//rule-result[@idref='xccdf_moc.elpmaxe.www_rule_$n']/result[text()='$want']"
	return 0
}

function test_sce_probe_root {
	local xccdf="$1"

	# The root holds the programs and the libraries ldd lists in its Linux
	# format, and the chroot into it needs root.
	[[ "$(uname)" == Linux ]] || return 255
	if [[ "$(id -u)" -ne 0 ]]; then
		echo "you need to be root" >&2
		return 255
	fi
	require "ldd" || return 255
	[[ -x /usr/bin/perl ]] || return 255

	local root result
	root=$(mktemp -d)
	result=$(mktemp)

	copy_program /bin/sh "$root"
	copy_program /usr/bin/perl "$root"
	# perl -e reads its script file, /dev/null
	mkdir "$root/dev"
	mknod -m 600 "$root/dev/null" c 1 3
	mkdir -p "$root/etc"
	echo probe_root >"$root/etc/marker"

	set_offline_chroot_dir "$root"
	$OSCAP xccdf eval --results "$result" "$srcdir/$xccdf" || true
	set_offline_chroot_dir ""

	assert_exists 1 "$(rule_result 1 pass)"
	assert_exists 1 "$(rule_result 2 pass)"
	assert_exists 1 "$(rule_result 3 pass)"
	assert_exists 1 "$(rule_result 4 error)"

	rm -r "$root" "$result"
	return 0
}

# Without CAP_SYS_CHROOT the scripts run in place, after a warning on the
# standard error of oscap.
function test_sce_probe_root_refused {
	local xccdf="$1"

	[[ "$(uname)" == Linux ]] || return 255
	if [[ "$(id -u)" -ne 0 ]]; then
		echo "you need to be root" >&2
		return 255
	fi
	require "capsh" || return 255

	local root result stderr
	root=$(mktemp -d)
	result=$(mktemp)
	stderr=$(mktemp)

	mkdir "$root/etc"
	echo probe_root >"$root/etc/marker"

	set_offline_chroot_dir "$root"
	# The command runs in the shell capsh starts, with its arguments.
	# shellcheck disable=SC2016
	capsh --drop=cap_sys_chroot -- -c '$OSCAP xccdf eval --results "$0" "$1"' "$result" "$srcdir/$xccdf" 2>"$stderr" || true
	set_offline_chroot_dir ""

	[[ "$(grep -c "Running script .* in place" "$stderr")" -eq 3 ]]
	assert_exists 1 "$(rule_result 1 fail)"
	assert_exists 1 "$(rule_result 4 error)"

	rm -r "$root" "$result" "$stderr"
	return 0
}

# Testing.
test_init

test_run "SCE in OSCAP_PROBE_ROOT" test_sce_probe_root test_sce_probe_root.xccdf.xml
test_run "SCE in OSCAP_PROBE_ROOT without CAP_SYS_CHROOT" test_sce_probe_root_refused test_sce_probe_root.xccdf.xml

test_exit
