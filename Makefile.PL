
use strict;
use warnings;

use ExtUtils::MakeMaker;

WriteMakefile(
  DISTNAME  => 'Data-Schema',
  NAME      => 'Data::Schema',
  AUTHOR    => "Steven\ Haryanto\ \<stevenharyanto\@gmail\.com\>",
  ABSTRACT  => "(DEPRECATED) Validate\ nested\ data\ structures\ with\ nested\ structure",
  VERSION   => '0.136',
  EXE_FILES => [ qw() ],
  (eval { ExtUtils::MakeMaker->VERSION(6.31) } ? (LICENSE => 'perl') : ()),
  PREREQ_PM    => {
    "Scalar::Util" => '0',
    "Test::Exception" => '0',
    "FindBin" => '0',
    "Data::ModeMerge" => '0',
    "Data::Dumper" => '0',
    "Storable" => '0',
    "YAML::Syck" => '0',
    "Test::More" => '0',
    "Digest::MD5" => '0',
    "List::MoreUtils" => '0',
    "Moose" => '0',
    "File::Slurp" => '0',
    "multidimensional" => '0',
    "bareword::filehandles" => '0',
  },
  test => {TESTS => 't/*.t'}
);

