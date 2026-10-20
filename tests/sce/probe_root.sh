#!/bin/sh
#
# This is an SCE script used to test SCE in OSCAP_PROBE_ROOT. It passes when
# /etc/marker holds the word the test writes in the root. It runs shell
# builtins alone: the root holds /bin/sh and its libraries.

read -r word </etc/marker
if [ "$word" = probe_root ]; then
	exit "$XCCDF_RESULT_PASS"
fi
exit "$XCCDF_RESULT_FAIL"
