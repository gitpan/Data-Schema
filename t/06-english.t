#!perl -T

use lib './t'; require 'testlib.pm';
use strict;
use warnings;
use Test::More tests => 6;
use Data::Schema;

# casual tests for english
test_english('int', 'int', 'english 1');
test_english(["array"], 'array', 'english 2');
test_english([array=>{of=>"str"}], 'array of (string)', 'english 3');
test_english([hash=>{of=>["float", "object"]}],
                     'hash of (float => object)', 'english 4');
test_english([any=>{of=>["int", [array=>{all_elems=>"int"}]]}],
                     '(int) or (array of (int))', 'english 5');
test_english([all=>{of=>["int", "float"]}],
                     '(int) as well as (float)', 'english 6');


