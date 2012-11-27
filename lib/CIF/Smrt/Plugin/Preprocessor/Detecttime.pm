package CIF::Smrt::Plugin::Preprocessor::Detecttime;

use warnings;
use strict;

use CIF qw/normalize_timestamp/;

sub process {
    my $class   = shift;
    my $rules   = shift;
    my $rec     = shift;
        
    my $dt = $rec->{'detecttime'};
    if($dt){
        $rec->{'detecttime'} = normalize_timestamp($rec->{'detecttime'});
        $rec->{'dt'} = DateTime::Format::DateParse->parse_datetime($rec->{'detecttime'})->epoch();
        return $rec;
    }
    
    $dt = DateTime->from_epoch(epoch => time());
    $rec->{'dt'} = DateTime::Format::DateParse->parse_datetime($dt)->epoch();

    if(lc($rec->{'detection'}) eq 'hourly'){
        $dt = $dt->ymd().'T'.$dt->hour.':00:00Z';
    } elsif(lc($rec->{'detection'}) eq 'daily') {
        $dt = $dt->ymd().'T00:00:00Z';
    } elsif(lc($rec->{'detection'}) eq 'monthly') {
        $dt = $dt->year().'-'.$dt->month().'-01T00:00:00Z';
    } elsif(lc($rec->{'detection'} ne 'now')){
        $dt = $dt->ymd().'T00:00:00Z';
    } else {
        $dt = $dt->ymd().'T'.$dt->hms().'Z';
    }
    
    $rec->{'detecttime'} = $dt;
        
    return $rec;
}

1;