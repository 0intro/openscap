#!/usr/bin/env bash

# Test that crapi hashes in libgcrypt's FIPS mode in a process that can lock
# no memory. test_crapi_fips exits 255 when the system cannot provide that
# setting, and so does this test, so that ctest reports it skipped.

. "$builddir/tests/test_common.sh"

set -e -o pipefail

[ -z "${CUSTOM_OSCAP+x}" ] || exit 255

dir=$(make_temp_dir /tmp tmp)
trap 'rm -rf "$dir"' EXIT

dd if=/dev/urandom of="$dir/file" bs=4k count=1 2>/dev/null
sum=$(sha256sum "$dir/file" | cut -d ' ' -f 1)

ret=0
./test_crapi_fips "$dir/file" "$sum" 2>"$dir/err" || ret=$?
cat "$dir/err" >&2
if [ "$ret" -ne 0 ]; then
	exit "$ret"
fi
if grep -q 'secure memory' "$dir/err"; then
	echo "libgcrypt reported a secure memory failure" >&2
	exit 1
fi
