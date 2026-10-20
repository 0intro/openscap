#!/usr/bin/perl
#
# This is an SCE script used to test a Perl script in OSCAP_PROBE_ROOT. It
# passes when /etc/marker holds the word the test writes in the root.

open(my $f, '<', '/etc/marker') or exit($ENV{XCCDF_RESULT_FAIL});
my $word = <$f>;
chomp $word;
exit($word eq 'probe_root' ? $ENV{XCCDF_RESULT_PASS} : $ENV{XCCDF_RESULT_FAIL});
