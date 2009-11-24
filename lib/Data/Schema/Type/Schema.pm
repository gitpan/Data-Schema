package Data::Schema::Type::Schema;
our $VERSION = '0.12';


# ABSTRACT: Make schema as type


use Moose;
use Scalar::Util qw/tainted/;

extends 'Data::Schema::Type::Base';

has name => (is => 'rw');

# normalized schema
has nschema => (is => 'rw');

sub handle_type {
    my ($self, $data, $attr_hashes) = @_;

    my $s = $self->nschema;
    my $ds = $self->validator;
    $ds->save_validation_state();
    $ds->init_validation_state();
    $ds->_validate($data, {
                           type=>$s->{type},
                           attr_hashes=>[@{$s->{attr_hashes}}, @$attr_hashes],
                           def=>$s->{def}});
    my $errors = $ds->errors;
    $ds->restore_validation_state();

    # push errors
    for (@$errors) {
        if (@{ $ds->errors } >= $ds->config->max_errors) {
            $ds->too_many_errors(1);
            last;
        }
        push @{ $ds->errors },
            [[@{$ds->data_pos}, @{$_->[0]}], [@{$ds->schema_pos}, @{$_->[1]}], $_->[2]];
    }

    !@$errors;
};

sub emit_perl {
    my ($self, $attr_hashes, $subname) = @_;
    $subname //= "NONAME";
    my $ds = $self->validator;
    my $s = $self->nschema;
    my $perl = '';

    my ($code, $basecsubname) = $ds->emitpls_sub(
	{
	    type=>$s->{type},
	    attr_hashes=>[@{$s->{attr_hashes}}, @$attr_hashes],
	    def=>$s->{def}
	}
    );
    $perl .= $code;
    $perl .= "# schema: ".$self->name." ".$self->_dump($attr_hashes)."\n";
    $perl .= "sub ".$subname.' {'."\n";
    $perl .= "    ".$basecsubname.'(@_);'."\n";
    $perl .= "}\n\n";

    $perl;
};

sub short_english {
    my ($self) = @_;
    "schema_" . $self->name;
}

sub english {
    my ($self) = @_;
    $self->name;
}


__PACKAGE__->meta->make_immutable;
no Moose;
1;

__END__
=pod

=head1 NAME

Data::Schema::Type::Schema - Make schema as type

=head1 VERSION

version 0.12

=head1 SYNOPSIS

    # write schemas and store them in hashes (or files, or objects, ...)
    my $schemas = {
        even_int => [int => {divisible_by=>2}],
        positive_even => [even_int => {min=>0}],
    };

    use Data::Schema;
    my $ds = Data::Schema->new(
        plugins=>['Data::Schema::Plugin::LoadSchema::Hash']
    );
    $n->config->schema_search_path([$schemas]);

    my $res;
    $res = $ds->validate(-2, 'even_int');                   # success
    $res = $ds->validate(-2, 'positive_even');              # fail
    $res = $ds->validate(4, [even_int=>{divisible_by=>3}]); # fail
    $res = $ds->validate(6, [even_int=>{divisible_by=>3}]); # success

=head1 DESCRIPTION

This is the type handler that makes a schema available as type in other
schemas. What this basically does is that you can reuse a schema in other
schemas.

To load schemas, either from a hash or YAML files, see
L<Data::Schema::Plugin::LoadSchema::Hash> or
L<Data::Schema::Plugin::LoadSchema::YAMLFile>.

=head1 TYPE ATTRIBUTES

The type attributes available are whatever attributes are available for the base
type.

=head1 SEE ALSO

L<Data::Schema::Manual::Schema>

=head1 AUTHOR

  Steven Haryanto <stevenharyanto@gmail.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2009 by Steven Haryanto.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

