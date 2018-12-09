package SorWeTo::Server::Sessions::Cookies;
use Mojo::Base -base;

# This is basically, just a copy of MOjolicious::Sessions, with a couple
# of small tweaks: using different cookie names - to support multiple
# sessions, for instance

use Mojo::JSON;
use Mojo::Util qw(b64_decode b64_encode);

has cookie_prefix      => 'swt_sess';

sub load {
  my ($self, $c, $sess_id) = @_;

  my $cookie_name = join '_', $self->cookie_prefix,
      ($sess_id ? $sess_id : ());

  return unless my $value = $c->signed_cookie( $cookie_name );
  return $value;
}

sub store {
  my ($self, $c, $params) = @_;

  my $sess_id = $params->{session_id};
  my $session = $params->{session};
  
  my $path    = $c->app->sessions->cookie_path;
  my $secure  = $c->app->sessions->secure;
  my $domain  = $c->app->sessions->cookie_domain;

  my $cookie_name = join '_', $self->cookie_prefix,
      ($sess_id ? $sess_id : ());
  print STDERR "session cookie: $cookie_name\n";

  

}

1;
