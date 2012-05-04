package FlickrAssets::CMS;

use strict;
use warnings;

require MT::Asset::FlickrPhoto;
use FlickrAssets::Util qw(:all);

sub flickr_photo_create {
    my $app = shift;
    my (%params, %errors, $tmpl, $photo_url_info);

    return $app->error("Permission denied.")
        unless $app->user->is_superuser || $app->permissions && $app->permissions->can_upload;

    $errors{invalid_plugin_config} = 1 unless is_valid_plugin_config();

    $params{$_} = $app->param($_) || '' for qw(photo_url continue_args no_insert);

    # checking params preemptively passed via url or submitted with form
    if ($params{photo_url}) {
        if (is_valid_photo_url($params{photo_url})) {
            $photo_url_info = parse_photo_url($params{photo_url});
            if ($photo_url_info && $photo_url_info->{photo_id}) {
                if ( my ($p) = MT::Asset::FlickrPhoto->search_by_meta('flickr_photo_id', $photo_url_info->{photo_id}) ) {
                    $params{original_asset_id} = $p->id;
                    $errors{photo_already_exists} = 1;
                }
            }
        }
        else {
            $errors{invalid_photo_url} = 1;
        }
    }

    if ($app->param("submit") && !keys %errors) {
        return unless $app->validate_magic;

        # checking required params
        unless ($photo_url_info) {
            $errors{invalid_photo_url} = 1;
        }
        else {
            # getting photo metadata from flickr
            my ($photo, $photo_user, $photo_info, $photo_sizes);
            my $photo_id = $photo_url_info->{photo_id};

            require Flickr::API2;
            my $api = Flickr::API2->new({
                key    => plugin->get_config_value("api_key"),
                secret => plugin->get_config_value("api_secret"),
            });
            
            eval {
                $photo = $api->photos->by_id($photo_id);
                if ($photo) {
                    $photo_user = $api->people->getInfo($photo->owner_id);
                    $photo_info = $photo->info;
                    $photo_sizes = $photo->sizes;
                }
            };

            if ($@) {
                my $err = error_code_from_flickr_exception($@);

                unless (defined $err) {
                    $errors{api_error} = $@;
                }
                elsif ($err == 1) {
                    $errors{api_error_not_found} = 1;
                }
                elsif ($err == 2) {
                    $errors{api_error_permission_denied} = 1;
                }
                elsif ($err == 100) {
                    $errors{api_error_invalid_key} = 1;
                }
                elsif ($err == 105) {
                    $errors{api_error_service_unavailable} = 1;
                }
                else {
                    $errors{api_error_code} = $err;
                }
            }

            # some extra metadata checks
            unless (keys %errors) {
                unless (ref $photo_info->{photo} && ref $photo_sizes->{size} && ref $photo_user) {
                    $errors{api_error_invalid_photo_info} = 1;
                }
            }

            unless (keys %errors) {
                # everything seems to be just swell, so let's create a new asset
                $photo_info = $photo_info->{photo};
                $photo_sizes = $photo_sizes->{size};

                my $asset = MT::Asset::FlickrPhoto->new;
                $asset->blog_id($app->blog->id);
                $asset->label($photo->title);
                $asset->description($photo->description);
                $asset->modified_by($app->user->id);

                # flickr-specific stuff
                $asset->flickr_photo_id($photo_id);
                $asset->flickr_photo_secret($photo_info->{secret});
                $asset->flickr_photo_server($photo_info->{server});
                $asset->flickr_photo_farm($photo_info->{farm});
                $asset->flickr_photo_user_nsid($photo_user->{nsid});
                $asset->flickr_photo_user_path_alias($photo_user->{path_alias});

                # populating flickr image sizes
                my %sizes = map {
                    $_->{label} => {
                        width  => $_->{width},
                        height => $_->{height},
                    }
                } @$photo_sizes;
                $asset->flickr_photo_sizes(\%sizes);

                $asset->url($asset->flickr_image_url);

                # importing flickr tags
                my @tags = map { $_->{raw} } @{$photo_info->{tags}->{tag}};
                $asset->set_tags(@tags);

                my $original = $asset->clone;
                $asset->save or return $app->error("Couldn't save asset: " . $asset->errstr);
                $app->run_callbacks('cms_post_save.asset', $app, $asset, $original);

                # be nice and return users back to asset insert/listing dialog views
                if ($params{continue_args}) {
                    my $url = $app->uri . '?' . $params{continue_args};
                    $url .= '&no_insert=' . $params{no_insert};
                    $url .= '&dialog_view=1';
                    return $app->redirect($url);
                }

                # otherwise close dialog via js and redirect to the normal
                # asset listing page (seems to be the default mt behavior)
                $params{new_asset_id} = $asset->id;
                $tmpl = plugin->load_tmpl("create_photo_complete.tmpl");
            }
        }
    }

    %params = (%params, %errors, errors => 1) if keys %errors;
    $tmpl ||= plugin->load_tmpl("create_photo.tmpl");
    return $app->build_page($tmpl, \%params);
}

sub edit_asset_source {
    my ($cb, $app, $tmpl) = @_;

    # adding "view page" link
    my $repl_re = '(<a .*?View Asset"><\/a>)';
    my $new = <<NEW;
<mt:if name="class" eq="flickr_photo"><a href="<mt:var name="page_url" escape="html">" style="margin-left: 1em">View Page</a></mt:if>
NEW
    $$tmpl =~ s/$repl_re/$1$new/;

    # show image dimensions
    $repl_re = '<mt:if name="class" eq="image"><mt:var name="image_width"';
    $new = '<mt:if name="class" like="^(image|flickr_photo)$"><mt:var name="image_width"';
    $$tmpl =~ s/$repl_re/$1$new/g;
}

sub asset_list_source {
    my ($cb, $app, $tmpl) = @_;

    if ($app->param('filter_val')) {
        if ($app->param('filter_val') eq 'flickr_photo') {
            # fixing title
            my $replace_re = '<mt:setvarblock name="page_title">.*?setvarblock>';
            my $new = q{<mt:setvarblock name="page_title">Insert Flickr Photo</mt:setvarblock>};
            $$tmpl =~ s/$replace_re/$new/;

            # replacing "Upload New File" with our thingy
            $replace_re = '<mt:setvarblock name="upload_new_file_link">.*?setvarblock>';
            # omg %)
            $new = <<NEW;
<mt:setvarblock name="upload_new_file_link">
<img src="<mt:var name="static_uri">images/status_icons/create.gif" alt="Add Flickr Photo" width="9" height="9" />
<mt:unless name="asset_select"><mt:setvar name="entry_insert" value="1"></mt:unless>
<a href="<mt:var name="script_url">?__mode=flickr_photo_create&amp;blog_id=<mt:var name="blog_id">&amp;no_insert=<mt:var name="no_insert">&amp;dialog_view=1&amp;<mt:if name="asset_select">asset_select=1&amp;<mt:else>entry_insert=1&amp;</mt:if>edit_field=<mt:var name="edit_field" escape="url">&amp;continue_args=<mt:var name="return_args" escape="url">">Add Flickr Photo</a>
</mt:setvarblock>
NEW
            $$tmpl =~ s/$replace_re/$new/s;
            $$tmpl =~ s/phrase="Insert"/phrase="Continue"/;
        }
    }
    else {
        # just appending our "Add Flickr Photo" link on listings with mixed asset types
        my $replace_re = '(<mt:setvarblock name="upload_new_file_link">.*?)(<\/mt:setvarblock>)';
        my $new = <<NEW;
<img src="<mt:var name="static_uri">images/status_icons/create.gif" alt="Add Flickr Photo" width="9" height="9" style="margin-left: 1em" />
<a href="<mt:var name="script_url">?__mode=flickr_photo_create&amp;blog_id=<mt:var name="blog_id">&amp;no_insert=<mt:var name="no_insert">&amp;dialog_view=1&amp;<mt:if name="asset_select">asset_select=1&amp;<mt:else>entry_insert=1&amp;</mt:if>edit_field=<mt:var name="edit_field" escape="url">&amp;continue_args=<mt:var name="return_args" escape="url">">Add Flickr Photo</a>
NEW
        $$tmpl =~ s/$replace_re/$1$new$2/s;
    }
}

sub asset_insert_source {
    my ($cb, $app, $tmpl) = @_;

    # enable thumbnail previews for flickr photos in the entry asset manager
    my $old = '<mt:If tag="AssetType" like="\^\((.+?)\)\$">';
    my $new;
    $$tmpl =~ s/$old/<mt:If tag="AssetType" like="^($1|flickr photo)\$">/g;

    $old = '<mt:If tag="AssetType" eq="image">';
    $new = '<mt:If tag="AssetType" like="^(image|flickr photo)$">';
    $$tmpl =~ s/\Q$old\E/$new/g;
}

sub edit_entry_param {
    my ($cb, $app, $param, $tmpl) = @_;

    # enable thumbnail previews for flickr photos in the entry asset manager
    if (ref $param->{asset_loop}) {
        for my $p (@{$param->{asset_loop}}) {
            my $asset = MT::Asset->load($p->{asset_id});
            if ($asset->class eq 'flickr_photo') {
                ($p->{asset_thumb}) = $asset->thumbnail_url(Width => 100);
            }
        }
    }
}

sub editor_source {
    my ($cb, $app, $tmpl) = @_;

    # adding some css
    $$tmpl .= q{
        <mt:setvarblock name="html_head" append="1">
        <link rel="stylesheet" type="text/css" href="<mt:var name="static_uri">plugins/FlickrAssets/editor.css" />
        </mt:setvarblock>
    };

    # adding insert photo toolbar button
    my $insert_image_button_re = '<a.*?<b>Insert Image<\/b>.*?<\/a>';
    my $new_button = '<a href="javascript: void 0;" title="Insert Flickr Photo" mt:command="open-dialog" mt:dialog-params="__mode=list_assets&amp;_type=asset&amp;edit_field=<mt:var name="toolbar_edit_field">&amp;blog_id=<mt:var name="blog_id">&amp;dialog_view=1&amp;filter=class&amp;filter_val=flickr_photo" class="command-insert-flickr-photo toolbar button"><b>Insert Flickr Photo</b><s></s></a>';
    $$tmpl =~ s/($insert_image_button_re)/$1$new_button/;
}

1;
