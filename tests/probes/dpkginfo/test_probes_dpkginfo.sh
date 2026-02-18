#!/usr/bin/env bash

. $builddir/tests/test_common.sh
. $srcdir/dpkginfo_common.sh

set -e -o pipefail

unset OSCAP_PROBE_ROOT

[ -f /var/lib/dpkg/status ] || exit 255

A_NAME=$(awk '/^Package:/{print $2}' /var/lib/dpkg/status | sort -u | sed -n '1p')
B_NAME=$(awk '/^Package:/{print $2}' /var/lib/dpkg/status | sort -u | sed -n '2p')

[ -n "$A_NAME" ] || exit 255
[ -n "$B_NAME" ] || exit 255

test_init

test_run "dpkginfo probe test" test_probes_dpkginfo "$A_NAME" "$B_NAME"

test_exit
