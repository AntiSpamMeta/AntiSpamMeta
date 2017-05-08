#!/usr/bin/env perl
use v5.20;
use warnings;

use DBIx::Class::DeploymentHandler::DeployMethod::SQL::Translator::ScriptHelpers 'schema_from_schema_loader';
use Authen::Passphrase::RejectAll;

schema_from_schema_loader({ naming => 'v4' }, sub {
        my ($schema, $versions) = @_;

        while (my ($name, $user) = each %{ $::users->{person} }) {
            my %flags;
            for my $flag (split(//, $user->{flags})) {
                $flags{$flag} = 1;
            }
            $schema->resultset('Users')->create({
                    name          => $name,
                    # We don't have the manually adjusted schema, so we need to
                    # pass the raw value for the passphrase column
                    passphrase    => Authen::Passphrase::RejectAll->new->as_rfc2307,
                    flag_secret   => $flags{s} // 0,
                    flag_admin    => $flags{a} // 0,
                    flag_hilights => $flags{h} // 0,
                    flag_debug    => $flags{d} // 0,
                    flag_plugin   => $flags{p} // 0,
                });
        }

        say "NOTE: The data from users.json has been moved to the database.\n"
        . "You may remove users.json now, although keeping a backup is strongly recommended.";
    })
