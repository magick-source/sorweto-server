package SorWeTo::Utils::DataChecks;

use strict;
use warnings;

use Exporter qw(import);

our @EXPORT_OK = qw(
  check_email
  check_password
);

sub check_email {
  my ($email) = @_;

  unless ($email =~ m{
    \A\w[\w\.\-]+\@\w+[\w\-\.]*\w+
  }x) {
    #TODO: log rejections, maybe, for debug
    return;
  }

  # TODO: check completeness of regexp
  # TODO: check MX record of domain, maybe?

  return 1;
}

sub check_password {
  my ($password, $username) = @_;

  return if $username and $password eq $username;

  return if length($password)<8;
  return if length($password)<12 and $password !~ /[\d\W]/;

  return 1;
}

1;
