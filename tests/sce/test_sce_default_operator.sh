#!/usr/bin/env bash

# Test that SCE passes EQUALS, the XCCDF default, as the operator of an
# exported value without an operator attribute, and the operator of a value
# that sets one.

. "$builddir/tests/test_common.sh"

set -e -o pipefail

function test_sce_default_operator {

	local xccdf="$1"
	local xccdf_file="${srcdir}/${xccdf}"
	local result
	result=$(mktemp)

	$OSCAP xccdf eval --results "$result" "$xccdf_file"

	assert_exists 1 "//rule-result/result[text()='pass']"

	rm "$result"
	return 0
}

# Testing.
test_init

test_run "SCE default operator" test_sce_default_operator test_sce_default_operator.xccdf.xml

test_exit
