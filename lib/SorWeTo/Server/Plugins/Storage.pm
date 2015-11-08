package SorWeTo::Server::Plugins::Storage;

use Mojo::Base 'Mojolicious::Plugin';

has config  => sub { {} };

has mounts  => sub { [] };

has plugins => sub {
      Mojolicious::Plugins->new(
          namespaces  => ['SorWeTo::Server::Plugins::Storage'],
        )
    };

has _plugins => sub { {} };

has app => sub { undef };

sub dependences {
  return;
}

sub register {
  my ($self, $app, $config) = @_;

  $config ||= {};
  $self->config( $config );

  my @secs = $app->config->keys_matching('^storage:');

  my @mounts = ();
  for my $sec (@secs) {
    push @mounts, scalar $app->config->config( $sec );
  }

  @mounts = sort { 
      length $b->{datapath} <=> length $a->{datapath}
      or $a->{datapath} cmp $b->{datapath}
    } @mounts;

  my %plugins = ();
  for my $mount (@mounts) {
    my $backend = lc($mount->{backend});
    next if $plugins{ $backend };

    my $config = $app->config->config("plugin:storage:$backend");
    my $plugin = $self->plugins->register_plugin(
        $backend, $self, $config
      );

    $plugins{ $backend }++;

    $mount->{_backend} = $backend;
    $self->_plugins->{$backend} = $plugin;
  }

  $self->mounts( \@mounts );

  $app->helper( storage => sub { $self } );

  return $self;
}

sub get_file {
  my ( $self, $path ) = @_;
  
  my ($plugin, $plugpath, $config) = $self->_plugin_for_path( $path );

  if ( $plugin ) {
    return $plugin->get_file( $plugpath, $config);
  }

  return 404;
}

sub put_file {
  my ( $self, $path, $body ) = @_;

  my ($plugin, $plugpath, $config) = $self->_plugin_for_path( $path );

  print STDERR "got '$plugin':'$plugpath' for '$path'\n";

  if ( $plugin ) {
    return $plugin->put_file( $plugpath, $body, $config);
  }

  return;
}

sub is_directory {
  my ($self, $path) = @_;

  my ($plugin, $plugpath, $config) = $self->_plugin_for_path( $path );

  if ($plugin) {
    return $plugin->is_directory( $plugpath, $config );
  }

  return;
}

sub is_file {
  my ($self, $path) = @_;

  my ($plugin, $plugpath, $config) = $self->_plugin_for_path( $path );

  if ($plugin) {
    return $plugin->is_file( $plugpath, $config );
  }

  return;
}

sub make_dir {
  my ($self, $path) = @_;

  my ($plugin, $plugpath, $config) = $self->_plugin_for_path( $path );

  if ($plugin) {
    return $plugin->make_dir( $plugpath, $config );
  }

  return;
}


sub _plugin_for_path {
  my ($self, $path) = @_;

  my $mounts = $self->mounts;
  for my $mount (@$mounts) {
    my $base = $mount->{datapath};
    $base .= '/' unless substr($base, -1) eq '/';
    next unless $path =~ m{^$base};

    (my $storpath = $path) =~ s{^$base}{};
    substr($storpath,0,0) = '/';

    my $backend = $mount->{_backend};
    my $plugin  = $self->_plugins->{ $backend };
    die "Error - missing plugin for 'storage:$backend'\n"
      unless $plugin;

    my %config = %$mount;
    delete @config{qw(backend datapath _backend)};

    return ($plugin, $storpath, \%config);
  }

  return;
}

1;
