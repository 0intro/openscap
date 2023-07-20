// SPDX-License-Identifier: LGPL-2.1-or-later

#ifdef HAVE_CONFIG_H
#include <config.h>
#endif

#include <stdio.h>
#include "memusage.h"

#if defined(OS_LINUX)
/* oscap_sys_memusage reads the files that test_sys_memusage writes. */
#undef MEMUSAGE_LINUX_SYS_STATUS
#undef MEMUSAGE_LINUX_SYS_CGROUP_USAGE
#undef MEMUSAGE_LINUX_SYS_CGROUP_LIMIT
#undef MEMUSAGE_LINUX_SYS_CGROUP2_CURRENT
#undef MEMUSAGE_LINUX_SYS_CGROUP2_MAX
#define MEMUSAGE_LINUX_SYS_STATUS "test_memusage.meminfo"
#define MEMUSAGE_LINUX_SYS_CGROUP_USAGE "test_memusage.memory.usage_in_bytes"
#define MEMUSAGE_LINUX_SYS_CGROUP_LIMIT "test_memusage.memory.limit_in_bytes"
#define MEMUSAGE_LINUX_SYS_CGROUP2_CURRENT "test_memusage.memory.current"
#define MEMUSAGE_LINUX_SYS_CGROUP2_MAX "test_memusage.memory.max"
#endif

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

/* Write text to path, or remove path if text is NULL. */
static int set_file(const char *path, const char *text)
{
	FILE *f;

	if (text == NULL) {
		if (remove(path) != 0 && errno != ENOENT)
			return -1;
		return 0;
	}
	f = fopen(path, "w");
	if (f == NULL)
		return -1;
	if (fputs(text, f) == EOF) {
		fclose(f);
		return -1;
	}
	return fclose(f) == 0 ? 0 : -1;
}

static int test_sys_memusage()
{
	const struct sys_test *t;
	struct sys_memusage mu;
	size_t i;
	int ok = 1;

	if (set_file(MEMUSAGE_LINUX_SYS_STATUS, meminfo) != 0) {
		perror(MEMUSAGE_LINUX_SYS_STATUS);
		return 0;
	}
	for (i = 0; i < sizeof sys_tests / sizeof sys_tests[0]; i++) {
		t = &sys_tests[i];
		if (set_file(MEMUSAGE_LINUX_SYS_CGROUP_USAGE, t->usage) != 0 ||
		    set_file(MEMUSAGE_LINUX_SYS_CGROUP_LIMIT, t->limit) != 0 ||
		    set_file(MEMUSAGE_LINUX_SYS_CGROUP2_CURRENT, t->current) != 0 ||
		    set_file(MEMUSAGE_LINUX_SYS_CGROUP2_MAX, t->max) != 0) {
			perror(t->name);
			ok = 0;
			break;
		}
		memset(&mu, 0, sizeof mu);
		if (oscap_sys_memusage(&mu) != 0) {
			fprintf(stderr, "%s: oscap_sys_memusage failed\n", t->name);
			ok = 0;
		} else if (mu.mu_total != t->total || mu.mu_realfree != t->realfree) {
			fprintf(stderr, "%s: mu_total %zu, mu_realfree %zu, want %zu, %zu\n",
				t->name, mu.mu_total, mu.mu_realfree, t->total, t->realfree);
			ok = 0;
		}
	}
	set_file(MEMUSAGE_LINUX_SYS_STATUS, NULL);
	set_file(MEMUSAGE_LINUX_SYS_CGROUP_USAGE, NULL);
	set_file(MEMUSAGE_LINUX_SYS_CGROUP_LIMIT, NULL);
	set_file(MEMUSAGE_LINUX_SYS_CGROUP2_CURRENT, NULL);
	set_file(MEMUSAGE_LINUX_SYS_CGROUP2_MAX, NULL);
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
	if (!test_sys_memusage()) {
		fprintf(stderr, "test_sys_memusage has failed\n");
		return 1;
	}
#endif
	return 0;
}
