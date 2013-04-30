package CIF::Smrt::Plugin::Pull::Http;

use strict;
use warnings;

# used for LWP user-agent version
# we should pull from higher up
our $VERSION = '1.0';

sub pull {
    my $class = shift;
    my $f = shift;
    return unless($f->{'feed'} =~ /^http/);
    return if($f->{'cif'});
    
    my $timeout = $f->{'timeout'} || 300;

    # If a proxy server is set in the configuration use LWP::UserAgent
    # since LWPx::ParanoidAgent does not allow the use of proxies
    # We'll assume that the proxy is sane and handles timeouts and redirects and such appropriately.
    my $ua;
    if ($f->{'proxy'}) {
        require LWP::UserAgent;
        $ua = LWP::UserAgent->new(agent => 'CIF/'.$VERSION);
        $ua->env_proxy();
        $ua->proxy(['http','https','ftp'], $f->{'proxy'});
    } else {
        # we use this instead of ::UserAgent, it does better
        # overall timeout checking
        require LWPx::ParanoidAgent;
        $ua = LWPx::ParanoidAgent->new(agent => 'CIF/'.$VERSION);
    }
    
    $ua->timeout($timeout);
    
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
            $ua->ssl_opts(SSL_verify_mode => 'SSL_VERIFY_NONE');
            $ua->ssl_opts(verify_hostname => 0);
        }
        my $r;
        if($f->{'mirror'}){
            $f->{'feed'} =~ m/\/([a-zA-Z0-9._-]+)$/;
            my $file = $f->{'mirror'}.'/'.$1;
            return($file.' isn\'t writeable by our user') if(-e $file && !-w $file);
            my $ret = $ua->mirror($f->{'feed'},$file);
            # unless it's a 200 or a 304 (which means cached, not modified)
            unless($ret->is_success() || $ret->status_line() =~ /^304 /){
                return $ret->decoded_content();   
            }
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
