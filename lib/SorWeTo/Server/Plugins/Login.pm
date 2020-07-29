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

    $self->_plugins->{$backend} = $plugin;
  }

  my $r = $app->routes;
  $r->route('/login/' )->to(cb => sub { $self->_login_page( @_ ) });
  $r->route('/logout/')->to(cb => sub { $self->_logout( @_ ) });

  return $self;
}

sub _logout {
  my ($self, $c) = @_;

  $c->session({ logged_out => 1 });

  return $c->redirect_to( '/' );
}

sub _login_page {
  my ($self, $c) = @_;

  my %login_data = ();
  for my $backend (values %{$self->_plugins}) {
    $backend->set_loginform_data( $c, \%login_data )
      if $backend->can('set_loginform_data');
  }
  $c->stash->{login_data} = \%login_data;

  my $ses_flash = $c->session->{flash};
  my $flash = $c->flash('errors');
  use Data::Dumper;
  print STDERR "flash: ", Dumper($ses_flash, $flash),"\n";

  my @backends = keys %{ $self->_plugins };
  $c->stash->{backends} = \@backends;
  $c->render(template => 'login/login' );
}


1;
