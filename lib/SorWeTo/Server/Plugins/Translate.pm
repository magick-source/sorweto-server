package SorWeTo::Server::Plugins::Translate;

use Mojo::Base qw(Mojolicious::Plugin);

use Translate::Fluent;

has resource_group  => sub {
    return Translate::Fluent::ResourceGroup->new(
        fallback_order  => [qw(website bundle language)],
      );
  };

sub register {
  my ($self, $app, $conf) = @_;

  $app->translations( $self );

  $app->renderer->add_helper( __  => sub { $self->translate( @_ ) });
  $app->helper( register_translations => sub {
      $self->register_translations( $app, @_ );
    });

  $self->register_translations( $app );

  return $self;
}

sub translate {
  my ($self, $c, $res_id, @_variables) = @_;

  my $context;
  if (scalar @_variables % 2 and ref $_variables[-1] eq 'HASH') {
    $context = pop @_variables;
  }
  $context ||= {};

  my %variables = @_variables;

  $context->{language}  = $c->stash->{language}
    if $c->stash->{language};

  $context->{language}  ||= $c->stash->{default_language}
    if $c->stash->{default_language};

  $context->{website}   = $c->req->url->base->host;

  return $self->resource_group->translate( $res_id, \%variables, $context );
}

sub slurp {
  my ($self, $path, $context) = @_;

  if (-f $path) {
    print STDERR "Slurping file '$path'\n";
    $self->resource_group->slurp_file( $path, $context );
  } else {
    local $context->{recursive} = $context->{recursive} // 1;
    print STDERR "Slurping directory '$path'\n";
    $self->resource_group->slurp_directory( $path, $context );
  }
}

sub register_translations {
  my ($self, $app, $path, $context) = @_;

  $path ||= 'translations';

  my ($pkg, $caller_path) = caller(2);
  $pkg =~ s{::}{/}g;
  $pkg.='.pm';
  if ($pkg and $caller_path) {
    $caller_path =~ s{(?:lib/)?$pkg\z}{$path};
    $self->slurp( $caller_path, $context );
  }

}

1;
