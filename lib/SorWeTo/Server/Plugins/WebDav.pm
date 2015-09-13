package SorWeTo::Server::Plugins::WebDav;

use Mojo::Base 'Mojolicious::Plugin';

has mtfnpy => undef;
has methods => sub { [qw(
                GET HEAD OPTIONS PROPFIND DELETE PUT
                COPY LOCK UNLOCK MOVE POST TRACE MKCOL
      )]
  };
has allowed_methods => sub { join( ',', @{ shift->methods } ) };

has config  => sub { {} };

sub register {
  my ($self, $app, $config) = @_;

  $config ||= {};
  $self->config( $config );

  $app->hook( before_dispatch => sub {
      $self->_handle_req( @_ );
    });

  return $self;
}

sub _handle_req {
  my ($self, $c) = @_;

  my $path = $c->req->url->path->clone->canonicalize->to_string;

  my $prefix = $self->config->{prefix} || '';
  substr($prefix, -1) = '' if substr($prefix, -1) eq '/';
  if ($prefix) {
    return unless $path =~ s/^$prefix//;

    $path ||= '/';
  }

  print STDERR "path: $path\n";

  return $self->render_error( $c, 501 );
}


sub render_error {
  my ($self, $c, $code) = @_;

  my $res = $c->res;
  return if ( $res->code || '' ) eq $code;

  $c->render(text => qq[
<!doctype html><html>
  <head><title>Error $code</title></head>
  <body><h2>Error $code</h2></body>
   </html>

], status => $code, type => 'html' );
}

1;
