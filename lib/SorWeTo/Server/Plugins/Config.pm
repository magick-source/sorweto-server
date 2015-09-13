package SorWeTo::Server::Plugins::Config;

use Mojo::Base qw(Mojolicious::Plugin);

use File::Spec::Functions 'file_name_is_absolute';

use Config::Tiny;

has config_data	=> sub { {} };
has app	=> undef;

sub register {
	my ($self, $app, $conf) = @_;

	$self->app($app);

	my $file = $conf->{file} || $ENV{MOJO_CONFIG};
	$file ||= $app->moniker . '.' . ($conf->{ext} || 'ini');

	$file = 'config/'.$file
		unless file_name_is_absolute $file;

	my $mode = $file =~ /^(.*)\.([^.]+)$/ ? join('.', $1, $app->mode, $2) : '';

	my $home = $app->home;
	$file = $home->rel_file($file) unless file_name_is_absolute $file;
	$mode = $home->rel_file($mode) if $mode && !file_name_is_absolute $mode;
	$mode = undef unless $mode && -e $mode;

	for my $f ($mode, $file) {
		next unless $f and -e $f;

		last if $self->_read_config($file);
	}

	unless ($self->{'##loaded'} or $conf->{'skipable'}) {
		$app->log->fatal('Missing config file: %s => %s', $file, $conf);
	}

  $app->config( $self );

	$app->helper( _c	=> \&config_helper );
	$app->helper( config	=> \&config_helper );
}

sub config {
	my $self = shift;
	my ($sec,$key) = @_;
	$sec = '_' if !$sec and $key;

	my %sec = $sec
			? %{ $self->config_data->{$sec} || {} } 
			: %{ $self->config_data };

	if ($key) {
		return $sec{$key};
	}

	return wantarray ? %sec : \%sec;
}

sub config_helper {
	my $c = shift;

	my $self = $c->app->config;

	return $self->config( @_ );
}

sub _read_config {
	my ($self, $fname) = @_;

	my $cfg = Config::Tiny->read($fname);
	unless ($cfg) {
		my $err = Config::Tiny->errstr;
		$self->app->log->warn("Error reading file '%s': %s", $fname, $err);
	}

	my %isa = ();
	for my $s (keys %$cfg) {
		next if $s eq '_';
		if ( $cfg->{ $s }->{_isa} ) {
			$isa{ $s } = [ split /\s*[,;]\s*/, delete $cfg->{ $s }->{_isa} ];
		}
	}

	my $_isa;
	my %_isaseen;
	$_isa = sub {
		my $s = shift;
		return if $_isaseen{ $s };
		$_isaseen{ $s }++;
		for my $ds ( @{ $isa{$s} }) {
			if ($isa{ $ds }) {
				$_isa->($ds);
			}
			for my $k (keys %{ $cfg->{ $ds } }) {
				$cfg->{ $s }{ $k } = $cfg->{ $ds }{ $k }
					unless exists $cfg->{ $s }{ $k };
			}
		}
		$_isaseen{ $s }--;
	};

	for my $s (keys %isa) {
		%_isaseen = ();
		$_isa->($s) if $isa{ $s } and @{ $isa{ $s } };
	}

	$self->{'##loaded'} = 1;

	$self->config_data( {%$cfg} ); #unbless it
}

1; 
