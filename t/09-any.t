#!perl -T

use strict;
use warnings;
use Test::More tests => 8;

use lib './t';
require 'testlib.pm';

# any is just either with no 'of' attributes

use_ok('Data::Schema::Type::Either');
use_ok('Data::Schema');

valid(undef, 'any', 'undef');
valid(1, 'any', 'num');
valid('', 'any', 'str');
valid([], 'any', 'array');
valid({}, 'any', 'hash');
valid(Data::Schema->new, 'any', 'obj');
