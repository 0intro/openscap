// SPDX-License-Identifier: LGPL-2.1-or-later

#ifdef HAVE_CONFIG_H
#include <config.h>
#endif

#include <fcntl.h>
#include <stdio.h>
#include <unistd.h>

#include <xccdf_session.h>

/*
 * Evaluate the XCCDF document of the first argument and write what
 * xccdf_session_print_syschar prints on standard output to the file of
 * the second. Exit 2 when xccdf_session_print_syschar reports a failure,
 * and 3 when it reports none but its output was lost.
 */
int main(int argc, char *argv[])
{
	struct xccdf_session *session;
	int fd, saved, ret, flushed;

	if (argc != 3) {
		fprintf(stderr, "usage: %s xccdf out\n", argv[0]);
		return 1;
	}
	session = xccdf_session_new(argv[1]);
	if (session == NULL || xccdf_session_load(session) != 0 ||
	    xccdf_session_evaluate(session) != 0) {
		fprintf(stderr, "cannot evaluate %s\n", argv[1]);
		xccdf_session_free(session);
		return 1;
	}
	fd = open(argv[2], O_WRONLY | O_CREAT | O_TRUNC, 0600);
	if (fd < 0) {
		perror(argv[2]);
		xccdf_session_free(session);
		return 1;
	}
	fflush(stdout);
	saved = dup(STDOUT_FILENO);
	if (saved < 0 || dup2(fd, STDOUT_FILENO) < 0) {
		perror("dup");
		xccdf_session_free(session);
		return 1;
	}
	close(fd);
	ret = xccdf_session_print_syschar(session);
	flushed = fflush(stdout);
	if (dup2(saved, STDOUT_FILENO) < 0) {
		perror("dup2");
		xccdf_session_free(session);
		return 1;
	}
	close(saved);
	xccdf_session_free(session);
	if (ret != 0) {
		fprintf(stderr, "xccdf_session_print_syschar returned %d\n", ret);
		return 2;
	}
	if (flushed != 0) {
		fprintf(stderr, "xccdf_session_print_syschar returned 0, and its output was lost\n");
		return 3;
	}
	return 0;
}
