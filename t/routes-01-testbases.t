#!perl -T

use 5.005;
use strict;
use warnings;
use Test::More;

BEGIN {
  use_ok('SorWeTo::Server::Routes') || print "Bail out!\n";
}

my $routes = SorWeTo::Server::Routes->new();

my $admin = $routes->admin_can();
$admin->any('/' => sub { print "Test\n" });

my $sadmin = $routes->admin_can('super');
$sadmin->any('/super/' => sub { print "SUPER\n" });

my $api = $routes->api;
$api->post('/add_url/' => sub { print "ADD Url\n" });

my $api_can = $routes->api_can('super');
$api_can->get('/super/' => sub { print "Super API\n" });


my $user_can = $routes->user_can('do_it');
$user_can->get('/do_it' => sub { print "Do IT\n"});

my $logged_in = $routes->logged_in;
$logged_in->any('/lets' => sub { print "Let's\n" });

my $anonymous = $routes->anonymous;
$anonymous->get('/do-not-track/' => sub { print "Do not Track\n" });

use Mojolicious::Command::routes;
use Mojo::Util qw(encode tablify);

my $rows = [];
Mojolicious::Command::routes::_walk( $_, 0, $rows, 5)
  for @{ $routes->children };
print encode('UTF-8', tablify( $rows ) );


done_testing();
