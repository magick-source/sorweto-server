package SorWeTo::Server::Plugins::Login::Base;

use Mojo::Base qw(Mojolicious::Plugin);

use SorWeTo::Db::User;
use SorWeTo::Db::UserLogin;
use SorWeTo::Db::TmpBlob;

use SorWeTo::User;
use SorWeTo::Error;

use SorWeTo::Utils::Digests qw();

use JSON qw(from_json to_json);

sub login_successful {
  my ($self, $c) = @_;

  # Maybe in the future we will support hooks on login!
  # so we want to call this even for api logins, but we don't want
  # to redirect api calls
  return if $c->stash->{'swt.is_api'};

  my $goto = '/';
  $goto = delete $c->session->{goto_after_login}
    if $c->session->{goto_after_login};

  return $c->redirect_to( $goto );
}

sub create_user_if_available {
  my ($self, $username, $user_data) = @_;

  die SorWeTo::Error->new(
      message => "Invalid Username",
    ) unless $username =~ m{\A[A-Za-z]\w+\z};

  my ($user) = SorWeTo::Db::User->search({ username => $username });
  return if $user; # user exists, we return nothing.

  my %uinfo = ( username => $username );
  for my $k (qw(display_name flags)) {
    $uinfo{ $k } = $user_data->{ $k };
  }
  $uinfo{ flags } = 'pending'
    unless $uinfo{ flags };

  $user = SorWeTo::Db::User->create(\%uinfo);
  $user = SorWeTo::User->from_dbuser( $user );

  return $user;
}

sub add_login_options {
  my ($self, $user, @logins) = @_;

  die SorWeTo::Error->weird(
      debug => "Trying to link login options with <@{[$user//'--undef--']}>"
    ) unless $user and $user->isa("SorWeTo::User");

  for my $login (@logins) {
    my $rec = {
        flags   => 'active', # can be overriden by the backends
        %$login,
        user_id => $user->user_id,
      };
    if ($rec->{info} and ref $rec->{info}) {
      $rec->{info} = to_json( $rec->{info}, {utf8=>1} );
    }
    SorWeTo::Db::UserLogin->insert( $rec );
  }
}

sub get_login_option {
  my ($self, $type, $identifier) = @_;

  my ($rec) = SorWeTo::Db::UserLogin->search({
      login_type  => $type,
      identifier  => $identifier,
      flags       => 'active',
    });

  eval {
    $rec->{info} = from_json( $rec->info, {utf8=>1} );
    1;
  };

  return $rec;
}

sub get_login_option_by_username {
  my ($self, $type, $username) = @_;

  my ($user) = SorWeTo::Db::User->search({ username => $username });
  return unless $user;

  my ($rec) = SorWeTo::Db::UserLogin->search({
      login_type  => $type,
      user_id     => $user->id,
      flags       => 'active',
    });
  
  eval {
    $rec->{info} = from_json( $rec->info, {utf8=>1} );
    1;
  };

  return $rec;
}

sub hash_password {
  my ($self, $password) = @_;

  return SorWeTo::Utils::Digests::make_salted_hash( $password );
}

sub is_password_correct {
  my ($self, $password, $hash) = @_;

  return SorWeTo::Utils::Digests::check_salted_hash( $password, $hash );
}

sub _user_error {
  my ($self, $message, @args) = @_;

  return SorWeTo::Error->new(
      message => $message,
      @args,
    );
}

sub _user_warning {
  my ($self, $message, @args) = @_;

  return SorWeTo::Error->new(
      message     => $message,
      error_type  => 'warning',
      @args,
    );
}

1;
