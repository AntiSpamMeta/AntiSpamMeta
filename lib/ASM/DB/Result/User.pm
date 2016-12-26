use utf8;
package ASM::DB::Result::User;

use strict;
use warnings;

use parent 'DBIx::Class::Core';

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
);

__PACKAGE__->set_primary_key('id');
__PACKAGE__->add_unique_constraint(uniq_user_name => ['name']);

1;
