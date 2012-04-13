package CIF::Smrt;
use base qw(Class::Accessor);

use 5.008008;
use strict;
use warnings;
use threads;

our $VERSION = '0.00_01';
$VERSION = eval $VERSION;  # see L<perlmodstyle>

__PACKAGE__->follow_best_practice;

use CIF::Utils ':all';
use Regexp::Common qw/net URI/;
use Regexp::Common::net::CIDR;
use Encode qw/encode_utf8/;
use Data::Dumper;
use File::Type;
use Module::Pluggable require => 1;
use Digest::MD5 qw/md5_hex/;
use Digest::SHA1 qw/sha1_hex/;
use URI::Escape;
use Try::Tiny;

my @processors = __PACKAGE__->plugins;
@processors = grep(/Processor/,@processors);

sub new {
    my ($class,%args) = (shift,@_);
    my $self = {};
    bless($self,$class);

    return $self;
}

sub get_feed { 
    my $f = shift;
    my ($content,$err) = threads->create('_get_feed',$f)->join();
    return(undef,$err) if($err);
    return(undef,'no content') unless($content);
    # auto-decode the content if need be
    $content = _decode($content,$f);

    # encode to utf8
    $content = encode_utf8($content);
    # remove any CR's
    $content =~ s/\r//g;
    delete($f->{'feed'});
    return($content);
}

# we do this sep cause it's in a thread
# this gets around memory leak issues and TLS threading issues with Crypt::SSLeay, etc
sub _get_feed {
    my $f = shift;
    return unless($f->{'feed'});

    foreach my $key (keys %$f){
        foreach my $key2 (keys %$f){
            if($f->{$key} =~ /<$key2>/){
                $f->{$key} =~ s/<$key2>/$f->{$key2}/g;
            }
        }
    }
    my @pulls = __PACKAGE__->plugins();
    @pulls = grep(/::Pull::/,@pulls);
    foreach(@pulls){
        if(my $content = $_->pull($f)){
            return(undef,$content);
        }
    }
    return('could not pull feed',undef);
}


## TODO -- turn this into plugins
sub parse {
    my $class = shift;
    my $f = shift;
    my ($content,$err) = get_feed($f);
    return($err,undef) if($err);

    my $return;
    # see if we designate a delimiter
    if(my $d = $f->{'delimiter'}){
        require CIF::Smrt::ParseDelim;
        $return = CIF::Smrt::ParseDelim::parse($f,$content,$d);
    } else {
        # try to auto-detect the file
        if($content =~ /<\?xml version=/){
            if($content =~ /<rss version=/){
                require CIF::Smrt::ParseRss;
                $return = CIF::Smrt::ParseRss::parse($f,$content);
            } else {
                require CIF::Smrt::ParseXml;
                $return = CIF::Smrt::ParseXml::parse($f,$content);
            }
        } elsif($content =~ /^\[?{/){
            # possible json content or CIF
            if($content =~ /^{"status"\:/){
                require CIF::Smrt::ParseCIF;
                $return = CIF::Smrt::ParseCIF::parse($f,$content);
            } elsif($content =~ /urn:ietf:params:xmls:schema:iodef-1.0/) {
                require CIF::Smrt::ParseJsonIodef;
                $return = CIF::Smrt::ParseJsonIodef::parse($f,$content);
            } else {
                require CIF::Smrt::ParseJson;
                $return = CIF::Smrt::ParseJson::parse($f,$content);
            }
        ## TODO -- fix this; double check it
        } elsif($content =~ /^#?\s?"\S+","\S+"/){
            require CIF::Smrt::ParseCsv;
            $return = CIF::Smrt::ParseCsv::parse($f,$content);
        } else {
            require CIF::Smrt::ParseTxt;
            $return = CIF::Smrt::ParseTxt::parse($f,$content);
        }
    }
    return(undef,$return);
}

sub _decode {
    my $data = shift;
    my $f = shift;

    my $ft = File::Type->new();
    my $t = $ft->mime_type($data);
    my @plugs = __PACKAGE__->plugins();
    @plugs = grep(/Decode/,@plugs);
    foreach(@plugs){
        if(my $ret = $_->decode($data,$t,$f)){
            return($ret);
        }
    }
    return $data;
}

sub insert {
    my $config = shift;
    my $recs = shift;

    require Iodef::Pb::Simple;
    require CIF::Archive;
    CIF::DBI->connection('DBI:Pg:database=cif_test;host=localhost','postgres','',{ AutoCommit => 0});
    foreach (@$recs){
        foreach my $key (keys %$_){
            next unless($_->{$key});
            if($_->{$key} =~ /<(\S+)>/){
                my $x = $_->{$1};
                if($x){
                    $_->{$key} =~ s/<\S+>/$x/;
                }
            }
        }
        foreach my $p (@processors){
            $p->process($config,$_);
        }
        my $iodef = Iodef::Pb::Simple->new($_);
        my $id;
        try {
            $id = CIF::Archive->insert({
                data    => $iodef->encode()
            });
            warn $id;
        } catch {
            my $err = shift;
            warn $err;
            return($err);
        }
    }

    CIF::Archive->dbi_commit() unless(CIF::Archive->db_Main->{'AutoCommit'});
    return(0);
}

sub process {
    my $class = shift;
    my %args = @_;

    my $threads = $args{'threads'};
    my $recs    = $args{'entries'};
    my $full    = $args{'full_load'};
    my $config  = $args{'config'};

    # we do this so other scripts can hook into us
    my $fctn = ($args{'function'}) ? $args{'function'} : 'CIF::Smrt::insert';

    # do the sort before we split
    $recs = _sort_detecttime($recs);
    my $batches;
    if($full){ 
        $batches = split_batches($threads,$recs);
    } else {
        # sort by detecttime and only process the last 5 days of stuff
        ## TODO -- make this configurable
        my $goback = DateTime->from_epoch(epoch => (time() - (84600 * 5)));
        $goback = $goback->ymd().'T'.$goback->hms().'Z';
        my @rr;
        foreach (@$recs){
            last if(($_->{'detecttime'} cmp $goback) == -1);
            push(@rr,$_);
        }
        # TODO -- round robin the split?
        $batches = split_batches($threads,\@rr);
    }
    
    ## CREATE THE IODEF analytics first...

    if(scalar @{$batches} == 1){
        insert($config,$recs);
    } else {
        foreach(@{$batches}){
            my $t = threads->create($fctn,$config,$_);
        }

        while(threads->list()){
            my @joinable = threads->list(threads::joinable);
            unless($#joinable > -1){
                sleep(1);
                next();
            }
            foreach(@joinable){
                $_->join();
            }
        }
    }
}

sub throttle {
    my $throttle = shift;

    require Linux::Cpuinfo;
    my $cpu = Linux::Cpuinfo->new();
    return(1) unless($cpu);
    my $cores = $cpu->num_cpus();
    return(1) unless($cores && $cores =~ /^\d$/);
    return(1) if($cores eq 1);
    return($cores) unless($throttle && $throttle ne 'medium');
    return($cores/2) if($throttle eq 'low');
    return($cores * 1.5);
}

sub split_batches {
    ## TODO -- think through this.
    my $tc = shift;
    my $recs = shift || return;
    my @array = @$recs;

    my @batches;
    if($#array == 0){
        push(@batches,$recs);
        return(\@batches);
    }

    my $num_recs = $#array + 1;
    my $batch = (($num_recs/$tc) == int($num_recs/$tc)) ? ($num_recs/$tc) : (int($num_recs/$tc) + 1);
    for(my $x = 0; $x <= $#array; $x += $batch){
        my $start = $x;
        my $end = ($x+$batch);
        $end = $#array if($end > $#array);
        my @a = @array[$x ... $end];
        push(@batches,\@a);
        $x++;
    }
    return(\@batches);
}

sub _sort_detecttime {
    my $recs = shift;

    foreach (@{$recs}){
        delete($_->{'regex'}) if($_->{'regex'});
        my $dt = $_->{'detecttime'};
        if($dt){
            $dt = normalize_timestamp($dt);
        }
        unless($dt){
            $dt = DateTime->from_epoch(epoch => time());
            if(lc($_->{'detection'}) eq 'hourly'){
                $dt = $dt->ymd().'T'.$dt->hour.':00:00Z';
            } elsif(lc($_->{'detection'}) eq 'monthly') {
                $dt = $dt->year().'-'.$dt->month().'-01T00:00:00Z';
            } elsif(lc($_->{'detection'} ne 'now')){
                $dt = $dt->ymd().'T00:00:00Z';
            } else {
                $dt = $dt->ymd().'T'.$dt->hms();
            }
        }
        $_->{'detecttime'} = $dt;
        $_->{'description'} = '' unless($_->{'description'});
    }
    ## TODO -- can we get around having to create a new array?
    my @new = sort { $b->{'detecttime'} cmp $a->{'detecttime'} } @$recs;
    return(\@new);
}

1;