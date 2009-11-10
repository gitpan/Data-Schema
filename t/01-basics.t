#!perl -T

use strict;
use warnings;
use Test::More tests => 108;

BEGIN {
    use_ok('Data::Schema');
    use_ok('Data::Schema::Type::Base');
}

use lib './t';
require 'testlib.pm';

package MyType1;
use Moose;
extends 'Data::Schema::Type::Base';
sub handle_attr_bar { 1 };

package main;

my $ds;
my $res;

# defer_loading, default is 1
$ds = new Data::Schema;
ok(!defined($INC{"Data/Schema/Type/Int.pm"}), "defer_loading=1 a");
$ds->validate(1, 'int');
ok(defined($INC{"Data/Schema/Type/Int.pm"}), "defer_loading=1 b");
$ds = Data::Schema->new(config=>{defer_loading=>0, schema_search_path=>["."]});
ok(defined($INC{"Data/Schema/Type/Str.pm"}), "defer_loading=0");

$ds = new Data::Schema;

$res = ds_validate(1, 'int');
ok($res && $res->{success}, 'procedural interface');

# first form
$res = $ds->validate(1);
ok(!$res->{success} && $res->{errors}[0] =~ /schema is missing/, 'missing schema');

$res = $ds->validate(1, 'foo');
ok(!$res->{success} && $res->{errors}[0] =~ /unknown type/, 'unknown type');

# second form
invalid(2, [int=>{divisible_by=>2}=>{divisible_by=>3}], 'multiple attrhash 1.1');
invalid(3, [int=>{divisible_by=>2}=>{divisible_by=>3}], 'multiple attrhash 1.2');
valid  (6, [int=>{divisible_by=>2}=>{divisible_by=>3}], 'multiple attrhash 1.3');

# third form
valid  ( 1, {type=>'int'}, 'third form 0.1');
invalid([], {type=>'int'}, 'third form 0.2');
valid  (10, {type=>'int', attrs=>{min=>10}}, 'third form 0.3');
invalid( 1, {type=>'int', attrs=>{min=>10}}, 'third form 0.4');
valid  (10, {type=>'int', attr_hashes=>[{min=>10}]}, 'third form 0.5');
invalid( 1, {type=>'int', attr_hashes=>[{min=>10}]}, 'third form 0.6');
valid  (15, {type=>'int', attr_hashes=>[{min=>10}], attrs=>{divisible_by=>3}}, 'third form 0.7');
invalid(10, {type=>'int', attr_hashes=>[{min=>10}], attrs=>{divisible_by=>3}}, 'third form 0.8');
# NOTE: def key of third form is tested in 06-schema.t
invalid( 1, {type=>'int', foo=>1}, 'third form unknown key');

# common attribute: required
valid  (1,     [int=>{required=>1}], 'required 1');
valid  (0,     [int=>{required=>1}], 'required 2');
valid  ('',    [str=>{required=>1}], 'required 2 str');
invalid(undef, [int=>{required=>1}], 'required 3');
valid  (undef, [int=>{required=>0}], 'required 4');
# alias for required: set=>1
valid  (1,     [int=>{set=>1}], 'set 1');
valid  (0,     [int=>{set=>1}], 'set 2');
valid  ('',    [str=>{set=>1}], 'set 2 str');
invalid(undef, [int=>{set=>1}], 'set 3');
valid  (undef, [int=>{set=>undef}], 'set 4');

# common attribute: forbidden
invalid(1,     [int=>{forbidden=>1}], 'forbidden 1');
invalid(0,     [int=>{forbidden=>1}], 'forbidden 2');
invalid('',    [str=>{forbidden=>1}], 'forbidden 2 str');
valid  (undef, [int=>{forbidden=>1}], 'forbidden 3');
valid  (undef, [int=>{forbidden=>0}], 'forbidden 4');
# alias for forbidden: set=>0
invalid(1,     [int=>{set=>0}], 'set 5');
invalid(0,     [int=>{set=>0}], 'set 6');
invalid('',    [str=>{set=>0}], 'set 6 str');
valid  (undef, [int=>{set=>0}], 'set 7');
valid  (undef, [int=>{set=>undef}], 'set 8');

# attribute conflict: required/forbidden & set
invalid(0,     [int=>{required=>1, forbidden=>1}], 'conflict required+forbidden 1a');
invalid(undef, [int=>{required=>1, forbidden=>1}], 'conflict required+forbidden 1b');
valid  (0,     [int=>{required=>1, forbidden=>0}], 'conflict required+forbidden 2a');
invalid(undef, [int=>{required=>1, forbidden=>0}], 'conflict required+forbidden 2b');
invalid(0,     [int=>{required=>0, forbidden=>1}], 'conflict required+forbidden 3a');
valid  (undef, [int=>{required=>0, forbidden=>1}], 'conflict required+forbidden 3b');
valid  (0,     [int=>{required=>0, forbidden=>0}], 'conflict required+forbidden 4a');
valid  (undef, [int=>{required=>0, forbidden=>0}], 'conflict required+forbidden 4b');
# conflict alias set=1 for required
invalid(0,     [int=>{set=>1, forbidden=>1}], 'conflict set+forbidden 1a');
invalid(undef, [int=>{set=>1, forbidden=>1}], 'conflict set+forbidden 1b');
valid  (0,     [int=>{set=>1, forbidden=>0}], 'conflict set+forbidden 2a');
invalid(undef, [int=>{set=>1, forbidden=>0}], 'conflict set+forbidden 2b');
invalid(0,     [int=>{set=>undef, forbidden=>1}], 'conflict set+forbidden 3a');
valid  (undef, [int=>{set=>undef, forbidden=>1}], 'conflict set+forbidden 3b');
valid  (0,     [int=>{set=>undef, forbidden=>0}], 'conflict set+forbidden 4a');
valid  (undef, [int=>{set=>undef, forbidden=>0}], 'conflict set+forbidden 4b');
# conflict alias set=0 for forbidden
invalid(0,     [int=>{required=>1, set=>0}], 'conflict required+set 1a');
invalid(undef, [int=>{required=>1, set=>0}], 'conflict required+set 1b');
valid  (0,     [int=>{required=>1, set=>undef}], 'conflict required+set 2a');
invalid(undef, [int=>{required=>1, set=>undef}], 'conflict required+set 2b');
invalid(0,     [int=>{required=>0, set=>0}], 'conflict required+set 3a');
valid  (undef, [int=>{required=>0, set=>0}], 'conflict required+set 3b');
valid  (0,     [int=>{required=>0, set=>undef}], 'conflict required+set 4a');
valid  (undef, [int=>{required=>0, set=>undef}], 'conflict required+set 4b');

# register_type
$ds->register_type(foo => MyType1->new);
$res = $ds->validate(1, 'foo');
ok($res->{success}, 'register_type');

$res = $ds->validate(1, [foo => {bar=>1}]);
ok($res->{success}, 'new attribute');

$res = $ds->validate(1, [foo => {baz=>1}]);
ok(!$res->{success} && $res->{errors}[0] =~ /unknown attribute/, 'unknown attribute');

# attr_hashes merge
valid  (2,  [int=>{divisible_by=>2}=>{"!divisible_by"=>3}], 'multiple attrhash 2.1');
valid  (3,  [int=>{divisible_by=>2}=>{"!divisible_by"=>3}], 'multiple attrhash 2.2');
valid  (1,  [int=>{divisible_by=>2}=>{"!divisible_by"=>3}], 'multiple attrhash 2.3');
invalid(1.1,[int=>{divisible_by=>2}=>{"!divisible_by"=>3}], 'multiple attrhash 2.4');

valid  (2, [int=>{one_of=>[2]}=>{"+one_of"=>[3]}], 'multiple attrhash 3.1');
valid  (3, [int=>{one_of=>[2]}=>{"+one_of"=>[3]}], 'multiple attrhash 3.2');
invalid(0, [int=>{one_of=>[2]}=>{"+one_of"=>[3]}], 'multiple attrhash 3.3');

invalid(2, [int=>{is=>2}=>{"*is"=>3}], 'multiple attrhash 4.1');
valid  (3, [int=>{is=>2}=>{"*is"=>3}], 'multiple attrhash 4.2');
invalid(0, [int=>{is=>2}=>{"*is"=>3}], 'multiple attrhash 4.3');

invalid(2,  [int=>{'^divisible_by'=>2}=>{"divisible_by"=>3}], 'multiple attrhash 5.1 (keep left attr)');
invalid(3,  [int=>{'^divisible_by'=>2}=>{"divisible_by"=>3}], 'multiple attrhash 5.2 (keep left attr)');
valid  (6,  [int=>{'^divisible_by'=>2}=>{"divisible_by"=>3}], 'multiple attrhash 5.3 (keep left attr)');

valid  (2,  [int=>{'^divisible_by'=>2}=>{"!divisible_by"=>3}], 'multiple attrhash 5.4 (keep left attr)');
invalid(3,  [int=>{'^divisible_by'=>2}=>{"!divisible_by"=>3}], 'multiple attrhash 5.5 (keep left attr)');

$ds = new Data::Schema;
invalid(15, {def=>{even=>[int=>{divisible_by=>2}]}, type=>'even', attr_hashes=>[{min=>10}], attrs=>{divisible_by=>3}}, 'third form 1.1', $ds);
valid  (12, {def=>{even=>[int=>{divisible_by=>2}]}, type=>'even', attr_hashes=>[{min=>10}], attrs=>{divisible_by=>3}}, 'third form 1.2', $ds);
invalid( 2, 'even', 'third form 1.3', $ds); # 'even' is still unknown after previous validation

valid  ( 2, {def=>{even=>[int=>{divisible_by=>2}], positive_even=>[even=>{min=>0}]},
             type=>'positive_even'}, 'third form 2.1', $ds);
invalid( 1, {def=>{even=>[int=>{divisible_by=>2}], positive_even=>[even=>{min=>0}]},
             type=>'positive_even'}, 'third form 2.2', $ds);
invalid(-2, {def=>{even=>[int=>{divisible_by=>2}], positive_even=>[even=>{min=>0}]},
             type=>'positive_even'}, 'third form 2.3', $ds);
invalid( 2, 'even', 'third form 2.4', $ds); # 'even' is still unknown after previous validation
invalid( 2, 'even', 'third form 2.5', $ds); # 'positive_even' is still unknown after previous validation

my $sch = {def=>{
                 even=>[int=>{divisible_by=>2}],
                 positive_even=>[even=>{min=>0}],
                 pe=>"positive_even",
                 array_of_pe=>[array=>{of=>'pe'}],
                },
           type=>'array_of_pe'};
invalid(2    , $sch, 'third form 3.1', $ds);
valid  ([]   , $sch, 'third form 3.2', $ds);
valid  ([2]  , $sch, 'third form 3.3', $ds);
invalid([-2] , $sch, 'third form 3.4', $ds);
invalid( 2, 'even', 'third form 2.5', $ds); # 'even' is still unknown after previous validation
invalid( 2, 'positive_even', 'third form 2.6', $ds);
invalid( 2, 'pe', 'third form 2.7', $ds);
invalid( [], 'array_of_pe', 'third form 2.8', $ds);

# attr suffix: errmsg
$res = ds_validate(10, [int=>{"min"=>200, "min.errmsg"=>"don't be so cheap!"}]);
ok(!$res->{success} && $res->{errors}[0] =~ /cheap/, 'attribute suffix: errmsg');
# config: gettext_function
$ds = new Data::Schema;
$ds->config->gettext_function(sub { "tong pedit atuh!" });
$res = $ds->validate(10, [int=>{"min"=>200, "min.errmsg"=>"min.errmsg"}]);
ok(!$res->{success} && $res->{errors}[0] =~ /pedit/, 'config: gettext_function');

# unknown attr suffix
$res = ds_validate(1, [int=>{"max.foo"=>1}]);
ok(!$res->{success} && $res->{errors}[0] =~ /suffix/, 'unknown attribute suffix');

# _pos_as_str escapes whitespaces
is($ds->_pos_as_str(["a", "b ", " c", "  d "]), "a/b_/_c/_d_", "_pos_as_str and whitespace");

# casual tests for english
test_english('int', 'int', 'english 1', $ds);
test_english(["array"], 'array', 'english 2', $ds);
test_english([array=>{of=>"str"}], 'array of (string)', 'english 3', $ds);
test_english([hash=>{of=>["float", "object"]}],
                     'hash of (float => object)', 'english 4', $ds);
test_english([any=>{of=>["int", [array=>{all_elems=>"int"}]]}],
                     '(int) or (array of (int))', 'english 5', $ds);
test_english([all=>{of=>["int", "float"]}],
                     '(int) as well as (float)', 'english 6', $ds);

# TODO: register_plugin, unknown plugin
