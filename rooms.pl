#!/usr/bin/perl

use utf8;
use open ":std", ":encoding(UTF-8)";

use Email::MIME;
use Email::MIME::Header;

my $s = "";

while (<>)
{
 $s .= $_;
}

my $parsed = Email::MIME->new($s);

my @parts = $parsed->parts; # These will be Email::MIME objects, too.
my $decoded = $parsed->body;
my $non_decoded = $parsed->body_raw;
my $content_type = $parsed->content_type;

my $from_header = $parsed->header_str("From");
print $from_header . "\n";
