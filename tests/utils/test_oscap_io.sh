#!/usr/bin/env bash

. "$builddir/tests/test_common.sh"

if [[ -n "${CUSTOM_OSCAP+x}" ]] ; then
	exit 255
fi

set -e -o pipefail

name=$(basename "$0" .sh)
oscap_io="bash $RUN_WRAPPER $builddir/utils/oscap-io/oscap-io"
xccdf="$srcdir/$name.xccdf.xml"
profile="xccdf_org.open-scap_profile_oscap_io"
pass="xccdf_org.open-scap_rule_pass"
fail="xccdf_org.open-scap_rule_fail"
unknown="xccdf_org.open-scap_rule_unknown"
stdout=$(mktemp -t "$name.out.XXXXXX")
stderr=$(mktemp -t "$name.err.XXXXXX")
result=$(mktemp -t "$name.xml.XXXXXX")
echo "Stdout file = $stdout"
echo "Result file = $result"

# Each request gets a line with the rule and its xccdf_test_result_type_t:
# 1 is pass, 2 fail, and 3 error, the answer to a request that fails.
$oscap_io "$xccdf" >"$stdout" <<END
$profile $pass
$profile $fail
$profile $unknown
xccdf_org.open-scap_profile_unknown $pass
$profile $pass
END
diff - "$stdout" <<END
$pass 1
$fail 2
$unknown 3
$pass 3
$pass 1
END

# oscap-io loads the document at the first request and exits 1 if that fails.
ret=0
echo "$profile $pass" | $oscap_io "$srcdir/missing.xml" >"$stdout" || ret=$?
[[ $ret -eq 1 ]]
[[ ! -s "$stdout" ]]

# With -syschar, one document follows every answer, a failed one included,
# so that a reader stays in step.
printf '%s\n' "$profile $unknown" "$profile $pass" | $oscap_io -syschar "$xccdf" >"$stdout"
grep -E "^(xccdf_org|<\?xml)" "$stdout" | sed 's/^<?xml.*/xml/' | diff - <(printf '%s\n' "$unknown 3" xml "$pass 1" xml)
awk '/^<\?xml/ { n++ } n == 2' "$stdout" >"$result"
assert_exists 1 '/oval_system_characteristics/collected_objects/object[@id="oval:x:obj:1"]'
assert_exists 1 '/oval_system_characteristics/system_data/ind-sys:variable_item[ind-sys:value="100"]'

# -v writes its diagnostics to standard error, and options match exactly.
echo "$profile $pass" | $oscap_io -v "$xccdf" >"$stdout" 2>"$stderr"
diff - "$stdout" <<<"$pass 1"
grep -q "evaluate profile" "$stderr"
ret=0
$oscap_io -syscharx "$xccdf" </dev/null >"$stdout" 2>"$stderr" || ret=$?
[[ $ret -eq 1 ]]
grep -q "^usage:" "$stderr"

rm -f "$stdout" "$stderr" "$result"
