package Data::Schema;

use Moose;
use vars qw(@ISA @EXPORT);
require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw(ds_validate);
use Data::PrefixMerge;
use Data::Schema::Type::Schema;

=head1 NAME

Data::Schema - Validate nested data structures with nested structure

=head1 VERSION

Version 0.03

=cut

our $VERSION = '0.03';

=head1 SYNOPSIS

    # OO interface
    use Data::Schema;
    my $validator = Data::Schema->new();
    my $schema = [array => {min_len=>2, max_len=>4}];
    my $data = [1, 2, 3];
    my $res = $validator->validate($data, $schema);
    print "valid!" if $res->{success}; # prints 'valid!'

    # procedural interface
    use Data::Schema;
    my $sch = ["hash",
               {keys =>
                    {name => "str",
                     age  => ["int", {required=>1, min=>18}]
                    }
                }
              ];
    my $r;
    $r = ds_validate({name=>"Lucy", age=>18}, $sch); # success
    $r = ds_validate({name=>"Lucy"         }, $sch); # fail: missing age
    $r = ds_validate({name=>"Lucy", age=>16}, $sch); # fail: underage

=head1 DESCRIPTION

NOTE: THIS IS A PRELIMINARY RELEASE. I have pinned down more or less the general
code structure, user interface, and schema syntax which I want, as well as
implemented a fairly complete set of types and type attributes. Also you already
can create new types by using schema or by writing Perl type handlers. In short,
it's already usable in term of validation task (and I am about to use it in
production code). However there are other stuffs like handling of default
values, variable substitution, filters, etc. which will be implemented in future
releases.

There are already a lot of data validation modules on CPAN. However, most of
them do not validate nested data structures. And of the rest, either I am not
really fond of the syntax, or the validator/schema system is not
simple/flexible/etc enough for my taste. Thus Data::Schema (DS) is born.

With DS, you validate a nested data structure with a schema, which is also a
nested data structure. This makes the schema more easily reusable in other
languages. Also, in DS you can define new types (or subtypes, actually) using
schema itself. This makes your validation "routine" even more reusable.

Potential application of DS: validating configuration, function parameters,
command line arguments, etc.

To get started, see L<Data::Schema::Manual::Basics>.

=head1 FUNCTIONS

=head2 ds_validate($data, $schema)

Non-OO wrapper for validate(). Exported by default. See C<validate()> method.

=cut

sub ds_validate {
    my ($data, $schema) = @_;
    my $validator = __PACKAGE__->new(schema => $schema);
    $validator->validate($data);
}

my $Merger = new Data::PrefixMerge;
$Merger->config->{recurse_array} = 1;

=head1 ATTRIBUTES

=cut

has plugins => (is => 'rw');
has type_handlers => (is => 'rw');

=head2 config

Configuration hashref. See B<CONFIG> section.

=cut

has config => (is => 'rw');

has validation_state_stack => (is => 'rw');

# validation state
has schema => (is => 'rw');
# has data_copy?
has too_many_errors => (is => 'rw');
has too_many_warnings => (is => 'rw');
has errors => (is => 'rw');
has warnings => (is => 'rw');
has data_pos => (is => 'rw');
has schema_pos => (is => 'rw');

=head1 METHODS

=cut

sub BUILD {
    my ($self, %args) = shift;

    # config
    if ($self->config) {
        # some sanity checks
        die "config must be a hashref" unless ref($self->config) eq 'HASH';
        die "config->{schema_search_path} must be an arrayref" unless ref($self->config->{schema_search_path}) eq 'ARRAY';
    } else {
        $self->config({
            max_errors => 10,
            max_warnings => 10,

            # LoadSchema::*, for L::YAMLFile it's a list of directory names, for
            # L::Hash it's a list of hashrefs
            schema_search_path => ["."],
        });
    }

    # add default type handlers
    if ($args{type_handlers}) {
        # some sanity checks
        die "type_handlers must be a hashref" unless ref($args{type_handlers}) eq 'HASH';
    } else {
        $self->type_handlers({});
        my %defth = (
            str     => 'Str',
            bool    => 'Bool',
            hash    => 'Hash',
            array   => 'Array',
            object  => 'Object',
            int     => 'Int',
            float   => 'Float',
            either  => 'Either',
            all     => 'All',
        );
        # aliases (XXX should not create handler object for all the aliases)
        $defth{string}  = $defth{str};
        $defth{boolean} = $defth{bool};
        $defth{integer} = $defth{int};
        $defth{and}     = $defth{all};
        $defth{or}      = $defth{either};
        $defth{any}     = $defth{either};
        $defth{obj}     = $defth{object};
        $self->register_type($_, "Data::Schema::Type::$defth{$_}") for keys %defth;
    }

    # add default plugins
    if ($self->plugins) {
        # some sanity checks
        die "plugins must be an arrayref" unless ref($self->plugins) eq 'ARRAY';
    } else {
        $self->plugins([]);
        my @defpl = (
        );
        $self->register_plugin("Data::Schema::Plugin::$_") for @defpl;
    }

    $self->validation_state_stack([]) unless $self->validation_state_stack;
};

=head2 merge_attr_hashes($attr_hashes)

Merge several attribute hashes if there are hashes that can be merged (i.e.
contains merge prefix in its keys). Used by DST::Base and DST::Schema. As DS
user, normally you wouldn't need this.

=cut

sub merge_attr_hashes {
    my ($self, $attr_hashes) = @_;
    my @merged;
    my $res = {error=>''};

    my $i = 0;
    while (1) {
        last if $i >= @$attr_hashes;
        my $attr_hash = $attr_hashes->[$i];
        my $has_merge_prefix = grep {/^[*+.!-]/} keys %$attr_hash;
        if ($i == 0 && $has_merge_prefix) {
            $res->{error} = "merge prefix found in first attrhash keys";
            last;
        }
        if ($has_merge_prefix) {
            my $mres = $Merger->merge($attr_hashes->[$i-1], $attr_hash);
            if (!$mres->{success}) {
                $res->{error} = $mres->{error};
                last;
            }
            $merged[-1] = $mres->{result};
        } else {
            push @merged, $attr_hashes->[$i];
        }
        $i++;
    }
    $res->{result} = \@merged unless $res->{error};
    $res->{success} = !$res->{error};
    $res;
}

=head2 init_validation_state()

Initialize validation state. Used internally by validate(). As DS user, normally
you wouldn't need this.

=cut

sub init_validation_state {
    my ($self) = @_;
    $self->schema(undef);
    $self->errors([]);
    $self->warnings([]);
    $self->too_many_errors(0);
    $self->too_many_warnings(0);
    $self->data_pos([]);
    $self->schema_pos([]);
}

=head2 save_validation_state()

Save validation state (position in data, position in schema, number of errors,
etc) into a stack, so that you can start using the validator to validate a new
data with a new schema, even in the middle of validating another data/schema.
Used internally by validate() and DST::Schema. As DS user, normally you wouldn't
need this.

See also: B<restore_validation_state()>.

=cut

sub save_validation_state {
    my ($self) = @_;
    my $state = {
        schema => $self->schema,
        errors => $self->errors,
        warnings => $self->warnings,
        too_many_errors => $self->too_many_errors,
        too_many_warnings => $self->too_many_warnings,
        data_pos => $self->data_pos,
        schema_pos => $self->schema_pos,
    };
    push @{ $self->validation_state_stack }, $state;
}

=head2 restore_validation_state()

Restore the last validation state into a stack. Used internally by validate()
and DST::Schema. As DS user, normally you wouldn't need this.

See also: B<save_validation_state()>.

=cut

sub restore_validation_state {
    my ($self) = @_;
    my $state = pop @{ $self->validation_state_stack };
    die "Can't restore validation state, stack is empty!" unless $state;
    $self->schema($state->{schema});
    $self->errors($state->{errors});
    $self->warnings($state->{warnings});
    $self->too_many_errors($state->{too_many_errors});
    $self->too_many_warnings($state->{too_many_warnings});
    $self->data_pos($state->{data_pos});
    $self->schema_pos($state->{schema_pos});
}

sub _log {
    my ($self, $stack, $limit, $message, $too_many_msgs) = @_;
    #print "log: ".$self->_pos_as_str($self->data_pos).": $message\n";
    if (defined($limit) && $limit > 0) {
        if (@$stack >= $limit) {
            push @$stack, [[], [], $too_many_msgs];
            return;
        }
    }
    push @$stack, [[ @{$self->data_pos} ], [ @{$self->schema_pos} ], $message];
}

=head2 log_error($message)

Add an error when in validation process. Will not add if there are already too
many errors (C<too_many_errors> attribute is true). Used by type handlers. As DS
user, normally you wouldn't need this.

=cut

sub log_error {
    my ($self, $message) = @_;
    $self->too_many_errors(1) unless
        $self->_log($self->errors, $self->config->{max_errors}, $message, "too many errors");
}

=head2 log_warning($message)

Add a warning when in validation process. Will not add if there are already too
many warnings (C<too_many_warnings> attribute is true). Used by type handlers.
As DS user, normally you wouldn't need this.

=cut

sub log_warning {
    my ($self, $message) = @_;
    $self->too_many_warnings(1) unless
        $self->_log($self->warnings, $self->config->{max_warnings}, $message, "too many warnings");
}

sub _pos_as_str {
    my $self = shift;
    my $pos_elems = shift;
    join "/", @$pos_elems;
}

=head2 check_type_name($name)

Checks whether C<$name> is a valid type name. Returns true if valid,
false if invalid. By default it requires that type name starts with a
lowercase letter and contains only lowercase letters, numbers, and
underscores. Maximum length is 64.

You can override this method if you want stricter/looser type name
criteria.

=cut

sub check_type_name {
    my ($self, $name) = @_;
    $name =~ /\A[a-z][a-z0-9_]{0,63}\z/;
}

=head2 register_type($name, $class|$obj)

Register a new type, along with a class name (C<$class>) or the actual object
(C<$obj>) to handle the type. If C<$class> is given, the class will be require'd
(if not already require'd) and instantiated to become object.

Any object can become a type handler, as long as it has:

* a C<validator()> rw property to store/set validator object;
* C<handle_type()> method to handle type checking;
* zero or more C<handle_attr_*()> methods to handle attribute checking.

See L<Data::Schema::Manual::TypeHandler> for more details on writing a type
handler.

=cut

sub register_type {
    my ($self, $name, $obj_or_class) = @_;

    $self->check_type_name($name) or die "Invalid type name syntax: $name";

    if (exists $self->type_handlers->{$name}) {
        die "Type already registered: $name";
    }

    my $obj;
    if (ref($obj_or_class)) {
        $obj = $obj_or_class;
    } else {
        eval "use $obj_or_class";
        die "Can't load class $obj_or_class: $@" if $@;
        $obj = $obj_or_class->new();
    }
    $obj->validator($self);
    $self->type_handlers->{$name} = $obj;
}

=head2 register_plugin($class|$obj)

Register a new plugin. Accept a plugin object or class. If C<$class> is given,
the class will be require'd (if not already require'd) and instantiated to
become object.

Any object can become a plugin, you don't need to subclass from anything, as
long as it has:

* a C<validator()> rw property to store/set validator object;
* zero or more C<handle_*()> methods to handle some events/hooks.

See L<Data::Schema::Manual::Plugin> for more details on writing a plugin.

=cut

sub register_plugin {
    my ($self, $obj_or_class) = @_;

    my $obj;
    if (ref($obj_or_class)) {
        $obj = $obj_or_class;
    } else {
        eval "use $obj_or_class";
        die "Can't load class $obj_or_class: $@" if $@;
        $obj = $obj_or_class->new();
    }
    $obj->validator($self);
    push @{ $self->plugins }, $obj;
}

=head2 call_handler($name, [@args])

Try handle_*() method from each registered plugin until one returns 0 or 1. If
a plugin return -1 (decline) then we continue to the next plugin. Returns the
status of the last plugin. Returns -1 if there's no handler to invoke.

=cut

sub call_handler {
    my ($self, $name, @args) = @_;
    $name = "handle_$name" unless $name =~ /^handle_/;
    for my $p (@{ $self->plugins }) {
        if ($p->can($name)) {
            my $res = $p->$name(@args);
            return $res if $res != -1;
        }
    }
    -1;
}

=head2 get_type_handler($name)

Try to get type handler for a certain type. If type is not found, invoke
handle_unknown_type() in plugins to give plugins a chance to load the type. If
type is still not found, return undef.

=cut

sub get_type_handler {
    my ($self, $name) = @_;
    my $th;
    if (!($th = $self->type_handlers->{$name})) {
        # let's give plugin a chance to do something about it and then try again
        if ($self->call_handler("unknown_type", $name) > 0) {
            $th = $self->type_handlers->{$name};
        }
    }
    $th;
}

=head2 normalize_schema($schema)

Normalize a schema into the third form (hash form) ({type=>...,
attr_hashes=>..., def=>...) as well as do some sanity checks on it. Returns an
error message string if fails.

=cut

sub normalize_schema {
    my ($self, $schema) = @_;

    if (!defined($schema)) {

        return "schema is missing";

    } elsif (!ref($schema)) {

        return { type=>$schema, attr_hashes=>[], def=>undef };

    } elsif (ref($schema) eq 'ARRAY') {

        my $type = $schema->[0];
        if (!defined($type)) {
            return "array form needs at least 1 element for type";
        }
        my @attr_hashes;
        for (1..@$schema-1) {
            if (ref($schema->[$_]) ne 'HASH') {
                return "array form element [$_] (attrhash) must be a hashref";
            }
            push @attr_hashes, $schema->[$_];
        }
        return { type=>$type, attr_hashes=>\@attr_hashes, def=>undef };

    } elsif (ref($schema) eq 'HASH') {

        my $type = $schema->{type};
        if (!defined($type)) {
            return "hash form must have 'type' key";
        }
        my @attr_hashes;
        my $a = $schema->{attrs};
        if (defined($a)) {
            if (ref($a) ne 'HASH') {
                return "hash form 'attrs' key must be a hashref";
            }
            push @attr_hashes, $a;
        }
        $a = $schema->{attr_hashes};
        if (defined($a)) {
            if (ref($a) ne 'ARRAY') {
                return "hash form 'attr_hashes' key must be an arrayref";
            }
            for (0..@$a-1) {
                if (ref($a->[$_]) ne 'HASH') {
                    return "hash form 'attr_hashes'[$_] must be a hashref";
                }
                push @attr_hashes, $a->[$_];
            }
        }
        my $def = {};
        $a = $schema->{def};
        if (defined($a)) {
            if (ref($a) ne 'HASH') {
                return "hash form 'def' key must be a hashref";
            }
        }
        $def = $a;
        for (keys %$schema) {
            return "hash form has unknown key `$_'" unless /^(type|attrs|attr_hashes|def)$/;
        }
        return { type=>$type, attr_hashes=>\@attr_hashes, def=>$def };

    }

    return "schema must be a str, arrayref, or hashref";
}

=head2 register_schema_as_type($schema, $name)

Register schema as new type. $schema is a normalized schema. Return {success=>(0
or 1), error=>...}. Fails if type with name B<$name> is already defined, or if
$schema cannot be parsed. Might actually register more than one type actually,
if the schema contains other types in it (hash form of schema can define types).

=cut

sub register_schema_as_type {
    my ($self, $nschema, $name, $path) = @_;
    $path ||= "";
    my $res = {};

    while (1) {
        if ($self->type_handlers->{$name}) {
            $res->{error} = "type `$name' already registered (path `$path')";
            last;
        }
        if (ref($nschema) ne 'HASH') {
            $res->{error} = "schema must be in 3rd form (hash): (path `$path')";
            last;
        }
        if ($nschema->{def}) {
            for (keys %{ $nschema->{def} }) {
                my $r = $self->register_schema_as_type($nschema->{def}{$_}, $_, "$path/$_");
                if (!$r->{success}) {
                    $res->{error} = $r->{error};
                    last;
                }
            }
        }
        my $th = Data::Schema::Type::Schema->new(nschema=>$nschema);
        $self->register_type($name => $th);
        last;
    }
    $res->{success} = !$res->{error};
    $res;
}

=head2 validate($data[, $schema])

Validate a data structure. $schema must be given unless you already give the
schema via the B<schema> attribute.

Returns {success=>0 or 1, errors=>[...], warnings=>[...]}. The 'success' key
will be set to 1 if the data validates, otherwise 'errors' and 'warnings' will
be filled with the details.

=cut

sub validate {
    my ($self, $data, $schema) = @_;
    $schema ||= $self->schema;

    $self->init_validation_state();
    $self->_validate($data, $schema);

    # XXX DECISION: only ds_validate() format error and warnings?

    {success  => !@{$self->errors},
     errors   => [map { sprintf "data\@%s schema\@%s %s", $self->_pos_as_str($_->[0]), $self->_pos_as_str($_->[1]), $_->[2] } @{ $self->errors   }],
     warnings => [map { sprintf "data\@%s schema\@%s %s", $self->_pos_as_str($_->[0]), $self->_pos_as_str($_->[1]), $_->[2] } @{ $self->warnings }],
    };
    #{errors=>$self->errors, warnings=>$self->warnings};
}

# the difference between validate() and _validate(): _validate() is not for the
# end-user, it doesn't initialize validation state and so can be used in the
# middle of another validation (e.g. for validating schema types). _validate()
# also doesn't format and returns the list of errors/warnings, you need to get
# them yourself from the validator.

sub _validate {
    my ($self, $data, $schema) = @_;

    # since schema may define types inside it, we save the original types list
    # so we can register new types and then restore back to original state
    # later.
    my $orig_type_handlers;

    while (1) {
        my $s = $self->normalize_schema($schema);
        if (!ref($s)) {
            $self->log_error("schema error: $s");
            last;
        }

        if ($s->{def}) {
            $orig_type_handlers = { %{$self->type_handlers} };
            push @{ $self->schema_pos }, 'def', '';
            my $has_err;
            for (keys %{ $s->{def} }) {
                $self->schema_pos->[-1] = $_;
                my $subs = $self->normalize_schema($s->{def}{$_});
                if (!ref($subs)) {
                    $has_err++;
                    $self->log_error("normalize schema type error: $s");
                    last;
                }
                my $res = $self->register_schema_as_type($subs, $_);
                if (!$res->{success}) {
                    $has_err++;
                    $self->log_error("register schema type error: $res->{error}");
                    last;
                }
            }
            pop @{ $self->schema_pos };
            pop @{ $self->schema_pos };
            last if $has_err;
        }

        my $th = $self->get_type_handler($s->{type});
        if (!$th) {
            $self->log_error("schema error: unknown type `$s->{type}'");
            last;
        }
        $th->handle_type($data, $s->{attr_hashes});
        last;
    }

    $self->type_handlers($orig_type_handlers) if $orig_type_handlers;
}

=head1 CONFIG

Configuration is set like this:

 my $validator = new Data::Schema;
 $validator->config->{CONFIGVAR} = 'VALUE';
 # ...

Available configuration variables:

=head2 max_errors => INT

Maximum number of errors before validation stops. Default is 10.

=head2 max_warnings => INT

Maximum number of warnings before warnings will not be added anymore. Default is
10.

=head2 schema_search_path => [...]

A list of places to look for schemas. If you use DSP::LoadSchema::YAMLFile, this
will be a list of directories to search for YAML files. If you use
DSP::LoadSchema::Hash, this will be the hashes to search for schemas. This is
used if you use schema types (types based on schema).

See <Data::Schema::Type::Schema> for more details.

=head2 gettext_function => \&func

If set to a coderef, then this will be used to get custom error message when
errmsg attribute suffix is used. For example, if schema is:

 [str => {regex=>'/^\w+$/', 'regex.errmsg'=>'alphanums_only'}]

then your function will be called with 'alphanums_only' as the argument.


=head1 SEE ALSO

L<Data::Schema::Manual::Basics>,
L<Data::Schema::Manual::Schema>,
L<Data::Schema::Manual::TypeHandler>,
L<Data::Schema::Manual::Plugin>

Some other data validation modules on CPAN: L<Data::FormValidator>, L<Data::Rx>,
L<Kwalify>.

=head1 AUTHOR

Steven Haryanto, C<< <steven at masterweb.net> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-data-schema at
rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Data-Schema>.  I
will be notified, and then you'll automatically be notified of
progress on your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Data::Schema


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Data-Schema>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Data-Schema>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Data-Schema>

=item * Search CPAN

L<http://search.cpan.org/dist/Data-Schema/>

=back


=head1 ACKNOWLEDGEMENTS


=head1 COPYRIGHT & LICENSE

Copyright 2009 Steven Haryanto, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.


=cut

__PACKAGE__->meta->make_immutable;
1;
