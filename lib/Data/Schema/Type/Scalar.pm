package Data::Schema::Type::Scalar;
our $VERSION = '0.133';


# ABSTRACT: Role for scalar types


use Moose::Role;
#requires ...


sub chkarg_attr_deps {
    my ($self, $arg, $name) = @_;
    $self->chkarg_r_array($arg, $name, 0, 0,
                          sub {
                              my ($arg, $name) = @_;
                              return unless $self->chkarg_r_array($arg, $name, 2, 2);
                              return unless $self->chkarg_r_schema($arg->[0], "$name/0");
                              return unless $self->chkarg_r_schema($arg->[1], "$name/1");
                              1;
                          }
                      );
}

sub handle_attr_deps {
    my ($self, $data, $arg) = @_;
    my $has_err = 0;
    my $ds = $self->validator;

    push @{ $ds->schema_pos }, 0;
    for my $i (0..scalar(@$arg)-1) {
        $ds->schema_pos->[-1] = $i;
        my ($schema1, $schema2) = @{ $arg->[$i] };

        $ds->save_validation_state();
        $ds->init_validation_state();
        $ds->_validate($data, $schema1);
        my $match1 = !@{ $ds->errors };
	$ds->restore_validation_state();
        if ($match1) {
	    my $pos_before = @{ $ds->errors };
	    $ds->_validate($data, $schema2);
            my $match2 = $pos_before == @{ $ds->errors };
	    if (!$match2) { $has_err++; last if $ds->too_many_errors }
        }
    }
    pop @{ $ds->schema_pos };
    !$has_err;
}

sub emitpl_attr_deps {
    my ($self, $arg) = @_;
    my $perl = '';
    my $ds = $self->validator;

    my @arg;
    for my $i (0..scalar(@$arg)-1) {
	my ($code1, $csubname1) = $ds->emitpls_sub($arg->[$i][0]);
	my ($code2, $csubname2) = $ds->emitpls_sub($arg->[$i][1]);
	$perl .= $code1 . $code2;
	push @arg, [$csubname1, $csubname2];
    }

    $perl .= $ds->emitpl_my('@arg');
    $perl .= '@arg = ('.join(", ", map {"[\\&$_->[0], \\&$_->[1]]"} @arg).");\n";
    $perl .= 'push @$schemapos, -1;'."\n";
    $perl .= 'for my $i (0..scalar(@arg)-1) {'."\n";
    $perl .= '    $schemapos->[-1] = $i;'."\n";
    $perl .= '    my ($schema1, $schema2) = @{ $arg[$i] };'."\n";
    $perl .= '    my ($suberrors1, $subwarnings1) = $schema1->($data);'."\n";
    $perl .= '    next if @$suberrors1;'."\n";
    $perl .= '    my ($suberrors2, $subwarnings2) = $schema2->($data, $datapos, $schemapos);'."\n";
    $perl .= '    '.$ds->emitpl_push_errwarn('suberrors2', 'subwarnings2');
    $perl .= "}\n";
    $perl .= 'pop @$schemapos;'."\n";
    $perl;
}

Data::Schema::Type::Base::__make_attr_alias(deps => qw/dep/);

no Moose::Role;
1;

__END__
=pod

=head1 NAME

Data::Schema::Type::Scalar - Role for scalar types

=head1 VERSION

version 0.133

=head1 SYNOPSIS

    use Data::Schema;

=head1 DESCRIPTION

This is the role for scalar types. It provides attributes like 'deps'. Lots of
types are scalars, e.g. num, str, etc.

Role consumer is not required to provide any method.

=head1 TYPE ATTRIBUTES

=head2 deps => [[SCHEMA1, SCHEMA2], [SCHEMA1B, SCHEMA2B], ...]

Aliases: dep

If data matches SCHEMA1, then data must also match SCHEMA2.

This is not unlike an if-elsif statement.

See also L<Data::Schema::Type::Either> where you can also write attribute
'of' => [SCHEMA1, SCHEMA1B, ...]. But the disadvantage of the 'of' attribute
of 'either' type is it does not report validation error details for SCHEMA2,
SCHEMA2B, etc. It just report that data does not match any of
SCHEMA1/SCHEMA1B/...

Example (in YAML):

 - either
 - set: 1
   of: [str, array, hash]
   deps:
     - [str, [str, {one_of: [str, string, int, float, ...]}]]
     - [array, [array, {minlen: 2, ...}]]
     - [hash, [hash, {keys: {type: ..., def: ..., attr_hashes: ...}}]]

The above YAML snippet is actually from DS schema. A schema can be str
(first form), array (second form), or hash (third form). For each form, we
define further validation in the 'deps' attribute. If we write the above
schema like this instead:

 - either
 - set: 1
   of:
     - [str, {one_of: [str, string, int, float, ...]}]
     - [array, {minlen: 2, ...}]
     - [hash, {keys: {type: ..., def: ..., attr_hashes: ...}}]

Then whenever there's a validation failure somewhere, the error details will
be hidden because the final error will just be from 'either's 'of'
attribute: that none of the alternatives matches.

=head1 AUTHOR

  Steven Haryanto <stevenharyanto@gmail.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2009 by Steven Haryanto.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

