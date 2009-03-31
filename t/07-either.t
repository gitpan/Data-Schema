#!perl -T

use strict;
use warnings;
use Test::More tests => 137;

use lib './t';
require 'testlib.pm';

use_ok('Data::Schema::Type::Either');
use_ok('Data::Schema');

# 3x9x5=135
for my $type (qw(either or any)) {
    for (qw(alternatives alternative alt alts choice choices schema schemas of)) {
        my $sch = [$type => {$_ => [ [int=>{divisible_by=>2}], [int=>{divisible_by=>7}] ]}];

        valid(undef, $sch, "$_ undef");
        invalid(1, $sch, "$_ 1");
        valid(4, $sch, "$_ 2");
        valid(21, $sch, "$_ 3");
        valid(42, $sch, "$_ 4");
    }
}
