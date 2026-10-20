#!/usr/bin/env bash
#
# This is an SCE script used to test an interpreter line with an argument.
# It passes when bash runs it.

[[ -n $BASH_VERSION ]] && exit "$XCCDF_RESULT_PASS"
exit "$XCCDF_RESULT_FAIL"
