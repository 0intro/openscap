#!/bin/sh
#
# This is an SCE script used to test the operators SCE passes. UNSET is a
# value without an operator attribute, SET a value with the operator
# "not equal".

echo "UNSET=$XCCDF_OPERATOR_UNSET SET=$XCCDF_OPERATOR_SET"
if [ "$XCCDF_OPERATOR_UNSET" = EQUALS ] && [ "$XCCDF_OPERATOR_SET" = NOT_EQUAL ]; then
	exit "$XCCDF_RESULT_PASS"
fi
exit "$XCCDF_RESULT_FAIL"
