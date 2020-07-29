package SorWeTo::Server::Plugins::UserErrors;

use Mojo::Base qw(Mojolicious::Plugin);

use SorWeTo::Error;

sub register {
  my ($self, $app, $conf) = @_;

  $app->helper(add_user_error     => \&_user_error          );
  $app->helper(add_user_warning   => \&_user_waring         );
  $app->helper(under_construction => \&_under_construction  );

  return $self;
}

sub _user_error {
  my ($c, $message, @args) = @_;

  __add_error( $c,
      SorWeTo::Error->new(
        message => $message,
        @args,
      )
    );

  return;
}

sub _user_warning {
  my ($c, $message, @args) = @_;

  __add_error( $c,
    SorWeTo::Error->new(
      message     => $message,
      error_type  => 'warning',
      @args,
    ),
  );

  return;
}

sub _under_construction {
  my ($c, $message, $link, @args) = @_;

  my $error = SorWeTo::Error->new(
      message     => $message,
      error_type  => 'info',
      icon        => 'tools',
      @args
    );

  __add_error( $c, $error );

  return $c->redirect_to( $link );
}

sub __add_error {
  my ($c, $error) = @_;

  my $errors = $c->stash->{errors} ||= [];

  push @$errors, $error;
}

1;

