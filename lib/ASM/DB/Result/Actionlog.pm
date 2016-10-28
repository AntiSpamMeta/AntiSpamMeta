use utf8;
package ASM::DB::Result::Actionlog;

use strict;
use warnings;

use parent 'DBIx::Class::Core';

__PACKAGE__->load_components('InflateColumn::DateTime');
__PACKAGE__->table('actionlog');
__PACKAGE__->add_columns(
    index => { data_type => 'bigint', is_auto_increment => 1, is_nullable => 0 },
    time => {
        data_type => 'timestamp',
        datetime_undef_if_invalid => 1,
        default_value => \'current_timestamp',
        is_nullable => 0,
    },
    action    => { data_type => 'varchar', is_nullable => 0, size => 20 },
    reason    => { data_type => 'varchar', is_nullable => 1, size => 512 },
    channel   => { data_type => 'varchar', is_nullable => 1, size => 51 },
    nick      => { data_type => 'varchar', is_nullable => 0, size => 17 },
    user      => { data_type => 'varchar', is_nullable => 1, size => 11 },
    host      => { data_type => 'varchar', is_nullable => 1, size => 64 },
    ip        => { data_type => 'integer', is_nullable => 1, extra => { unsigned => 1 } },
    gecos     => { data_type => 'varchar', is_nullable => 1, size => 512 },
    account   => { data_type => 'varchar', is_nullable => 1, size => 17 },
    bynick    => { data_type => 'varchar', is_nullable => 1, size => 17 },
    byuser    => { data_type => 'varchar', is_nullable => 1, size => 11 },
    byhost    => { data_type => 'varchar', is_nullable => 1, size => 64 },
    bygecos   => { data_type => 'varchar', is_nullable => 1, size => 512 },
    byaccount => { data_type => 'varchar', is_nullable => 1, size => 17 },
);

__PACKAGE__->set_primary_key('index');

1;
