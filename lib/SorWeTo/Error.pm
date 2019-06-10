package SorWeTo::Error;

use Mojo::Base '-base';

use overload '""' => 'stringify';

has error_type => 'error';
has message    => undef;
has debug      => undef;
has stacktrace => undef;
has dumped     => 0;

sub stringify {
  my ($self) = @_;

  if ($self->debug and !$self->dumped) {
    print STDERR sprintf "[DEBUG] %s\n%s",
        $self->debug, $self->stacktrace;
    $self->dumped(1);
  }

  return "ERROR: ".$self->message."\n\n";
}

sub weird {
  my ($class, %data) = @_;

  $data{stacktrace} ||= _make_stacktrace();
  $data{message}    ||= "Something weird just happened - call a developer";

  return $class->new( %data );
}

sub _make_stacktrace {
  my $stack = '';

  my $depth = 1;
  while (my ($package, $file, $line, $sub) = caller($depth++)) {
    $sub.= '(...)' if $sub and $sub ne '(eval)';
    
    $stack.="\t$sub called in $file:$line\n";

    last if $depth > 20;
  }

  return $stack;
}

1;
