package SorWeTo::Server::Plugins::UserSettings;

use Mojo::Base qw(Mojolicious::Plugin);

has config    => sub { {} };
has settings  => sub { {} };

sub dependencies { qw( User MySQL ) }

sub register {
  my ( $self, $app, $conf ) = @_;

  $app->helper( register_user_setting => sub { $self->register_setting( @_ ) });

  return $self;
}


sub post_register {
  my ($self, $app) = @_;

  $app->add_user_helper(settings  => sub { $self->user_settings( @_ ) });
  $app->add_user_helper(setting => sub { $self->user_setting( @_ ) });

  print STDERR "registed user helpers (settings and setting)\n";
}

sub register_setting {
  my ($self, $c, $setting) = @_;

  my $set_name = $setting->{name};
  unless ( $set_name ) {
    warn "Trying to register a setting without a name";

    return;
  }

  $self->settings->{ $set_name } = $setting;

  return;
}

sub user_settings {
  my ($self, $user) = @_;

  my $settings = $user->{_us_settings} ||= do {
    my $data = SorWeTo::Server::Plugins::UserSettings::Data->new(
        settings  => $self->settings, 
        user_id   => $user->user_id,
      ); 

    $data;
  };

  return $settings;
}

sub user_setting {
  my ($self, $user, $name) = shift;

  my $settings = $self->user_settings( @_ );

  return $settings->get( $name );
}

package SorWeTo::Server::Plugins::UserSettings::Data;

use Mojo::Base -base;

use SorWeTo::Db::UserSetting;

has 'user_id';
has 'settings';

has updated => sub { {} };

has _data => \&_load_settings;

sub _load_settings {
  my ($self) = @_;

  my @recs = SorWeTo::Db::UserSetting
                ->search_where( user_id => $self->user_id );
 
  my %recs = map { $_->name => $_ } @recs;

#TODO(maybe): unpack on load

  return \%recs;
}

sub get {
  my ($self, $name) = @_;

  # no definition, no data
  return unless my $def = $self->settings->{ $name };

  return unless my $rec = $self->_data->{ $name };

  my $value;
  if ($def->{is_number}) {
    $value = $rec->value_num;

  } elsif ( $rec->{_unpacked} ) {
    $value = $rec->{_unpacked};

  } else {
    $value = $rec->value_blob;
  }

  return $value;
}

sub set {
  my ($self, $name, $value) = @_;

  unless (defined $value) {
    warn "FAILED: setting to undef - use ->unset instead";
    return;
  }

  my $def = $self->settings->{ $name };
  unless ( $def ) {
    warn "FAILED: Trying to set a setting that is not defined ($name)";
    return;
  }

  # TODO: Apply filters and stuff
  if ( $def->{is_number} and $value !~ m{\A\-?\d+(\.\d{1,2})?\z}) {
    warn "FAILED: Trying to set a numeric setting with '$value'";
    return;
  }

  # TODO(maybe): bulk update the database
  my $rec = $self->_data->{ $name };
  unless ( $rec ) {
    $rec = SorWeTo::Db::UserSetting->create({
          user_id => $self->user_id,
          name => $name
        });

    $self->_data->{ $name } = $rec;
  }

  if ($def->{is_number}) {
    $rec->value_int( $value );
  } else {

    #TODO(maybe): pack on update
    $rec->value_blob( $value );
  }

  $rec->update();

  return;
}

sub unset {
  my ($self, $name) = @_;

  my $rec = $self->_data->{ $name };
  return unless $rec;

  $rec->delete;
  delete $self->_data->{ $name };

  return;
}

sub increment_by {
  my ($self, $name, $diff) = @_;

  unless (defined $diff and $diff =~ m{[^\-\d\.]}) {
    warn "FAILED: Trying to increment by non-numeric value";
    return;
  }

  return unless $diff; # zero diff, zero work?

  my $def = $self->settings->{ $name };
  unless ( $def ) {
    warn "FAILED: user setting not registered: $name";
    return;
  }

  unless ( $def->{is_number} ) {
    warn "FAILED: trying to increment a non-numeric setting '$name'";
    return;
  }

  my $rec = $self->_data->{ $name };
  if ( $rec ) {
    $rec->increment_setting( $diff );

  } else {
    # incrementing from 0 is a set
    $self->set( $name, $diff );
  }

}

1;

