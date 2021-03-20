package SorWeTo::Server::Plugins::MySQL;

use Mojo::Base qw(Mojolicious::Plugin);

use SorWeTo::Db;

sub register {
	my ($self, $app, $conf) = @_;

  my $dbinfo  = $conf;
  unless ($dbinfo and keys %$dbinfo) {
    $dbinfo = $app->config->config('mysql:sorweto');
    $dbinfo = $app->config->config('mysql')
      unless keys %$dbinfo;
  }

  unless ($dbinfo) {
    die "Missing MySQL configuration ([plugin:MySQL] or [mysql]"
      unless $dbinfo and %$dbinfo;
  }

  SorWeTo::Db->init($dbinfo);

  return $self;
}

1; 
