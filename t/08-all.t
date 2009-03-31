#!perl -T

use strict;
use warnings;
use Test::More tests => 32;

use lib './t';
require 'testlib.pm';

use_ok('Data::Schema::Type::All');
use_ok('Data::Schema');

# 2x3x5=30
for my $type (qw(all and)) {
    for (qw(schema schemas of)) {
        my $sch = [$type => {$_ => [ [int=>{divisible_by=>2}], [int=>{divisible_by=>7}] ]}];

        valid(undef, $sch, "$_ undef");
        invalid(1, $sch, "$_ 1");
        invalid(4, $sch, "$_ 2");
        invalid(21, $sch, "$_ 3");
        valid(42, $sch, "$_ 4");
    }
}
