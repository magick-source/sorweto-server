package SorWeTo::Server::Plugins::Login;

use Mojo::Base qw(Mojolicious::Plugin);

has config => sub { {} };

has plugins => sub {
  Mojolicious::Plugins->new(
    namespaces => ['SorWeTo::Server::Plugins::Login'],
  );
};

has _plugins => sub { {} };

has 'app';

sub dependencies { qw( User ) }

sub register {
  my ($self, $app, $conf) = @_;

  $self->app( $app );

  my $backends = $conf->{backends}||'email';
  my %backends = map { $_ => 0 } grep { $_ } split /\s*[,;]\s*/, $backends;
  %backends = qw(email 0) unless keys %backends;

  for my $backend (sort keys %backends) {
    my $config = $app->config->config("plugin:login:$backend");
    my $plugin = $self->plugins->register_plugin(
        $backend, $self, $config
      );
  }

  my $r = $app->routes;
  $r->route('/login/')->to(cb => sub { $self->_login_page( @_ ) });

  return $self;
}

sub _login_page {
  my ($self, $c) = @_;

  $c->render(template => 'login/login');
}


1;
