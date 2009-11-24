#!perl -T

use strict;
use warnings;
use Test::More tests => 1;

use lib './t';
require 'testlib.pm';

use Data::Schema;

# TODO: emit_perl should not interfere with subsequent validate
# TODO: turning off compile in the middle of validations
# TODO: turning on compile in the middle of validations
# TODO: compiling invalid schema

ok(1, 'DUMMY');
