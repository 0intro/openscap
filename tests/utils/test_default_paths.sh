#!/usr/bin/env bash
. $builddir/tests/test_common.sh

set -e
set -o pipefail

prefix=$(mktemp -d -t test_default_paths.XXXXXX)
mkdir "$prefix/bin" "$prefix/lib"
cp "$builddir/utils/oscap" "$prefix/bin/"
cp -P "$builddir"/src/libopenscap.so* "$prefix/lib/"

output=$(env -u OSCAP_SCHEMA_PATH -u OSCAP_CPE_PATH LD_LIBRARY_PATH="$prefix/lib" "$prefix/bin/oscap" -V)
echo "$output" | grep -Fx "Schema files: $prefix/share/openscap/schemas"
echo "$output" | grep -Fx "Default CPE files: $prefix/share/openscap/cpe"

output=$(OSCAP_SCHEMA_PATH=/schemas OSCAP_CPE_PATH=/cpe LD_LIBRARY_PATH="$prefix/lib" "$prefix/bin/oscap" -V)
echo "$output" | grep -Fx "Schema files: /schemas"
echo "$output" | grep -Fx "Default CPE files: /cpe"

rm -rf "$prefix"
