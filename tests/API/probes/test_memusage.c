// SPDX-License-Identifier: LGPL-2.1-or-later

#ifdef HAVE_CONFIG_H
#include <config.h>
#endif

#include <stdio.h>
#include <fcntl.h>
#include <limits.h>
#include <sys/stat.h>
#include <unistd.h>
#include "memusage.h"
#define OSCAP_TEST_READ_COMMON_SIZET
#include "memusage.c"

static int test_basic()
{
	size_t size;
	char *strval = strdup("17 kB\n");
	int ret = read_common_sizet(&size, strval);
	free(strval);
	return (size == 17 && ret == 0);
}

static int test_no_unit()
{
	size_t size;
	char *strval = strdup("42");
	int ret = read_common_sizet(&size, strval);
	free(strval);
	return (ret == -1);
}

static int test_invalid_number()
{
	size_t size = 0;
	char *strval = strdup("www kB\n");
	int ret = read_common_sizet(&size, strval);
	free(strval);
	return (ret == -1);
}

static int test_errno()
{
	size_t size;
	char *strval = strdup("17 kB\n");

	/* Test that setting errno outside of the read_common_sizet function
	 * doesn't influence the function and doesn't make the function fail.
	 */
	errno = EINVAL;

	int ret = read_common_sizet(&size, strval);
	free(strval);
	return (ret != -1);
}

#if defined(OS_LINUX)
static int write_file(const char *root, const char *name, const char *text)
{
	char path[PATH_MAX];
	size_t len = strlen(text);
	int fd, ok;

	snprintf(path, sizeof(path), "%s/%s", root, name);
	fd = open(path, O_WRONLY | O_CREAT | O_EXCL, 0600);
	if (fd == -1)
		return 0;
	ok = write(fd, text, len) == (ssize_t)len;
	return close(fd) == 0 && ok;
}

/*
 * Read the memory usage from a root directory holding a /proc with known
 * values, which differ from those of this system.
 */
static int test_rootfd()
{
	char root[] = "/tmp/test_memusage.XXXXXX";
	char path[PATH_MAX];
	struct sys_memusage mu_sys;
	struct proc_memusage mu_proc;
	int rootfd;
	int ok = 0;

	if (mkdtemp(root) == NULL)
		return 0;
	snprintf(path, sizeof(path), "%s/proc", root);
	mkdir(path, 0700);
	snprintf(path, sizeof(path), "%s/proc/self", root);
	mkdir(path, 0700);
	if (!write_file(root, "proc/meminfo",
	    "MemTotal: 2048 kB\nMemFree: 1024 kB\nBuffers: 1 kB\n"
	    "Cached: 2 kB\nActive: 3 kB\nInactive: 4 kB\n"))
		goto cleanup;
	if (!write_file(root, "proc/self/status",
	    "VmHWM: 5 kB\nVmRSS: 6 kB\nVmData: 7 kB\nVmStk: 8 kB\n"
	    "VmExe: 9 kB\nVmLib: 10 kB\nVmLck: 11 kB\n"))
		goto cleanup;

	rootfd = open(root, O_RDONLY | O_DIRECTORY);
	if (rootfd == -1)
		goto cleanup;
	ok = oscap_sys_memusage(rootfd, &mu_sys) == 0 &&
	    mu_sys.mu_total == 2048 && mu_sys.mu_realfree == 1027 &&
	    oscap_proc_memusage(rootfd, &mu_proc) == 0 &&
	    mu_proc.mu_rss == 6 && mu_proc.mu_hwm == 5;
	close(rootfd);

cleanup:
	snprintf(path, sizeof(path), "%s/proc/self/status", root);
	unlink(path);
	snprintf(path, sizeof(path), "%s/proc/meminfo", root);
	unlink(path);
	snprintf(path, sizeof(path), "%s/proc/self", root);
	rmdir(path);
	snprintf(path, sizeof(path), "%s/proc", root);
	rmdir(path);
	rmdir(root);
	return ok;
}
#endif

int main(int argc, char *argv[])
{
	if (!test_basic()) {
		fprintf(stderr, "test_basic has failed\n");
		return 1;
	}
	if (!test_no_unit()) {
		fprintf(stderr, "test_no_unit has failed\n");
		return 1;
	}
	if (!test_invalid_number()) {
		fprintf(stderr, "test_invalid_number has failed\n");
		return 1;
	}
	if (!test_errno()) {
		fprintf(stderr, "test_errno has failed\n");
		return 1;
	}
#if defined(OS_LINUX)
	if (!test_rootfd()) {
		fprintf(stderr, "test_rootfd has failed\n");
		return 1;
	}
#endif
	return 0;
}
