#!/usr/bin/env bash

. "$builddir/tests/test_common.sh"

if [[ -n "${CUSTOM_OSCAP+x}" ]] ; then
	exit 255
fi

set -e -o pipefail

name=$(basename "$0" .sh)
log=$(mktemp -t "${name}.log.XXXXXX")
echo "Log file = $log"

bash "$RUN_WRAPPER" "./${name}" "$srcdir/test_single_rule.xccdf.xml" "$log"

rm -f "$log"
