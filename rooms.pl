#!/usr/bin/perl

use utf8;
#no utf8;

#use open ":std", ":encoding(utf8)";
binmode(STDOUT, ':encoding(utf8)');
#binmode(STDOUT, ':raw');

use Email::MIME;
use Email::MIME::Header;
use Net::SMTP;
use DateTime::Format::Mail;
use Data::Dumper;
use Sys::Syslog;
use Data::Uniqid qw ( suniqid uniqid luniqid );
use LWP::Simple;


use Encode;
use Encode::DoubleEncodedUTF8;

my $SLEEP_MINUTES = 2;

my $SUBJECT = "zarezervovano";
my $DATA = "rezervace provedena";

openlog('rooms', 'cons,pid', 'local6');

my $our_domain = "hzsol.cz";
my $smtpd = "localhost";
my $user = "nextcloud";
my $request_id = uniqid;
my $s = "";
my $user = $ENV{'USER'};
my $home = $ENV{'HOME'};


#&send_mail('michal.grezl@hzsol.cz', 'michal.grezl@hzsol.cz', 'localhost');
#&send_mail("x", "michal.grezl\@hzsol.cz", "localhost");

while (<>)
{
 $s .= $_;
}

wsyslog('info', 'start');


my $email_object = Email::MIME->new($s);

my @parts = $email_object->parts;

  my $decoded = $email_object->body;
  my $ct = $email_object->content_type;



foreach $i (@parts){
#  print $i->content_type;
  if ($i->subparts) {
    foreach $sub_i ($i->parts) {
#     print $sub_i->content_type . " .\n";
      if ($sub_i->content_type =~ "text/plain") {
        &confirm_invitation($sub_i->body);
      }
    }
  }
}

print "done\n";

my $decoded = $email_object->body;
my $non_decoded = $email_object->body_raw;
my $content_type = $email_object->content_type;

my $from_header = $email_object->header_str("From");

$from_header =~ tr/ĚŠČŘŽÝÁÍÉŮ/ESCRZYAIEU/;
$from_header =~ tr/ěščřžýáíéů/escrzyaieu/;

print "- $from_header\n";

wsyslog('info', "from:" . $from_header);
#wsyslog('info', "user:" . $user);
wsyslog('info', "home:" . $home);

my $address = &parse_nxtc_from_header($from_header);
wsyslog('info', "address:" . $address);
&send_mail('mailmaster@hzsol.cz', $address, 'localhost');

closelog();

################################################################################
sub send_mail()
################################################################################
{
  my ($sender, $recipient, $smtpd) = @_;


  my $smtp = Net::SMTP->new($smtpd,
                        Hello => $our_domain,
                        Timeout => 120,
                        Debug   => 0,
                      ) or do {
                        &log_string("cannot create smtp object");
                        return "timeout";
                      };

  &wsyslog('info', "from $sender to $recipient via $smtpd ... hello:$our_domain");

  $smtp->mail($sender)  or do {
    my $from_err = "from error:" . $smtp->message;
    chomp $from_err;
    &wsyslog('error', $from_err);
    return $from_err;
  };
  $smtp->to($recipient) or do {
    my $recp_err = "recipient error:" . $smtp->message;
    chomp $recp_err;
    &wsyslog('error', $recp_err);
    return $recp_err;
  };
  $smtp->data();
  $smtp->datasend("From: " . $sender . "\n");
  $smtp->datasend("To: " . $recipient . "\n");
  $smtp->datasend("Date: " . date_r() . "\n");
  $smtp->datasend("Subject: " . $SUBJECT  . "\n");
  $smtp->datasend($DATA);
  $smtp->datasend("\n");
  $smtp->dataend();
  $m = $smtp->message;
  $smtp->quit;

  chomp $m;

  &wsyslog('info', "sent, smtp code: ".$smtp->code . " " . $m);

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
  my @x;
  my %data;
  my $accept_link;

  @data = split /^/m, $s;

  foreach my $i (@data){
    @x = $i =~ m/\s*(.*?):\s(.*).$/;
    if ($x[0] ne "") {
       my $fixed0 = decode("utf-8-de", $x[0]);
       my $fixed1 = decode("utf-8-de", $x[1]);
        print $fixed."\n";

      $data{$fixed0} = $fixed1;
    }
  }

  print Dumper \%data;

  if ($data{Accept} ne "") {
    $accept_link = $data{Accept};
  } else {
    $accept_link = $data{Přijmout};
  }

  print "Link: $accept_link .\n";
  wsyslog('info', "accept link: " . $accept_link);
  wsyslog('info', "Sleeping");
  sleep $SLEEP_MINUTES * 60;
  my @args = ("/usr/bin/wget", "-q", '-O/tmp/zzxzz'.$$, $accept_link);
  wsyslog('info', "visited.");
  system(@args) == 0 or do {
    wsyslog('info',"system call ( @args ) failed: $?");
  };
  wsyslog('info', "Done");

}

################################################################################
sub wsyslog
################################################################################
{
  my ($a, $b) = @_;
  syslog($a, $request_id. " " . $b);
}

################################################################################
sub parse_nxtc_from_header()
################################################################################
{
  my $from_header = shift;
  my $address;
   print " $from_header x\n";

  if (
    $from_header =~ m/^\"(.*)prostrednictvim.*\" (.*)$/gm or
    $from_header =~ m/^\"(.*)via.*\" (.*)$/gm
  ) {
    print "all $1 $2\n";

    @x = split(" ",$1);
    $address = $x[0]. "." .$x[1] . '@hzsol.cz';
    print "$address\n" 
  }

  return $address;
}
