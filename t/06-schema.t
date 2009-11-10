#!perl -T

use strict;
use warnings;
use Test::More tests => 28;
use Test::Exception;
use FindBin '$Bin';

BEGIN {
    use_ok('Data::Schema::Type::Schema');
    use_ok('Data::Schema::Plugin::LoadSchema::YAMLFile');
    use_ok('Data::Schema');
}

use lib './t';
require 'testlib.pm';

my $ds = Data::Schema->new;
$ds->register_plugin('Data::Schema::Plugin::LoadSchema::YAMLFile');
$ds->config->schema_search_path(["$Bin/schemas"]);

dies_ok { $ds->validate(1, 'invalid_unknown_base') } 'schema type: unknown base type';
dies_ok { $ds->validate(1, 'invalid_recursive') } 'schema type: recursive';
dies_ok { $ds->validate(1, 'invalid_circular') } 'schema type: circular';

valid('1.2.3.4', 'ip', 'basic 1', $ds);
invalid('1.2.3', 'ip', 'basic 2', $ds);
invalid([], 'ip', 'basic 3', $ds);

valid(undef, 'ip', 'undef', $ds);
invalid(undef, [ip=>{required=>1}], 'required 1', $ds);
valid('1.2.3.4', [ip=>{required=>1}], 'required 2', $ds);
valid(undef, [ip=>{forbidden=>1}], 'forbidden 1', $ds);
invalid('1.2.3.4', [ip=>{forbidden=>1}], 'forbidden 2', $ds);

valid(['1.2.3.4'], [array=>{elem=>['ip']}], 'array 1', $ds);
valid([], [array=>{elem=>['ip']}], 'array 2', $ds);
invalid('1.2.3.4', [array=>{elem=>['ip']}], 'array 3', $ds);
invalid(['1.2.3'], [array=>{elem=>['ip']}], 'array 4', $ds);

valid(4, 'positive_even', 'schema on schema 1', $ds);
valid(undef, 'positive_even', 'schema on schema 2', $ds);
invalid(-4, 'positive_even', 'schema on schema 3', $ds);
valid(-4, 'even', 'schema on schema 4', $ds);

valid({line1=>1, city=>1, province=>1, country=>"ID", postcode=>12345}, 'address', 'schema on schema + merge 1', $ds);
invalid({line1=>1, city=>1, province=>1, country=>"ID", zipcode=>12345}, 'address', 'schema on schema + merge 2', $ds);
invalid({line1=>1, city=>1, province=>1, country=>"US", zipcode=>12345}, 'address', 'schema on schema + merge 3', $ds);
valid({line1=>1, city=>1, province=>1, country=>"US", zipcode=>12345}, 'us_address', 'schema on schema + merge 4', $ds);
invalid({line1=>1, city=>1, province=>1, country=>"ID", zipcode=>12345}, 'us_address', 'schema on schema + merge 5', $ds);
invalid({line1=>1, city=>1, province=>1, country=>"US", postcode=>12345}, 'us_address', 'schema on schema + merge 6', $ds);
