package SorWeTo::Server::Plugins::Email;

use Mojo::Base qw(Mojolicious::Plugin);

sub register {
  my ($self, $app, $conf) = @_;

  $app->helper( send_email => \&send_email );
}

sub send_email {
  my ($c, $template_name, $data) = @_;

  my $old_stash = $c->stash;
  $c->stash( $data );

  my ($output, $format) = $c->app->renderer->render(
      $c,
#      Mojolicious::Controller->new( stash => $data ),
      { template => "email/$template_name",
        format   => 'html',
      }
    );


  $c->stash( $old_stash );

  return unless $output;

  #TODO: Actually send the email

  print STDERR "email:\n$output\n--------------------\n*********\n";
} 
 
1;
