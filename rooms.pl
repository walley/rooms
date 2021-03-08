#!/usr/bin/perl

use utf8;
use open ":std", ":encoding(UTF-8)";

use Email::MIME;
use Email::MIME::Header;
use Net::SMTP;
use DateTime::Format::Mail;
use Data::Dumper;


my $our_domain = "hzsol.cz";
my $smtpd = "localhost";
my $user = "nextcloud";

my $s = "";

while (<>)
{
 $s .= $_;
}

#&send_mail("x", "michal.grezl\@hzsol.cz", "localhost");

my $email_object = Email::MIME->new($s);

my @parts = $email_object->parts; # These will be Email::MIME objects, too.

foreach $i (@parts){
  print $i->content_type;
  if ($i->subparts) {
    print "*\n";
    foreach $sub_i ($i->parts) {
      print $sub_i->content_type . " .\n";
       if ($sub_i->content_type =~ "text/plain") {
          print $sub_i->body . " .\n";
          &confirm_invitation( $sub_i->body);
       }
    }
  }
  print "\n";
}

$email_object->walk_parts(sub {
    my ($part) = @_;
    return if $part->subparts; # multipart

    if ( $part->content_type =~ m[text/html]i ) {
        my $body = $part->body;
        $body =~ s/<link [^>]+>//; # simple filter example
        $part->body_set( $body );
    }
});


my $decoded = $email_object->body;
my $non_decoded = $email_object->body_raw;
my $content_type = $email_object->content_type;

my $from_header = $email_object->header_str("From");

print $from_header . "\n";

################################################################################
sub send_mail()
################################################################################
{
  my ($id, $recipient, $smtpd) = @_;


  my $smtp = Net::SMTP->new($smtpd,
                        Hello => $our_domain,
                        Timeout => 120,
                        Debug   => 1,
                      ) or do {
                        &log_string("cannot create smtp object");
                        return "timeout";
                      };

  my $useraddress = $user . "\@" . $our_domain;

  &log_string("from $useraddress send_mail($id, $recipient, $smtpd) hello:$our_domain ...");

  $smtp->mail($useraddress)  or do {
    my $from_err = "from error:" . $smtp->message;
    chomp $from_err;
    &log_string($from_err);
    return $from_err;
  };
  $smtp->to($recipient) or do {
    my $recp_err = "recipient error:" . $smtp->message;
    chomp $recp_err;
    &log_string($recp_err);
    return $recp_err;
  };
  $smtp->data();
  $smtp->datasend("From: " . $useraddress . "\n");
  $smtp->datasend("To: $recipient\n");
  $smtp->datasend("Date: " . date_r() . "\n");
  $smtp->datasend("Subject: testmail number $id\n");
  $smtp->datasend("\n");
  $smtp->datasend("I came from $origin.\n");
  $smtp->datasend("A simple test message, its id is $id\n");
  $smtp->datasend("some other useful stuff follows: $id, $recipient, $smtpd\n");
  $smtp->dataend();
  $m = $smtp->message;
  $smtp->quit;

  chomp $m;

  &log_string("smtp code: ".$smtp->code);
  &log_string("sent: " . $recipient . " id: " . $id);

  return $m;
}

################################################################################
sub log_string
################################################################################
{
  my ($p) = @_;
  my $fh;
  open($fh, ">>/tmp/mailtestor.log") or die "log";
  print $fh time . " ";
  print $fh $p."\n";
  close($fh);
}

################################################################################
sub date_r
################################################################################
{
  my $dt = DateTime->now(time_zone=>'local');
  my $str = DateTime::Format::Mail->format_datetime($dt);

  return $str;
}

################################################################################
sub confirm_invitation()
################################################################################
{
  my ($s) = @_;

  @data = split /^/m, $s;

  foreach my $i (@data){
    my @x = $i =~ m/\s*(.*?):\s(.*)/;
    print Dumper \@x;
  }

}

