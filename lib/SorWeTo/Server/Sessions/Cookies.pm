package SorWeTo::Server::Sessions::Cookies;
use Mojo::Base -base;

# This is a backend for SWT::SRV::Sessions, using cookies
# It is inspired to Mojolicious::Sessions. This is the default
# backend for SWT Sessions, but not the recomended. However
# for simple sites that don't need a proper database, it may be
# an useful default.

# Whenever using a Database, TmpBlog is the recomended default - which
# stores the data in a table in the database.

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
  my $value   = $params->{value};
  my $expires = $params->{expires};

  my $cookie_name = join '_', $self->cookie_prefix,
      ($sess_id ? $sess_id : ());

  my $options = {
    domain    => $c->app->sessions->cookie_domain,
    secure    => $c->app->sessions->secure,
    path      => $c->app->sessions->cookie_path,
    httponly  => 1,
    expires   => $expires,
  };

  $c->signed_cookie( $cookie_name, $value, $options );

  return;
}

1;
