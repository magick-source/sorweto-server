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
  if ($plugins) {
    $plugins = [split /\s*[,;]\s*/, $plugins];
    my %registered = ();
    for my $plugin (@$plugins) {
      next unless $plugin;
      next if $registered{ $plugin };
      my $config = $self->config->config("plugin:$plugin") || {};
      my $plugin = $self->plugins->register_plugin(
                        $plugin, $self, $config
                    );
      
      if ($plugin and $plugin->can('dependences')) {
        my @depends = $plugin->dependences();
        if (@depends) {
          push @$plugins, grep { !$registered{ $_ } } @depends;
        }
      }

      $registered{ $plugin } = 1;
    }
  }

}

1;
