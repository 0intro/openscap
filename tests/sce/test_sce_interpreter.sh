#!/usr/bin/env bash

# Test that SCE runs a script it cannot execute, as on a noexec mount, and
# an executable script without an interpreter line, through the interpreter
# named on the first line of the script, or /bin/sh for a script without
# that line.

. "$builddir/tests/test_common.sh"

set -e -o pipefail

function test_sce_interpreter {
	local xccdf="$1"

	local dir
	dir=$(mktemp -d)
	local result="$dir/results.xml"

	cp "$srcdir/$xccdf" "$srcdir"/interpreter_*.sh "$dir"
	chmod 600 "$dir"/interpreter_*.sh
	chmod 700 "$dir/interpreter_exec_none.sh"

	# SCE runs the interpreters itself. A failing oscap-run-sce-script
	# first in PATH makes the test fail wherever SCE runs that helper.
	mkdir "$dir/bin"
	printf '#!/bin/sh\nexit 1\n' >"$dir/bin/oscap-run-sce-script"
	chmod 700 "$dir/bin/oscap-run-sce-script"
	PATH="$dir/bin:$PATH" $OSCAP xccdf eval --results "$result" "$dir/$xccdf"

	assert_exists 4 "//rule-result/result[text()='pass']"

	rm -r "$dir"
	return 0
}

# Testing.
test_init

test_run "SCE interpreter" test_sce_interpreter test_sce_interpreter.xccdf.xml

test_exit
