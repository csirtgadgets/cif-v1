package CIF::Client::Query;
use base 'Class::Accessor';

use strict;
use warnings;

use Module::Pluggable require => 1, search_path => [__PACKAGE__];
use Digest::SHA1 qw/sha1_hex/;
use CIF qw(is_uuid);

my @plugins = __PACKAGE__->plugins();

__PACKAGE__->follow_best_practice();
__PACKAGE__->mk_accessors(qw(
    apikey limit confidence
    guid description feed
));

sub new {
    my $class   = shift;
    my $args    = shift;
   
    my $self = {};
    bless($self,$class);
    
    my ($err,$ret);
    foreach my $p (@plugins){
        ($err,$ret) = $p->process($args);
        return($err) if($err);
        last if($ret);
    }
   
    $ret = \%$args unless($ret);
    $ret = [$ret] unless(ref($ret) eq 'ARRAY');
      
    foreach my $qq (@{$ret}){
        $qq->{'query'} = lc($qq->{'query'});
        $qq->{'query'} = sha1_hex($qq->{'query'}) unless($qq->{'query'} =~ /^[a-f0-9]{32,40}$/ || is_uuid($qq->{'query'}) );
        
        ## don't ask, its' all crap.
        $args->{'limit'}        = $qq->{'limit'} if($qq->{'limit'});
        $args->{'description'}  = $qq->{'description'} if($qq->{'description'});
        $args->{'feed'}         = $qq->{'feed'} if($qq->{'feed'});
        $args->{'confidence'}   = $qq->{'confidence'} if($qq->{'confidence'});
        
        $qq = MessageType::QueryStruct->new({
            query   => $qq->{'query'},
            nolog   => $qq->{'nolog'},
        });
    }
    
    my $msg = MessageType::QueryType->new({
        apikey      => $args->{'apikey'},
        limit       => $args->{'limit'},
        confidence  => $args->{'confidence'},
        guid        => $args->{'guid'},
        description => $args->{'description'},
        query       => $ret,
        
        ## TODO: clean this up...
        feed        => $args->{'feed'},
    });
        
    return (undef,$msg->encode());
}

# skel
sub process {}

1;