package SorWeTo::Server::Plugins::MoreHelpers;

use Mojo::Base qw(Mojolicious::Plugin);

sub register {
  my ($self, $app, $conf) = @_;

  $app->renderer->add_helper( include_maybe => \&include_maybe );
  $app->helper( handle_input_errors => \&handle_input_errors );
  $app->helper( emit_hook => \&_emit_hook );
}

sub include_maybe {
  my ($c, $template, @params) = @_;

  return $c->render_maybe( $template, 'mojo.string' => 1, @params );
}

sub handle_input_errors {
  my ($c, $v, %params) = @_;

  my %errors = ();
  for my $fld ( @{ $v->failed }) {
    my $err = $v->error( $fld );
    my $check_name = $err->[0];
    my %params = ();
    if ( ref $err->[1] eq 'ARRAY' ) {
      for my $i (0..$#{ $err->[1] } ) {
        $params{ "err_info_$i" } = $err->[1]->[ $i ];
      }

    } elsif (ref $err->[1] eq 'HASH' ) {
      for my $k (keys %{ $err->[1] }) {
        $params{ "err_info_$k" } = $err->[1]->{ $k };
      }

    } elsif ( defined $err->[1] ) {
      $params{ err_info_0 } = $err->[1];
    }


    my $trans_id = "validation_error_$check_name";
    my $message = $c->translate( $trans_id,
        field_name  => $fld,
        %params,
      );
    unless ( $message ) {
      $message = $c->translate( 'validation_error_base',
          check_name  => $check_name,
          field_name  => $fld,
          %params,
        );
    }

    $errors{ $fld } = {
        field       => $fld,
        check_name  => $check_name,
        message     => $message,
      };
    $c->evlog("request.input_error.$fld",
      {
        message => $message,
        error_data => $err
      });
  }

  if ( $params{ return_errors} ) {
    return \%errors;

  } elsif ( $params{ api_errors } ) {
    my $code = $params{ error_code } || 400;
    $c->res->code( $code );
    $c->render(json => { errors => [values %errors] });

  } else {
    my $errors = $c->stash->{errors} ||= [];
    push @$errors, values %errors;

  }

  return;
}

sub _emit_hook {
  my ($c, $hook, @params) = @_;

  $c->app->plugins->emit_hook( $hook => $c, @params );
}

1;
