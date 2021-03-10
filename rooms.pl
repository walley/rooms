#!/usr/bin/perl

#use utf8;
no utf8;

#use open ":std", ":encoding(utf8)";
#binmode(STDOUT, ':encoding(utf8)');
#binmode(STDOUT, ':raw');

use Email::MIME;
use Email::MIME::Header;
use Net::SMTP;
use DateTime::Format::Mail;
use Data::Dumper;
use Sys::Syslog;
use Data::Uniqid qw ( suniqid uniqid luniqid );
use LWP::Simple;

openlog('rooms', 'cons,pid', 'local6');

my $our_domain = "hzsol.cz";
my $smtpd = "localhost";
my $user = "nextcloud";
my $request_id = uniqid;
my $s = "";
my $user = $ENV{'USER'}; 
my $home = $ENV{'HOME'}; 


while (<>)
{
 $s .= $_;
}

wsyslog('info', 'start');

#&send_mail("x", "michal.grezl\@hzsol.cz", "localhost");

my $email_object = Email::MIME->new($s);

my @parts = $email_object->parts;

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

my $decoded = $email_object->body;
my $non_decoded = $email_object->body_raw;
my $content_type = $email_object->content_type;

my $from_header = $email_object->header_str("From");
wsyslog('info', "from:" . $from_header);
wsyslog('info', "user:" . $user);
wsyslog('info', "home:" . $home);

closelog();

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
  my @x;
  my %data;
  my $accept_link;

  @data = split /^/m, $s;

  foreach my $i (@data){
    @x = $i =~ m/\s*(.*?):\s(.*).$/;
    if ($x[0] ne "") {
      $data{$x[0]} = $x[1];
    }
  }

  print Dumper \%data;

  if ($data{Accept} ne "") {
    $accept_link = $data{Accept};
  } else {
    $accept_link = $data{'Přijmout'};
  }

  print "Link: $accept_link .\n";
  wsyslog('info', "visited: " . $accept_link);

#  $contents = get($data{Accept});

  sleep 60;
  wsyslog('info', "sleeping");
#  $cmd = "/usr/bin/wget -q -O /dev/null " . $data{Accept};
  my @args = ("/usr/bin/wget", "-q", '-O/tmp/zzxzz'.$$, $accept_link);
  system(@args) == 0 or do {
    wsyslog('info',"system call ( @args ) failed: $?");
  };

}

################################################################################
sub wsyslog
################################################################################
{
  my ($a, $b) = @_;
  syslog($a, $request_id. " " . $b);
}
