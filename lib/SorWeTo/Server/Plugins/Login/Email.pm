package SorWeTo::Server::Plugins::Login::Email;

use Mojo::Base qw(SorWeTo::Server::Plugins::Login::Base);

use SorWeTo::Error;

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

    my $email;
    if ($email = $c->param('email')) {
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
        push @errors, 'Invalid password - 8+ characters with numbers or punctuation, 12+ no restrictions';
      }
    } else {
      push @errors, 'the Password is required';
    }

    my $passhash;
    if (my $passwd2 = $c->param('password2')) {
      $user{password2} = $passwd2;
      if ( $password eq $passwd2 ) {
        $passhash = $self->hash_password( $password );
      } else {
        push @errors, 'Confirmation password must match the password';
      }
    } else {
      push @errors, 'Confirmation password is required (and must match the password)';
    }

    unless (@errors) {
      eval {
        my $user = $self->create_user_if_available( $uname );
        if ( $user ) {
          my %data = (
            user_id => $user->user_id,
            email   => $email,

          );
          $self->add_login_options( $user,
              { login_type =>'email',
                identifier => $email,
                info       => {
                  password => $passhash,
                },
              },
              { login_type =>'username',
                identifier => $user->username,
                info       => {
                  password => $passhash,
                },
              },
            );

          $c->send_email('email/login/confirm_email', {
                email     => $email,
                username  => $user->username,

              });
        } else {
          push @errors, 'Username selected is not available, please try a different one';
        }
        1;
      } or do {
        my $err = $@;

        unless (ref $err and $err->isa("SorWeTo::Error")) {
          $err = SorWeTo::Error->weird(debug => $err);
        }
        push @errors, $err;
      };
      
      unless ( @errors ) {
        return $c->render('login/email/account_created');
      }
    }
  }

  $c->stash->{user} = \%user;
  $c->stash->{errors} = \@errors;
  $c->stash->{show_sidebar} = 0;

  $c->render('login/email/create_account');
}

1;
