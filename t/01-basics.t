#!perl -T

use strict;
use warnings;
use Test::More;
use Test::Exception;
use Data::Dumper;
use Data::Schema;

use lib './t';
require 'testlib.pm';

package MyType1;
use Moose;
extends 'Data::Schema::Type::Base';
sub handle_attr_bar { 1 };
sub emitpl_attr_bar { '' };

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
dies_ok(sub { $res = $ds->validate(1) }, 'schema error: missing');
dies_ok(sub { $ds->validate(1, 'foo') }, 'schema error: unknown type [1f]');

# second form
invalid(2, [int=>{divisible_by=>2}=>{divisible_by=>3}], 'multiple attrhash 1.1');
invalid(3, [int=>{divisible_by=>2}=>{divisible_by=>3}], 'multiple attrhash 1.2');
valid  (6, [int=>{divisible_by=>2}=>{divisible_by=>3}], 'multiple attrhash 1.3');
dies_ok(sub { $ds->validate(1, ['foo']) }, 'schema error: unknown type (2f)');
dies_ok(sub { $ds->validate(1, [int=>{foo=>1}]) }, 'schema error: unknown attr (2f)');
dies_ok(sub { $ds->validate(1, [int=>{deps=>1}]) }, 'schema error: incorrect attr arg (2f)'); # XXX should test on every known attr

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
dies_ok(sub { $ds->validate( 1, {type=>'int', foo=>1}) }, 'third form unknown key');

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
dies_ok(sub {$ds->validate(0,     [int=>{required=>1, forbidden=>1}])}, 'conflict required+forbidden 1a');
dies_ok(sub {$ds->validate(undef, [int=>{required=>1, forbidden=>1}])}, 'conflict required+forbidden 1b');
valid  (0,     [int=>{required=>1, forbidden=>0}], 'conflict required+forbidden 2a');
invalid(undef, [int=>{required=>1, forbidden=>0}], 'conflict required+forbidden 2b');
invalid(0,     [int=>{required=>0, forbidden=>1}], 'conflict required+forbidden 3a');
valid  (undef, [int=>{required=>0, forbidden=>1}], 'conflict required+forbidden 3b');
valid  (0,     [int=>{required=>0, forbidden=>0}], 'conflict required+forbidden 4a');
valid  (undef, [int=>{required=>0, forbidden=>0}], 'conflict required+forbidden 4b');
# conflict alias set=1 for required
dies_ok(sub{$ds->validate(0,     [int=>{set=>1, forbidden=>1}])}, 'conflict set+forbidden 1a');
dies_ok(sub{$ds->validate(undef, [int=>{set=>1, forbidden=>1}])}, 'conflict set+forbidden 1b');
valid  (0,     [int=>{set=>1, forbidden=>0}], 'conflict set+forbidden 2a');
invalid(undef, [int=>{set=>1, forbidden=>0}], 'conflict set+forbidden 2b');
invalid(0,     [int=>{set=>undef, forbidden=>1}], 'conflict set+forbidden 3a');
valid  (undef, [int=>{set=>undef, forbidden=>1}], 'conflict set+forbidden 3b');
valid  (0,     [int=>{set=>undef, forbidden=>0}], 'conflict set+forbidden 4a');
valid  (undef, [int=>{set=>undef, forbidden=>0}], 'conflict set+forbidden 4b');
# conflict alias set=0 for forbidden
dies_ok(sub{$ds->validate(0,     [int=>{required=>1, set=>0}])}, 'conflict required+set 1a');
dies_ok(sub{$ds->validate(undef, [int=>{required=>1, set=>0}])}, 'conflict required+set 1b');
valid  (0,     [int=>{required=>1, set=>undef}], 'conflict required+set 2a');
invalid(undef, [int=>{required=>1, set=>undef}], 'conflict required+set 2b');
invalid(0,     [int=>{required=>0, set=>0}], 'conflict required+set 3a');
valid  (undef, [int=>{required=>0, set=>0}], 'conflict required+set 3b');
valid  (0,     [int=>{required=>0, set=>undef}], 'conflict required+set 4a');
valid  (undef, [int=>{required=>0, set=>undef}], 'conflict required+set 4b');

# register_type
$ds->register_type(foo => MyType1->new);
$res = $ds->validate(1, 'foo');
ok($res->{success}, 'user type: register_type');

$res = $ds->validate(1, [foo => {bar=>1}]);
ok($res->{success}, 'user type: new attribute');
dies_ok(sub { $ds->validate(1, [foo=>{baz=>1}]) }, 'user type: unknown attribute');

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

my $sch = [
    "hash",
    {  keys =>{a=>"int"  , b=>"int" ,   c =>"int",                   , "^f"=>"int"  ,   g=>"int"   }},
    {"*keys"=>{a=>"array",              c =>"int", d=>"int"          ,  "f"=>"array", "^g"=>"array"}},
    {"*keys"=>{            b=>"hash", "!c"=>"int",         , e=>"int",  "f"=>"hash" ,  "g"=>"hash" }},
];
invalid({a=>1 }, $sch, 'merge 3 attrhash: a replaced by 2: invalid)');
valid  ({a=>[]}, $sch, 'merge 3 attrhash: a replaced by 2: valid)');
invalid({b=>1 }, $sch, 'merge 3 attrhash: b replaced by 3: invalid)');
valid  ({b=>{}}, $sch, 'merge 3 attrhash: b replaced by 3: valid)');
invalid({c=>1 }, $sch, 'merge 3 attrhash: c removed by 3)');
valid  ({d=>1 }, $sch, 'merge 3 attrhash: d new from 2)');
valid  ({e=>1 }, $sch, 'merge 3 attrhash: e new from 3)');
invalid({f=>[]}, $sch, 'merge 3 attrhash: f keep from 1: invalid 1)');
invalid({f=>{}}, $sch, 'merge 3 attrhash: f keep from 1: invalid 2)');
valid  ({f=>1 }, $sch, 'merge 3 attrhash: f keep from 1: valid)');
valid  ({g=>[]}, $sch, 'merge 3 attrhash: g keep from 2: valid)');
invalid({g=>{}}, $sch, 'merge 3 attrhash: g keep from 2: invalid 1)');
invalid({g=>1 }, $sch, 'merge 3 attrhash: g keep from 2: invalid 2)');

$ds = new Data::Schema;
invalid(15, {def=>{even=>[int=>{divisible_by=>2}]}, type=>'even', attr_hashes=>[{min=>10}], attrs=>{divisible_by=>3}}, 'third form 1.1', $ds);
valid  (12, {def=>{even=>[int=>{divisible_by=>2}]}, type=>'even', attr_hashes=>[{min=>10}], attrs=>{divisible_by=>3}}, 'third form 1.2', $ds);
dies_ok(sub { $ds->validate(2, 'even') }, 'third form 1.3: "even" is still unknown after previous validation');

valid  ( 2, {def=>{even=>[int=>{divisible_by=>2}], positive_even=>[even=>{min=>0}]},
             type=>'positive_even'}, 'third form 2.1', $ds);
invalid( 1, {def=>{even=>[int=>{divisible_by=>2}], positive_even=>[even=>{min=>0}]},
             type=>'positive_even'}, 'third form 2.2', $ds);
invalid(-2, {def=>{even=>[int=>{divisible_by=>2}], positive_even=>[even=>{min=>0}]},
             type=>'positive_even'}, 'third form 2.3', $ds);
dies_ok(sub {$ds->validate(2, 'even')}, 'third form 2.4: "even" is still unknown after previous validation');
dies_ok(sub {$ds->validate(2, 'even')}, 'third form 2.5: "positive_even" is still unknown after previous validation');

$sch = {def=>{
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
dies_ok(sub{$ds->validate( 2, 'even')}, 'third form 2.5: "even" is still unknown after previous validation');
dies_ok(sub{$ds->validate( 2, 'positive_even')}, 'third form 2.6: "even" is still unknown after previous validation');
dies_ok(sub{$ds->validate( 2, 'pe')}, 'third form 2.7: "pe" is still unknown after previous validation');
dies_ok(sub{$ds->validate([], 'array_of_pe')}, 'third form 2.8: "array_of_pe" is still unknown after previous validation');

# attr suffix: errmsg
$res = ds_validate(10, [int=>{"min"=>200, "min:errmsg"=>"don't be so cheap!"}]);
ok(!$res->{success} && $res->{errors}[0] =~ /cheap/, 'attribute suffix: errmsg');
# attrless suffix: errmsg
my ($rnc, $rc) = test_validate(10, [int=>{"min"=>200, one_of=>[25, 50, 100, 250, 500], ":errmsg"=>"invalid donation amount"}]);
is((scalar @{ $rnc->{errors} }), 1, 'attributeless suffix: errmsg 1');
like($rnc->{errors}[0], '/invalid donation amount/', 'attributeless suffix: errmsg 2');
is((scalar @{ $rc ->{errors} }), 1, 'attributeless suffix: errmsg (compiled) 1');
like($rnc->{errors}[0], '/invalid donation amount/', 'attributeless suffix: errmsg 2 (compiled)');
 
# config: gettext_function
$ds = new Data::Schema;
$ds->config->gettext_function(sub { "tong pedit atuh!" });
$res = $ds->validate(10, [int=>{"min"=>200, "min:errmsg"=>"min:errmsg"}]);
ok(!$res->{success} && $res->{errors}[0] =~ /pedit/, 'config: gettext_function');
diag("  INFO: currently this test generates warning from Storable, since we're trying to freeze coderef");

# unknown attr suffix
dies_ok(sub {ds_validate(1, [int=>{"max:foo"=>1}])}, 'unknown attribute suffix');

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

# compile
$ds = new Data::Schema;
my ($sub, $subname) = $ds->compile([int => {min=>2, divisible_by=>2}]);
is(scalar(@{ $sub->(undef) }), 0, "compile 1: valid data 1");
is(scalar(@{ $sub->(2    ) }), 0, "compile 1: valid data 2");
is(scalar(@{ $sub->(0    ) }), 1, "compile 1: invalid data 1");
is(scalar(@{ $sub->(1    ) }), 2, "compile 1: invalid data 2");
is(scalar(@{ $sub->([]   ) }), 1, "compile 1: invalid data 3");

# note: we don't use 'foo' because it's already compiled above when doing register_type
dies_ok(sub { $ds->compile("foo2") }, "compile 1: invalid schema: unknown type");
dies_ok(sub { $ds->compile([int => {foo=>1}]) }, "compile 1: invalid schema: unknown attr");
dies_ok(sub { $ds->compile([int => {deps=>1}]) }, "compile 1: invalid schema: incorrect attr arg");

# emit_perl
$ds = new Data::Schema;
{
    my $code1 = $ds->emit_perl("int");
    my $code1b = $ds->emit_perl("int");
    $ds->config->allow_extra_hash_keys(1);
    my $code2 = $ds->emit_perl("int");
    like($code1 , qr/^\s*sub /m, "emit_perl: valid 1");
    like($code1b, qr/^\s*sub /m, "emit_perl: valid 1b");
    like($code2 , qr/^\s*sub /m, "emit_perl: valid 2");
    ok($code1 eq $code1b, "emit_perl: recompile if config changes a");
    ok($code1 ne $code2 , "emit_perl: recompile if config changes b");
    dies_ok(sub { my $code = $ds->emit_perl("foo") }, "emit_perl: invalid");
}

# TODO: register_plugin, unknown plugin

done_testing();
