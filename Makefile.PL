use strict;
use warnings;

use inc::Module::Install;

name          ('Email-ARF');
author        ('Ricardo SIGNES <rjbs@cpan.org>');
license       ('perl');
version_from  ('lib/Email/ARF/Report.pm');

requires('Email::MIME'  => 1.859); # subparts method
requires('Params::Util' => 0.00);  # no minimum; used for _INSTANCE
requires('Scalar::Util' => 0.00);  # unknown minimum; used for blessed

requires('Email::MIME::ContentType' => 0.00); # no minimum

WriteAll();
