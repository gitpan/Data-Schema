package Data::Schema::Type::Float;
our $VERSION = '0.132';


# ABSTRACT: Type handler for floating point numbers ('float')


use Moose;
extends 'Data::Schema::Type::Num';

override handle_pre_check_attrs => sub {
    super(@_);
    # XXX extra check when Num support other non-floats, e.g. complex, rational
};

sub short_english {
    "float";
}

sub english {
    "float";
}


__PACKAGE__->meta->make_immutable;
no Moose;
1;

__END__
=pod

=head1 NAME

Data::Schema::Type::Float - Type handler for floating point numbers ('float')

=head1 VERSION

version 0.132

=head1 SYNOPSIS

 use Data::Schema;

=head1 DESCRIPTION

This is the type handler for type 'float'.

=head1 TYPE ATTRIBUTES

See L<Data::Schema::Type::Num>.

=head1 AUTHOR

  Steven Haryanto <stevenharyanto@gmail.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2009 by Steven Haryanto.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

