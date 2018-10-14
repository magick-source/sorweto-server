package SorWeTo::Server::Plugins::Themes;

use Mojo::Base qw(Mojolicious::Plugin);
use Mojo::Base qw(Mojolicious::Renderer);

has 'theme';
has 'theme_by_host' => sub { {} };
has 'themes' => sub { {} };

sub register {
	my ($self, $app, $conf) = @_;

	bless $app->renderer, ref $self;
	$self = $app->renderer;

	my $theme = $app->config->config('design','theme');
	if ($theme) {
		$self->theme($theme);
	} else {
		my $theme_by_host = $app->config->config('theme_by_host');
		$self->theme_by_host( $theme_by_host )
			if $theme_by_host;
	}

	$app->helper( register_themes => sub { $self->register_themes($app, @_ ) });

	return $self;
}

sub template_path {
	my ($self, $options) = @_;

	my $tmpl;
	my $theme 	 = $options->{theme}
				|| $self->theme;
	if (!$theme and $options->{hostname}) {
		$theme = $self->theme_by_host->{ $options->{hostname} }
				|| $self->theme_by_host->{ default };
	}
	if ($theme and $options->{template}) {
		my $oldtmpl = $options->{template};

		$options->{template} = "themes/$theme/$oldtmpl";
		$tmpl = $self->SUPER::template_path( $options );

		$options->{template} = $oldtmpl;
		unless ($tmpl) {
			if ($self->themes->{$theme}->{parent}) {
				return $self->template_path({
					%$options,
					theme => $self->themes->{$theme}->{parent},
				});
			}
		}
	}

	$tmpl = $self->SUPER::template_path( $options )
		unless $tmpl and -r $tmpl;

	return $tmpl;
}

sub register_themes {
	my ($self, $app, $c, @themes) = @_;

	my %paths = map { $_ => 1 } @{ $app->renderer->paths };
	my ($pkg, $caller_path) = caller(2);
	$pkg =~ s{::}{/}g;
	$pkg.='.pm';
	if ($pkg and $caller_path) {
		$caller_path =~ s{(?:lib/)?$pkg\z}{templates};
		unshift @{ $app->renderer->paths }, $caller_path
			unless $paths{ $caller_path };
	}

	for my $theme (@themes) {
		my $inipath = $self->template_path({
			template	=> 'theme',
			format		=> 'ini',
			theme		=> $theme,
		});
		if ($inipath) {
			my $config = $app->config->load_file($inipath);

			if ($config) {
				$self->themes->{ $theme } = $config->config('_');
			}
		}
	}
}

sub _render_template {
	my ($self, $c, $output, $options) = @_;

	my $hostname = $c->req->url->base->host;
	$options->{hostname} = $hostname;

	return $self->SUPER::_render_template($c, $output, $options);
}

1;
