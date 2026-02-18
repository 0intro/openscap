#!/usr/bin/env bash

. $builddir/tests/test_common.sh

set -e -o pipefail

DPKGTEST="${builddir}/tests/probes/dpkginfo/root"

dpkg_query_field() {
    local name="$1"
    local field="$2"
    local root="$3"
    local status_file

    if [ -n "$root" ]; then
        status_file="${root}/var/lib/dpkg/status"
    else
        status_file="/var/lib/dpkg/status"
    fi

    awk -v pkg="$name" -v fld="$field" '
        /^Package:/ { cur = $2; next }
        cur == pkg && $0 ~ "^" fld ":" {
            sub(/^[^:]+:[[:space:]]*/, "")
            print
            exit
        }
    ' "$status_file"
}

dpkg_parse_evr() {
    local evr="$1"
    local what="$2"
    local epoch version release

    if [[ "$evr" == *:* ]]; then
        epoch="${evr%%:*}"
        evr="${evr#*:}"
    else
        epoch="0"
    fi

    if [[ "$evr" == *-* ]]; then
        version="${evr%-*}"
        release="${evr##*-}"
    else
        version="$evr"
        release=""
    fi

    case "$what" in
        epoch)   echo "$epoch" ;;
        version) echo "$version" ;;
        release) echo "$release" ;;
    esac
}

dpkg_prepare_offline() {
    set_offline_chroot_dir "$DPKGTEST"
    rm -rf "${DPKGTEST}"
    mkdir -p "${DPKGTEST}/var/lib/dpkg"
    cat > "${DPKGTEST}/var/lib/dpkg/status" <<'STATUSEOF'
Package: testpkg-alpha
Status: install ok installed
Priority: optional
Section: misc
Installed-Size: 100
Maintainer: Test <test@example.com>
Architecture: amd64
Version: 2:1.2.3-4ubuntu5
Description: Test package alpha

Package: testpkg-beta
Status: install ok installed
Priority: optional
Section: misc
Installed-Size: 200
Maintainer: Test <test@example.com>
Architecture: arm64
Version: 3.4.5-6
Description: Test package beta

Package: testpkg-removed
Status: deinstall ok config-files
Priority: optional
Section: misc
Installed-Size: 50
Maintainer: Test <test@example.com>
Architecture: amd64
Version: 0.1-1
Description: Removed package

STATUSEOF
}

dpkg_cleanup_offline() {
    rm -rf "${DPKGTEST}"
    set_offline_chroot_dir ""
}

function test_probes_dpkginfo {
    probecheck "dpkginfo" || return 255

    local ret_val=0
    local DF="test_probes_dpkginfo.xml"
    local RF="results.xml"
    local A_NAME="$1"
    local B_NAME="$2"

    rm -f $RF

    local A_ARCH A_EVR A_EPOCH A_VERSION A_RELEASE
    local B_ARCH B_EVR B_EPOCH B_VERSION B_RELEASE

    if [ -n "$OSCAP_PROBE_ROOT" ]; then
        local root="$OSCAP_PROBE_ROOT"
    else
        local root=""
    fi

    A_ARCH=$(dpkg_query_field "$A_NAME" "Architecture" "$root")
    A_EVR=$(dpkg_query_field "$A_NAME" "Version" "$root")
    A_EPOCH=$(dpkg_parse_evr "$A_EVR" epoch)
    A_VERSION=$(dpkg_parse_evr "$A_EVR" version)
    A_RELEASE=$(dpkg_parse_evr "$A_EVR" release)

    B_ARCH=$(dpkg_query_field "$B_NAME" "Architecture" "$root")
    B_EVR=$(dpkg_query_field "$B_NAME" "Version" "$root")
    B_EPOCH=$(dpkg_parse_evr "$B_EVR" epoch)
    B_VERSION=$(dpkg_parse_evr "$B_EVR" version)
    B_RELEASE=$(dpkg_parse_evr "$B_EVR" release)

    bash ${srcdir}/dpkginfo.xml.sh \
        "$A_NAME" "$A_ARCH" "$A_EPOCH" "$A_VERSION" "$A_RELEASE" "$A_EVR" \
        "$B_NAME" "$B_ARCH" "$B_EPOCH" "$B_VERSION" "$B_RELEASE" "$B_EVR" \
        > $DF

    $OSCAP oval eval --results $RF $DF

    if [ -f $RF ]; then
        verify_results "def" $DF $RF 7 && verify_results "tst" $DF $RF 7
        ret_val=$?
    else
        ret_val=1
    fi

    rm -f $RF $DF

    return $ret_val
}
