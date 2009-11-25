#!perl -T

use lib './t';
use lib './t/lib';
use warnings;
use Test::More tests => 8;
use Test::Exception;

eval "package I1; require Data::Schema; import Data::Schema qw/Foo/; package main;";
ok($@, 'import: unknown');

#plugin

package IP1; require Data::Schema; import Data::Schema qw/Plugin::LoadSchema::YAMLFile Plugin::LoadSchema::Hash/; our $ds = new Data::Schema; package main;
is(scalar(@{ $IP1::ds->plugins }), 2, 'import plugin 1');

package IP2; require Data::Schema; import Data::Schema qw//; our $ds = new Data::Schema; package main;
is(scalar(@{ $IP2::ds->plugins }), 0, 'import plugin 2');

eval "package IP3; require Data::Schema; import Data::Schema qw/Plugin::Foo/; package main;";
ok($@, 'import plugin: unknown');

# type
package IT1; require Data::Schema; import Data::Schema qw/Type::MyType1/; our $ds = new Data::Schema; package main;
ok($IT1::ds->type_handlers->{mytype1}, 'import type 1');
ok(!$IP2::ds->type_handlers->{mytype1}, 'import type 2');

# schema
package IS1; require Data::Schema; import Data::Schema qw/Schema::Schema/; our $ds = new Data::Schema; package main;
ok($IS1::ds->type_handlers->{schema}, 'import schema 1');
ok(!$IP2::ds->type_handlers->{schema}, 'import schema 2');
