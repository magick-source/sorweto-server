package SorWeTo::Server::Sessions::TmpBlob;
use Mojo::Base -base;

# This is a backend for SWT::SRV::Sessions, that uses TmpBlob plugin
# to store the session data in mysql.

has tmpblob_type => 'session';

sub load {
  my ($self, $c, $sess_id) = @_;

  return $c->tmp_blob_load( $self->tmpblob_type, $sess_id );
}

sub store {
  my ($self, $c, $params) = @_;

  my $sess_id = $params->{session_id};
  my $value   = $params->{value};
  my $expires = $params->{expires};

  $c->tmp_blob_store( $self->tmpblob_type, $sess_id, $value, $expires );
  return;
}

1;
