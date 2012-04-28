#!/usr/bin/perl

use strict;
use warnings;

use Flickr::API2;

my $api = Flickr::API2->new({ key => '56263dbbba4ba450382a136242ea7852', secret => '0b96f7ca68a2b840' });
#my $api = Flickr::API2->new({ key => '56dfef:dbbba4ba450382a136242ea7852', secret => '0b96f7ca68a2b840' });
#my $id = '7098065151';
#my $id = 'zhopa';
my $id = '6961699460';
my $photo;
my $info;
my $sizes;

eval {
    $photo = $api->photos->by_id($id);
    $info = $photo->info;
    $sizes = $photo->sizes;
};
if ($@) {
    my $ecode = ($@ =~ /\((\d+)\)$/) ? $1 : 0;
    my $msg = "api error";
    if ($ecode == 1) {
        $msg = "photo not found";
    } elsif ($ecode == 100) {
        $msg = "invalid api key";
    }
    print "ERROR: $msg";
}

use Data::Dump qw(dump);
#dump $photo;
#dump $info;
#dump $sizes;

my %s =
    map {
        $_->{label} => { width => $_->{width}, height => $_->{height} }
    } @{$sizes->{size}};

dump \%s;
