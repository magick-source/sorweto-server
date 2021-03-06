package SorWeTo::Server::Routes;

use Mojo::Base qw(Mojolicious::Routes);

has api         => \&__api_builder;

has anonymous   => \&__anonymous_builder;
has logged_in   => \&__loggedin_builder;

has __admin     => sub { {} };
has _base_admin => \&__base_admin_builder;

has __usercan   => sub { {} };
has __apican    => sub { {} };

sub _sorweto_admin_right { 'sorweto_admin' }

sub admin_can {
  my ($self, $right) = @_;

  $right //= _sorweto_admin_right();;

  my $route = $self->__admin->{ $right } 
          ||= $self->__admin_route_builder( $right );

  return $route;
}

sub api_can {
  my ($self, $right) = @_;

  $right = '' unless defined $right;
  my $route = $self->__apican->{ $right } 
          ||= $self->__can_route_builder( $self->api, $right );

  return $route;
}

sub user_can {
  my ($self, $right) = @_;

  return $self->logged_in
    unless $right;

  my $route = $self->__usercan->{ $right } 
          ||= $self->__can_route_builder( $self->logged_in, $right );

  return $route; 
}

sub __can_route_builder {
  my ($self, $base, $right) = @_;

  my $route = $base->under('/' => sub {
      my ($c) = @_;

      print STDERR "XXX: got to route_builded[$right]\n";
 
      my $user = $c->user();
      if ($user->is_anonymous() ) {
        $c->inline_login(); 
      }

      if ( $c->user_has_right( $right ) ) {
        $c->stash->{'swt.restricted'}{ $right }++;
        return 1;
      }

      $c->reply->not_found();
      return undef;
    });

  return $route;
}

sub __admin_route_builder {
  my ($self, $right) = @_;

  my $route = $self->_base_admin;
  
  $route = $route->under('/' => sub {
      my ($c) = @_;

      return __login_or_fail( $c )
        unless $c->user_has_right( $right );

      return 1;
    });

  return $route;
}

sub __base_admin_builder {
  my ($self) = @_;

  my $route = $self->under('/admin/' => sub {
      my ($c) = @_;

      my $user = $c->user();
      return __login_or_fail( $c )
        unless $user and !$user->is_anonymous;

      return 1;
    });
}

sub __login_or_fail {
  my ($c) = @_;

  if ($c->req->method eq 'GET') {
    if ( $c->user() and !$c->user->is_anonymous() ) {
      $c->reply->not_found(); # TODO(MAYBE): convert to a forbiden?

    } else {
      #TODO(MAYBE): Convert login to api, and do it inline
      $c->session->{goto_after_login} = $c->req->url->to_string();
      $c->redirect_to('/login/');

    }

  } else {
    $c->reply->not_found(); # TODO(MAYBE): convert to a forbiden?
  }
}

sub __api_builder {
  my ($self) = @_;

  return $self->under('/api/' => sub  {
      my ($c) = @_;

      $c->stash->{format} ||= 'json';
      $c->stash->{'swt.is_api'} = 1;
      
      #TODO: Support for auth
      print STDERR "XXX: under the /api/ handler\n";
  
      return 1;
    });
}

sub __anonymous_builder {
  my ($self) = @_;

  return $self->under('/' => sub {
      my ($c) = @_;

      my $user = $c->user;

      return 1 if !$user or $user->is_anonymous;

      return undef;
    });
}

sub __loggedin_builder {
  my ($self) = @_;

  return $self->under('/' => sub {
    my ($c) = @_;

    my $user = $c->user;
    if ($user and !$user->is_anonymous) {
      $c->stash->{'swt.logged_in'} = 1;
      return 1;
    }

    return undef;
  });
}

1;

