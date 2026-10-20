#!/usr/bin/env bash

. "$builddir/tests/test_common.sh"

set -e -o pipefail

# The systemd probes connect to the system bus at DBUS_SYSTEM_BUS_ADDRESS,
# which they set to the standard socket when it is unset. The probes run
# in the oscap process, so the environmentvariable probe reads the
# address they used.
function test_probes_systemdunitproperty_dbus_address {
	probecheck "systemdunitproperty" || return 255
	probecheck "environmentvariable" || return 255

	local address="$1"
	local definition="${srcdir}/test_probes_systemdunitproperty_dbus_address.xml"
	local result
	result=$(mktemp results.XXXXXXX.xml)

	if [[ -n "$address" ]]; then
		DBUS_SYSTEM_BUS_ADDRESS="$address" $OSCAP oval eval --results "$result" "$definition"
	else
		unset DBUS_SYSTEM_BUS_ADDRESS
		address="unix:path=/run/dbus/system_bus_socket"
		$OSCAP oval eval --results "$result" "$definition"
	fi

	local item='oval_results/results/system/oval_system_characteristics/system_data/ind-sys:environmentvariable_item'
	assert_exists 1 "$item"
	assert_exists 1 "$item/ind-sys:value[text()=\"$address\"]"
	rm -f "$result"
	return 0
}

test_init

test_run "test_probes_systemdunitproperty_dbus_address (unset)" test_probes_systemdunitproperty_dbus_address ""
test_run "test_probes_systemdunitproperty_dbus_address (set)" test_probes_systemdunitproperty_dbus_address "unix:path=/tmp/test-socket"

test_exit
