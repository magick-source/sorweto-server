package SorWeTo::Server::Plugins::User;

use Mojo::Base qw(Mojolicious::Plugin);

use SorWeTo::Db::User;
use SorWeTo::User;

has __user  => undef;
has helpers => sub { {} };
has app     => undef;

sub register {
  my ($self, $app, $conf) = @_;

  $self->app( $app );

  $app->helper( add_user_helper   => sub { $self->add_user_helper( @_ ) } );

  $app->helper( user              => sub { $self->get_user( @_ ) });
  $app->helper( user_by_username  => sub { $self->user_by_username( @_ ) } );

  $app->helper( user_has_right    => sub { $self->user_has_right( @_ ) } );  
  $app->helper( can_track_user    => \&_can_track_user );

  $app->add_user_helper('has_right' => sub { $self->_user_has_right( @_ ) } );

  my $r = $app->routes;
  $r->get('/user/do-not-track')->to(cb => \&_r_do_not_track );
  $r->get('/user/track-again')->to(cb => \&_r_track_again );
  
  return $self;
}

sub add_user_helper {
  my ($self, $c, $name, $cb) = @_;

  die "Invalid help name: '$name'"
    unless $name =~ m{\A[a-zA-Z]\w+\z};


  $self->helpers->{$name} = $cb;
  unless ( SorWeTo::User->can( $name ) ) {
    no strict 'refs';
    *{ "SorWeTo::User::$name" } = sub {
      my ($user, @params) = @_;
      use Data::Dumper;
      print STDERR "user->$name: ", Dumper([ map { ref $_ || $_ }  @_ ]);
      unless (ref $user and $user->isa('SorWeTo::User')) {
        if (defined $user) {
          unshift @params, $user;
        }
        $user = undef;
      }

      return $cb->( $user, @params );
    };
  }

  return $self;
}

sub get_user {
  my ($self, $c) = @_;

  my $user_id = $c->session->{user_id} || 0;

  unless ($c->stash->{__userobj}{ $user_id } ) {
    my $userobj;

    if ($user_id) {
      my ($user) = SorWeTo::Db::User->retrieve( $user_id );

      if ($user and $user->id) {
         $userobj = SorWeTo::User->from_dbuser( $user );
      }
    }

    $userobj ||= __anonymous();
    
    $c->stash->{__userobj}{ $user_id } = $userobj;
  }

  return $c->stash->{__userobj}{ $user_id };
}

sub user_by_username {
  my ($self, $c, $username) = @_;

  # TODO: Get user object from database if possible, and return it
  print STDERR "called user_by_username '$username'\n";

  return;
}

sub user_has_right {
  my ($self, $c, @params) = @_;

  my ($user, $right);
  if (scalar @params <= 1) {
    ($right) = @params;

  } elsif (!(scalar @params % 2)) {
    my %params = @params;
    $right = $params{ right };
    $user  = $params{ user };

    die "parameter \$right is missing"
      unless defined $right;

  } else {
    die "Invalid set of params to user_has_right";
  }

  if ($user and $right eq '') { #test for trackable
    die "only can test trackable for current user";
  }

  return _can_track_user( $c )
    unless $right;

  $user ||= $c->user;

  return $self->_user_has_right( $user, $right );
}

sub _user_has_right {
  my ($self, $user, $right) = @_;

  my $plugins = $self->app->plugins;

  # HOOK: user_has_right => $next => $user => $right
  my $has_right = $plugins->emit_chain('user_has_right', $user, $right);

  return $has_right;
}

sub _can_track_user {
  my ($c) = @_;

  return if $c->stash->{_do_not_track_};

  return 1;
}

sub _r_do_not_track {
  my ($c) = @_;

  my ($user) = $c->user();

  if ( $user->anonymous ) {
    __stop_tracking( $c );
    $c->redirect_to('/');

  } else {
    $c->render( template => 'error/logged_not_track');
  }

  return;
}

sub _r_track_again {
  my ($c) = @_;

  __start_tracking( $c );
  $c->redirect_to('/');

  return;
}

sub __stop_tracking {
  my ($c) = @_;

  $c->stash->{_do_not_track_} = 1;

  return;
}

sub __start_tracking {
  my ($c) = @_;

  $c->session; # To make sure the session is loaded
  $c->stash->{_do_not_track_} = 0;

  return;
}

sub __anonymous {
  return SorWeTo::User->unknown_user();
}

1;
