package SorWeTo::Server::Plugins::Docs;

use Mojo::Base qw(Mojolicious::Plugin);

use Text::Markdown qw(markdown);
use Mojo::ByteStream qw(b);

has config => sub { {} };

has doc_paths => sub { [] };

sub register {
  my ($self, $app, $conf) = @_;

  $app->routes->get('/docs/*docname'
      => [docname => qr([a-zA-Z0-9\-/]{3,})]
    )->to(cb => sub {$self->render_doc( @_ )} );

  $app->helper(register_docs => sub { $self->register_docs( @_ ) });
  $app->helper(parse_md_string => \&parse_string );
  $app->helper(parse_doc  => sub { $self->parse_doc( @_ ) });

  return $self;
}

sub parse_md_string {
  my ($c, $str) = @_;

  return markdown( $str );
}

sub parse_doc {
  my ($self, $c, $doc) = @_;

  my $fname = $self->_find_doc( $c, $doc );
  return unless $fname;

  my $md;
  { local $/=undef;
    open my $fh, '<', $fname or die "Error reading file '$fname'";
    $md = <$fh>;
  }

  return unless $md;
  
  my $html = markdown( $md );

  return $html;
}

sub _find_doc {
  my ($self, $c, $doc) = @_;

#TODO: add support for language specific documents
#      using language/default language

  my @components = split m{/}, $doc;
  return if grep { $_ eq '..' } @components;

  # the last registered path takes precedence.
  for my $path (reverse @{ $self->doc_paths }) {
    my $dp = $path;
    $dp.='/' unless substr($dp, -1) eq '/';

    $dp .= $doc;

    $dp .= '.md' unless $dp=~m[\.md\z];

    print STDERR "docs: > checking '$dp'\n";

    return $dp if -e $dp;
  }

  return undef;
}

sub render_doc {
  my ($self, $c) = @_;

  my $doc = $c->stash->{docname};

  my $html = $self->parse_doc( $c, $doc );

  return $c->reply->not_found
    unless $html;
    
  my ($title) = $html =~ m{\<h1\>([^\<]+)\</h1\>};
  $c->stash->{pagename} = $title if $title;

  $c->stash->{rendered_doc} = b( $html );
  $c->render( template => "markdown_doc" );
}

sub register_docs {
  my ($self, $c_maybe, $path) = @_;

  $path ||= 'docs';

  my ($pkg, $caller_path) = caller(2);
  $pkg =~ s{::}{/};
  $pkg .= '.pm';

  if ($pkg and $caller_path) {
    $caller_path =~ s{(:?lib/)?$pkg\z}{$path};
    push @{$self->doc_paths}, $caller_path;
  }

  return;
}

1;
