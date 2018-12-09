package SorWeTo::Server::Plugins::Login::Email;

use Mojo::Base qw(Mojolicious::Plugin);

use SorWeTo::Utils::DataChecks qw(
    check_email
    check_password
  );

has config => sub { {} };

sub register {
  my ($self, $login, $conf) = @_;

  $self->config( $conf || {} );

  my $r = $login->app->routes;

  $r->route('/login/email')->to(cb => sub { $self->_login_email( @_ ) } );
  $r->route('/create_account/email')->to(cb => sub { $self->_new_user( @_ );});

  return $self;
}

sub _login_email {
  my ($self, $c) = @_;

  $c->render( text => 'Just some text to render');
}

sub _new_user {
  my ($self, $c) = @_;
  
  my %user = ();
  my @errors = ();
  if (my $uname = $c->param('username')) {
    $user{username} = $uname;
    if ($uname =~ m{\A\w{3,18}\z}) {
      my $old_user = $c->user_by_username( $uname );
      if ($old_user) {
        push @errors, 'Username already exists, please try a different one';
        # TODO: Suggest some alternatives
      }
    } else {
      push @errors, 'Invalid username - use 3 to 18 alphanumeric characters';
    }

    if (my $email = $c->param('email')) {
      $user{email} = $email;
      unless (check_email( $email )) {
        push @errors, 'Invalid email address';
      }
    } else {
      push @errors, 'Email Address is required';
    }

    my $password;
    if ($password = $c->param('password')) {
      $user{password} = $password;
      unless (check_password( $password, $uname )) {
        push @errors, 'Invalid password - 8+ characters with numbers, 12+ no restrictions';
      }
    } else {
      push @errors, 'the Password is required';
    }

    if (my $passwd2 = $c->param('password2')) {
      $user{password2} = $passwd2;
      unless ( $password eq $passwd2 ) {
        push @errors, 'Confirmation password must match the password';
      }
    } else {
      push @errors, 'Confirmation password is required (and match the password)';
    }

    unless (@errors) {
      push @errors, "TODO: actually create the account\n";
      # TODO: actually create the account!
    }
  }

  $c->stash->{user} = \%user;
  $c->stash->{errors} = \@errors;

  $c->render('login/email/create_account');
}

1;
