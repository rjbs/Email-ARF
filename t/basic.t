#!perl -T
use strict;
use warnings;

use Test::More tests => 22;

BEGIN { use_ok('Email::ARF::Report'); }

sub test_report {
  my ($filename) = @_;
  open my $fh, '<', "t/messages/$filename.msg" or die "couldn't read file: $!";
  my $content = do { local $/; <$fh> };
  my $report = Email::ARF::Report->new($content);
}

my @data = (
  example0 => { type => 'abuse'   },
  example1 => { type => 'opt-out' },
  example2 => { type => 'abuse', 'source-ip' => '10.67.41.167' },
);

while (my ($file, $attr) = splice @data, 0, 2) {
  my $report = test_report($file);
  isa_ok($report, 'Email::ARF::Report');

  is($report->feedback_type, delete $attr->{type}, "$file: feedback_type");
  is($report->user_agent,    'SomeGenerator/1.0',  "$file: user_agent");
  is($report->arf_version,   '0.1',                "$file: arf_version");

  for my $field (keys %$attr) {
    is($report->field($field), $attr->{$field}, "$file: $field");
  }

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
}
