#!/usr/bin/perl

use strict;
use warnings;

use FindBin;

use lib "$FindBin::Bin/../lib";

use Mojolicious::Commands;

Mojolicious::Commands->start_app('SorWeTo::Server');


