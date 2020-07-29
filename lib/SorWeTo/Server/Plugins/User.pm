package SorWeTo::Server::Plugins::User;

use Mojo::Base qw(Mojolicious::Plugin);

use SorWeTo::Db::User;
use SorWeTo::User;

has __user  => undef;
has helpers => sub { {} };

sub register {
  my ($self, $app, $conf) = @_;

  print STDERR "on SWT::Srv::Plg::User->register\n";

  $app->renderer->add_helper(
      add_user_helper => sub { $self->add_user_helper( @_ ) }
    );

  $app->renderer->add_helper( user => sub { $self->get_user( @_ ) });
  $app->renderer->add_helper(
      user_by_username => sub { $self->user_by_username( @_ ) }
    );

  my $r = $app->routes;
  $r->route('/user/do-not-track')->to(cb => \&_r_do_not_track );
  $r->route('/user/track-again')->to(cb => \&_r_track_again );
  
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

  unless ($c->stash->{__userobj}) {
    my $userobj;

    my $user_id = $c->session->{user_id};
    if ($user_id) {
      my ($user) = SorWeTo::Db::User->retrieve( $user_id );

      if ($user and $user->id) {
         $userobj = SorWeTo::User->from_dbuser( $user );
      }
    }

    $userobj ||= __anonymous();
    
    $c->stash->{__userobj} = $userobj;
  }

  return $c->stash->{__userobj};
}

sub user_by_username {
  my ($self, $c, $username) = @_;

  # TODO: Get user object from database if possible, and return it
  print STDERR "called user_by_username '$username'\n";

  return;
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
  return SorWeTo::User->new( @_ );
}

1;
