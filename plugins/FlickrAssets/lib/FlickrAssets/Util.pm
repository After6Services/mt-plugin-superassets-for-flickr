package FlickrAssets::Util;

use strict;
use warnings;

require MT;

use Exporter qw(import);
our @ALL = qw(
    error_code_from_flickr_exception
    is_valid_photo_url
    is_valid_plugin_config
    parse_photo_url
    plugin
);
our @EXPORT_OK = @ALL;
our %EXPORT_TAGS = (all => \@ALL);

sub init {
    my $cb = shift;

    # Flickr::API2 uses LWP::UserAgent::default_header(), which is not
    # available in the older version of the module supplied with MT,
    # so we're going to fake it!
    require LWP::UserAgent;
    unless (LWP::UserAgent->can('default_header')) {
        no warnings 'redefine';
        *LWP::UserAgent::default_header = sub { };
    }
}

#
# Validate/extract user path_alias/nsid, photo id and optionally set id and photo size context
# from a Flickr photo URL:
#
# http://www.flickr.com/photos/amouchinski/7098065151/sizes/l/in/set-72157629499885466/
# http://www.flickr.com/photos/amouchinski/7098065151/in/photostream/
# http://www.flickr.com/photos/77525377@N08/7098065151/
# http://flic.kr/p/bPertD
#
sub is_valid_photo_url {
    my $url = shift;
    return $url && $url =~ m'\s* https?://(?:www\.)? (?: flickr\.com/photos/[^/]+/[^/]+ | flic\.kr/p/[^/]+ )'ix;
}

sub parse_photo_url {
    my $url = shift;
    my $data;

    return unless $url;

    if ($url =~ m'flickr\.com/photos/([^/]+)/([^/]+)(.*)'i) {
        my ($user, $context) = ($1, $3);
        $data->{photo_id} = $2;
        $data->{ $user =~ /\d+\@/ ? 'user_nsid' : 'path_alias' } = $user;

        if ($context) {
            $data->{size} = $1 if $context =~ m'sizes/(\w+)';
            $data->{set_id} = $1 if $context =~ m'in/set-([^/]+)';
        }
    }
    elsif ($url =~ m'flic.kr/p/(.*)'i) {
        require Encode::Base58;
        $data->{photo_id} = Encode::Base58::decode_base58($1);
    }

    return $data;
}

sub plugin {
    return MT->component("FlickrAssets");
}

sub is_valid_plugin_config {
    return plugin->get_config_value("api_key") && plugin->get_config_value("api_secret");
}

sub error_code_from_flickr_exception {
    my $message = shift;
    return ($message && $message =~ /\((\d+)\)$/) ? $1 : undef;
}

1;
