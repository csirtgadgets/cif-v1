package CIF::Smrt::Plugin::Pull::Http;

use strict;
use warnings;

# used for LWP user-agent version
our $VERSION = '1.0';

sub pull {
    my $class = shift;
    my $f = shift;
    return unless($f->{'feed'} =~ /^http/);
    return if($f->{'cif'});
    
    my $timeout = $f->{'timeout'} || 30;

    require LWP::UserAgent;
    my $ua = LWP::UserAgent->new(agent => 'CIF/'.$VERSION);
    $ua->timeout($timeout);
    
    # load up proxy if we have it
    $ua->env_proxy();
    if($f->{'proxy'}){
        $ua->proxy(['http','ftp'], $f->{'proxy'});
    }
    
    # work-around for what appears to be a threading / race condition
    $ua->max_redirect(0) if($f->{'feed'} =~ /^https/);

    my $content;
    if($f->{'feed_user'}){
       my $req = HTTP::Request->new(GET => $f->{'feed'});
       $req->authorization_basic($f->{'feed_user'},$f->{'feed_password'});
       my $ress = $ua->request($req);
       unless($ress->is_success()){
            return('request failed: '.$ress->status_line());
       }
       $content = $ress->decoded_content();
    } else {
        if(defined($f->{'verify_tls'}) && $f->{'verify_tls'} == 0){
            $ua->ssl_opts(verify_hostname => 0);
        }
        my $r;
        if($f->{'mirror'}){
            $f->{'feed'} =~ m/\/([a-zA-Z0-9._-]+)$/;
            my $file = $f->{'mirror'}.'/'.$1;
            return($file.' isn\'t writeable by our user') if(-e $file && !-w $file);
            $ua->mirror($f->{'feed'},$file);
            open(F,$file) || return($!.': '.$file);
            $content = join('',<F>);
            close(F);
            return('no content') unless($content && $content ne '');
        } else {
            $r = $ua->get($f->{'feed'});
            if($r->is_success()){
                $content = $r->decoded_content();
            } else {
                return('failed to get feed: '.$f->{'feed'}."\n".$r->status_line());
            }
            $ua = undef;
        }
    }
    return(undef,$content);
}

1;
