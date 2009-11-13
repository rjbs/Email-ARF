use strict;
use warnings;

use inc::Module::Install;

name          ('Email-ARF');
author        ('Ricardo SIGNES <rjbs@cpan.org>');
license       ('perl');
version_from  ('lib/Email/ARF/Report.pm');

requires('Email::MIME'  => 1.859); # subparts method
requires('Params::Util' => 0.000); # no minimum; used for _INSTANCE
requires('Scalar::Util' => 0.000); # unknown minimum; used for blessed

requires('Email::MIME::Creator'     => 1.451); # known bug prior to this
requires('Email::MIME::ContentType' => 0.000); # no minimum

test_requires('Email::Simple::Creator'	=> 2.100); # required by t/create.t, 2.1 is known as working version

WriteAll();
