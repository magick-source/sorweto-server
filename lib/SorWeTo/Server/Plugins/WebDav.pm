package SorWeTo::Server::Plugins::WebDav;

use Mojo::Base 'Mojolicious::Plugin';

has mtfnpy => undef;
has methods => sub { [qw(
                GET HEAD OPTIONS PROPFIND DELETE PUT
                COPY LOCK UNLOCK MOVE POST TRACE MKCOL
                LIST
      )]
  };
has allowed_methods => sub { join( ',', @{ shift->methods } ) };

has config  => sub { {} };

sub dependences {
  return qw(storage);
}

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

  $c->res->headers->header(
      'DAV' => '1,2,<http://apache.org/dav/propset/fs/1>'
    );
  $c->res->headers->header( 'MS-Author-Via' => 'DAV' );

  my $cmd = "cmd_". lc $c->req->method;

  print STDERR "webdav[$cmd]: $path\n";

  if (my $x = UNIVERSAL::can( $self, $cmd ) ) {
    my $parts = Mojo::Path->new->parse($path)->parts;

    return $c->render_not_found
      if @$parts and grep { $_ eq '..' } @$parts;

    return $x->( $self, $c, $path );    
  }

  return $self->render_error( $c, 501 );
}

*cmd_post   = *not_impl;
*cmd_trace  = *not_impl;

sub not_impl {
  my ($self, $c) = @_;

  $self->render_error( $c, 501 );
}

sub cmd_put {
  my ($self, $c, $path) = @_;

  return $self->render_error( $c, 403 )
    unless $c->req->headers->content_length;

  if ($c->app->storage->is_directory( $path )) {
    return $self->render_error( $c, 409 );
  }

  my $dir = $path;
  $dir =~ s{\/[^\/]+$}{\/}g;
  unless ($c->app->storage->is_directory( $path )) {
    return $self->render_error( $c, 406 );
  }

  if ($c->app->storage->put_file( $path, \($c->req->body || '') ) ) {
    return $c->render( text => 'created', status => 201 );
  }

  $self->render_error( $c, 500 );
}

sub cmd_mkcol {
  my ($self, $c, $path) = @_;

  return $self->render_error( $c, 403 )
    if $path eq '/';

  return $self->render_error( $c, 415 )
    if $c->req->headers->content_length;

  return $self->render_error( $c, 405 )
    if $c->app->storage->is_file( $path );

  return $self->render_error( $c, 409 )
    unless $c->app->storage->make_dir( $path );

  return $c->render( text => 'created', status => 201 );
}

sub cmd_get {
  my ($self, $c, $path) = @_;

  my ($err,$fhandle) = $c->app->storage->get_file( $path );

  if ($err) {
    return $self->render_error( $c, $err );

  } elsif ($fhandle) {
    
    my $file = Mojo::Asset::File->new( handle => $fhandle );
    
    my $types = $c->app->types;
    my $type = $path =~ /\.(\w+)$/ ? $types->type($1) : undef;
    $c->res->headers->content_type($type || $types->type('txt'));

    $c->app->static->serve_asset( $c, $file );
    $c->stash->{'mojo.static'} = 1;

    return !!$c->rendered;
  
  } else {
    return $self->render_error( $c, 404 ); 
  }
}

sub cmd_list {
  my ($self, $c, $path) = @_;

  return $c->render( json => [{name=>'text.txt', size=>123, ctime=>12343456}]);
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
