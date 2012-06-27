package CIF::Smrt;
use base 'Class::Accessor';

use 5.008008;
use strict;
use warnings;
use threads;

our $VERSION = '0.99_01';
$VERSION = eval $VERSION;  # see L<perlmodstyle>

use CIF qw/generate_uuid_url generate_uuid_random is_uuid/;
use Regexp::Common qw/net URI/;
use Regexp::Common::net::CIDR;
use Encode qw/encode_utf8/;
use Data::Dumper;
use File::Type;
use Module::Pluggable require => 1;
use Digest::SHA1 qw/sha1_hex/;
use URI::Escape;
use Try::Tiny;
use Iodef::Pb::Simple;
require CIF::Archive;
#use ZeroMQ qw(:all);

__PACKAGE__->follow_best_practice;
__PACKAGE__->mk_accessors(qw(config db_config feeds_config feeds threads entries defaults feed rules load_full goback));

my @processors = __PACKAGE__->plugins;
@processors = grep(/Processor/,@processors);

sub new {
    my $class = shift;
    my $args = shift;
    
    my $self = {};
    bless($self,$class);
    
    $self->init($args);

    return (undef,$self);
}

sub init {
    my $self = shift;
    my $args = shift;
    
    $self->set_feed($args->{'feed'});
    
    $self->init_config($args);
    $self->init_rules($args);
    
    $self->set_threads(     $args->{'threads'}      || $self->get_config->{'threads'}   || 1);
    $self->set_goback(      $args->{'goback'}       || $self->get_config->{'goback'}    || 3);
    $self->set_load_full(   $args->{'load_full'}    || $self->get_config->{'load_full'} || 0);
    
    
    $self->set_goback(time() - ($self->get_goback() * 84600));
    $self->set_goback(0) if($self->get_load_full());
    
    $self->init_db($args);
    $self->init_feeds($args);
}

sub init_config {
    my $self = shift;
    my $args = shift;
    
    $args->{'config'} = Config::Simple->new($args->{'config'}) || return(undef,'missing config file');
    $self->set_config($args->{'config'}->param(-block => 'cif_smrt'));
        
    $self->set_db_config($args->{'config'}->param(-block => 'db'));
    $self->set_feeds_config($args->{'config'}->param(-block => 'cif_feeds'));
}

sub init_rules {
    my $self = shift;
    my $args = shift;
    
    $args->{'rules'} = Config::Simple->new($args->{'rules'}) || return(undef,'missing rules file');
    my $defaults    = $args->{'rules'}->param(-block => 'default');
    my $rules       = $args->{'rules'}->param(-block => $self->get_feed());
    
    map { $defaults->{$_} = $rules->{$_} } keys (%$rules);
    
    unless(is_uuid($defaults->{'guid'})){
        $defaults->{'guid'} = generate_uuid_url($defaults->{'guid'});
    }
    $self->set_rules($defaults);
}

sub init_feeds {
    my $self = shift;
    
    my $feeds = $self->get_feeds_config->{'enabled'} || return;
    $self->set_feeds($feeds);
}

sub init_db {
    my $self = shift;
    my $args = shift;
    
    my $config = $self->get_db_config();
    
    my $db          = $config->{'database'} || 'cif';
    my $user        = $config->{'user'}     || 'postgres';
    my $password    = $config->{'password'} || '';
    my $host        = $config->{'host'}     || '127.0.0.1';
    
    my $dbi = 'DBI:Pg:database='.$db.';host='.$host;
    
    require CIF::DBI;
    my $ret = CIF::DBI->connection($dbi,$user,$password,{ AutoCommit => 0});
    return $ret;   
}

sub pull_feed { 
    my $f = shift;
    my ($content,$err) = threads->create('_pull_feed',$f)->join();
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
sub _pull_feed {
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
    my $self = shift;
    my $f = $self->get_rules();
    
    my ($content,$err) = pull_feed($f);
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

sub process {
    my $self = shift;
    my $args = shift;

    my $threads = $self->get_threads();
    my $full    = 1;
    
    warn 'parsing...' if($::debug);
    my $recs = $self->parse();
    
    warn 'mapping...' if($::debug);
    foreach my $r (@$recs){
        #delete($_->{'regex'}) if($_->{'regex'});
        foreach my $key (keys %$r){
            next unless($r->{$key});
            if($r->{$key} =~ /<(\S+)>/){
                my $x = $r->{$1};
                if($x){
                    $r->{$key} =~ s/<\S+>/$x/;
                }
            }
        }
        foreach my $p (@processors){
            $r = $p->process($self->get_rules(),$r);
        }
    }
    
    warn 'sorting...' if($::debug);
    $recs = [ sort { $b->{'dt'} <=> $a->{'dt'} } @$recs ];
    
    warn 'submitting...' if($::debug);
    
    my @array;
    foreach (@$recs){
        last if($_->{'dt'} < $self->get_goback());
        $_->{'id'} = generate_uuid_random();
        my $iodef = Iodef::Pb::Simple->new($_);
        push(@array,{ uuid => $_->{'id'}, data => $iodef });
    }
   
    ## TODO -- thread out analytics
    
    ## TODO -- re-write using the client in version 1.1
    
    # store
    my $state = 0;
    warn 'entries: '.($#array + 1) if($::debug);
    for(my $i = 0; $i <= $#array; $i++){
        my $id = CIF::Archive->insert({
            guid    => $self->get_rules->{'guid'},
            data    => $array[$i]->{'data'},
            uuid    => $array[$i]->{'uuid'},
            feeds   => $self->get_feeds(),
        });
        $state = 0;
        warn $id if($::debug && $::debug > 1);
        if($i % 1000 == 0){
            warn 'commiting...' if($::debug);
            CIF::Archive->dbi_commit();
            $state = 1;
        }
    }
    warn 'commiting last...' if($::debug);
    CIF::Archive->dbi_commit() unless($state);
    return(undef,1);
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

sub normalize_timestamp {
    my $dt = shift;
    return $dt if($dt =~ /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$/);
    if($dt && ref($dt) ne 'DateTime'){
        if($dt =~ /^\d+$/){
            if($dt =~ /^\d{8}$/){
                $dt.= 'T00:00:00Z';
                $dt = eval { DateTime::Format::DateParse->parse_datetime($dt) };
                unless($dt){
                    $dt = DateTime->from_epoch(epoch => time());
                }
            } else {
                $dt = DateTime->from_epoch(epoch => $dt);
            }
        } elsif($dt =~ /^(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})(\S+)?$/) {
            my ($year,$month,$day,$hour,$min,$sec,$tz) = ($1,$2,$3,$4,$5,$6,$7);
            $dt = DateTime::Format::DateParse->parse_datetime($year.'-'.$month.'-'.$day.' '.$hour.':'.$min.':'.$sec,$tz);
        } else {
            $dt =~ s/_/ /g;
            $dt = DateTime::Format::DateParse->parse_datetime($dt);
            return undef unless($dt);
        }
    }
    $dt = $dt->ymd().'T'.$dt->hms().'Z';
    return $dt;
}

1;
