package SorWeTo::Server::Plugins::Stats;

use Mojo::Base qw(Mojolicious::Plugin);

has backend => sub {
    warn "Plugin Stats: using DevNull backend";
    require SorWeTo::Server::Plugins::Stats::DevNull;
    return SorWeTo::Server::Plugins::Stats::DevNull->new();
  };

has enabled_metrics => sub {
    my %enabled = map { $_ => 1 } qw(
        wallclock
        pageviews
        request_count
        response_type
      );
    return \%enabled;
  };

has disabled      => sub { {} };

has 'app';

sub register {
  my ($self, $app, $conf) = @_;

  # we are going to mess it up, so copying just in case
  $conf = { %$conf };

  $self->_metrics_config( $conf );
  
  if ($conf->{backend}) {
    $self->_load_backend( $conf );
  }

  $self->_hook_metrics( $app );

  $app->helper( stats_count   => sub { $self->_stats_count( @_ ) });
  $app->helper( stats_timing  => sub { $self->_stats_timing( @_ ) });

  $app->helper(
      register_hook_count => sub { $self->_register_hook_count( @_ ) }
    );

  return $self;
}


# Helpers
sub _register_hook_count {
  my ($self, $c, $hook_name, $metric_path) = @_;

  $c->app->hook( $hook_name => sub {
      my ($c) = @_;
      use Data::Dumper;
      print STDERR "on $hook_name handler: ", Dumper( \@_ );
      $c->stats_count( $metric_path );
    });
}

sub _stats_count {
  my ($self, $c, $metric_path) = @_;

  unless ($metric_path) {
    warn "Counting nothing? no metric name or path?";
    return;
  }

  return unless $self->__metric_is_enabled( $metric_path );

  $self->backend->count( $metric_path );

  return;
}

sub _stats_timing {
  my ($self, $c, $metric_path, $timing) = @_;

  unless ($metric_path) {
    warn "timing nothing? no metric name or path?";
    return;
  }

  return unless $self->__metric_is_enabled( $metric_path );

  $self->backend->timing( $timing );

  return;
}

sub __metric_is_enabled {
  my ($self, $metric) = @_;

  my @bits = split /\./, $metric;
  my $i = 0;
  while ($i < scalar @bits) {
    my $metric_name = join '.', @bits[0..$i];
    unless ( $self->enabled_metrics->{ $metric_name } ) {
      if ( $self->disabled->{ $metric_name } 
          or $self->disabled->{ all } ) {
        return;
      }
    }
    $i++;
  }

  return 1;
}

# Loading
sub _load_backend {
  my ($self, $conf) = @_;

  my $backend = delete $conf->{backend};

  my $class;
  if ( $backend =~ m{\A\w+\z} ) {
    $class = "SorWeTo::Server::Plugins::Stats::$backend";
  } else {
    $class = $backend;
  }

  eval "use $class; 1" or die $@;

  $self->backend( $class->new( $conf ) );

  return;
}

sub _metrics_config {
  my ($self, $conf) = @_;

  my %to_set   = (enable=>{},disable=>{});
  my %disabled  = ();

  if ($conf->{disable_all}) {
    delete $conf->{disable_all};
    $self->disabled->{all} = 1;
    @{ $self->enabled_metrics } = ();
  }

  for my $k (keys %$conf) {
    next unless $k =~ m{\A(?:dis|en)able_};
    # don't disable with enable=false or the other way around
    unless ( $conf->{$k} ) {
      warn "config '$k' is false - enable_/disable_ keys must always have true values";
      next;
    }

    my ($do, $metric) = split /_/, $k, 2;
    $to_set{ $do }{ $metric }++;

    delete $conf->{ $k };
  }
  for my $k (keys %{ $to_set{enable} }) {
    if ( $to_set{disable}{ $k } ) {
      warn "metric '$k' is both enabled and disabled in config - keeping enabled";
      delete $to_set{disable}{ $k };
    }
  }
  $self->disabled->{$_}++ for keys %{ $to_set{disable} };
  $self->enabled->{$_}++ for keys %{ $to_set{enable} };

  return;
}

# Hookup stuff
my @event_metrics = qw(
    wallclock
    pageviews
    request_count
    request_type
    request_size
    response_code
    response_type
    response_size
  );

sub _hook_metrics {
  my ($self, $app, $to_set) = @_;

  for my $tp (@event_metrics) {
    if ( $self->enabled_metrics->{ $tp } ) {
      $app->hook(log__event_sent => sub { $self->_event_sent( @_ ) });
      last;
    }
  }

  return;
}

sub _event_sent {
  my ($self, $event, $c) = @_;

  my %metrics = %{$self->enabled_metrics};
  
  my $type = $event->{request}->{type};

  if ($metrics{ request_count }) {
    $self->backend->count('requests.count');
    if ( $metrics{ request_type }) {
      $self->backend->count("$type.requests.count");
    }
  }

  if ($metrics{ wallclock }) {
    $self->backend->timing( "wallclock", $event->{core}->{wallclock} );
    if ($metrics{ request_type }) {
      $self->backend->timing( "$type.wallclock", $event->{core}->{wallclock} );
    }
  }

  if ($metrics{ pageviews } and $event->{request}->{type} eq 'page') {
    if ( !$metrics{ request_type} ) { # pageviews is just one of the types
      $self->backend->count("page.requests.count");
      $self->backend->timing( "page.wallclock", $event->{core}->{wallclock} );
    }
  }

  if ($metrics{ request_size }) {
    my $size  = $event->{request}->{header_size}
              + $event->{request}->{body_size};
    $self->backend->timing( "request.size", $size );
    if ($metrics{ request_type }) {
      $self->backend->timing( "$type.request.size", $size );
    }
  }

  if ($metrics{ response_code }) {
    my $code  = $event->{response}->{code};
    $self->backend->count( "response.by_code.$code.count", $code );
    if ($metrics{ request_type }) {
      $self->backend->count( "$type.response.by_code.$code.count", $code );
    }
  }
  if ($metrics{ response_size }) {
    my $size  = $event->{response}->{header_size}
              + $event->{response}->{body_size};
    $self->backend->timing( "response.size", $size );
    if ($metrics{ request_type }) {
      $self->backend->timing( "$type.response.size", $size );
    }
  }
  if ($metrics{ reponse_type}) {
    my $rtype = $event->{response}->{type};
    $self->backend->count("response.by_type.$rtype.count");
    if ($metrics{ request_type}) {
      $self->backend->count("$type.response.by_type.$rtype.count");
    }
  }

}

1;
