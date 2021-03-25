package SorWeTo::Server::Plugins::Login::Email;

use Mojo::Base qw(SorWeTo::Server::Plugins::Login::Base);

use SorWeTo::Error;

use SorWeTo::Utils::DataChecks qw(
    check_email
    check_password
  );

use SorWeTo::Utils::Digests qw(
  generate_random_hash
);

has config => sub { {} };

sub register {
  my ($self, $login, $conf) = @_;

  $self->config( $conf || {} );

  my $r = $login->app->routes;

  $r->any('/login/email')->to(cb => sub { $self->_login_email( @_ ) } );
  $r->any('/create_account/email')->to(cb => sub { $self->_new_user( @_ );});
  $r->any('/login/confirm_email/:token')->to(cb => sub {
      $self->_confirm_email( @_ );
    });
  $r->any('/login/email/forgot-password')->to(cb => sub {
      $self->_forgot_password( @_ );
    });
  $r->any('/login/email/forgot-password/:tmp_hash'
      => [tmp_hash  => qr/[0-9a-h]{30}/]
    )->to(cb => sub {
      $self->_forgot_password_checked( @_ );
    });

  $login->app->helper( inline_login => sub { $self->_inline_login( @_ ) });

  return $self;
}

sub set_loginform_data {
  my ($self, $c, $login_data) = @_;

  $login_data->{email} = {
    username  => '',
    password  => '',
  };
  
  if (my $filledup = $c->flash('email_login')) {
    $login_data->{email} = $filledup;
  }

  return;
}

sub _login_email {
  my ($self, $c) = @_;

  my $username  = $c->param('username');
  my $passwd    = $c->param('password');

  unless ($username and $passwd) {
    return $self->_login_error(
        $c, 
        $c->__('error-login-username-or-password-missing')
      );
  }

  $self->__inline_login( $c, $username, $passwd );

  if ($c->stash->{'login.errors'}) {
    return $self->_finish_with_error( $c, $username, $passwd );
  }

  return $self->login_successful( $c );

}

sub _inline_login {
  my ($self, $c) = @_;
  
  my $username  = $c->param('username');
  my $passwd    = $c->param('password');

  return unless $username and $passwd;
  
  $self->__inline_login( $c, $username, $passwd );

  $self->login_successful( $c );

  return;
}

sub __inline_login {
  my ($self, $c, $username, $passwd) = @_;

  if ( check_email( $username ) ) {
    return $self->__login_with_email( $c, $username, $passwd );

  } elsif ( $username =~ m{\A\w{3,18}\z} ) {
    return $self->__login_with_username( $c, $username, $passwd );

  } else {
    return $self->_login_error( $c,
        $c->__('error-login-invalid-username'),
      );
  }

}

sub __login_with_username {
  my ($self, $c, $username, $passwd ) = @_;

  my $login_option = $self->get_login_option_by_username( 'email', $username );

  return $self->__check_password( $c, $login_option, $passwd );
}

sub __login_with_email {
  my ($self, $c, $email, $passwd ) = @_;

  my $login_option = $self->get_login_option('email', $email);

  return $self->__check_password( $c, $login_option, $passwd );
}

sub __check_password {
  my ($self, $c, $login_option, $passwd) = @_;

  unless ( $login_option ) {
    $c->evinfo('no login_option found');

    return $self->_login_error( $c, 
         $c->__('error-login-username-or-password-invalid'),
      );
  }

  $login_option->info;

  my $passwd_isok = $self->is_password_correct(
        $passwd,
        $login_option->{info}->{password}
    );
  unless ( $passwd_isok ) {
    $c->evinfo("there is an login_otion, but the password is wrong");
    return $self->_login_error( $c, 
         $c->__('error-login-username-or-password-invalid'),
      );
  }

  $c->session->{user_id} = $login_option->user_id;
}

sub _login_error {
  my ($self, $c, $message) = @_;

  $c->add_user_error(
      $message,
      icon  => 'error',
    );

  $c->stash->{'login.errors'}++;

  return;
}

sub _finish_with_error {
  my ($self, $c, $username, $passwd) = @_;

  $c->flash({
      email_login => {
        username  => $username,
        password  => $passwd,
      },
    });

  return $c->redirect_to('/login/');
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
          $self->add_login_options( $user,
              { login_type =>'email',
                identifier => $email,
                info       => {
                  password => $passhash,
                },
                flags      => 'pending',
              }
            );

          my %data = (
            user_id   => $user->user_id,
            username  => $user->username,
            email     => $email,
          );
          $self->__send_activation_email( $c, \%data );
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

sub _confirm_email {
  my ($self, $c) = @_;

  my $token = $c->param('token');

  my $data  = $c->tmp_blob_load( 'checkemail', $token );
  unless ($data) {
    #TODO: maybe block IPs who fall here a few times
    return $c->render('login/email/error_confirming_email');
  }

  my ($user_login) = $self->get_login_option(
                        'email', $data->{email}, 'pending'
                      );

  unless ($user_login) {
    # This should not really happen, but... you never know, right?
    warn 'Valid tmp_blog for email confirmation, but no user_login';
    return $c->render('login/email/error_confirming_email');
  }

  $user_login->user_id;

  #MAYBE: add a 'set_flag' method in SorWeTo::Db?
  $user_login->flags('active');
  $user_login->update;

  # Email confirmed, no need for the blob anymore
  $c->tmp_blob_delete('checkemail', $token );

  $c->render( 'login/email/email_confirmed');
}

sub _forgot_password {
  my ($self, $c) = @_;

  my $username = $c->param('username');
  my $login;
  if ( $username =~ m{\A\w{3,18}\z} ) {
    $login = $self->get_login_option_by_username( 'email', $username );
    unless ($login) {
      $login = $self->get_login_option_by_username(
                  'email', $username, 'pending'
                );
    }

  } elsif ( check_email( $username ) ) {
    $login = $self->get_login_option('email', $username );
    unless ($login) {
      $login = $self->get_login_option('email', $username, 'pending' );  
    }

  }

  if ( $login ) {
    my ($user) = SorWeTo::Db::User->search_where( id => $login->user_id );
    my $data = {
        user_id   => $user->user_id,
        username  => $user->username,
        email     => $login->identifier,
      };

    if ( $login->flags =~ m{pending} ) {
      $self->__send_activation_email( $c, $data );

      return $c->render('login/email/account_not_activated');

    } else {
      $self->__send_change_password_email( $c, $data );

      return $c->render('login/email/forgot_password_email_sent');
    }
  }

  $c->render( 'login/email/forgot_password' );
}

sub _forgot_password_checked {
  my ($self, $c) = @_;

  my $token = $c->stash->{tmp_hash}; 
  my $data  = $c->tmp_blob_load( 'checkemail', $token );
  unless ($data) {
    return $c->reply->not_found;
  }

  my %pwd = ();
  my @errors = ();

  my $uname = $data->{username};

  my $password;
  if ($password = $c->param('password')) {
    $pwd{password} = $password;
    unless (check_password( $password, $uname )) {
      push @errors, 'Invalid password - 8+ characters with numbers or punctuation, 12+ no restrictions';
    }
  } else {
    push @errors, 'the Password is required';
  }

  my $passhash;
  if (my $passwd2 = $c->param('password2')) {
    $pwd{password2} = $passwd2;
    if ( $password eq $passwd2 ) {
      $passhash = $self->hash_password( $password );
    } else {
      push @errors, 'Confirmation password must match the password';
    }
  } else {
    push @errors, 'Confirmation password is required (and must match the password)';
  }

  @errors = ()
    unless keys %pwd;

  if ( keys %pwd and !@errors ) {
    my $login = $self->get_login_option('email', $data->{email} );

    $login->{info}->{password} = $passhash;
    $self->update_login_option( $login );

    # Password changed, no need for the blob anymore
    $c->tmp_blob_delete('checkemail', $token );

    return $c->render( 'login/email/password_changed' ); 
  }

  $c->stash->{errors} = \@errors;
  $c->stash->{'forgot-token'} = 1;
  $c->stash->{pwd} = \%pwd;
  $c->render( 'login/email/change_password' );
}

sub __send_activation_email {
  my ($self, $c, $data) = @_;

  my $username  = $data->{username};
  my $email     = $data->{email};

  my $tmp_id = generate_random_hash('checkemail');
  $c->tmp_blob_store( 'checkemail', $tmp_id, $data );
  $c->send_email('login/confirm_email', {
        email_type=> 'confirm-email',
        email     => $email,
        username  => $username,
        blob_id   => $tmp_id,
        confirm_url =>
          => $c->url_for("/login/confirm_email/$tmp_id")->to_abs,
      });

  return;
}

sub __send_change_password_email {
  my ($self, $c, $data) = @_;

  my $username  = $data->{username};
  my $email     = $data->{email};

  my $tmp_id = generate_random_hash('checkemail');
  $c->tmp_blob_store( 'checkemail', $tmp_id, $data );
  $c->send_email('login/change_password', {
        email_type=> 'change-password',
        email     => $email,
        username  => $username,
        blob_id   => $tmp_id,
        change_url =>
          => $c->url_for("/login/email/forgot-password/$tmp_id")->to_abs,
      });

  return;
}

1;
