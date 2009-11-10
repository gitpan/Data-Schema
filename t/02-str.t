#!perl -T

use strict;
use warnings;
use Test::More tests => 143;

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

test_comparable('str', 'a', 'b', 'A', 'B'); # 26

test_sortable('str', 'a', 'b', 'c'); # 27

# cistr
valid  ('a', [cistr => {is=>"a"}], "cistr:is 1");
valid  ('a', [cistr => {is=>"A"}], "cistr:is 2");
valid  ('A', [cistr => {is=>"a"}], "cistr:is 3");
invalid('a', [cistr => {is=>"b"}], "cistr:is 4");
valid  ('a', [cistr => {one_of=>[qw/a/]}], "cistr:one_of 1");
valid  ('A', [cistr => {one_of=>[qw/a/]}], "cistr:one_of 2");
valid  ('a', [cistr => {one_of=>[qw/A/]}], "cistr:one_of 3");
valid  ('A', [cistr => {one_of=>[qw/A/]}], "cistr:one_of 4");
invalid('b', [cistr => {one_of=>[qw/a/]}], "cistr:one_of 5");
test_sortable('cistr', 'a', 'B', 'c'); # 27
