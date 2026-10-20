#!/bin/sh -
#
# This is an SCE script used to test, in OSCAP_PROBE_ROOT, an interpreter
# line whose argument "-" ends the options of sh.

read -r word </etc/marker
if [ "$word" = probe_root ]; then
	exit "$XCCDF_RESULT_PASS"
fi
exit "$XCCDF_RESULT_FAIL"
