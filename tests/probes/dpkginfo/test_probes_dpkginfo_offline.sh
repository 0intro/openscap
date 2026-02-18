#!/usr/bin/env bash

. $builddir/tests/test_common.sh
. $srcdir/dpkginfo_common.sh

set -e -o pipefail

test_init

dpkg_prepare_offline

test_run "dpkginfo probe test (offline)" test_probes_dpkginfo testpkg-alpha testpkg-beta

dpkg_cleanup_offline

test_exit
