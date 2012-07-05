package Data::Schema::Type::TypeName;
our $VERSION = '0.134';


# ABSTRACT: Type handler for DS type 'typename'


use Moose;
extends 'Data::Schema::Type::Str';

override handle_pre_check_attrs => sub {
    return unless super(@_);
    my ($self, $data) = @_;
    unless ($data =~ /\A[a-z_][a-z0-9_]{0,63}\z/) {
        $self->validator->data_error("invalid type name `$data`");
        return;
    }
    1;
};

override emitpl_pre_check_attrs => sub {
    my ($self) = @_;
    my $ds = $self->validator;

    my $perl = super(@_);
    $ds->_load_type_handler($_) for keys %{$ds->type_handlers}; # to defeat defer_loading
    $perl .= 'my %known_types = ('.join(", ", map {"'$_' => [".($ds->type_handlers->{$_}->isa("Data::Schema::Type::Schema") ? 1:0)."]"} sort keys %{$ds->type_handlers}).");\n";
    $perl .= 'unless ($data =~ /\A[a-z_][a-z0-9_]{0,63}\z/) { '.$ds->emitpl_data_error('"invalid type name `$data`"', 1).'; pop @$schemapos; last L1 }'."\n";
    $perl;
};


sub chkarg_attr_known {
    my ($self, $arg, $name) = @_;
    $self->chkarg_bool($arg, $name);
}

sub handle_attr_known {
    my ($self, $data, $arg) = @_;
    my $ds = $self->validator;

    return 1 unless defined($arg);
    if ($ds->type_handlers->{$data} xor $arg) {
	$ds->data_error($arg ? "unknown type name `$data`" : "known type name `$data`");
	return 0;
    }
    1;
}

sub emitpl_attr_known {
    my ($self, $arg) = @_;
    my $ds = $self->validator;
    my $perl = '';

    return ' ' unless defined($arg);
    $perl .= 'if ($known_types{$data} xor '.($arg ? 1:0).') { '.$ds->emitpl_data_error(($arg ? '"unknown type name `$data`"' : '"known type name `$data`"'), 1).' }'."\n";
    $perl;
}


sub chkarg_attr_isa_schema {
    my ($self, $arg, $name) = @_;
    $self->chkarg_bool($arg, $name);
}

sub handle_attr_isa_schema {
    my ($self, $data, $arg) = @_;
    my $ds = $self->validator;

    return 1 unless defined($arg);
    unless ($ds->type_handlers->{$data}) {
	$ds->data_error("unknown type name `$data`");
	return 0;
    }
    $ds->_load_type_handler($data); # to defeat defer_loading
    my $isa_schema = $ds->type_handlers->{$data}->isa("Data::Schema::Type::Schema");
    if ($isa_schema xor $arg) {
	$ds->data_error($arg ? '"type `$data` is not a schema type"' : '"type `$data` is a schema type"');
	return 0;
    }
    1;
}

sub emitpl_attr_isa_schema {
    my ($self, $arg) = @_;
    my $ds = $self->validator;
    my $perl = '';

    return ' ' unless defined($arg);
    $perl .= 'unless ($known_types{$data}) { '.$ds->emitpl_data_error('"unknown type name `$data`"', 1).' }'."\n";
    $perl .= 'my $isa_schema = $known_types{$data}[0];'."\n";
    $perl .= 'if ($isa_schema xor '.($arg ? 1:0).') { '.$ds->emitpl_data_error(($arg ? '"type `$data` is not a schema type"' : '"type `$data` is a schema type"'), 1).' }'."\n";
    $perl;
};


__PACKAGE__->meta->make_immutable;
no Moose;
1;

__END__
=pod

=head1 NAME

Data::Schema::Type::TypeName - Type handler for DS type 'typename'

=head1 VERSION

version 0.134

=head1 SYNOPSIS

 use Data::Schema;

=head1 DESCRIPTION

This is type handler for 'typename'. It is just like string,
except it only accepts valid type names (/^[a-z][a-z0-9_]$/).

This is used for validating DS schemas and does not have much use
elsewhere.

Example:

 ds_validate("int", "typename"); # valid
 ds_validate("integer number", "typename"); # invalid, contains whitespace

=head1 TYPE ATTRIBUTES

Aside from attributes from string, here are other recognized
attributes:

=head2 known => BOOL

If true, require that type name is known at that point of the
validation.

Example:

 ds_validate("foo", [typename=>{known=>1}); # invalid, foo is not a known type
 ds_validate("foo", {def => {foo=>"str"}, 
                     attr_hashes => [{known=>1}], 
                     type => "typename"}); # valid, foo is known here

=head2 isa_schema => BOOL

If true, require that type name is a schema type.

Example:

 ds_validate("int", [typename=>{isa_schema=>1}]); # invalid, int is not a schema type
 ds_validate("foo", [typename=>{isa_schema=>1}]); # valid if foo is a schema type

=head1 SEE ALSO

L<Data::Schema::Type::Str>

L<Data::Schema::Schema::Schema>

=head1 AUTHOR

  Steven Haryanto <stevenharyanto@gmail.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2009 by Steven Haryanto.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

