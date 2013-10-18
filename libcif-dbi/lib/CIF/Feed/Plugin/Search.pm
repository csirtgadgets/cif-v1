package CIF::Feed::Plugin::Search;
use base 'CIF::Feed::Plugin';

use warnings;
use strict;

use Module::Pluggable require => 1, search_path => [__PACKAGE__];
use CIF qw/debug/;

__PACKAGE__->table('search');
__PACKAGE__->columns(All => qw/id uuid guid hash confidence reporttime created/);
__PACKAGE__->sequence('search_id_seq');

## TODO: database config?
my @plugins = __PACKAGE__->plugins();

sub generate_feeds {
    my $class   = shift;
    my $args    = shift;
        
    my @feeds;

    my $desc = 'search feed';

    my $feed_args = {
        description => $desc,
        report_time => $args->{'report_time'},
        confidence  => $args->{'confidence'},
        guid        => $args->{'guid'},
        vars    => [
            $args->{'start_time'},
            $args->{'confidence'},
            $args->{'limit'},
            $args->{'uuid'},
        ],
        group_map       => $args->{'group_map'},
        restriction_map => $args->{'restriction_map'},
        restriction     => $args->{'restriction'},
    };
    debug($desc.': generating');
    my $f = $class->SUPER::generate_feeds($feed_args);
    debug('records: '.keys %$f);
    debug($desc.': encoding');
    $f = $class->SUPER::encode_feed({ recs => $f, %$feed_args });
    push(@feeds,$f);
    
    return(\@feeds);
}
    
1;
