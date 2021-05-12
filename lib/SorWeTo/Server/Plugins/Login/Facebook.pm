package SorWeTo::Server::Plugins::Login::Facebook;

use Mojo::Base qw(SorWeTo::Server::Plugins::Login::Base);

use SorWeTo::Utils::String qw(urify);

use MIME::Base64 qw(decode_base64);
use Digest::SHA qw(hmac_sha256);
use JSON qw(from_json);
use LWP::UserAgent; 

use SorWeTo::Error;

has config => sub { {} };

sub register {
  my ($self, $login, $conf) = @_;

  $self->config( $conf || {} );

  $login->app->html_hook( html_body_end => sub { $self->_html_body_end( @_ ) } );

  my $r = $login->app->routes;
  $r->api->post('login/facebook' => sub { $self->_handle_login( @_ ) } );

  return $self;
}

sub set_loginform_data {
  my ($self, $c, $login_data) = @_;

  $c->stash->{on_login_page} = 1;

  return;
}

sub _handle_login {
  my ($self, $c) = @_;

  unless ($self->config->{app_id}) {
    $c->res->code(501);
    return;
  }

  my $sig_req = $c->req->param('signedRequest');
  unless ($sig_req) {
    $c->res->code( 400 );
    return;
  }
  my ($sig, $payload) = split /\./, $sig_req;
  $sig = decode_fb_data( $sig );

  my $app_secret = $self->config->{app_secret};
  my $calc_sig = hmac_sha256($payload, $app_secret);

  unless ( $sig eq $calc_sig ) {
    $c->res->code( 400 );
    return;
    
  }
  
  my $data;
  eval { 
    $data = from_json(decode_fb_data( $payload ) );
    1;
  } or do {
    $c->res->code( 400 );
    return;
  };
 
  my $fbuid = $data->{user_id};

  my $login_option = $self->get_login_option('facebook', $fbuid);
  if ($login_option) {
    $c->session->{user_id} = $login_option->user_id;
  } else {
    $self->_create_user_with_facebook( $c, $data );
  }

  my %res = ();
  if ( $c->session->{user_id} ) {
    $self->login_successful( $c );
    %res = (
        done  => 1,
        goto  => $c->url_for((delete $c->session->{goto_after_login} || '/')),
      );
  } else {
    $c->res->code( 401 );
    %res = (
        done  => 0,
      );
  }

  $c->render( json => \%res );
}

sub _create_user_with_facebook {
  my ($self, $c, $data) = @_;

  my $token = $data->{oauth_token};
  my $burl = "https://graph.facebook.com/me";
  my $url = "$burl?access_token=$token";

  my $ua = LWP::UserAgent->new();
  my $res = $ua->get( $url );

  if ( $res->is_success ) {
    my $prof;
    eval {
      $prof = from_json( $res->content );
      1;

    } or do {
      print STDERR "Error parsing user profile: $@";
      return $c->res->code(500);
    };

    my $purl = "$burl/picture?redirect=0&access_token=$token";
    # fetch the profile picture.
    my $pres = $ua->get( $purl );
    # TODO: set profile image

    $self->create_user_from_external(
        display_name  => $prof->{name},
        external_id   => $data->{user_id},
        source        => 'facebook',
        auto_login    => 1,
        c             => $c,
      );
  }

  return;
}

sub decode_fb_data {
  my ($input) = @_;

  $input =~ tr{-_}{+/};

  return decode_base64( $input );
}

sub _html_body_end {
  my ($self, $c) = @_;

  return unless $c->stash->{on_login_page};

  my $app_id = $self->config->{app_id};
  return unless $app_id;

my $jsurl = $c->url_for('/sorweto/js/facebook.js');
  return <<EoJS;
<script>
var fb_app_id = '$app_id';
</script>
<script src="$jsurl"></script>
EoJS

}

1;
