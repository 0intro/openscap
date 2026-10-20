#!/usr/bin/env bash

# Test that an SCE script reads end of file on its standard input while the
# standard input of oscap stays open.

. "$builddir/tests/test_common.sh"

set -e -o pipefail

function test_sce_stdin {

	local xccdf="$1"
	local xccdf_file="${srcdir}/${xccdf}"
	local dir
	dir=$(mktemp -d)
	local result="$dir/results.xml"

	# The writer holds the FIFO open while it sleeps, so a read of the FIFO
	# waits until the writer exits.
	mkfifo "$dir/fifo"
	sleep 60 >"$dir/fifo" &
	local writer=$!

	local ret=0
	# OSCAP holds a command and its arguments.
	# shellcheck disable=SC2086
	timeout 15 $OSCAP xccdf eval --results "$result" "$xccdf_file" <"$dir/fifo" || ret=$?
	kill "$writer"
	[[ $ret -ne 124 ]] || die "oscap timed out: the SCE script read the standard input of oscap"
	[[ $ret -eq 0 ]]

	assert_exists 1 "//rule-result/result[text()='pass']"

	rm -r "$dir"
	return 0
}

# Testing.
test_init

test_run "SCE standard input" test_sce_stdin test_sce_stdin.xccdf.xml

test_exit
