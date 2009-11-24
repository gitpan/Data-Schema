#!perl -T

use strict;
use warnings;
use Test::More;

use lib './t';
require 'testlib.pm';

use Data::Schema;

for my $type (qw(either or any)) {
    for (qw(of)) {
        my $sch = [$type => {$_ => [ [int=>{divisible_by=>2}], [int=>{divisible_by=>7}] ]}];

        valid(undef, $sch, "$_ undef");
        invalid(1, $sch, "$_ 1");
        valid(4, $sch, "$_ 2");
        valid(21, $sch, "$_ 3");
        valid(42, $sch, "$_ 4");
    }
}

test_scalar_deps('either', "x", {of=>["int", "str"]}, {of=>["int"]});

done_testing();
