use utf8;

package ASM::DB::ResultSet::User;

use strict;
use warnings;

use parent 'DBIx::Class::ResultSet';
use namespace::autoclean;

sub by_name {
    my ( $self, $name ) = @_;

    return $self->find( { name => $name }, { key => 'uniq_user_name' } );
}

sub by_name_or_new {
    my ( $self, $name ) = @_;

    return $self->find_or_new( { name => $name }, { key => 'uniq_user_name' } );
}

1;
