package SorWeTo::Server;

use Mojo::Base 'Mojolicious';

use SorWeTo::Server::Sessions;

has config => undef;

has last_hostname => undef;

sub startup {
  my $self = shift;

  unshift @{$self->plugins->namespaces}, 'SorWeTo::Server::Plugins';

  $self->sessions( SorWeTo::Server::Sessions->new() );
  $self->plugins->register_plugin('config', $self,  {file => 'server.ini'});

  my $defaults = $self->defaults;
  $defaults->{sitename} = $self->config->config('_','sitename')
                        || 'Some SorWeTo Site';
  $defaults->{pagename} = 'just some page';

  my $namespaces = $self->config->config('server','namespaces');
  if ($namespaces) {
    $namespaces = [split /\s*[,;]\s*/, $namespaces];
    unshift @{$self->plugins->namespaces}, $_
      for grep { $_ } @$namespaces;
  }

  my $plugins = $self->config->config('server', 'plugins');
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

1;
