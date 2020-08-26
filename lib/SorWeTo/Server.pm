package SorWeTo::Server;

use Mojo::Base 'Mojolicious';

use SorWeTo::Server::Sessions;
use SorWeTo::Server::Routes;

has config => undef;

has last_hostname => undef;

has evlog => undef;

has translations => undef;

sub startup {
  my $self = shift;

  unshift @{$self->plugins->namespaces}, 'SorWeTo::Server::Plugins';

  $self->plugins->register_plugin('config', $self,  {file => 'server.ini'});

 
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

  my $defaults = $self->defaults;
  $defaults->{sitename}         = $self->config->config('_','sitename')
                               || 'Some SorWeTo Site';
  $defaults->{sitebase}         = $self->config->config('_','sitebase')
                               || '/';

  $defaults->{pagename}         = 'just some page';
  $defaults->{page_description} = '';
  $defaults->{author}           = '';
  $defaults->{show_sidebar}     = 1;
  $defaults->{default_language} = $self->config->config('_', 'default_language')
                               || 'en';

  my $namespaces = $self->config->config('server','namespaces');
  if ($namespaces) {
    $namespaces = [split /\s*[,;]\s*/, $namespaces];
    unshift @{$self->plugins->namespaces}, $_
      for grep { $_ } @$namespaces;

  }
  push @{ $self->commands->namespaces }, 'SorWeTo::Server::Command';

  $self->renderer->add_helper('html_hook', \&_html_hook_handler );

  my $plugins = $self->config->config('server', 'plugins') // '';

  # we always want to have translations handy
  unless ($plugins =~ m{\btranslate\b}) {
    $plugins = $plugins ? "translate,$plugins" : 'translate';
  }
  # We really like to have a simple way to send error messages to the user
  unless ($plugins =~ m{\bUserErrors\b}) {
    $plugins = 'UserErrors,'.$plugins;
  }
  # We always want to have the evlog system around!
  unless ($plugins =~ m{\blog\b}) {
    $plugins = 'log,'.$plugins; # by now it should have at least translate
  }
  my @plugged = ();
  if ($plugins) {
    my @plugins = split /\s*[,;]\s*/, $plugins;
    my %registered = ();
    while (my $plugin = shift @plugins) {
      print STDERR "going to register $plugin\n";
      next unless $plugin;
      next if $registered{ $plugin };
      my $config = $self->config->config("plugin:$plugin") || {};
      my $pluged = $self->plugins->register_plugin(
                        $plugin, $self, $config
                    );
      
      if ($pluged and $pluged->can('dependencies')) {
        my @depends = $pluged->dependencies();
        print STDERR "dependencies for $plugin: @depends\n";
        if (@depends) {
          push @plugins, grep { !$registered{ $_ } } @depends;
        }
      }
      push @plugged, $pluged;

      $registered{ $plugin } = 1;
    }
  }

	for my $pluged ( @plugged ) {
		next unless $pluged and $pluged->can('post_register');
		$pluged->post_register( $self );
	}
}

sub _html_hook_handler {
  my ($c, $hook_name, @params) = @_;

  return '';
}

1;
