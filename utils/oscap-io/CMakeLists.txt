if(ENABLE_OSCAP_UTIL_IO)
	file(GLOB UTILS_IO_SOURCES "*.c")
	add_executable(oscap-io ${UTILS_IO_SOURCES})
	target_link_libraries(oscap-io openscap)

	set(OSCAP_UTIL_DESTINATION ${CMAKE_INSTALL_BINDIR})
	# Install the 'oscap-io' utility
	install(TARGETS "oscap-io"
		DESTINATION ${OSCAP_UTIL_DESTINATION}
	)
endif()
