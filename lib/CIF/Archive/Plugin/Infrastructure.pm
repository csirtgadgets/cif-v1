package CIF::Archive::Plugin::Infrastructure;
use base 'CIF::Archive::Plugin';

use warnings;
use strict;

use Module::Pluggable require => 1, search_path => [__PACKAGE__];
use Regexp::Common qw/net/;

use Try::Tiny;

my @plugins = __PACKAGE__->plugins();

__PACKAGE__->table('infrastructure');
__PACKAGE__->columns(Primary => 'id');
__PACKAGE__->columns(All => qw/id uuid guid address portlist protocol confidence detecttime created/);
__PACKAGE__->columns(Essential => qw/id uuid guid address portlist protocol confidence detecttime created/);
__PACKAGE__->sequence('infrastructure_id_seq');

sub insert {
    my $class = shift;
    my $data = shift;
    
    my $tbl = $class->table();
    foreach(@plugins){
        if($_->prepare($data)){
            $class->table($_->table());
        }
    }

    my $uuid = $data->{'uuid'};
    my $severity    = 'medium';
    my $portlist;
    my $protocol;
    my $confidence  = 50;
    my $msg = $data->{'data'};
    
    my @ids;
    my $addresses = $class->iodef_addresses($data->{'data'});
    foreach my $a (@$addresses){
        next unless($a->get_content() =~ /^$RE{'net'}{'IPv4'}/);
        my $id = $class->SUPER::insert({
            uuid        => $data->{'uuid'},
            guid        => $data->{'guid'},
            address     => $a->get_content(),
            confidence  => $confidence,
            portlist    => $portlist,
            protocol    => $protocol,
        });
        push(@ids,$id);
    }
    return(undef,@ids);
}

sub query { }
    
1;
