#!/usr/bin/env bash

# Copyright 2019 Red Hat Inc., Durham, North Carolina.
# All Rights Reserved.
#
# OpenSCAP Probes Test Suite.
# Tests the rpmverifypackage probe.
#
# Authors:
#      Jan Černý <jcerny@redhat.com>
#      Evgenii Kolesnikov <ekolesni@redhat.com>

. $builddir/tests/test_common.sh
. $srcdir/rpmverifypackage_common.sh
. $srcdir/../rpm_common.sh

set -e -o pipefail
set -x

# foo-requires requires foo. The probe must check it against the database
# of the root, where foo is installed until the test erases it.
function test_probes_rpmverifypackage_offline_deps {
    probecheck "rpmverifypackage" || return 255
    require "rpmbuild" || return 255

    local pkg="${RPMBUILD}/RPMS/noarch/foo-requires-1.0-1.noarch.rpm"
    local DF="test_probes_rpmverifypackage_offline_deps.xml"
    local RF="${builddir}/tests/probes/rpm/rpmverifypackage/results_deps.xml"
    local item='/oval_results/results/system/oval_system_characteristics/system_data/lin-sys:rpmverifypackage_item'

    if [[ ! -f "$pkg" ]]; then
        rpmbuild --define "_buildhost testhost" --define "_tmppath ${RPMTEST}/tmp" --define "_topdir ${RPMBUILD}" -ba "${srcdir}/foo-requires.spec"
    fi
    rpm -i --nosignature "$pkg" --badreloc --relocate="/etc=${RPMTEST}/etc/" --dbpath="${RPMTEST}${RPMDB_PATH}"

    bash "${srcdir}/rpmverifypackage.xml.sh" foo-requires "(none)" noarch 1.0 1 > "$DF"
    result=$RF

    $OSCAP oval eval --results "$RF" "$DF"
    assert_exists 1 "$item"'/lin-sys:dependency_check_passed[text()="true"]'

    rpm -e --nodeps --justdb --dbpath="${RPMTEST}${RPMDB_PATH}" foo
    $OSCAP oval eval --results "$RF" "$DF"
    assert_exists 1 "$item"'/lin-sys:dependency_check_passed[text()="false"]'

    rm -f "$RF" "$DF"
}

test_init

rpm_prepare_offline

test_run "rpmverifypackage probe test" test_probes_rpmverifypackage "foobar"
test_run "rpmverifypackage offline dependency check" test_probes_rpmverifypackage_offline_deps

rpm_cleanup_offline

test_exit