#!perl -T

use lib './t'; require 'testlib.pm';
use strict;
use warnings;
use Test::More tests => 1;
use Data::Schema;

my $ds = new Data::Schema;
$ds->config->gettext_function(sub { "tong pedit atuh!" });
my $res = $ds->validate(10, [int=>{"min"=>200, "min:errmsg"=>"min:errmsg"}]);
ok(!$res->{success} && $res->{errors}[0] =~ /pedit/, 'gettext_function 1');
