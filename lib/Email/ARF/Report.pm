package Email::ARF::Report;

use strict;
use warnings;

use Carp ();
use Email::MIME 1.859 ();
use Email::MIME::ContentType ();
use Scalar::Util ();
use Params::Util qw(_INSTANCE);

=head1 NAME

Email::ARF::Report - interpret Abuse Reporting Format (ARF) messages

=head1 SYNOPSIS

  my $report = Email::ARF::Report->new($text);

=head1 DESCRIPTION

=head1 METHODS

=head2 new

=cut

sub new {
  my ($class, $source) = @_;

  Carp::croak "no report source provided" unless $source;

  my $mime = blessed $source ? $source : Email::MIME->new($source);

  Carp::croak "ARF report source could not be interpreted as MIME message"
    unless eval { $mime->isa('Email::MIME') };

  my $ct_header = $mime->content_type;
  my $ct = Email::MIME::ContentType::parse_content_type($ct_header);

  Carp::croak "non-ARF content type '$ct_header' on ARF report source"
    unless $ct->{discrete}  eq 'multipart'
    and    $ct->{composite} eq 'report'
    and    $ct->{attributes}{'report-type'} eq 'feedback-report';

  Carp::croak "too few subparts for ARF report" unless $mime->subparts >= 3;

  my ($description_part, $report_part, $original_email) = $mime->subparts;

  my $report_header = $report_part->content_type;
  my $report_ct = Email::MIME::ContentType::parse_content_type($report_header);
  Carp::croak "bad content type '$report_header' for machine-readable section"
    unless $report_ct->{discrete}  eq 'message'
    and    $report_ct->{composite} eq 'feedback-report';

  my $self = bless {
    description_part => $description_part,
    report_part      => $report_part,
    original_email   => $original_email,
  } => $class;

  $self->_acquire_fields;

  return $self;
}

sub _acquire_fields {
  my ($self) = @_;
  
  my $report_body = $self->_report_part->body;

  $report_body =~ s/\A(\x0d|\x0a)+//g;

  # This should be a header object, when the interface to that is more
  # stabilized.
  my $fields = Email::Simple->new($report_body);

  $self->{fields} = $fields;
}

sub _description_part { $_[0]->{description_part} }
sub _report_part      { $_[0]->{report_part}      }
sub original_email    { $_[0]->{original_email}   }

sub description {
  $_[0]->_description_part->body;
}

sub _fields { $_[0]->{fields} }

sub field {
  my ($self, $field) = @_;

  return $self->_fields->header($field);
}

sub feedback_type  { $_[0]->field('Feedback-Type'); }
sub user_agent     { $_[0]->field('User-Agent');    }
sub report_version { $_[0]->field('Version');       }

=head1 SEE ALSO

L<http://www.mipassoc.org/arf/>

L<http://www.shaftek.org/publications/drafts/abuse-report/draft-shafranovich-feedback-report-01.txt>

=head1 PERL EMAIL PROJECT

This module is maintained by the Perl Email Project

L<http://emailproject.perl.org/wiki/Email::ARF::Report>

=head1 AUTHORS

Ricardo SIGNES E<lt>F<rjbs@cpan.org>E<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2007 by Ricardo SIGNES

This library is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

1;
