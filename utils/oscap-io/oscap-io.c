#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <xccdf_session.h>
#include <oscap_error.h>

/*
 * oscap-io evaluates the rules of an XCCDF document or a data stream on
 * request. Each line of standard input holds a request, a profile and a
 * rule separated by a space. For each request oscap-io prints a line per
 * rule result, the rule and its xccdf_test_result_type_t, and a request
 * it fails to evaluate, for an unknown profile or rule or an evaluation
 * error, gets XCCDF_RESULT_ERROR. With -syschar, the answer is followed
 * by one oval_system_characteristics document per OVAL file of the
 * document. The output is flushed after each request, and diagnostics go
 * to standard error.
 */

static int verbose;
static int syschar;
static char *argv0;
static struct xccdf_session *session;

static void
verbosef(const char *fmt, ...)
{
	va_list arg;

	if (!verbose)
		return;
	va_start(arg, fmt);
	vfprintf(stderr, fmt, arg);
	va_end(arg);
}

/* print the queued OpenSCAP errors, which empties the queue */
static void
printerr(const char *what)
{
	char *err;

	err = oscap_err_get_full_error();
	if (err != NULL)
		fprintf(stderr, "error: %s: %s\n", what, err);
	else
		fprintf(stderr, "error: %s\n", what);
	free(err);
}

static struct xccdf_session*
session_new(char *file)
{
	struct xccdf_session *s;

	s = xccdf_session_new(file);
	if (s == NULL) {
		printerr("xccdf_session_new");
		return NULL;
	}

	xccdf_session_set_validation(s, false, false);
	xccdf_session_set_product_cpe(s, "cpe:/a:open-scap:oscap");

	if (xccdf_session_load(s) != 0) {
		printerr("xccdf_session_load");
		xccdf_session_free(s);
		return NULL;
	}

	return s;
}

static int
session_set_profile(char *profile)
{
	if (xccdf_session_set_profile_id(session, profile) != 0)
		return 0;

	switch (xccdf_session_set_profile_id_by_suffix(session, profile)) {
	case OSCAP_PROFILE_NO_MATCH:
		fprintf(stderr, "missing profile %s\n", profile);
		return 1;
	case OSCAP_PROFILE_MULTIPLE_MATCHES:
		fprintf(stderr, "%s matches multiple profiles\n", profile);
		return 1;
	default:
		return 0;
	}
}

static int
session_evaluate_rule(char *rule)
{
	struct xccdf_rule_result_iterator *resIt;
	struct xccdf_rule_result *res;
	int resultCode, printed;
	const char *ruleRef;

	xccdf_session_add_rule(session, rule);

	if (xccdf_session_evaluate(session) != 0) {
		printerr("xccdf_session_evaluate");
		return 1;
	}

	resIt = xccdf_session_get_rule_results(session);
	printed = 0;
	while (xccdf_rule_result_iterator_has_more(resIt)) {
		res = xccdf_rule_result_iterator_next(resIt);
		resultCode = (int)xccdf_rule_result_get_result(res);
		if (resultCode == XCCDF_RESULT_NOT_SELECTED)
			continue;
		ruleRef = xccdf_rule_result_get_idref(res);
		printf("%s %d\n", ruleRef, resultCode);
		printed++;
		verbosef("-> %s [%s]\n", ruleRef, xccdf_test_result_type_get_text(resultCode));
	}
	xccdf_rule_result_iterator_free(resIt);

	/* the check engine itself may answer notselected, as an SCE script can */
	if (printed == 0)
		printf("%s %d\n", rule, XCCDF_RESULT_NOT_SELECTED);

	return 0;
}

static int
evaluate(char *xccdf, char *profile, char *rule)
{
	if (session == NULL) {
		session = session_new(xccdf);
		if (session == NULL)
			exit(1);
	}

	if (session_set_profile(profile) != 0)
		return 1;
	return session_evaluate_rule(rule);
}

static void
usage(void)
{
	fprintf(stderr, "usage: %s [ -v ] [ -syschar ] xccdf\n", argv0);
	exit(1);
}

int
main(int argc, char *argv[])
{
	char *line, *s, *profile, *rule;
	size_t len;

	argv0 = argv[0];
	argc--;
	argv++;

	while (argc > 1) {
		if (strcmp(argv[0], "-v") == 0)
			verbose = 1;
		else if (strcmp(argv[0], "-syschar") == 0)
			syschar = 1;
		else
			usage();
		argc--;
		argv++;
	}

	if (argc != 1)
		usage();

	line = NULL;
	len = 0;
	while (getline(&line, &len, stdin) != -1) {
		line[strcspn(line, "\n")] = '\0';
		profile = strtok_r(line, " ", &s);
		if (profile == NULL)
			continue;
		rule = strtok_r(NULL, " ", &s);
		if (rule == NULL)
			continue;
		verbosef("evaluate profile [%s] rule [%s]\n", profile, rule);

		if (evaluate(argv[0], profile, rule) != 0) {
			if (oscap_err())
				printerr("evaluate");
			printf("%s %d\n", rule, XCCDF_RESULT_ERROR);
		}
		if (syschar && xccdf_session_print_syschar(session) != 0) {
			printerr("xccdf_session_print_syschar");
			exit(1);
		}
		xccdf_session_result_reset(session);
		fflush(stdout);
	}
	free(line);

	xccdf_session_free(session);

	return 0;
}
