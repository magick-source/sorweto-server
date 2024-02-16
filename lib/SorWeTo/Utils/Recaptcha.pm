package SorWeTo::Utils::Recaptcha;

use parent 'Exporter';
our @EXPORT_OK = qw(check_recaptcha);

use LWP::UserAgent;

sub check_recaptcha {
  my ($secret_key, $remote_ip, $response) = @_;

  my $ua = LWP::UserAgent->new();

  my $result = $ua->post(
    'https://www.google.com/recaptcha/api/siteverify',
    {
      secret_key  => $secret_key,
      response    => $response,
      remoteip    => $remote_ip,
    }
  );

  if ($result->is_success) {
    print STDERR "Recaptcha Result: ", $result->content,"\n\n";
  } else {
    return false;
  }
}

1;
