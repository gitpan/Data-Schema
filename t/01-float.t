#!perl -T

use strict;
use warnings;
use Test::More tests => 63;

use lib './t';
require 'testlib.pm';

use_ok('Data::Schema::Type::Float');
use_ok('Data::Schema');

valid(1, 'float', 'float 1');
valid(0, 'float', 'float 2');
valid(-1, 'float', 'float 3');
valid(1.1, 'float', 'float 4');
invalid('a', 'float', 'str');
invalid([], 'float', 'array');
invalid({}, 'float', 'hash');

valid(undef, 'float', 'undef');

test_is_isnt_oneof('float', 1, -2.1, 3.1, -4.1); # 26
test_min_max('float', -4.1, 5.1, 10.1); # 27
