package SorWeTo::User;

use Mojo::Base -base;

has _user => undef;

sub from_dbuser {
  my ($class, $dbuser) = @_;

  return SorWeTo::User->new(
    _user => $dbuser,
  );
}

sub username {
  my ($self) = @_;

  return unless $self->_user;
  return $self->_user->username;
}

sub display_name {
  my ($self) = @_;

  return unless $self->_user;
  return $self->_user->display_name;
}

sub user_id {
  my ($self) = @_;

  return unless $self->_user;
  return $self->_user->id;
}

sub is_anonymous {
  my ($self) = @_;

  return $self->_user ? 0 : 1;
};
*anonymous = *is_anonymous;

sub has_right {
  #TODO: implement support for different permission backends
  return 0;
}

1;
