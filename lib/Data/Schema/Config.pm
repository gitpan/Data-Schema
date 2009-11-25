package Data::Schema::Config;
our $VERSION = '0.13';


# ABSTRACT: Data::Schema configuration


use Moose;


has max_errors => (is => 'rw', default => 100);


has max_warnings => (is => 'rw', default => 100);


has schema_search_path => (is => 'rw', default => sub { ["."] });


has gettext_function => (is => 'rw');


has defer_loading => (is => 'rw', default => 1);


has allow_extra_hash_keys => (is => 'rw', default => 0);


has debug => (is => 'rw', default => 0);


has compile => (is => 'rw', default => 0);

__PACKAGE__->meta->make_immutable;
no Moose;
1;

__END__
=pod

=head1 NAME

Data::Schema::Config - Data::Schema configuration

=head1 VERSION

version 0.13

=head1 SYNOPSIS

    # getting configuration
    if ($validator->config->allow_extra_hash_keys) { ... }

    # setting configuration
    $validator->config->max_errors(100);

=head1 DESCRIPTION

Configuration variables for Data::Schema.

=head1 ATTRIBUTES

=head2 max_errors => INT

Maximum number of errors before validation stops with 'too many
errors' message. Default is 10.

=head2 max_warnings => INT

Maximum number of warnings before no more warnings are recorded. 
Default is 10.

=head2 schema_search_path => ARRAYREF

A list of places to look for schemas. If you use DSP::LoadSchema::YAMLFile, this
will be a list of directories to search for YAML files. If you use
DSP::LoadSchema::Hash, this will be the hashes to search for schemas. This is
used if you use schema types (types based on schema).

See <Data::Schema::Type::Schema> for more details.

=head2 gettext_function => CODEREF

If set to a coderef, then this will be used to get custom error message when
errmsg attribute suffix is used. For example, if schema is:

 [str => {regex=>'/^\w+$/', 'regex:errmsg'=>'alphanums_only'}]

then your function will be called with 'alphanums_only' as the argument.

Default is none.

=head2 defer_loading => BOOL

Default true. If set to true, try to load require/use as later as
possible (e.g.  loading type handler classes, etc) to improve startup
performance.

=head2 allow_extra_hash_keys => BOOL

Default false. When hash has 'keys' type attribute, it automatically limits
allowed keys to only those specified in 'keys'. But if you set this config to
true, extra keys will still be allowed.

Example:

 # under allow_extra_hash_keys = 0 (the default)
 ds_validate({c=>1}, [hash => {keys=>{a=>"int", b=>"int"}}]); # failed, key c not allowed

 # under allow_extra_hash_keys = 1
 ds_validate({c=>1}, [hash => {keys=>{a=>"int", b=>"int"}}]); # ok
 # but
 ds_validate({c=>1}, [hash => {keys=>{a=>"int", b=>"int"},
                               allowed_keys=>[qw/a b/]}]); # still not allowed due to allowed_keys

=head2 debug => INT

Default 0. Valid values between 0 and 5. Validation emits debugging
info of various levels into logs. Increase this if you want to see
more debugging. Useful if you have complex schema.

Compiled schema currently does not emit debugging info, so if you're
debugging schema, turn off compilation. See C<compile>.

=head2 compile => BOOL

Default false. If true, then before validating, the schema will be
automatically compiled to Perl code first (unless it is already
compiled). This can result in faster validation.

Schema is recompiled if its content is different or if the
configuration changes (because some configuration like
C<allow_extra_hash_keys> can alter the behaviour of validator)..

Compiled schema remembers config values like B<max_errors>, etc at
compile-time.

You can also get the Perl code using C<emit_perl> and compile the code
using C<compile>.

The emitted Perl code can work without DS.

The Perl code are compiled in the C<Data::Schema::__compiled> namespace.

Performance gain is expected to be in the order of one magnitude
(10x) or more if the schema is complex.

=head1 AUTHOR

  Steven Haryanto <stevenharyanto@gmail.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2009 by Steven Haryanto.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

