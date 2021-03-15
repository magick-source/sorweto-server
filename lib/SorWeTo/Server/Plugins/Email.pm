package SorWeTo::Server::Plugins::Email;

use Mojo::Base qw(Mojolicious::Plugin);

use Net::SMTP;

sub register {
  my ($self, $app, $conf) = @_;

  $app->helper( send_email => \&send_email );
}

sub send_email {
  my ($c, $template_name, $data) = @_;

  my $send_to = $data->{recipient} || $data->{email};
  unless ($send_to) {
    warn "Trying to send an email without recipient! Ignoring";
    return;
  }

  my $old_stash = $c->stash;
  $data->{template} = "email/$template_name";
  $data->{format}   = 'html';

  $c->stash( $data );

  my ($output, $format) = $c->app->renderer->render(
      $c
    );

  $c->stash( $old_stash );

  return unless $output;

  my $hostname = $c->req->url->base->host;

  my $config = $c->config("send_email:$hostname");
  unless ($config) {
    $config = $c->config("send_email");
  }

  $config->{smtp_server} ||= 'localhost';
  $config->{from_email}  ||= "noreplay\@$hostname";

  unless ( $data->{subject} ) {
    warn "Sending email without a subject";
    $data->{subject} = "Email from $hostname";
  }


  my %params = (
      Debug => $config->{debug},
      SSL   => $config->{SSL} // 1,
    );

use Data::Dumper;
print STDERR "smtp config: ", Dumper( $config );

  my $smtp = Net::SMTP->new( $config->{smtp_server}, %params );
  unless ($smtp) {
    warn "Send Email Fail: Failed to connect to $config->{smtp_server}";
    return;
  }
  $c->evinfo("started smtp! banner: %s", $smtp->banner);
  if ( $config->{username} ) {
    $smtp->auth( $config->{username}, $config->{password} );
  }

  $smtp->mail( $config->{from_email} );
  if ( $smtp->to( $send_to ) ) {
    $smtp->data();
    $smtp->datasend( "Subject: $data->{subject}\n");
    $smtp->datasend( "To: $send_to\n" );
    $smtp->datasend( "Content-Type: text/html; charset=UTF-8\n"); 
    $smtp->datasend( "\n" ); # End of the header
    $smtp->datasend( $output );
    $smtp->dataend();

  } else {
    my $err = $smtp->message();
    warn "Send Email Fail: $err";
  }

  $smtp->quit();

  my $tweet = 'email-sent';
  $c->tweet( $tweet );
  if ($data->{email_type}) {
    $tweet .= ":$data->{email_type}";
    $tweet =~ s{[^a-zA-Z0-9:\-]}{-}g;
    $tweet =~ s{\-+}{-}g;
    $c->tweet( $tweet );
  }
} 
 
1;
