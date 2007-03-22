#!perl -T
use strict;
use warnings;

use Test::More tests => 2;

BEGIN { use_ok('Email::ARF::Report'); }

use Email::Simple::Creator;

my $email = Email::Simple->create(
  header => [
    Subject => 'take our hard math tests!',
    To      => 'mathman@sq1.example.com',
    From    => 'mr.glitch@eatyou.example.net',
  ],
  body   => "Our math tests are so hard, you'll cube yourself!",
);

my $report = Email::ARF::Report->create(
  description    => "Please do not send math tests to our customers!",
  fields         => { 'Source-IP' => '127.0.0.127' },
  header         => [ Subject => 'Math Abuse Report' ],
  original_email => $email,
);

is($report->field('Source-IP'), '127.0.0.127', 'field we passed in is there');
