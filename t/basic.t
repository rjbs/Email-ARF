#!perl -T
use strict;
use warnings;

use Test::More tests => 8;

BEGIN { use_ok('Email::ARF::Report'); }

sub test_report {
  my ($filename) = @_;
  open my $fh, '<', "t/messages/$filename.msg" or die "couldn't read file: $!";
  my $content = do { local $/; <$fh> };
  my $report = Email::ARF::Report->new($content);
}

my $report = test_report('example-0');
isa_ok($report, 'Email::ARF::Report');

is($report->feedback_type, 'abuse',             "correct feedback_type");
is($report->user_agent,    'SomeGenerator/1.0', "correct user_agent");
is($report->arf_version,   '0.1',               "correct arf_version");

is($report->field('version'), '0.1',            "field accessor works");

is(
  $report->original_email->header('subject'),
  'Earn money',
  'we can get headers from the original message via the report',
);

like(
  $report->description,
  qr/\QIP 10.67.41.167\E/,
  "we seem to be able to get the report description",
);
