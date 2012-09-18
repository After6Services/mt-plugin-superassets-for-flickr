package MT::Asset::FlickrPhoto;

use strict;
use warnings;

use base 'MT::Asset';

require MT;
require MT::Util;
use FlickrAssets::Util qw(:all);

__PACKAGE__->install_properties({
    class_type  => 'flickr_photo',
    column_defs => {
        flickr_photo_id              => 'string meta indexed',
        flickr_photo_secret          => 'string meta',
        flickr_photo_server          => 'string meta',
        flickr_photo_farm            => 'string meta',
        flickr_photo_sizes           => 'hash meta',
        flickr_photo_user_nsid       => 'string meta indexed',
        flickr_photo_user_path_alias => 'string meta indexed',
    },
});

sub class_label { "Flickr Photo" }   

sub class_label_plural { "Flickr Photos" }

sub has_thumbnail { 1 }

# entry asset manager needs this
sub file_name { shift->label }

# see http://www.flickr.com/services/api/misc.urls.html
# size names match the ones in API responses
our @SIZES = (
    { name => 'Square',       alias => 'Square 75',  size => 75,   img_suffix => 's', page_suffix => 'sq' },
    { name => 'Large Square', alias => 'Square 150', size => 150,  img_suffix => 'q', page_suffix => 'q'  },
    { name => 'Thumbnail',    alias => 'Thumbnail',  size => 100,  img_suffix => 't', page_suffix => 't'  },
    { name => 'Small',        alias => 'Small 240',  size => 240,  img_suffix => 'm', page_suffix => 's'  },
    { name => 'Small 320',    alias => 'Small 320',  size => 320,  img_suffix => 'n', page_suffix => 'n'  },
    { name => 'Medium',       alias => 'Medium 500', size => 500,  img_suffix => '',  page_suffix => 'm'  },
    { name => 'Medium 640',   alias => 'Medium 640', size => 640,  img_suffix => 'z', page_suffix => 'z'  },
    { name => 'Medium 800',   alias => 'Medium 800', size => 800,  img_suffix => 'c', page_suffix => 'c'  },
    { name => 'Large',        alias => 'Large 1024', size => 1024, img_suffix => 'b', page_suffix => 'l'  },
    { name => 'Original',     alias => 'Original',   size => 9999, img_suffix => 'o', page_suffix => 'o'  },
);

# size of the asset's url, default insert option, etc.
our $DEFAULT_SIZE = 'Medium 640';

# allow the following sizes to insert into entries via the options dialog
our @SIZES_EMBED = ('Small', 'Small 320', 'Medium', 'Medium 640', 'Medium 800', 'Large');

# returns size hashref from @SIZES by name or img_suffix key
# or using $key provided explicitly
sub _size_info {
    my ($key, $val) = shift;
    unless (defined $val) {
        $val = $key;
        $key = undef;
    }

    if (defined $val) {
        unless ($key) {
            $key = length($val) < 2 ? 'img_suffix' : 'name';
        }
        my ($size) = grep { $_->{$key} eq $val } @SIZES;
        return $size;
    }
}

#
# In addition to standard asset thumbnail_url() method params, this one takes
# 'size' as well - a Flickr API size name or letter.
#
sub thumbnail_url {
    my ($asset, %param) = @_;

    my $size = _size_info($asset->best_size_match(%param));
    my $asset_sizes = $asset->flickr_photo_sizes;

    return (
        $asset->flickr_image_url($size->{img_suffix}),
        $asset_sizes->{$size->{name}}->{width},
        $asset_sizes->{$size->{name}}->{height},
    );
}

#
# Returns name of a photo size that fits best the given $w/$h or $size from the list of
# sizes the photo has on Flickr; falls back to default size; when none fit well, returns undef.
#
sub best_size_match {
    my ($asset, %params) = @_;
    my ($w, $h, $size) = @params{qw/width height size/};
    my $size_info;

    $w ||= $params{Width};
    $h ||= $params{Height};

    if ($size) {
        $size_info = _size_info($size);
        if ($size_info) {
            $w = $h = $size_info->{size};
        }
    }

    unless ($size_info || $w || $h) {
        $size_info = _size_info($DEFAULT_SIZE);
        $w = $h = $size_info->{size};
    }

    $w ||= $h;
    $h ||= $w;

    my $photo_sizes = $asset->flickr_photo_sizes;
    delete $photo_sizes->{Original} if exists $photo_sizes->{Original};

    if ($photo_sizes && keys %$photo_sizes) {
        my @sizes_fit = grep {
            $photo_sizes->{$_}->{width} <= $w && $photo_sizes->{$_}->{height} <= $h
        } keys %$photo_sizes;

        if (@sizes_fit) {
            my %sizes_delta = map {
                my $delta = $w - $photo_sizes->{$_}->{width} + $h - $photo_sizes->{$_}->{height};
                $delta => $_;
            } @sizes_fit;
            
            return $sizes_delta{ ( sort { $a <=> $b } keys %sizes_delta )[0] };
        }
    }

    return 'Square';  # the smallest one
}

sub largest_size {
    my $asset = shift;

    my $sizes = $asset->flickr_photo_sizes;
    my @sizes_desc = sort { $b->{size} <=> $a->{size} } @SIZES;
    for (@sizes_desc) {
        return $_->{name} if exists $sizes->{$_->{name}};
    }
}

#
# See http://www.flickr.com/services/api/misc.urls.html
# 
# http://farm{farm-id}.staticflickr.com/{server-id}/{id}_{secret}.jpg
# http://farm{farm-id}.staticflickr.com/{server-id}/{id}_{secret}_[mstzb].jpg
# http://farm{farm-id}.staticflickr.com/{server-id}/{id}_{o-secret}_o.(jpg|gif|png)
# 
# Skipping originals for now.
# 
sub flickr_image_url {
    my ($asset, $size) = @_;
    $size = _size_info($DEFAULT_SIZE)->{img_suffix} unless defined $size;

    return sprintf(
        "http://farm%s.staticflickr.com/%s/%s_%s%s.jpg",
        ( map { $asset->$_ } qw/flickr_photo_farm flickr_photo_server flickr_photo_id flickr_photo_secret/ ),
        $size ? "_$size" : ''
    );
}

#
# Photo pages:
#
# http://www.flickr.com/photos/[user]/[photo id]/
# http://www.flickr.com/photos/[user]/[photo id]/in/set-[set id]/
# http://www.flickr.com/photos/[user]/[photo id]/in/photostream/
# http://www.flickr.com/photos/[user]/[photo id]/in/set-[set id]/sizes/[size letter]/
#
# Skipping the photo set/stream context for now.
# 
sub flickr_page_url {
    my ($asset, $size) = @_;

    if ($size) {
        $size = _size_info($size);
        # ignoring size context for default image size
        undef $size if $size->{name} eq $DEFAULT_SIZE;
    }

    return sprintf(
        "http://www.flickr.com/photos/%s/%s/%s",
        $asset->flickr_photo_user_path_alias || $asset->flickr_photo_user_nsid,
        $asset->flickr_photo_id,
        $size ? "sizes/" . $size->{page_suffix} . "/" : ''
    );
}

sub insert_options {
    my ($asset, $param) = @_;
    my $app = MT->instance;
    my $blog = $asset->blog;

    my $sizes = $asset->flickr_photo_sizes;
    $param->{sizes} = [
        map {
            my $s = _size_info($_);
            { name => $s->{alias}, letter => $s->{img_suffix} };
        } grep {
            exists $sizes->{$_};
        }
        @SIZES_EMBED
    ];

    my $prefs = $blog->flickr_photo_embed_options;
    my $prefs_size = _size_info($prefs->{size});
    my $selected_size;

    if ($prefs_size && exists $sizes->{$prefs_size->{name}}) {
        $selected_size = $prefs_size->{name};
    }
    else {
        my $width = $prefs_size ? $prefs_size->{width} : $blog->image_default_width;
        $selected_size = $asset->best_size_match(width => $width);
    }
    $param->{default_size} = _size_info($selected_size)->{img_suffix};

    for (qw(none left center right)) {
        $param->{"align_$_"} = ($prefs->{align} || $blog->image_default_align || 'none') eq $_ ? 1 : 0;
    }

    $param->{link_to_page} = exists $prefs->{link_to_page} ? $prefs->{link_to_page} : 1;

    $param->{can_save_settings} = $app->permissions->can_save_image_defaults ? 1 : 0;

    return $app->build_page(
        plugin->load_tmpl('photo_insert_options.tmpl'), $param
    );
}

sub on_upload {
    my $asset = shift;
    my ($param) = @_;
    my $app = MT->instance;
    my $blog = $asset->blog;

    $asset->SUPER::on_upload(@_);

    return unless $param->{new_entry};

    if ($param->{save_settings}) {
        return $app->error("Permission denied saving Flickr settings for blog " . $blog->id)
            unless $app->permissions->can_save_image_defaults;

        my $options = $blog->flickr_photo_embed_options;
        $options->{$_} = $param->{$_} for qw(align size link_to_page);
        $blog->flickr_photo_embed_options($options);

        $blog->save or die $blog->errstr;
    }
}

sub as_html {
    my ($asset, $param) = @_;
    my $text = '';

    $param->{enclose} = 1 unless exists $param->{enclose};

    if ($param->{include}) {
        my $size = $asset->flickr_photo_sizes->{ _size_info($param->{size})->{name} };

        # styles used for image assets
        my $style = '';
        if ($param->{wrap_text} && $param->{align}) {
            $style = 'class="mt-image-' . $param->{align} . '" ';

            if ($param->{align} eq 'none') {
                $style .= q{style=""};
            }
            elsif ($param->{align} eq 'left') {
                $style .= q{style="float: left; margin: 0 20px 20px 0;"};
            }
            elsif ($param->{align} eq 'right') {
                $style .= q{style="float: right; margin: 0 0 20px 20px;"};
            }
            elsif ($param->{align} eq 'center') {
                $style .= q{style="text-align: center; display: block; margin: 0 auto 20px;"};
            }
        }

        $text = sprintf(
            '<img src="%s" alt="%s" width="%s" height="%s" %s>',
            MT::Util::encode_html( $asset->flickr_image_url($param->{size}) ),
            MT::Util::encode_html($asset->label),
            $size->{width},
            $size->{height},
            $style,
        );

        if ($param->{link_to_page}) {
            $text = sprintf(
                '<a href="%s" target="_blank">%s</a>',
                MT::Util::encode_html($asset->flickr_page_url),
                $text,
            );
        }
    }
    else {
        $text = sprintf(
            '<a href="%s">%s</a>',
            MT::Util::encode_html($asset->url),
            MT->translate('View image'),
        );
    }

    return $param->{enclose} ? $asset->enclose($text) : $text;
}

sub edit_template_param {
    my $asset = shift;
    my ($cb, $app, $param, $tmpl) = @_;

    my $largest_size = $asset->largest_size;
    $param->{image_height} = $asset->flickr_photo_sizes->{$largest_size}->{height};
    $param->{image_width}  = $asset->flickr_photo_sizes->{$largest_size}->{width};

    $param->{page_url} = $asset->flickr_page_url;
}

1;
