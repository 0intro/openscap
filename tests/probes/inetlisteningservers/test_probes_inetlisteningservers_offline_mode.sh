#!/usr/bin/env bash

. "$builddir/tests/test_common.sh"

set -e -o pipefail

function test_probes_inetlisteningservers_offline_mode {
	probecheck "inetlisteningservers" || return 255

	local definition="${srcdir}/test_probes_inetlisteningservers_offline_mode.xml"
	local result="results_offline_mode.xml"
	[[ -f "$result" ]] && rm -f "$result"

	# The probe reads the sockets of the init process of the root. This
	# init, named sendmail, listens on 127.0.0.1:8080 (0100007F:1F90)
	# with the socket of inode 12345.
	local tmpdir
	tmpdir=$(make_temp_dir /tmp "test_offline_mode_inetlisteningservers")
	mkdir -p "${tmpdir}/proc/1/net" "${tmpdir}/proc/1/fd"
	cat > "${tmpdir}/proc/1/net/tcp" <<'END'
  sl  local_address rem_address   st tx_queue rx_queue tr tm->when retrnsmt   uid  timeout inode
   0: 0100007F:1F90 00000000:0000 0A 00000000:00000000 00:00000000 00000000     0        0 12345 1 0000000000000000 100 0 0 10 0
END
	echo "1 (sendmail) S 0 1 1 0 -1 4194560 0 0 0 0 0 0 0 0 20 0 1 0 0" > "${tmpdir}/proc/1/stat"
	printf 'Name:\tsendmail\nUid:\t0\t0\t0\t0\n' > "${tmpdir}/proc/1/status"
	ln -s "socket:[12345]" "${tmpdir}/proc/1/fd/3"
	set_offline_chroot_dir "${tmpdir}"

	$OSCAP oval eval --results "$result" "$definition"

	set_offline_chroot_dir ""
	rm -rf "${tmpdir}"

	local item='oval_results/results/system/oval_system_characteristics/system_data/lin-sys:inetlisteningserver_item'
	assert_exists 1 "$item"
	assert_exists 1 "$item/lin-sys:local_port[text()=\"8080\"]"
	assert_exists 1 "$item/lin-sys:program_name[text()=\"sendmail\"]"
	assert_exists 1 "$item/lin-sys:pid[text()=\"1\"]"
	assert_exists 1 'oval_results/results/system/tests/test[@test_id="oval:1:tst:1"][@result="true"]'
	return 0
}

function test_probes_inetlisteningservers_offline_mode_no_procfs {
	probecheck "inetlisteningservers" || return 255

	local definition="${srcdir}/test_probes_inetlisteningservers_offline_mode.xml"
	local result="results_offline_mode_no_procfs.xml"
	[[ -f "$result" ]] && rm -f "$result"

	# The /proc of this root is empty, as in a disk image.
	local tmpdir
	tmpdir=$(make_temp_dir /tmp "test_offline_mode_inetlisteningservers")
	mkdir "${tmpdir}/proc"
	set_offline_chroot_dir "${tmpdir}"

	$OSCAP oval eval --results "$result" "$definition"

	set_offline_chroot_dir ""
	rm -rf "${tmpdir}"

	assert_exists 1 'oval_results/results/system/tests/test[@test_id="oval:1:tst:1"][@result="not applicable"]'
	assert_exists 1 'oval_results/results/system/oval_system_characteristics/collected_objects/object[@id="oval:1:obj:1"][@flag="not applicable"]'
	return 0
}

function test_probes_inetlisteningservers_offline_mode_no_proc {
	probecheck "inetlisteningservers" || return 255

	local definition="${srcdir}/test_probes_inetlisteningservers_offline_mode.xml"
	local result="results_offline_mode_no_proc.xml"
	[[ -f "$result" ]] && rm -f "$result"

	# This root has no /proc at all.
	local tmpdir
	tmpdir=$(make_temp_dir /tmp "test_offline_mode_inetlisteningservers")
	set_offline_chroot_dir "${tmpdir}"

	$OSCAP oval eval --results "$result" "$definition"

	set_offline_chroot_dir ""
	rm -rf "${tmpdir}"

	assert_exists 1 'oval_results/results/system/tests/test[@test_id="oval:1:tst:1"][@result="not applicable"]'
	assert_exists 1 'oval_results/results/system/oval_system_characteristics/collected_objects/object[@id="oval:1:obj:1"][@flag="not applicable"]'
	return 0
}

test_init

test_run "test_probes_inetlisteningservers_offline_mode" test_probes_inetlisteningservers_offline_mode
test_run "test_probes_inetlisteningservers_offline_mode_no_procfs" test_probes_inetlisteningservers_offline_mode_no_procfs
test_run "test_probes_inetlisteningservers_offline_mode_no_proc" test_probes_inetlisteningservers_offline_mode_no_proc

test_exit
