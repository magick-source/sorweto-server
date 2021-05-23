package SorWeTo::Server::Plugins::Notices;

use Mojo::Base qw(Mojolicious::Plugin);

sub register {
  my ($self, $app, $conf) = @_;

  $app->helper( add_notice => \&_add_notice );

  return $self;
}

sub _add_notice {
  my ($c, $notice) = @_;

  my $notices = $c->stash->{site_notices} ||= [];

  push @$notices, $notice;
}

1;
