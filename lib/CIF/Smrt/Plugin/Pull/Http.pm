package CIF::Smrt::Plugin::Pull::Http;

require LWP::Simple;
require LWP::UserAgent;

our $VERSION = '0.01';

## TODO -- remove LWP::Simple
sub pull {
    my $class = shift;
    my $f = shift;
    return unless($f->{'feed'} =~ /^http/);
    return if($f->{'cif'});

    my $timeout = $f->{'timeout'} || 10;

    my $content;
    if($f->{'feed_user'}){
       my $ua = LWP::UserAgent->new();
       $ua->timeout($timeout);
       my $req = HTTP::Request->new(GET => $f->{'feed'});
       $req->authorization_basic($f->{'feed_user'},$f->{'feed_password'});
       my $ress = $ua->request($req);
       unless($ress->is_success()){
            print('request failed: '.$ress->status_line()."\n");
            return;
       }
       $content = $ress->decoded_content();
    } else {
        my $ua = LWP::UserAgent->new(agent => 'CIF/'.$VERSION);
        if(defined($f->{'verify_tls'}) && $f->{'verify_tls'} == 0){
            $ua->ssl_opts(verify_hostname => 0);
        }
        my $r;
        if($f->{'mirror'}){
            $f->{'feed'} =~ m/\/([a-zA-Z0-9._-]+)$/;
            my $file = $f->{'mirror'}.'/'.$1;
            $ua->mirror($f->{'feed'},$file);
            open(F,$file) || die($!.': '.$file);
            $content = join('',<F>);
            close(F);
            return('no content',undef) unless($content && $content ne '');
        } else {
            $r = $ua->get($f->{'feed'});
            if($r->is_success()){
                $content = $r->decoded_content();
            } else {
                #$content = LWP::Simple::get($f->{'feed'});
                print 'failed to get feed: '.$f->{'feed'}."\n".$r->status_line();
            }
        }
    }
    return($content);
}

1;
