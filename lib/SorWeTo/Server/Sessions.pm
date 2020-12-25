package SorWeTo::Server::Sessions;

use Mojo::Base -base;
use Mojo::Util qw(b64_decode b64_encode);

# This package have all of the functionality in Mojolicious::Sessions
# We forked it to allow for server side sessions - this package keeps
# most of the functionality of Mojolicious::Sessions, except storing
# the session as a cookie - which is delegated to the default backend
# SWT::Srv::Sessions::Cookies - which can be replaced with other options
# of which, we are implementing SWT::Srv::Sessions::MySQL - other
# options for the near future are Redis and, maybe, memcache

use SorWeTo::Server::Sessions::Cookies;

use Digest::SHA;
use Time::HiRes qw();

has [qw(cookie_domain secure)];
has cookie_name        => 'swt_sessid';
has cookie_path        => '/';
has default_expiration => 3600;
has deserialize        => sub { \&Mojo::JSON::j };
has serialize          => sub { \&Mojo::JSON::encode_json };

has backend => sub {
  return SorWeTo::Server::Sessions::Cookies->new();
};

use constant CURRENT_COOKIE_VERSION => 1;

sub load {
  my ($self, $c) = @_;

  my $stash = $c->stash;
  
  return if $stash->{'mojo.session_id'};

  return unless my $sess_id = $c->signed_cookie($self->cookie_name);

  if ($sess_id eq 'DoNotTrack') {
    $stash->{_do_not_track_} = 1;
    $stash->{'mojo.session_id'} = $sess_id;
    return;
  }

  my $sess_data = $self->backend->load( $c, $sess_id );
  return unless $sess_data;
  # just to allow for future upgrades without breaking
  # existing sessions.
  my ($version,$value) = split /\+/, $sess_data, 2;
  return if $version > CURRENT_COOKIE_VERSION; 

  $value =~ y/-/=/;
  return unless my $session = $self->deserialize->(b64_decode $value);

  my $expiration = $session->{expiration} // $self->default_expiration;
  return if !(my $expires = delete $session->{expires}) && $expiration;
  return if defined $expires && $expires <= time;

  return unless $stash->{'mojo.active_session'} = keys %$session;
  $stash->{'mojo.session'} = $session;
  $stash->{'mojo.session_id'} = $sess_id;
  $session->{flash} = delete $session->{new_flash} if $session->{new_flash};

  # we only really care if it was empty or not
  $stash->{'swt.session_loaded_keys'} = keys %$session;

  return;
}

sub store {
  my ($self, $c) = @_;

  my $stash = $c->stash;
  my $session = $stash->{_do_not_track_} ? {} : $c->session;

  # when redirecting to another page we need to
  # add the errors from the stash to the flash
  # to make them available for later
  if ( $c->res->is_redirect and $stash->{errors}) {
    $session->{new_flash}->{errors} = $stash->{errors};
  }

  return unless $stash->{'mojo.active_session'}
            or  keys %$session
            or  $stash->{'mojo.session_id'}
            or  $stash->{_do_not_track_};

  my $sess_id;
  if ($stash->{_do_not_track_}) {
    $sess_id = 'DoNotTrack';
  } elsif ($stash->{'mojo.session_id'}) {
    $sess_id = $stash->{'mojo.session_id'};
  }
  unless ($stash->{_do_not_track_}) {
    if ( ($sess_id and $sess_id eq 'DoNotTrack')
        or ($session and keys %$session)) {
      if (!defined $sess_id or $sess_id eq 'DoNotTrack') {
        $sess_id = _generate_session_id();
      }
    }
  }

  # Handle flash
  my $old = delete $session->{flash};
  $session->{new_flash} = $old if $stash->{'mojo.static'};
  delete $session->{new_flash} unless keys %{$session->{new_flash}};

  # Generate "expire" value from "expiration" if necessary
  my $expiration = $session->{expiration};
  unless (defined $expiration) {
    $expiration = $sess_id eq 'DoNotTrack'
        # We want the do not track session to last for a year
        # not just 1 hour - that would not be much of a no tracking
        # solution, would it?
        ? 365 * 24 * 60 * 60 
        : $self->default_expiration;
  }
  my $default    = delete $session->{expires};
  # this is one of the bits we diverge from Mojo - we want the
  # session to keep extending as long as it is being used
  # unless $session->{expiration} is explicitly set to 0
  my $expires;
  if ( $session->{logged_out} ) {
    $expires = time - 3600;

  } elsif ( $expiration ) {
    $expires = time + $expiration;

  } elsif ( $default ) {
    $expires = $default;
  }


  my $options = {
    domain    => $self->cookie_domain,
    expires   => $expires,
    httponly  => 1,
    path      => $self->cookie_path,
    secure    => $self->secure,
    samesite  => 'Lax',
  };
  $c->signed_cookie($self->cookie_name, $sess_id, $options);

  # it doesn't matter what's in the session, it is just a trow out
  # if the user doesn't want to be tracked, they can only use features
  # that don't need any type of session. Any mechanism that allows passing
  # data from one request to the next would allow tracking
  return if $sess_id eq 'DoNotTrack';

  # we need to save the session if it have data
  # or if the version we have stored had data
  # This doesn't update the expiration date of the
  # session data itself, but as it is empty, it doesn't matter
  my $needs_saved = ($session and %$session);
  $needs_saved  ||= $c->stash->{'swt.session_loaded_keys'};
  return unless $needs_saved;

  if ($expires) {
    $session->{expires} = $expires;
  }

  my $value = b64_encode $self->serialize->( $session ), '';
  $value =~ y/=/-/;
  $value = CURRENT_COOKIE_VERSION.'+'.$value;

  #TODO(maybe): calculate some digest of the serialized data and
  #     and compare that with the version already store
  #     to see if it is worth updating the database
  #     That would imply moving the expiration time out of the
  #     serialized blob, but that may not be a problem

  $self->backend->store( $c, {
          session_id  => $sess_id,
          value       => $value,
          expires     => $expires,
    });

  return;
}

sub _generate_session_id {
  my $digest = Digest::SHA->new( 256 )
          ->add( $$, +{}, Time::HiRes::time(), rand(time()) )
          ->hexdigest();
  return substr( $digest, hex(substr($digest, 0, 1)), 16 );
}

1;

=encoding utf8

=head1 NAME

SorWeTo::Server::Sessions - Session manager with pluggable storage backend

=head1 SYNOPSIS
  
  use SorWeTo::Server::Sessions;
  my $sessions = SorWeTo::Server::Sessions->new;
  $sessions->default_expiration(86400);
  $sessions->backend( SorWeTo::Server::Sessions::MySQL->new() );


