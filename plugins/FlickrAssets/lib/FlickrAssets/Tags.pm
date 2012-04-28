package FlickrAssets::Tags;

use strict;
use warnings;

require MT::Asset::FlickrPhoto;

sub is_valid_asset {
    my $asset = shift;
    return $asset && $asset->class eq 'flickr_photo';
}

sub _hdlr_flickr_photo_page {
    my ($ctx, $args) = @_;

    my $asset = $ctx->stash('asset');
    return $ctx->_no_asset_error unless is_valid_asset($asset);

    return $asset->flickr_page_url(
        $asset->best_size_match( %{$args || {}} )
    );
}

sub _hdlr_flickr_photo_width {
    return _flickr_photo_dimension('width', @_);
}

sub _hdlr_flickr_photo_height {
    return _flickr_photo_dimension('height', @_);
}

sub _flickr_photo_dimension {
    my ($which, $ctx, $args) = @_;

    my $asset = $ctx->stash('asset');
    return $ctx->_no_asset_error unless is_valid_asset($asset);

    my $size = MT::Asset::FlickrPhoto::_size_info(
        $asset->best_size_match( %{$args || {}} )
    );

    return $asset->flickr_photo_sizes->{$size->{name}}->{$which};
}

1;
