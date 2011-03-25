use strict;
use warnings;
package Email::ARF::Report;
# ABSTRACT: interpret Abuse Reporting Format (ARF) messages

use Carp ();
use Email::MIME 1.900 (); # ->subtypes
use Email::MIME::ContentType ();
use Scalar::Util ();
use Params::Util qw(_INSTANCE);

=begin :prelude

=head1 WARNING

B<Achtung!>  This is a prototype.  This module will definitely continue to
exist, but maybe the interface will change radically once more people have seen
it and tried to use it.  Don't rely on its interface to keep you employed, just
yet.

=end :prelude

=head1 SYNOPSIS

  my $report = Email::ARF::Report->new($text);

  if ($report->field('source-ip') eq $our_ip) {
    my $sender = $report->original_email->header('from');

    UserManagement->disable_account($sender);
  }

=head1 DESCRIPTION

ARF, the Abuse Feedback Report Format, is used to report email abuse incidents
to an email provider.  It includes mechanisms for providing machine-readable
details about the incident, a human-readable description, and a copy of the
offending message.

=method new

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
    mime             => $mime,
    description_part => $description_part,
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

  my $email = Email::MIME->new($src_email_body);
}

=method create

  my $mail = Email::ARF::Report->create(
    original_email => $email,
    description    => $description,
    fields         => \%fields,      # or \@fields
    header_str     => \@headers,
  );

This method creates a new ARF report from scratch.

The C<original_email> parameter may be given as a string, a string reference,
or as an object that provides an C<as_string> method.

The optional C<header_str> parameter is an arrayref of name/value pairs to be
added as extra headers in the ARF report.  The values are expected to be
character strings, and will be MIME-encoded as needed.  To pass pre-encoded
headers, use the C<header> parameter.  These are handled by L<Email::MIME>'s
C<create> constructor.

Default values are provided for the following fields:

  version       - 0.1
  user-agent    - Email::ARF::Report/$VERSION
  feedback-type - other

=cut

sub create {
  my ($class, %arg) = @_;

  require Email::MIME::Creator;

  my $description_part = Email::MIME->create(
    attributes => { content_type => 'text/plain' },
    body       => $arg{description},
  );

  my $original_body = ref $arg{original_email}
                    ? Scalar::Util::blessed $arg{original_email}
                      ? $arg{original_email}->as_string
                      : ${ $arg{original_email} }
                    : $arg{original_email};

  $description_part->header_set('Date');

  my $original_part = Email::MIME->create(
    attributes => { content_type => 'message/rfc822' },
    body       => $original_body,
  );

  $original_part->header_set('Date');

  my $field_pairs = ref $arg{fields} eq 'HASH'
                  ? [ %{ $arg{fields} } ]
                  : $arg{fields};

  my $fields = Email::Simple->create(header => $field_pairs);

  $fields->header_set('Date');

  unless (defined $fields->header('user-agent')) {
    $fields->header_set('User-Agent', "$class/" . $class->VERSION);
  }

  unless (defined $fields->header('version')) {
    $fields->header_set('Version', "0.1");
  }

  unless (defined $fields->header('Feedback-Type')) {
    $fields->header_set('Feedback-Type', "other");
  }

  my $report_part = Email::MIME->create(
    attributes => { content_type => 'message/feedback-report' },
    body       => $fields->header_obj->as_string,
  );

  $report_part->header_set('Date');

  my $report = Email::MIME->create(
    attributes => {
      # It is so asinine that I need to do this!  Only certain blessed
      # attributes are heeded, here.  The rest are dropped. -- rjbs, 2007-03-21
      content_type  => 'multipart/report; report-type="feedback-report"',
    },
    parts  => [ $description_part, $report_part, $original_part ],

    header     => $arg{header}     || [],
    header_str => $arg{header_str} || [],
  );

  $class->new($report);
}

=method as_email

This method returns an Email::MIME object representing the report.

Note!  This method returns a B<new> Email::MIME object each time it is called.
If you just want to get a string representation of the report, call
C<L</as_string>>.  If you call C<as_email> and make changes to the Email::MIME
object, the Email::ARF::Report will I<not> be affected.

=cut

sub as_email {
  return Email::MIME->new($_[0]->as_string)
}

=method as_string

This method returns a string representation of the report.

=cut

sub as_string { $_[0]->{mime}->as_string }

=method original_email

This method returns an Email::Simple object containing the original message to
which the report refers.  Bear in mind that this message may have been edited
by the reporter to remove identifying information.

=cut

sub original_email {
  $_[0]->{original_email}
}

=method description

This method returns the human-readable description of the report, taken from
the body of the human-readable (first) subpart of the report.

=cut

sub _description_part { $_[0]->{description_part} }

sub description {
  $_[0]->_description_part->body;
}

sub _fields { $_[0]->{fields} }

=method field

  my $value  = $report->field($field_name);
  my @values = $report->field($field_name);

This method returns the value for the given field from the second,
machine-readable part of the report.  In scalar context, it returns the first
value for the field.

=cut

sub field {
  my ($self, $field) = @_;

  return $self->_fields->header($field);
}

=head2 feedback_type

=method user_agent

=method arf_version

These methods are shorthand for retrieving the fields of the same name, except
for C<arf_version>, which returns the F<Version> header.  It has been renamed
to avoid confusion with the universal C<VERSION> method.

=cut

sub feedback_type { $_[0]->field('Feedback-Type'); }
sub user_agent    { $_[0]->field('User-Agent');    }
sub arf_version   { $_[0]->field('Version');       }

=head1 SEE ALSO

L<http://www.mipassoc.org/arf/>

L<http://www.shaftek.org/publications/drafts/abuse-report/draft-shafranovich-feedback-report-01.txt>

=head1 PERL EMAIL PROJECT

This module is maintained by the Perl Email Project

L<http://emailproject.perl.org/wiki/Email::ARF::Report>

=cut

1;
