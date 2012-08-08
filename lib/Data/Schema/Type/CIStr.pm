package Data::Schema::Type::CIStr;
our $VERSION = '0.135';


# ABSTRACT: Type handler for case-insensitive string ('cistr')


use Moose;
extends 'Data::Schema::Type::Str';

sub _equal {
    my ($self, $a, $b) = @_;
    lc($a) eq lc($b);
}

sub _emitpl_equal {
    my ($self, $a, $b) = @_;
    "(lc($a) eq lc($b))";
}

sub _compare {
    my ($self, $a, $b) = @_;
    lc($a) cmp lc($b);
}

sub _emitpl_compare {
    my ($self, $a, $b) = @_;
    "(lc($a) cmp lc($b))";
}

sub _rematch {
    my ($self, $str, $re) = @_;
    $str =~ qr/$re/i;
}

sub _emitpl_rematch {
    my ($self, $str, $re) = @_;
    $re = qr/$re/i unless ref($re) eq 'Regexp';
    "($str =~ ".$self->_dump($re).")";
}


__PACKAGE__->meta->make_immutable;
no Moose;
1;

__END__
=pod

=head1 NAME

Data::Schema::Type::CIStr - Type handler for case-insensitive string ('cistr')

=head1 VERSION

version 0.135

=head1 SYNOPSIS

 use Data::Schema;

=head1 DESCRIPTION

This is type handler for 'cistr'. 'cistr' is just like 'str' except that
comparison/sorting/regex matching is done case-insensitively.

=head1 SEE ALSO

L<Data::Schema::Type::Str>

=head1 AUTHOR

  Steven Haryanto <stevenharyanto@gmail.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2009 by Steven Haryanto.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

