#!perl -T

use strict;
use warnings;
use Test::More tests => 72;

use lib './t';
require 'testlib.pm';

use_ok('Data::Schema::Type::Int');
use_ok('Data::Schema');

valid(1, 'int', 'int 1');
valid(0, 'int', 'int 2');
valid(-1, 'int', 'int 3');
invalid(1.1, 'int', 'float');
invalid('a', 'int', 'str');
invalid([], 'int', 'array');
invalid({}, 'int', 'hash');

valid(1, 'integer', 'alias 1');

valid(undef, 'int', 'undef');

test_comparable('int', 1, -2, 3, -4); # 26
test_sortable('int', -4, 5, 10); # 27

# mod
invalid(10, [int=>{mod=>[3,2]}], 'mod 1');
valid(11, [int=>{mod=>[3,2]}], 'mod 2');

# divisible_by
invalid(11, [int=>{divisible_by=>3}], 'divisible_by 1');
valid(12, [int=>{divisible_by=>3}], 'divisible_by 2');
for (qw(not_divisible_by undivisible_by)) {
    valid(11, [int=>{$_=>3}], "$_ 1");
    invalid(12, [int=>{$_=>3}], "$_ 2");
}
