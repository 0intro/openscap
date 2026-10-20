#!/usr/bin/env bash

. "$builddir/tests/test_common.sh"

if [[ -n "${CUSTOM_OSCAP+x}" ]] ; then
	exit 255
fi

set -e -o pipefail

name=$(basename "$0" .sh)
result=$(mktemp -t "${name}.out.XXXXXX")
echo "Result file = $result"

# One document per OVAL file of the session.
bash "$RUN_WRAPPER" "./${name}" "$srcdir/test_single_rule.xccdf.xml" "$result"
[[ "$(grep -c '^<?xml' "$result")" -eq 1 ]]
assert_exists 1 '/oval_system_characteristics'
assert_exists 1 '/oval_system_characteristics/collected_objects/object[@id="oval:x:obj:1"][@flag="complete"]'
assert_exists 1 '/oval_system_characteristics/system_data/ind-sys:variable_item[ind-sys:value="100"]'

bash "$RUN_WRAPPER" "./${name}" "$srcdir/test_multiple_oval_files_with_same_basename.xccdf.xml" "$result"
[[ "$(grep -c '^<?xml' "$result")" -eq 2 ]]

# A session without OVAL prints nothing.
bash "$RUN_WRAPPER" "./${name}" "$srcdir/test_xccdf_results_arf_no_oval.xccdf.xml" "$result"
[[ ! -s "$result" ]]

# A document that cannot be written is a failure the caller sees.
ret=0
bash "$RUN_WRAPPER" "./${name}" "$srcdir/test_single_rule.xccdf.xml" /dev/full || ret=$?
[[ $ret -eq 2 ]]

rm -f "$result"
