#!perl -T

use Test::More tests => 13;

BEGIN {
	use_ok( 'Data::Schema' );

	#use_ok( 'Data::Schema::Type::Base' );
	use_ok( 'Data::Schema::Type::Hash' );
	use_ok( 'Data::Schema::Type::Array' );
	use_ok( 'Data::Schema::Type::Str' );
	#use_ok( 'Data::Schema::Type::Num' );
	use_ok( 'Data::Schema::Type::Int' );
	use_ok( 'Data::Schema::Type::Float' );
	use_ok( 'Data::Schema::Type::Bool' );
	use_ok( 'Data::Schema::Type::Schema' );
	use_ok( 'Data::Schema::Type::Either' );
	use_ok( 'Data::Schema::Type::All' );
	use_ok( 'Data::Schema::Type::Object' );

	#use_ok( 'Data::Schema::Plugin::LoadSchema::Base' );
	use_ok( 'Data::Schema::Plugin::LoadSchema::Hash' );
	use_ok( 'Data::Schema::Plugin::LoadSchema::YAMLFile' );
}

diag( "Testing Data::Schema $Data::Schema::VERSION, Perl $], $^X" );
