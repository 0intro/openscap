if(ENABLE_PROBES_LINUX)
	add_oscap_test("test_probes_dpkginfo_virtual_packages.sh" LABELS linux linux_only)
endif()
