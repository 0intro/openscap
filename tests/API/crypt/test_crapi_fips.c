// SPDX-License-Identifier: LGPL-2.1-or-later

#ifdef HAVE_CONFIG_H
#include <config.h>
#endif

#include <fcntl.h>
#include <gcrypt.h>
#include <linux/capability.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <sys/mman.h>
#include <sys/resource.h>
#include <sys/syscall.h>
#include <unistd.h>

#include <crapi/crapi.h>
#include <crapi/digest.h>

enum {
	Skip = 255,		/* the exit status of a test that cannot run */
	Sha256size = 32,
};

/*
 * drop_ipc_lock clears CAP_IPC_LOCK from the effective, permitted and
 * inheritable sets, so that RLIMIT_MEMLOCK bounds what mlock locks.
 */
static int drop_ipc_lock(void)
{
	struct __user_cap_header_struct hdr = { _LINUX_CAPABILITY_VERSION_3, 0 };
	struct __user_cap_data_struct data[_LINUX_CAPABILITY_U32S_3];
	const uint32_t bit = 1U << CAP_IPC_LOCK;

	if (syscall(SYS_capget, &hdr, data) != 0)
		return -1;
	data[0].effective &= ~bit;
	data[0].permitted &= ~bit;
	data[0].inheritable &= ~bit;
	return syscall(SYS_capset, &hdr, data);
}

/* can_lock reports whether mlock of one page still succeeds. */
static int can_lock(void)
{
	long size = sysconf(_SC_PAGESIZE);
	void *p;
	int ok;

	p = mmap(NULL, size, PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
	if (p == MAP_FAILED)
		return 1;
	ok = mlock(p, size) == 0;
	munmap(p, size);
	return ok;
}

static void tohex(const uint8_t *b, size_t n, char *s)
{
	static const char digits[] = "0123456789abcdef";
	size_t i;

	for (i = 0; i < n; i++) {
		s[2*i] = digits[b[i] >> 4];
		s[2*i + 1] = digits[b[i] & 0xf];
	}
	s[2*n] = '\0';
}

/*
 * Hash the file of the first argument with crapi, libgcrypt in FIPS mode,
 * in a process that can lock no memory, like a scanner without CAP_IPC_LOCK
 * or under a seccomp filter that denies mlock, and compare the SHA-256 with
 * the second argument. Exit 255 when the system cannot set up that
 * process or libgcrypt cannot run in FIPS mode here.
 */
int main(int argc, char *argv[])
{
	const struct rlimit nolock = { 0, 0 };
	uint8_t sum[Sha256size];
	char hex[2*Sha256size + 1];
	size_t len = sizeof sum;
	int fd;

	if (argc != 3) {
		fprintf(stderr, "usage: %s file sha256\n", argv[0]);
		return 2;
	}
	if (drop_ipc_lock() != 0 || setrlimit(RLIMIT_MEMLOCK, &nolock) != 0) {
		perror("drop CAP_IPC_LOCK and RLIMIT_MEMLOCK");
		return Skip;
	}
	if (can_lock()) {
		fprintf(stderr, "%s: mlock still succeeds\n", argv[0]);
		return Skip;
	}
	/* libgcrypt takes this before gcry_check_version, which crapi_init calls. */
	gcry_control(GCRYCTL_FORCE_FIPS_MODE, 0);
	if (crapi_init(NULL) != 0) {
		fprintf(stderr, "%s: crapi_init failed\n", argv[0]);
		return 1;
	}
	if (!gcry_fips_mode_active() || !gcry_control(GCRYCTL_OPERATIONAL_P, 0)) {
		fprintf(stderr, "%s: libgcrypt is not in operational FIPS mode\n", argv[0]);
		return Skip;
	}
	fd = open(argv[1], O_RDONLY);
	if (fd == -1) {
		perror(argv[1]);
		return 2;
	}
	if (crapi_digest_fd(fd, CRAPI_DIGEST_SHA256, sum, &len) != 0 || len != sizeof sum) {
		fprintf(stderr, "%s: crapi_digest_fd failed\n", argv[0]);
		return 1;
	}
	close(fd);
	tohex(sum, len, hex);
	if (strcmp(hex, argv[2]) != 0) {
		fprintf(stderr, "%s: sha256 %s, want %s\n", argv[0], hex, argv[2]);
		return 1;
	}
	return 0;
}
