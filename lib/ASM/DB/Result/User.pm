use utf8;
package ASM::DB::Result::User;

use strict;
use warnings;

use parent 'DBIx::Class::Core';

use Authen::Passphrase::RejectAll;

__PACKAGE__->load_components('InflateColumn::DateTime', 'PassphraseColumn');
__PACKAGE__->table('users');
__PACKAGE__->add_columns(
    id => {
        data_type         => 'bigint',
        is_auto_increment => 1,
        is_nullable       => 0
    },
    name => {
        data_type   => 'varchar',
        size        => 20,
        is_nullable => 0,
    },
    passphrase => {
        data_type        => 'text',
        passphrase       => 'rfc2307',
        passphrase_class => 'BlowfishCrypt',
        passphrase_args  => {
            cost => 13,
            salt_random => 1,
        },
        passphrase_check_method => 'check_password',
        is_nullable => 0,
    },
    flag_secret => {
        data_type   => 'boolean',
        is_nullable => 0,
        default_value => 0,
    },
    flag_hilights => {
        data_type   => 'boolean',
        is_nullable => 0,
        default_value => 0,
    },
    flag_admin => {
        data_type   => 'boolean',
        is_nullable => 0,
        default_value => 0,
    },
    flag_plugin => {
        data_type   => 'boolean',
        is_nullable => 0,
        default_value => 0,
    },
    flag_debug => {
        data_type   => 'boolean',
        is_nullable => 0,
        default_value => 0,
    },
);

__PACKAGE__->set_primary_key('id');
__PACKAGE__->add_unique_constraint(uniq_user_name => ['name']);

sub new {
    my $self = shift;
    $_[0]{passphrase} //= Authen::Passphrase::RejectAll->new;

    $self->SUPER::new(@_);
}

1;
