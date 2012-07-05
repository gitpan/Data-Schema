#!perl -T

use lib './t'; require 'testlib.pm';
use strict;
use warnings;
use Test::More tests => 3;
use Data::Schema;

my $ds = new Data::Schema;

ok(!defined($INC{"Data/Schema/Type/Int.pm"}), "defer_loading=1 a");
$ds->validate(1, 'int');
ok(defined($INC{"Data/Schema/Type/Int.pm"}), "defer_loading=1 b");

$ds = Data::Schema->new(config=>{defer_loading=>0, schema_search_path=>["."]});
ok(defined($INC{"Data/Schema/Type/Str.pm"}), "defer_loading=0");


