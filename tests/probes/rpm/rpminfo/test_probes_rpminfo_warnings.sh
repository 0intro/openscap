#!/usr/bin/env bash

. "$builddir/tests/test_common.sh"

set -e -o pipefail

function test_probes_rpminfo_warnings {
    probecheck "rpminfo" || return 255
    require "rpm" || return 255

    local ret_val=0
    local definition="${srcdir}/test_probes_rpminfo_warnings.xml"
    local result stderr home
    result=$(mktemp results.XXXXXXX.xml)
    stderr=$(mktemp stderr.XXXXXXX)

    # librpm warns when the database backend differs from %_db_backend,
    # as for a bdb_ro database read with the sqlite backend.
    home=$(mktemp -d "$PWD/home.XXXXXXX")
    echo '%_db_backend bogus' > "$home/.rpmmacros"
    HOME="$home" rpm -q rpm 2>&1 >/dev/null | grep '^warning: ' >/dev/null || return 255

    HOME="$home" $OSCAP oval eval --results "$result" "$definition" 2> "$stderr"

    assert_exists 1 '/oval_results/results/system/tests/test[@test_id="oval:1:tst:1"][@result="true"]'
    if grep -E '^(warning: |W: |E: )' "$stderr"; then
        echo "The RPM warning reached stderr." >&2
        ret_val=1
    fi

    rm -rf "$home" "$result" "$stderr"

    return $ret_val
}

test_init

test_run "rpminfo probe test (warnings)" test_probes_rpminfo_warnings

test_exit
