package SorWeTo::Server::Plugins::CookieConsent;

use Mojo::Base qw(Mojolicious::Plugin);

has cookie_name => 'swt_cookie_consent';
has cookie_path => '/';
has default_expiration  => 6*30*24*60*60; #show every 6 months.

sub register {
  my ($self, $app, $conf) = @_;

  $app->routes->api->get('cookie/consent')->to(cb => sub { $self->consent( @_ ) });

  $app->hook( before_dispatch => sub { $self->_check_cookie( @_ ) });

  $app->html_hook( html_body_end => sub { $self->_html_body_end( @_ ) });

  return $self;
}

sub consent {
  my ($self, $c) = @_;

  $self->_set_cookie( $c );

  $c->render(json => {result=>"ok"});
}

sub _check_cookie {
  my ($self, $c) = @_;

  my $stash = $c->stash;
  return if exists $stash->{'swt.cookie_consent'};

  my $consent = $c->signed_cookie( $self->cookie_name ) || 0;

  my $is_home = $c->req->url->path eq '/';

  if (!$consent and $is_home) {
    my $cnt = $c->session->{'swt.consent_count'}++;
    if ( $cnt > 3 ) {
      $consent = 1;
      $self->_set_cookie( $c );
    }
  }

  my $cnt = $c->session->{'swt.consent_count'} || '-';

  $c->stash->{'swt.cookie_consent'} = $consent;

  return;
}

sub _set_cookie {
  my ($self, $c) = @_;

  my $expires = time + $self->default_expiration;
  my $options = {
      expires   => $expires,
      httponly  => 1,
      path      => $self->cookie_path,
      samesite  => 'lax',
    };
  $c->signed_cookie( $self->cookie_name, time, $options);

  delete $c->session->{'swt.cookie_consent'};

  return;
}

sub _html_body_end {
  my ($self, $c) = @_;

  return
    if $c->stash->{'swt.cookie_consent'};

  return 
    if $c->stash->{_do_not_track_};

  return $c->include('inc/cookie_toast');
}

1;
