package SorWeTo::Server::Plugins::MoreHelpers;

use Mojo::Base qw(Mojolicious::Plugin);

sub register {
  my ($self, $app, $conf) = @_;

  $app->renderer->add_helper( include_maybe => \&include_maybe );
}

sub include_maybe {
  my ($c, $template, @params) = @_;

  return $c->render_maybe( $template, 'mojo.string' => 1, @params );
}

1;
