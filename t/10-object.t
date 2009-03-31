#!perl -T

use strict;
use warnings;
use Test::More tests => 50;

use lib './t';
require 'testlib.pm';

use_ok('Data::Schema::Type::Object');
use_ok('Data::Schema');

valid(undef, 'object', 'undef');
invalid('', 'object', 'scalar');
invalid([], 'object', 'arrayref');
invalid({}, 'object', 'hashref');

package C1; use Moose;
package C2; use Moose; sub m1 {}
package C3; use Moose; sub m2 {}
package C4; use Moose; sub m1 {} sub m2 {}

package D1; use Moose;
package D2; use Moose; extends 'C1';
package D3; use Moose; extends 'C2';
package D4; use Moose; extends 'C1', 'C2';

package main;

valid(C1->new, 'object', 'object');
valid(C1->new, 'obj', 'alias obj');

my $c1 = new C1; my $c2 = new C2; my $c3 = new C3; my $c4 = new C4;
my $d1 = new D1; my $d2 = new D2; my $d3 = new D3; my $d4 = new D4;

for (qw(can can_all)) { # 2x4=8
    invalid($c1, [object=>{$_=>[qw/m1 m2/]}], "$_ 1");
    invalid($c2, [object=>{$_=>[qw/m1 m2/]}], "$_ 2");
    invalid($c3, [object=>{$_=>[qw/m1 m2/]}], "$_ 3");
    valid  ($c4, [object=>{$_=>[qw/m1 m2/]}], "$_ 4");
}
for (qw(can_one)) { # 4
    invalid($c1, [object=>{$_=>[qw/m1 m2/]}], "$_ 1");
    valid  ($c2, [object=>{$_=>[qw/m1 m2/]}], "$_ 2");
    valid  ($c3, [object=>{$_=>[qw/m1 m2/]}], "$_ 3");
    valid  ($c4, [object=>{$_=>[qw/m1 m2/]}], "$_ 4");
}
for (qw(cannot cant)) { # 2x6=12
    valid  ($c1, [object=>{$_=>[qw/m1/]}], "$_ 1");
    invalid($c2, [object=>{$_=>[qw/m1/]}], "$_ 2");

    valid  ($c1, [object=>{$_=>[qw/m1 m2/]}], "$_ 3");
    invalid($c2, [object=>{$_=>[qw/m1 m2/]}], "$_ 4");
    invalid($c3, [object=>{$_=>[qw/m1 m2/]}], "$_ 5");
    invalid($c4, [object=>{$_=>[qw/m1 m2/]}], "$_ 6");
}

for (qw(isa isa_all)) { #2x4=8
    invalid($d1, [object=>{$_=>[qw/C1 C2/]}], "$_ 1");
    invalid($d2, [object=>{$_=>[qw/C1 C2/]}], "$_ 2");
    invalid($d3, [object=>{$_=>[qw/C1 C2/]}], "$_ 3");
    valid  ($d4, [object=>{$_=>[qw/C1 C2/]}], "$_ 4");
}
for (qw(isa_one)) { # 4
    invalid($d1, [object=>{$_=>[qw/C1 C2/]}], "$_ 1");
    valid  ($d2, [object=>{$_=>[qw/C1 C2/]}], "$_ 2");
    valid  ($d3, [object=>{$_=>[qw/C1 C2/]}], "$_ 3");
    valid  ($d4, [object=>{$_=>[qw/C1 C2/]}], "$_ 4");
}
for (qw(not_isa)) { # 1x6=6
    valid  ($d1, [object=>{$_=>[qw/C1/]}], "$_ 1");
    invalid($d2, [object=>{$_=>[qw/C1/]}], "$_ 2");

    valid  ($d1, [object=>{$_=>[qw/C1 C2/]}], "$_ 3");
    invalid($d2, [object=>{$_=>[qw/C1 C2/]}], "$_ 4");
    invalid($d3, [object=>{$_=>[qw/C1 C2/]}], "$_ 5");
    invalid($d4, [object=>{$_=>[qw/C1 C2/]}], "$_ 6");
}
