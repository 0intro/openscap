#!/usr/bin/env bash
. $builddir/tests/test_common.sh

set -e
set -o pipefail

# Stage oscap and libopenscap under a temporary root, in the configured
# library directory, and check that the default paths follow the library.
root=$(cd "$(mktemp -d -t test_default_paths.XXXXXX)" && pwd -P)
trap 'rm -rf "$root"' EXIT
libdir=$root$CMAKE_INSTALL_FULL_LIBDIR
datadir=$root$CMAKE_INSTALL_FULL_DATADIR
mkdir -p "$root/bin" "$libdir"
cp "$builddir/utils/oscap" "$root/bin/"
cp -P "$builddir"/src/libopenscap.so* "$libdir/"
export LD_LIBRARY_PATH=$libdir

# A DT_RPATH to the build tree outranks LD_LIBRARY_PATH.
ldd "$root/bin/oscap" | grep -Fq "$libdir/libopenscap.so" || exit 255

output=$(env -u OSCAP_SCHEMA_PATH -u OSCAP_CPE_PATH "$root/bin/oscap" -V)
echo "$output" | grep -Fx "Schema files: $datadir/openscap/schemas"
echo "$output" | grep -Fx "Default CPE files: $datadir/openscap/cpe"

output=$(OSCAP_SCHEMA_PATH=/schemas OSCAP_CPE_PATH=/cpe "$root/bin/oscap" -V)
echo "$output" | grep -Fx "Schema files: /schemas"
echo "$output" | grep -Fx "Default CPE files: /cpe"
