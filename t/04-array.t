#!perl -T

use strict;
use warnings;
use Test::More tests => 159;

use_ok('Data::Schema::Type::Array');
use_ok('Data::Schema');

use lib './t';
require 'testlib.pm';

valid([], 'array', 'basic 1');
valid([1, 2], 'array', 'basic 2');

# not array
invalid({}, 'array', 'hash');
invalid('123', 'array', 'str');
invalid(\1, 'array', 'refscalar');

# required
valid(undef, 'array', 'undef');
invalid(undef, [array => {required => 1}], 'required 1');
valid([], [array => {required => 1}], 'required 2');

test_len('array', [1], [1,2], [1,2,3]); # 36

test_is_isnt_oneof('array', [1], [2], [3], [4]); # 62

# all_elements = 5x3=15
for (qw(all_elements all_element all_elems all_elem of)) {
    my $sch = [array=>{$_=>"int"}];
    valid([], $sch, "$_ 1");
    valid([1, 0, -1], $sch, "$_ 2");
    invalid([1, "a"], $sch, "$_ 3");
}

# elements 4x12 = 48
for (qw(elements element elems elem)) {
    my $sch = [array=>{$_=>["int", "str", [str=>{minlen=>2}]]}];
    valid([], $sch, "$_ 1.1");
    valid([1], $sch, "$_ 1.2");
    invalid(["a"], $sch, "$_ 1.3");
    valid([1,""], $sch, "$_ 1.4");
    invalid([1,[]], $sch, "$_ 1.5");
    invalid([1,"",""], $sch, "$_ 1.6");
    valid([1,"","ab"], $sch, "$_ 1.7");

    $sch = [array=>{$_=>["array", [array=>{minlen=>1, $_=>[[int=>{min=>2}]]}]]}];
    invalid([1], $sch, "$_ 2.1");
    valid([[]], $sch, "$_ 2.2");
    invalid([[], []], $sch, "$_ 2.3");
    invalid([[], [1]], $sch, "$_ 2.4");
    valid([[], [2]], $sch, "$_ 2.5");
}

# elements_regex 4x5 = 20
for (qw(
     elements_regex
     element_regex
     elems_regex
     elem_regex
     )) {
    my $sch = [array=>{$_=>{'^0|1$'=>'int'}}];
    valid([], $sch, "$_ 1");
    valid([1], $sch, "$_ 2");
    valid([1, 1], $sch, "$_ 3");
    invalid([1, "a"], $sch, "$_ 4");
    invalid([1, 1, 1], $sch, "$_ 5");
}

# unique
invalid([1, 1, 2], [array=>{unique=>1}], 'unique 1');
valid  ([1, 3, 2], [array=>{unique=>1}], 'unique 2');
valid  ([1, 1, 2], [array=>{unique=>0}], 'unique 3');
invalid([1, 3, 2], [array=>{unique=>0}], 'unique 4');
