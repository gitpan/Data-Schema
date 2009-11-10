use inc::Module::Install;

name     'Data-Schema';
all_from 'lib/Data/Schema.pm';
author   'Steven Haryanto <steven@masterweb.net>';
license  'perl';

build_requires 'Test::More';

test_requires 'FindBin';
test_requires 'Test::Exception';

requires 'Moose';
requires 'Data::Dumper';
requires 'Storable';
requires 'Scalar::Util';
requires 'List::MoreUtils';
requires 'Data::PrefixMerge' => '0.06';

# for DSP::LoadSchema::YAMLFile
requires 'YAML::XS';
requires 'File::Slurp';

auto_install;

WriteAll;
