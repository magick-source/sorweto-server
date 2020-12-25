package SorWeTo::Server::Plugins::Log;

use Mojo::Base qw(Mojolicious::Plugin);

use Data::Dumper;
use Time::HiRes qw();

use JSON qw(to_json);

has level => 5;
has evlog_level => 5;

my %levels = (
  trace   => 9,
  notice  => 6,
  info    => 4,
  warning => 3,
  error   => 2,
  fatal   => 1,
);

sub info_level { 5 }
sub notice_level { 6 }

sub register {
  my ($self, $app, $conf) = @_;

  $app->evlog( $self );
  
  $app->helper( evlog     => sub { $self->ev_log(@_); } );
  $app->helper( evinfo    => sub { $self->ev_info( @_ ); } );
  $app->helper( evnotice  => sub { $self->ev_notice( @_ ); } );
  $app->helper( tweet     => sub { $self->_tweet( @_ ); } );
  $app->helper( growl     => sub { $self->_growl( @_ ); } );

  $self->level( $conf->{evlog_level} || $conf->{log_level} || 5 );

  $app->hook( before_dispatch => sub { $self->_start_event( @_ ) } );
  $app->hook( after_dispatch  => sub { $self->_send_event( @_ ) } );

### TODO: Add support for real eventlog systems

  return $self;
}

sub ev_log {
  my ($self, $c, $path, $data) = @_;

  my $evt = $c->stash->{_event2log} ||= $self->_init_event($c);

  my $is_array = $path =~ s{\@\z}{};
  my @parts = split /\./, $path;
  my $last = pop @parts;
  my $box = $evt;
  for my $part (@parts) {
    $box = $box->{$part} ||= {};
  }

  if ($is_array) {
    push @{ $box->{ $last } }, $data;
  } else {
    $box->{$last} = $data;
  }

  print STDERR "EventLogged to: $path\n";

  return;
}

sub _tweet {
  my ($self, $c, $tweet) = @_;

  my $evt = $c->stash->{_event2log} ||= $self->_init_event($c);
  $evt->{'track-n-trace'}->{tweet}->{$tweet}++;

  return;
}

sub _growl {
  my ($self, $c, $growl, $data) = @_;

  $growl =~ s{\.}{-}g;

  $self->ev_log($c, "track-n-trace.growl.$growl@", $data);

  return;
}

sub _trace {
  my ($self, $c, $type, $mask, @data) = @_;
  
  return if $self->level < $levels{ $type };

  my $logline = _apply_mask( $mask, @data );
  $logline =~ s{\n+\z}{};
  $logline =~ s{\n}{\n\t}g;
  print STDERR "\U$type: ", $logline,"\n";

  return if $self->evlog_level < $levels{ $type };

  $self->ev_log( $c, 'track-n-trace.log@', {
      type  => $type,
      log   => $logline,
      time  => int(Time::HiRes::time()*1000),
    });
}

sub ev_info {
  my ($self, $c, $mask, @data) = @_;

  $self->_trace( $c, 'info', $mask, @data);
}

sub ev_notice {
  my ($self, $c, $mask, @data) = @_;

  $self->_trace( $c, 'notice', $mask, @data);
}

sub _apply_mask {
  my ($mask, @data) = @_;

  local $Data::Dumper::Indent = 0;
  
  ($mask, @data) = map {  $_ =~ s{\$VAR1 = }{}; $_ =~ s{\;}{}; $_ }
    map { $_ // '<UNDEF>' }
    map { ref $_ ? '<<'. Dumper( $_ ) .'>>' : $_ }
      $mask, @data;
  
  my $res;
  if ($mask =~ m{\%} ) {
    $mask =~ s{\%T}{Time::HiRes::time}eg;
    $res = sprintf $mask, @data;
  } else {
    $res = join '', $mask, @data;
  }

  return $res;
}

sub _init_event {
  my ( $self, $c ) = @_;

  print STDERR "Initing event\n";

  my $event = {
    core => {
      time_created  => int(Time::HiRes::time() * 1000 ),
      type          => 'WEB',
      application   => $c->stash('sitename'),
    },
    request => {
      hostname    => $c->req->url->base->host,
      method      => $c->req->method,
      url         => $c->req->url->path->to_string,
      header_size => $c->req->header_size,
      body_size   => $c->req->body_size,
    },
  };

  return $event;
}

sub _start_event {
  my ($self, $c) = @_;

  $c->stash->{_event2log} ||= $self->_init_event($c);

  return;
}

sub _send_event {
  my ($self, $c) = @_;

  my $evt = delete $c->stash->{_event2log};
  return unless $evt;

  $evt->{core}->{time_sent} = int(Time::HiRes::time() * 1000);

  my $evs = to_json( $evt, { pretty => 0, utf8 => 1 });

### TODO: send the event for real! This will do for now
  print STDERR "EVT<<\n$evs\n>>\n\n";
}

1;
