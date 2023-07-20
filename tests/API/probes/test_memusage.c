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

static const char meminfo[] =
	"MemTotal:        8000000 kB\n"
	"MemFree:         1000000 kB\n"
	"Buffers:          200000 kB\n"
	"Cached:          3000000 kB\n"
	"Active:          4000000 kB\n"
	"Inactive:        2000000 kB\n";

/*
 * Each test gives the contents of the cgroup files in bytes, NULL for a
 * missing file, and the memory oscap_sys_memusage must report in KiB.
 * The memory comes from meminfo, where the free memory is MemFree +
 * Cached + Buffers, unless a cgroup limit below MemTotal bounds the total
 * and the free memory. 9223372036854771712 is how cgroup v1 reports a
 * group without a limit.
 */
static const struct sys_test {
	const char *name;
	const char *usage;	/* cgroup v1 memory.usage_in_bytes */
	const char *limit;	/* cgroup v1 memory.limit_in_bytes */
	const char *current;	/* cgroup v2 memory.current */
	const char *max;	/* cgroup v2 memory.max */
	size_t total;		/* mu_total */
	size_t realfree;	/* mu_realfree */
} sys_tests[] = {
	{ "cgroup v1", "536870912\n", "2147483648\n", NULL, NULL, 2097152, 1572864 },
	{ "cgroup v2", NULL, NULL, "268435456\n", "1073741824\n", 1048576, 786432 },
	{ "cgroup v2 max", NULL, NULL, "268435456\n", "max\n", 8000000, 4200000 },
	{ "no cgroup", NULL, NULL, NULL, NULL, 8000000, 4200000 },
	{ "cgroup v1 unlimited", "536870912\n", "9223372036854771712\n", NULL, NULL, 8000000, 4200000 },
	{ "cgroup v1 above MemTotal", "536870912\n", "17179869184\n", NULL, NULL, 8000000, 4200000 },
	{ "cgroup v2 above MemTotal", NULL, NULL, "268435456\n", "17179869184\n", 8000000, 4200000 },
	{ "cgroup v1 usage above limit", "2147487744\n", "2147483648\n", NULL, NULL, 2097152, 0 },
};

/* Write text to the file at path in root, or remove it if text is NULL. */
static int set_file(const char *root, const char *path, const char *text)
{
	char full[PATH_MAX];
	size_t len;
	int fd, ok;

	snprintf(full, sizeof(full), "%s%s", root, path);
	if (text == NULL) {
		if (remove(full) != 0 && errno != ENOENT)
			return -1;
		return 0;
	}
	len = strlen(text);
	fd = open(full, O_WRONLY | O_CREAT | O_TRUNC, 0600);
	if (fd == -1)
		return -1;
	ok = write(fd, text, len) == (ssize_t)len;
	return (close(fd) == 0 && ok) ? 0 : -1;
}

/*
 * oscap_sys_memusage reads meminfo and the cgroup files in a root directory
 * holding them, through a descriptor of that root, as a probe in
 * PROBE_OFFLINE_CHROOT mode reads those of the scanner.
 */
static int test_sys_memusage()
{
	static const char *dirs[] = {
		"/proc", "/sys", "/sys/fs", "/sys/fs/cgroup", "/sys/fs/cgroup/memory",
	};
	char root[] = "/tmp/test_memusage.XXXXXX";
	char path[PATH_MAX];
	const struct sys_test *t;
	struct sys_memusage mu;
	size_t i;
	int rootfd;
	int ok = 0;

	if (mkdtemp(root) == NULL)
		return 0;
	for (i = 0; i < sizeof dirs / sizeof dirs[0]; i++) {
		snprintf(path, sizeof(path), "%s%s", root, dirs[i]);
		if (mkdir(path, 0700) != 0)
			goto cleanup;
	}
	if (set_file(root, MEMUSAGE_LINUX_SYS_STATUS, meminfo) != 0)
		goto cleanup;
	rootfd = open(root, O_RDONLY | O_DIRECTORY);
	if (rootfd == -1)
		goto cleanup;
	ok = 1;
	for (i = 0; i < sizeof sys_tests / sizeof sys_tests[0]; i++) {
		t = &sys_tests[i];
		if (set_file(root, MEMUSAGE_LINUX_SYS_CGROUP_USAGE, t->usage) != 0 ||
		    set_file(root, MEMUSAGE_LINUX_SYS_CGROUP_LIMIT, t->limit) != 0 ||
		    set_file(root, MEMUSAGE_LINUX_SYS_CGROUP2_CURRENT, t->current) != 0 ||
		    set_file(root, MEMUSAGE_LINUX_SYS_CGROUP2_MAX, t->max) != 0) {
			perror(t->name);
			ok = 0;
			break;
		}
		memset(&mu, 0, sizeof mu);
		if (oscap_sys_memusage(rootfd, &mu) != 0) {
			fprintf(stderr, "%s: oscap_sys_memusage failed\n", t->name);
			ok = 0;
		} else if (mu.mu_total != t->total || mu.mu_realfree != t->realfree) {
			fprintf(stderr, "%s: mu_total %zu, mu_realfree %zu, want %zu, %zu\n",
				t->name, mu.mu_total, mu.mu_realfree, t->total, t->realfree);
			ok = 0;
		}
	}
	close(rootfd);

cleanup:
	set_file(root, MEMUSAGE_LINUX_SYS_STATUS, NULL);
	set_file(root, MEMUSAGE_LINUX_SYS_CGROUP_USAGE, NULL);
	set_file(root, MEMUSAGE_LINUX_SYS_CGROUP_LIMIT, NULL);
	set_file(root, MEMUSAGE_LINUX_SYS_CGROUP2_CURRENT, NULL);
	set_file(root, MEMUSAGE_LINUX_SYS_CGROUP2_MAX, NULL);
	for (i = sizeof dirs / sizeof dirs[0]; i > 0; i--) {
		snprintf(path, sizeof(path), "%s%s", root, dirs[i - 1]);
		rmdir(path);
	}
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
	if (!test_sys_memusage()) {
		fprintf(stderr, "test_sys_memusage has failed\n");
		return 1;
	}
#endif
	return 0;
}
