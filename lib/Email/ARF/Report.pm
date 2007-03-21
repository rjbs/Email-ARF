use strict;
use warnings;

package Email::ARF::Report;

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

  my $report = Email::ARF::Report->new($message);

Given either an Email::MIME object or a string containing the text of an email
message, this method returns a new Email::ARF::Report object.  If the given
message source is not a valid report in ARF format, an exception is raised.

=cut

sub new {
  my ($class, $source) = @_;

  Carp::croak "no report source provided" unless $source;

  my $mime = Scalar::Util::blessed $source
           ? $source
           : Email::MIME->new($source);

  Carp::croak "ARF report source could not be interpreted as MIME message"
    unless eval { $mime->isa('Email::MIME') };

  my $ct_header = $mime->content_type;
  my $ct = Email::MIME::ContentType::parse_content_type($ct_header);

  Carp::croak "non-ARF content type '$ct_header' on ARF report source"
    unless $ct->{discrete}  eq 'multipart'
    and    $ct->{composite} eq 'report'
    and    $ct->{attributes}{'report-type'} eq 'feedback-report';

  Carp::croak "too few subparts for ARF report" unless $mime->subparts >= 3;

  my ($description_part, $report_part, $original_part) = $mime->subparts;

  my $report_header = $report_part->content_type;
  my $report_ct = Email::MIME::ContentType::parse_content_type($report_header);
  Carp::croak "bad content type '$report_header' for machine-readable section"
    unless $report_ct->{discrete}  eq 'message'
    and    $report_ct->{composite} eq 'feedback-report';

  my $self = bless {
    description_part => $description_part,
    report_part      => $report_part,
    original_part    => $original_part,
  } => $class;

  $self->{fields} = $self->_email_from_body($report_part)->header_obj;
  $self->{original_email} = $self->_email_from_body($original_part);

  return $self;
}

sub _email_from_body {
  my ($self, $src_email) = @_;
  
  my $src_email_body = $src_email->body;

  $src_email_body =~ s/\A(\x0d|\x0a)+//g;

  my $email = Email::Simple->new($src_email_body);
}

=head2 original_email

This method returns an Email::Simple object containing the original message to
which the report refers.  Bear in mind that this message may have been edited
by the reporter to remove identifying information.

=cut

sub original_email {
  $_[0]->{original_email}
}

=head2 description

=cut

sub _description_part { $_[0]->{description_part} }

sub description {
  $_[0]->_description_part->body;
}

sub _report_part {
  $_[0]->{report_part}
}

sub _fields { $_[0]->{fields} }

sub field {
  my ($self, $field) = @_;

  return $self->_fields->header($field);
}

sub feedback_type { $_[0]->field('Feedback-Type'); }
sub user_agent    { $_[0]->field('User-Agent');    }
sub arf_version   { $_[0]->field('Version');       }

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
