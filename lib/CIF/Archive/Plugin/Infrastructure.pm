package CIF::Archive::Plugin::Infrastructure;
use base 'CIF::Archive::Plugin';

use warnings;
use strict;

use Module::Pluggable require => 1, search_path => [__PACKAGE__];
use Regexp::Common qw/net/;
use Regexp::Common::net::CIDR;
use Data::Dumper;

my @plugins = __PACKAGE__->plugins();

__PACKAGE__->table('infrastructure');
__PACKAGE__->columns(Primary => 'id');
__PACKAGE__->columns(All => qw/id uuid guid address portlist protocol confidence detecttime created/);
__PACKAGE__->sequence('infrastructure_id_seq');

sub insert {
    my $class = shift;
    my $data = shift;
    
    return unless(ref($data->{'data'}) eq 'IODEFDocumentType');       
       
    ## TODO -- clean this up, refactor
    my $tbl = $class->table();
    foreach(@plugins){
        if($_->prepare($data)){
            $class->table($_->table());
        }
    }

    my $uuid = $data->{'uuid'}; 
    
    ## TODO -- add these to Plugin
    my $portlist;
    my $protocol;
    my $confidence = $class->iodef_confidence($data->{'data'});
    $confidence = @{$confidence}[0]->get_content();
    
    my $msg = $data->{'data'};
    
    my @ids;
    my $systems = $class->iodef_systems($data->{'data'});
    
    return unless(@$systems);
    foreach my $system (@{$systems}){
        my @nodes = (ref($system->get_Node()) eq 'ARRAY') ? @{$system->get_Node()} : $system->get_Node();
        foreach my $node (@nodes){
            my $addresses = $node->get_Address();
            $addresses = [$addresses] if(ref($addresses) eq 'AddressType');
            foreach my $a (@$addresses){
                # we have to check for both because of urls that look like:
                # 1.1.1.1/abc.html
                next unless($a->get_content() =~ /^$RE{'net'}{'IPv4'}$/ || $a->get_content() =~ /^$RE{'net'}{'CIDR'}{'IPv4'}$/);
               
                my $id;
                # we do this here cause it's faster than doing 
                # it as a seperate check in the main class (1 less extra for loop)
                if($class->test_feed($data)){
                    my $services = $system->get_Service();
                    $services = (ref($system->get_Service()) eq 'ARRAY') ? $system->get_Service() : [$system->get_Service] if($services);
                    
                    my $hash = {
                        guid        => $data->{'guid'},
                        uuid        => $data->{'uuid'},
                        address     => $a->get_content(),
                        confidence  => $confidence,
                    };
                                              
                    if($services){  
                        foreach my $service (@$services){
                            $class->SUPER::insert({
                                portlist    => $service->get_Portlist(),
                                protocol    => $service->get_ip_protocol(),
                                %$hash,
                            });
                        }
                    } else {
                        $class->SUPER::insert($hash);
                    }
                }
                
                ## TODO -- clean this up into a function, map with ipv6
                ## it'll evolve into pushing this search into the hash table
                ## the client will then do the final leg of the work (Net::Patricia, etc)
                ## right now postgres can do it, but down the road big-data warehouses might not
                ## this way we can do faster hash lookups for non-advanced CIDR queries
                #my $id;
                
                my @index;
                if($a->get_content() =~ /^$RE{'net'}{'IPv4'}$/){
                    my @array = split(/\./,$a->get_content());
                    push(@index, (
                        $a->get_content(),
                        $array[0].'.'.$array[1].'.'.$array[2].'.0/24',
                        $array[0].'.'.$array[1].'.0.0/16',
                        $array[0].'.0.0.0/8'
                    ));
                } elsif($a->get_content() =~ /^$RE{'net'}{'CIDR'}{'IPv4'}{-keep}$/){
                    my @array = split(/\./,$1);
                    my $mask = $2;
                    my @a1;
                    ## TODO -- double check this..
                    ## ref: Client.pm +188
                    for($mask){
                        if($_ >= 8){
                            push(@index, $array[0].'.0.0.0/8');
                        }
                        if($_ >= 16){
                            push(@index,$array[0].'.'.$array[1].'.0.0/16');
                        }
                        if($_ >= 24){
                            push(@index,$array[0].'.'.$array[1].'.'.$array[2].'.0/24');
                        }     
                    }
                }
                $data->{'confidence'} = $confidence;
                foreach (@index){
                    $id = $class->insert_hash($data,$class->SUPER::generate_sha1($_));
                    push(@ids,$id);
                }
            }
        }
    }
    $class->table($tbl);
    return(undef,@ids);
}
    
1;
