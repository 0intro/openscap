// SPDX-License-Identifier: LGPL-2.1-or-later

#ifdef HAVE_CONFIG_H
#include <config.h>
#endif

#include <stdbool.h>
#include <stdio.h>
#include <string.h>

#include <oscap_debug.h>
#include <xccdf_benchmark.h>
#include <xccdf_session.h>

/* Results of the rules of test_single_rule.xccdf.xml without a profile. */
static const struct {
	const char *rule;
	xccdf_test_result_type_t result;
} want[] = {
	{ "xccdf_com.example.www_rule_test-pass", XCCDF_RESULT_PASS },
	{ "xccdf_com.example.www_rule_test-fail", XCCDF_RESULT_FAIL },
};

/* Count the probe threads started so far, which the DEVEL log records. */
static int probe_starts(const char *log)
{
	char line[BUFSIZ];
	FILE *f;
	int n;

	f = fopen(log, "r");
	if (f == NULL) {
		perror(log);
		return -1;
	}
	n = 0;
	while (fgets(line, sizeof line, f) != NULL) {
		if (strstr(line, "probe_common_main started") != NULL)
			n++;
	}
	fclose(f);
	return n;
}

/* Evaluate the session and check its rule results. */
static int evaluate(struct xccdf_session *session)
{
	struct xccdf_rule_result_iterator *it;
	struct xccdf_rule_result *rr;
	xccdf_test_result_type_t result;
	const char *rule;
	size_t i, found;
	int ok;

	if (xccdf_session_evaluate(session) != 0) {
		fprintf(stderr, "xccdf_session_evaluate failed\n");
		return 0;
	}
	ok = 1;
	found = 0;
	it = xccdf_session_get_rule_results(session);
	while (xccdf_rule_result_iterator_has_more(it)) {
		rr = xccdf_rule_result_iterator_next(it);
		rule = xccdf_rule_result_get_idref(rr);
		result = xccdf_rule_result_get_result(rr);
		for (i = 0; i < sizeof want / sizeof want[0]; i++) {
			if (strcmp(rule, want[i].rule) != 0)
				continue;
			found++;
			if (result != want[i].result) {
				fprintf(stderr, "%s: %s, want %s\n", rule,
					xccdf_test_result_type_get_text(result),
					xccdf_test_result_type_get_text(want[i].result));
				ok = 0;
			}
		}
	}
	xccdf_rule_result_iterator_free(it);
	if (found != sizeof want / sizeof want[0]) {
		fprintf(stderr, "%zu rule results, want %zu\n",
			found, sizeof want / sizeof want[0]);
		ok = 0;
	}
	return ok;
}

/*
 * Evaluate the session three times, with xccdf_session_result_reset
 * between evaluations. The reset keeps the probe threads, so the threads
 * of the first evaluation serve the other two.
 */
int main(int argc, char *argv[])
{
	struct xccdf_session *session;
	int first, third, i, ok;

	if (argc != 3) {
		fprintf(stderr, "usage: %s xccdf log\n", argv[0]);
		return 1;
	}
	if (!oscap_set_verbose("DEVEL", argv[2])) {
		fprintf(stderr, "cannot log to %s\n", argv[2]);
		return 1;
	}
	session = xccdf_session_new(argv[1]);
	if (session == NULL || xccdf_session_load(session) != 0) {
		fprintf(stderr, "cannot load %s\n", argv[1]);
		xccdf_session_free(session);
		return 1;
	}
	ok = evaluate(session);
	first = probe_starts(argv[2]);
	for (i = 0; ok && i < 2; i++) {
		xccdf_session_result_reset(session);
		ok = evaluate(session);
	}
	third = probe_starts(argv[2]);
	xccdf_session_free(session);
	if (!ok)
		return 1;
	printf("probe threads started: %d after the first evaluation, %d after the third\n",
		first, third);
	return first > 0 && third == first ? 0 : 1;
}
