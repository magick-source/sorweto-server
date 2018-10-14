package SorWeTo::Server;

use Mojo::Base 'Mojolicious';

has config => undef;

sub startup {
  my $self = shift;

  unshift @{$self->plugins->namespaces}, 'SorWeTo::Server::Plugins';
  
  $self->plugins->register_plugin('config', $self,  {file => 'server.ini'});

  my $namespaces = $self->config->config('server','namespaces');
  if ($namespaces) {
    $namespaces = [split /\s*[,;]\s*/, $namespaces];
    unshift @{$self->plugins->namespaces}, $_
      for grep { $_ } @$namespaces;
  }

  my $plugins = $self->config->config('server', 'plugins');
  my @plugged = ();
  if ($plugins) {
    $plugins = [split /\s*[,;]\s*/, $plugins];
    my %registered = ();
    for my $plugin (@$plugins) {
      next unless $plugin;
      next if $registered{ $plugin };
      my $config = $self->config->config("plugin:$plugin") || {};
      my $pluged = $self->plugins->register_plugin(
                        $plugin, $self, $config
                    );
      
      if ($pluged and $pluged->can('dependences')) {
        my @depends = $pluged->dependences();
        if (@depends) {
          push @$plugins, grep { !$registered{ $_ } } @depends;
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
