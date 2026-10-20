#!/usr/bin/awk -f
#
# This is an SCE script used to test an interpreter for which SCE knows no
# option that runs program text, which it refuses in OSCAP_PROBE_ROOT.

BEGIN { exit 101 }
