if(ENABLE_PROBES_LINUX)
	add_oscap_test("test_probes_inetlisteningservers_offline_mode.sh" LABELS linux linux_only)
endif()
