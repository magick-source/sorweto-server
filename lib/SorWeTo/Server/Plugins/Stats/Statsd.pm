package SorWeTo::Server::Plugins::Stats::Statsd;

use Mojo::Base -base;

use Net::Statsd;

has basepath  => '';
has hostname  => 'localhost';
has port      => 8125;

sub new {
  my ($class, $conf) = @_;

  my $self = $class->SUPER::new();

  $self->basepath( $conf->{basepath} )
    if $conf->{basepath};
  $self->hostname( $conf->{hostname} )
    if $conf->{hostname};
  $self->port( $conf->{port} )
    if $conf->{port};

  return $self;
}

sub timing {
  my ($self, $path, $timing) = @_;

  $path = join '.', $self->basepath, $path
    if $self->basepath;

  local $Net::Statsd::HOST  = $self->hostname;
  local $Net::Statsd::PORT  = $self->port;

  Net::Statsd::timing( $path, $timing );
}

sub count {
  my ($self, $path) = @_;

  $path = join '.', $self->basepath, $path
    if $self->basepath;

  local $Net::Statsd::HOST  = $self->hostname;
  local $Net::Statsd::PORT  = $self->port;

  Net::Statsd::increment( $path );
}

1;
