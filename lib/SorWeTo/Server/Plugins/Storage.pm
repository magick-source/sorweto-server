package SorWeTo::Server::Plugins::Storage;

use Mojo::Base 'Mojolicious::Plugin';

has config  => sub { {} };

sub dependences {
  return
}

sub register {
  my ($self, $app, $config) = @_;

  $config ||= {};
  $self->config( $config );

  use Data::Dumper;
  print STDERR "Storage config: ", Dumper($config);

  return $self;
}


1;
