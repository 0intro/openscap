#!/bin/sh
#
# This is an SCE script used to test the standard input SCE gives scripts. It
# reads its standard input to the end.

cat >/dev/null
exit "$XCCDF_RESULT_PASS"
