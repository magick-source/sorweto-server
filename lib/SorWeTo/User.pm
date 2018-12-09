package SorWeTo::User;

use Mojo::Base -base;

has username => undef;
has user_id  => undef;

has anonymous => sub {
  my ($user) = @_;

  return $user->user_id ? 0 : 1;
};

1;
