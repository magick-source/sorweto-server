package SorWeTo::Server::Plugins::Storage::Filesystem;

use Mojo::Base 'Mojolicious::Plugin';

use Fcntl qw( O_WRONLY O_TRUNC O_CREAT );

has config => sub { {} };

sub register {
  my ($self, $storage, $config) = @_;

  $self->config( $config || {} );

  return $self;
}

sub get_file {
  my ($self, $path, $instanceconfig) = @_;

  my %config = %{ $self->config };
  for my $k (keys %$instanceconfig) {
    $config{ $k } = $instanceconfig->{$k};
  }

  my $basedir = $config{ basedir };
  substr($basedir,-1,1) = ''
    if substr($basedir,-1) eq '/';

  $path = $basedir.$path;

  print STDERR "getting '$path'\n";

  if ( -e $path ) {
    if ( -r $path ) {
      open my $fh , '<', $path;

      return 0, $fh;
    } else {
      return 403;
    }
  }

  return 404;
}

sub put_file {
  my ($self, $path, $bodyref, $instanceconfig) = @_;

  my %config = %{ $self->config };
  for my $k (keys %$instanceconfig) {
    $config{ $k } = $instanceconfig->{$k};
  }

  my $basedir = $config{ basedir };
  substr($basedir,-1,1) = ''
    if substr($basedir,-1) eq '/';

  $path = $basedir.$path;

  print STDERR "putting '$path'\n";

  sysopen( my $fh, $path, O_WRONLY|O_CREAT|O_TRUNC ) or return;
  syswrite( $fh, $$bodyref );
  close $fh;

  return 1;
}

sub is_directory {
  my ($self, $path, $instanceconfig) = @_;

  my %config = %{ $self->config };
  for my $k (keys %$instanceconfig) {
    $config{ $k } = $instanceconfig->{$k};
  }

  my $basedir = $config{ basedir };
  substr($basedir,-1,1) = ''
    if substr($basedir,-1) eq '/';

  $path = $basedir.$path;

  print STDERR "checking dir '$path'\n";

  return -d $path;
}

sub is_file {
  my ($self, $path, $instanceconfig) = @_;

  my %config = %{ $self->config };
  for my $k (keys %$instanceconfig) {
    $config{ $k } = $instanceconfig->{$k};
  }

  my $basedir = $config{ basedir };
  substr($basedir,-1,1) = ''
    if substr($basedir,-1) eq '/';

  $path = $basedir.$path;

  print STDERR "checking is_file '$path'\n";

  return -e $path;
}

sub make_dir {
  my ($self, $path, $instanceconfig) = @_;

  my %config = %{ $self->config };
  for my $k (keys %$instanceconfig) {
    $config{ $k } = $instanceconfig->{$k};
  }

  my $basedir = $config{ basedir };
  substr($basedir,-1,1) = ''
    if substr($basedir,-1) eq '/';

  $path = $basedir.$path;

  print STDERR "make directory '$path'\n";

}

1;
