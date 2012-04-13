package CIF::Smrt::ParseXml;

use strict;
use warnings;
require XML::LibXML;

sub parse {
    my $f = shift;
    my $content = shift;
    
    my $parser = XML::LibXML->new();
    my $doc = $parser->load_xml(string => $content);
    my @nodes = $doc->findnodes('//'.$f->{'node'});
    return unless(@nodes);
    my @array;
    my @elements = split(',',$f->{'elements'}) if($f->{'elements'});
    my @elements_map = split(',',$f->{'elements_map'}) if($f->{'elements_map'});
    my @attributes_map = split(',',$f->{'attributes_map'}) if($f->{'attributes_map'});
    my @attributes = split(',',$f->{'attributes'}) if($f->{'attributes'});
    foreach my $node (@nodes){
        my $h;
        if(@elements_map){
            foreach (0 ... $#elements_map){
                $h->{$elements_map[$_]} = $node->findvalue('./'.$elements[$_]);
            }
        } else {
            foreach (0 ... $#attributes_map){
                $h->{$attributes_map[$_]} = $node->getAttribute($attributes[$_]);
            }
        }
        map { $h->{$_} = $f->{$_} } keys %$f;
        push(@array,$h);
    }
    return(\@array);
}

1;
