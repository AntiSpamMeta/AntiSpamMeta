use utf8;
package ASM::DB::Result::Alertlog;

use strict;
use warnings;

use parent 'DBIx::Class::Core';

__PACKAGE__->load_components('InflateColumn::DateTime');
__PACKAGE__->table('alertlog');
__PACKAGE__->add_columns(
    time => {
        data_type => 'timestamp',
        datetime_undef_if_invalid => 1,
        default_value => \'current_timestamp',
        is_nullable => 0,
    },
    channel => { data_type => 'text',     is_nullable => 0 },
    nick    => { data_type => 'text',     is_nullable => 0 },
    user    => { data_type => 'text',     is_nullable => 0 },
    host    => { data_type => 'text',     is_nullable => 0 },
    gecos   => { data_type => 'text',     is_nullable => 0 },
    level   => { data_type => 'tinytext', is_nullable => 0 },
    id      => { data_type => 'tinytext', is_nullable => 0 },
    reason  => { data_type => 'text',     is_nullable => 0 },
);

__PACKAGE__->set_primary_key('id');

1;
