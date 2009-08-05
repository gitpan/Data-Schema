#!perl -T

use strict;
use warnings;
use Test::More tests => 110;

BEGIN { use_ok('Data::Schema'); }

use lib './t';
require 'testlib.pm';

valid('', 'str', 'basic 1');
valid(' ', 'str', 'basic 2');
valid('abc', 'str', 'basic 3');
valid(1, 'str', 'basic 4');

# alias
valid('', 'string', 'alias 1');

# not string
invalid([], 'str', 'array');
invalid({}, 'str', 'hash');

# required
valid(undef, 'str', 'undef');
invalid(undef, [str => {required => 1}], 'required 1');
valid('abc', [str => {required => 1}], 'required 2');

test_len('str', 'a', 'ab', 'abc'); # 36

# match
for (qw(match matches)) {
    valid('12', [str => {$_=>'^\d+$'}], "$_ 1");
    invalid('12a', [str => {$_=>'^\d+$'}], "$_ 2");
    invalid('12', [str => {"not_$_"=>'^\d+$'}], "not_$_ 1");
    valid('12a', [str => {"not_$_"=>'^\d+$'}], "not_$_ 2");
}
# match regex object
valid('12', [str => {match=>qr/^\d+$/}], "match re object 1");
invalid('12a', [str => {match=>qr/^\d+$/}], "match re object 2");

test_is_isnt_oneof('str', 'a', 'b', 'c', 'd'); # 26

test_min_max('str', 'a', 'b', 'c'); # 27
