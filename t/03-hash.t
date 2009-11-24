#!perl -T

use strict;
use warnings;
use Test::More;

use Data::Schema;

use lib './t';
require 'testlib.pm';

valid({}, 'hash', 'basic 1');
valid({1, 2}, 'hash', 'basic 2');

# not hash
invalid([], 'hash', 'array');
invalid('123', 'hash', 'str');
invalid(\1, 'hash', 'refscalar');

# required
valid({}, [hash => {required => 1}], 'required 1');

test_len('hash', {a=>1}, {a=>1, b=>2}, {a=>1, b=>2, c=>3}); # 36

test_comparable('hash', {a=>1}, {b=>1}, {c=>1}, {d=>1}); # 26

for (qw(keys_match allowed_keys_regex)) {
    valid({a=>1}, [hash => {$_=>'^\w+$'}], "$_ 1");
    invalid({a=>1, 'b '=>2}, [hash => {$_=>'^\w+$'}], "$_ 2");
}

for (qw(keys_not_match forbidden_keys_regex)) {
    valid({'a '=>1}, [hash => {$_=>'^\w+$'}], "$_ 1");
    invalid({'a '=>1, b=>2}, [hash => {$_=>'^\w+$'}], "$_ 2");
}

for (qw(values_match allowed_values_regex)) {
    valid({1=>'a'}, [hash => {$_=>'^\w+$'}], "$_ 1");
    invalid({1=>'a', 2=>'b '}, [hash => {$_=>'^\w+$'}], "$_ 2");
}

for (qw(values_not_match forbidden_values_regex)) {
    valid({1=>'a '}, [hash => {$_=>'^\w+$'}], "$_ 1");
    invalid({1=>'a ', 2=>'b'}, [hash => {$_=>'^\w+$'}], "$_ 2");
}

# required_keys
valid({a=>1, b=>1, c=>1}, [hash => {required_keys=>[qw/a b/]}], "required_keys 1");
valid({a=>1, b=>1, c=>undef}, [hash => {required_keys=>[qw/a b/]}], "required_keys 2");
valid({a=>1, b=>undef, c=>1}, [hash => {required_keys=>[qw/a b/]}], "required_keys 3");
valid({a=>undef, b=>1, c=>1}, [hash => {required_keys=>[qw/a b/]}], "required_keys 4");
invalid({b=>1, c=>1}, [hash => {required_keys=>[qw/a b/]}], "required_keys 5");
invalid({c=>undef}, [hash => {required_keys=>[qw/a b/]}], "required_keys 6");
valid({}, [hash => {required_keys=>[]}], "required_keys 7");

for (qw(required_keys_regex)) {
    valid  ({a=>1    , b=>1    }, [hash => {$_=>'^[a]$'}], "$_ 1");
    valid  ({a=>1    , b=>undef}, [hash => {$_=>'^[a]$'}], "$_ 2");
    valid  ({a=>1    ,         }, [hash => {$_=>'^[a]$'}], "$_ 3");
    valid  ({a=>undef, b=>1    }, [hash => {$_=>'^[a]$'}], "$_ 4");
    valid  ({a=>undef, b=>undef}, [hash => {$_=>'^[a]$'}], "$_ 5");
    valid  ({a=>undef,         }, [hash => {$_=>'^[a]$'}], "$_ 6");
    invalid({          b=>1    }, [hash => {$_=>'^[a]$'}], "$_ 7");
    invalid({          b=>undef}, [hash => {$_=>'^[a]$'}], "$_ 8");
    invalid({                  }, [hash => {$_=>'^[a]$'}], "$_ 9");
}

for (qw(keys_of)) {
    my $sch = [hash=>{$_=>'int'}];
    valid({}, $sch, "$_ 1");
    valid({1=>1, 0=>0, -1=>-1}, $sch, "$_ 2");
    invalid({a=>1}, $sch, "$_ 3");
}

for (qw(of values_of)) {
    my $sch = [hash=>{$_=>'int'}];
    valid({}, $sch, "$_ 1");
    valid({a=>1, b=>0, c=>-1}, $sch, "$_ 2");
    invalid({a=>1, b=>"a"}, $sch, "$_ 3");
}

for (qw(some_of)) {
    # at least one int=>int, exactly 2 str=>str, at most one int=>array. note: str is also int
    my $sch = [hash=>{$_=>[ [int=>int=>1,-1], [str=>str=>2,2], [int=>array=>0,1] ]}];
    invalid([], $sch, "$_ 1");

    valid({1=>1, a=>"a", 3=>[]}, $sch, "$_ 2");

    valid({1=>1, 2=>2, 3=>[]}, $sch, "$_ 3");
    valid({1=>1, 2=>2}, $sch, "$_ 4");
    valid({1=>1, a=>"a"}, $sch, "$_ 5");

    invalid({a=>"a", b=>"b", 3=>[]}, $sch, "$_ 6"); # too few int=>int
    invalid({1=>1, 3=>[]}, $sch, "$_ 7"); # too few str=>str
    invalid({1=>1, 2=>2, a=>"a", 3=>[]}, $sch, "$_ 8"); # too many str=>str
    invalid({1=>1, a=>"a", 3=>[], 4=>[]}, $sch, "$_ 9"); # too many int=>array

    invalid({1=>1.1, a=>"a", 3=>[]}, $sch, "$_ 10"); # invalid int=>int
    invalid({1.1=>1, a=>"a", 3=>[]}, $sch, "$_ 11"); # invalid int=>int
    invalid({1=>1, a=>[], 3=>[]}, $sch, "$_ 12"); # invalid str=>str
    valid({1=>1, a=>"a", 3.1=>[]}, $sch, "$_ 13"); # invalid int=>array, but still valid
    valid({1=>1, a=>"a", 3=>{}}, $sch, "$_ 14"); # invalid int=>array, but still valid

    invalid({}, $sch, "$_ 15");
}

for (qw(keys)) {
    my $dse = new Data::Schema(config=>{allow_extra_hash_keys=>1});

    my $sch = [hash=>{$_=>{i=>'int', s=>'str', s2=>[str=>{minlen=>2}]}}];
    valid({}, $sch, "$_ 1.1");
    invalid({k=>1}, $sch, "$_ 1.2");
    valid  ({k=>1}, $sch, "$_ 1.2 (allow_extra_hash_keys=1)", $dse);
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
    invalid({h2=>{j=>1}}, $sch, "$_ 2.4");
    valid  ({h2=>{j=>1}}, $sch, "$_ 2.4 (allow_extra_hash_keys=1)", $dse);
    invalid({h2=>{hi2=>1}}, $sch, "$_ 2.5");
    valid({h2=>{hi2=>2}}, $sch, "$_ 2.6");
}

for (qw(keys_one_of allowed_keys)) {
    my $sch = [hash=>{$_=>["a", "b"]}];
    valid({}, $sch, "$_ 1");
    valid({a=>1, b=>1}, $sch, "$_ 2");
    invalid({a=>1, b=>1, c=>1}, $sch, "$_ 3");
}

for (qw(values_one_of allowed_values)) {
    my $sch = [hash=>{$_=>[1, 2, [3]]}];
    valid({}, $sch, "$_ 1");
    valid({a=>1, b=>2, c=>[3]}, $sch, "$_ 2");
    invalid({a=>3}, $sch, "$_ 3");
}

for (qw(keys_regex)) {
    my $sch = [hash=>{$_=>{'^i\d*$'=>'int'}}];
    valid({}, $sch, "$_ 1");
    valid({i=>1, i2=>2}, $sch, "$_ 2");
    invalid({i=>1, i2=>"a"}, $sch, "$_ 3");
    valid({j=>1}, $sch, "$_ 4");
}

for (qw(deps)) {
    my $sch;
    # second totally dependant on first
    $sch = [hash=>{$_ => [[a=>[int=>{set=>1}], b=>[int=>{set=>1}]],
                          [a=>[int=>{set=>0}], b=>[int=>{set=>0}]] ]}];
    valid  ({},                  $sch, "$_ 1.1");
    valid  ({a=>undef,b=>undef}, $sch, "$_ 1.2");
    invalid({a=>1,b=>undef},     $sch, "$_ 1.3");
    invalid({a=>undef,b=>1},     $sch, "$_ 1.4");
    valid  ({a=>1,b=>1},         $sch, "$_ 1.5");
    # no match
    valid  ({a=>"a",b=>undef},   $sch, "$_ 1.6");
    valid  ({a=>"a",b=>1},       $sch, "$_ 1.7");
    valid  ({a=>"a",b=>"a"},     $sch, "$_ 1.8");

    # mutually exclusive
    $sch = [hash=>{$_ => [[a=>[int=>{set=>1}], b=>[int=>{set=>0}]],
                          [a=>[int=>{set=>0}], b=>[int=>{set=>1}]] ]}];
    invalid({},                  $sch, "$_ 2.1");
    invalid({a=>undef,b=>undef}, $sch, "$_ 2.2");
    valid  ({a=>1,b=>undef},     $sch, "$_ 2.3");
    valid  ({a=>undef,b=>1},     $sch, "$_ 2.4");
    invalid({a=>1,b=>1},         $sch, "$_ 2.5");
    # no match
    valid  ({a=>"a",b=>undef},   $sch, "$_ 2.6");
    valid  ({a=>"a",b=>1},       $sch, "$_ 2.7");
    valid  ({a=>"a",b=>"a"},     $sch, "$_ 2.8");
}

# allow_extra_keys
valid  ({a=>1}       , [hash=>{keys=>{a=>"int"}}], "allow_extra_keys 1a");
invalid({a=>1,b=>2}  , [hash=>{keys=>{a=>"int"}}], "allow_extra_keys 1b");
valid  ({a=>1}       , [hash=>{keys=>{a=>"int"}, allow_extra_keys=>0}], "allow_extra_keys 2a");
invalid({a=>1,b=>2}  , [hash=>{keys=>{a=>"int"}, allow_extra_keys=>0}], "allow_extra_keys 2b");
valid  ({a=>1}       , [hash=>{keys=>{a=>"int"}, allow_extra_keys=>1}], "allow_extra_keys 3a");
valid  ({a=>1,b=>2}  , [hash=>{keys=>{a=>"int"}, allow_extra_keys=>1}], "allow_extra_keys 3b");
invalid({a=>"a",b=>2}, [hash=>{keys=>{a=>"int"}, allow_extra_keys=>1}], "allow_extra_keys 3c");
# overrides validator config setting
my $dse = Data::Schema->new(config=>{allow_extra_hash_keys=>1});
valid  ({a=>1,b=>2}  , [hash=>{keys=>{a=>"int"}}], "allow_extra_keys 4a", $dse);
invalid({a=>1,b=>2}  , [hash=>{keys=>{a=>"int"}, allow_extra_keys=>0}], "allow_extra_keys 4b");

done_testing();
