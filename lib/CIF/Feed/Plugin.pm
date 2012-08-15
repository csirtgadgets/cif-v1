package CIF::Feed::Plugin;
use base 'CIF::DBI';
use base 'Class::Accessor';

use warnings;
use strict;

use Try::Tiny;
use CIF::Msg;
use CIF::Msg::Feed;
use CIF qw/generate_uuid_random/;

__PACKAGE__->columns(All => qw/id uuid/);
__PACKAGE__->columns(Primary => 'id');
__PACKAGE__->has_a(uuid => 'CIF::Archive');

__PACKAGE__->follow_best_practice();
__PACKAGE__->mk_accessors(qw(restriction_map group_map));

sub generate_feeds {
    my $class   = shift;
    my $args    = shift;
   
    my @vars = @{$args->{'vars'}};
    
    my $sth = $class->sql_feed();
    my $ret = $sth->execute(@vars);
    return unless($ret);
    ## TODO: protect against orphan keys
    ## if there's nothing in the data section, trigger a warning
    ## or a delete?
    return($sth->fetchall_hashref('id'));
}

sub encode_feed {
    my $class = shift;
    my $args = shift;
  
    my $recs = $args->{'recs'};
    $recs = [ map { $recs->{$_}->{'data'} } keys (%$recs) ];
    
    delete($args->{'recs'});
        
    my $feed = FeedType->new({
        description     => $args->{'description'},
        ReportTime      => $args->{'report_time'},
        data            => $recs,
        version         => $CIF::VERSION,
        confidence      => $args->{'confidence'},
        guid            => $args->{'guid'},
        group_map       => $args->{'group_map'},
        restriction_map => $args->{'restriction_map'},
        uuid            => generate_uuid_random(),
        restriction     => $args->{'restriction'},
    });
    return $feed;
}

sub test_whitelist {
    my $class = shift;
    my $args = shift;
    
    return $args->{'recs'} if(keys %{$args->{'recs'}});
}

1;