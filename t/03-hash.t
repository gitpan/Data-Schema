#!perl -T

use strict;
use warnings;
use Test::More tests => 123;

BEGIN { use_ok('Data::Schema'); }

use lib './t';
require 'testlib.pm';

valid({}, 'hash', 'basic 1');
valid({1, 2}, 'hash', 'basic 2');

# not hash
invalid([], 'hash', 'array');
invalid('123', 'hash', 'str');
invalid(\1, 'hash', 'refscalar');

# required
valid(undef, 'hash', 'undef');
invalid(undef, [hash => {required => 1}], 'required 1');
valid({}, [hash => {required => 1}], 'required 2');

test_len('hash', {a=>1}, {a=>1, b=>2}, {a=>1, b=>2, c=>3}); # 36

test_is_isnt_oneof('hash', {a=>1}, {b=>1}, {c=>1}, {d=>1}); # 26

# keys_match, values_match = 1x8 = 8
for (qw(match)) {
    valid({a=>1}, [hash => {"keys_$_"=>'^\w+$'}], "keys_$_ 1");
    invalid({a=>1, 'b '=>2}, [hash => {"keys_$_"=>'^\w+$'}], "keys_$_ 2");
    valid({'a '=>1}, [hash => {"keys_not_$_"=>'^\w+$'}], "keys_not_$_ 1");
    invalid({'a '=>1, b=>2}, [hash => {"keys_not_$_"=>'^\w+$'}], "keys_not_$_ 2");

    valid({1=>'a'}, [hash => {"values_$_"=>'^\w+$'}], "values_$_ 1");
    invalid({1=>'a', 2=>'b '}, [hash => {"values_$_"=>'^\w+$'}], "values_$_ 2");
    valid({1=>'a '}, [hash => {"values_not_$_"=>'^\w+$'}], "values_not_$_ 1");
    invalid({1=>'a ', 2=>'b'}, [hash => {"values_not_$_"=>'^\w+$'}], "values_not_$_ 2");
}

# required_keys
valid({a=>1, b=>1, c=>1}, [hash => {required_keys=>[qw/a b/]}], "required_keys 1");
valid({a=>1, b=>1, c=>undef}, [hash => {required_keys=>[qw/a b/]}], "required_keys 2");
invalid({a=>1, b=>undef, c=>1}, [hash => {required_keys=>[qw/a b/]}], "required_keys 3");
invalid({a=>undef, b=>1, c=>1}, [hash => {required_keys=>[qw/a b/]}], "required_keys 4");
invalid({b=>1, c=>1}, [hash => {required_keys=>[qw/a b/]}], "required_keys 5");
invalid({c=>undef}, [hash => {required_keys=>[qw/a b/]}], "required_keys 6");
valid({}, [hash => {required_keys=>[]}], "required_keys 7");

# required_keys_regex = 1x7 = 7
for (qw(required_keys_regex)) {
    valid({a=>1, b=>1, c=>1}, [hash => {$_=>'^[ab]$'}], "$_ 1");
    valid({a=>1, b=>1, c=>undef}, [hash => {$_=>'^[ab]$'}], "$_ 2");
    invalid({a=>1, b=>undef, c=>1}, [hash => {$_=>'^[ab]$'}], "$_ 3");
    invalid({a=>undef, b=>1, c=>1}, [hash => {$_=>'^[ab]$'}], "$_ 4");
    valid({b=>1, c=>1}, [hash => {$_=>'^[ab]$'}], "$_ 5");
    valid({c=>undef}, [hash => {$_=>'^[ab]$'}], "$_ 6");
    valid({}, [hash => {$_=>'.*'}], "$_ 7");
}

# all_keys 2x3 = 6
for (qw(all_keys of)) {
    my $sch = [hash=>{$_=>'int'}];
    valid({}, $sch, "$_ 1");
    valid({a=>1, b=>0, c=>-1}, $sch, "$_ 2");
    invalid({a=>1, b=>"a"}, $sch, "$_ 3");
}

# keys 1x14 = 14
for (qw(keys)) {
    my $sch = [hash=>{$_=>{i=>'int', s=>'str', s2=>[str=>{minlen=>2}]}}];
    valid({}, $sch, "$_ 1.1");
    valid({k=>1}, $sch, "$_ 1.2");
    valid({i=>1}, $sch, "$_ 1.3");
    invalid({i=>"a"}, $sch, "$_ 1.4");
    valid({i=>1, s=>''}, $sch, "$_ 1.5");
    invalid({i=>1, s=>[]}, $sch, "$_ 1.6");
    invalid({i=>1, s=>'', s2=>''}, $sch, "$_ 1.7");
    valid({i=>1, s=>'', s2=>'ab'}, $sch, "$_ 1.8");

    $sch = [hash=>{$_=>{h=>"hash", h2=>[hash=>{minlen=>1, $_=>{hi2=>[int=>{min=>2}]}}]}}];
    invalid({h=>1}, $sch, "$_ 2.1");
    valid({h=>{}}, $sch, "$_ 2.2");
    invalid({h=>{}, h2=>{}}, $sch, "$_ 2.3");
    valid({h2=>{j=>1}}, $sch, "$_ 2.4");
    invalid({h2=>{hi2=>1}}, $sch, "$_ 2.5");
    valid({h2=>{hi2=>2}}, $sch, "$_ 2.6");
}

# keys_one_of 2x3 = 6
for (qw(keys_one_of allowed_keys)) {
    valid({}, [hash=>{$_=>["a", "b"]}], "$_ 1");
    valid({a=>1, b=>1}, [hash=>{$_=>["a", "b"]}], "$_ 2");
    invalid({a=>1, b=>1, c=>1}, [hash=>{$_=>["a", "b"]}], "$_ 3");
}

# keys_regex 1x4 = 4
for (qw(keys_regex)) {
    my $sch = [hash=>{$_=>{'^i\d*$'=>'int'}}];
    valid({}, $sch, "$_ 1");
    valid({i=>1, i2=>2}, $sch, "$_ 2");
    invalid({i=>1, i2=>"a"}, $sch, "$_ 3");
    valid({j=>1}, $sch, "$_ 4");
}
