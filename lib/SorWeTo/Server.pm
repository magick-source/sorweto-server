package SorWeTo::Server;

use Mojo::Base 'Mojolicious';

use SorWeTo::Server::Sessions;
use SorWeTo::Server::Routes;
use SorWeTo::Server::htmlHooks;

use Mojo::JSON qw(to_json);

has config => undef;

has last_hostname => undef;

has evlog => undef;

has translations => undef;

has html_hooks  => sub {
    SorWeTo::Server::htmlHooks->new( app => @_ );
  };

sub startup {
  my $self = shift;

  unshift @{$self->plugins->namespaces}, 'SorWeTo::Server::Plugins';

  $self->plugins->register_plugin('config', $self,  {file => 'server.ini'})
    unless $self->config;

 
  my $session_backend = $self->config->config('sessions', 'backend');
  my %session_params;
  if ($session_backend) {
    my $class;
    if ($session_backend =~ m{\A\w+\z}) {
      $class = "SorWeTo::Server::Sessions::$session_backend";
    } else {
      $class = $session_backend;
    }
    eval "use $class; 1"
      or die $@;
    $session_params{backend} = $class->new();
  }
  $self->sessions( SorWeTo::Server::Sessions->new( %session_params ) );
  $self->routes( SorWeTo::Server::Routes->new() );

  $self->html_hooks->init();

  my $defaults = $self->defaults;
  $defaults->{sitename}         = $self->config->config('_','sitename')
                               || 'Some SorWeTo Site';
  $defaults->{sitebase}         = $self->config->config('_','sitebase')
                               || '/';

  $defaults->{pagename}         = '';
  $defaults->{page_description} = '';
  $defaults->{author}           = '';
  $defaults->{show_sidebar}     = 1;
  $defaults->{default_language} = $self->config->config('_', 'default_language')
                               || 'en';
  
  push @{ $self->commands->namespaces }, 'SorWeTo::Server::Command';

  $self->load_plugin('log');
  $self->load_plugin('UserErrors');
  $self->load_plugin('translate');

  $self->register_static;

  $self->html_hook( 'html_head', sub { $self->_sitevars( @_ ) });
  $self->helper( api_fail => \&_api_fail );

  return;
}

sub warmup {
  my ($self) = @_;

  $self->SUPER::warmup;

  $self->plugins->emit_hook( 'warming_up' );

  return;
}


my %loaded = ();
sub load_plugin {
  my ($self, $plugin, $config) = @_;

  return if $loaded{ $plugin };

  unless ($config) {
    $config = $self->config->config("plugin:$plugin") || {};
  }

  my $pluged = $self->plugins->register_plugin( $plugin, $self, $config);
  if ($pluged) {
    $loaded{ $plugin }++;

    if ( $pluged->can('dependencies') ) {
      my @deps = $pluged->dependencies();
      for my $dep (@deps) {
        $self->load( $dep );
      }
    }
  }

  return ((defined wantarray) ? $pluged : ());
}

sub register_static {
  my ($self, $path) = @_;

  unless ($path) {
    my ($pkg, $fname) = caller;
    return unless $fname;

    $path = $fname;
    if ($path =~ m{lib/}) {
      $path =~ s{lib/.*\z}{};

    } else {
      $pkg =~ s{::}{/}g;
      $pkg .= '.pm';
      $path =~ s{$pkg\z}{};
    }
  }

  if ( -d "$path/public" ) {
    push @{ $self->static->paths }, "$path/public";

  } else {
    warn "'$path/public' is not a directory - not registering static";
  }

  return;
}

sub html_hook {
  my ($self, $hook, $handler) = @_;

  return $self->html_hooks->on( $hook, $handler );
}

sub _sitevars {
  my ($self, $c) = @_;

  my $base    = $c->url_for('/')->to_abs->to_string;
  my $apibase = $c->url_for('api')->to_abs->to_string;

  $base     =~ s{\Ahttps?:}{};
  $apibase  =~ s{\Ahttps?:}{};

  my %sitevars = (
    %{ $c->stash->{sitevars} || {} },
    apibase => $apibase,
    base    => $base,
  );
  my $sitevars_js = to_json( \%sitevars );

  return "<script>var sitevars = $sitevars_js; </script>";
}

sub _api_fail {
  my ($c, $error, $data) = @_;
    $error  ||= 500;
    $data   ||= {};
    $data->{error} = 1
      unless exists $data->{error};

  return $c->render( json => $data, status => $error );
}

1;
