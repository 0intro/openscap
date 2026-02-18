if(OPENSCAP_PROBE_LINUX_DPKGINFO)
	add_oscap_test("test_probes_dpkginfo.sh")
	add_oscap_test("test_probes_dpkginfo_offline.sh")
endif()
