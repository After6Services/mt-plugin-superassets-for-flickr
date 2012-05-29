# Flickr Assets

Flickr Assets is a Movable Type plugin that allows to import and use Flickr photos as native assets.

# Template Tags

## Overview

Flickr photos work just like other Movable Type's assets and can be accessed via tags *Asset*, *Assets*, *EntryAssets* and *PageAssets*:

    <mt:EntryAssets>
    <mt:if tag="AssetType" eq="flickr_photo">
        <div>
        <strong><mt:AssetLabel escape="html"></strong>
        <p><mt:AssetDescription escape="html"></p>
        <a href="<mt:FlickrPhotoPage>">
        <img src="<mt:AssetThumbnailURL width="500">" width="<mt:FlickrPhotoWidth width="500">" height="<mt:FlickrPhotoHeight="500">" alt="<mt:AssetLabel escape="html">" />
        </a>
        </div>
    </mt:if>
    </mt:EntryAssets>

Photos can also be filtered by class name:

    <mt:Assets class="flickr_photo" lastn="1">
    ...
    </mt:Assets>

## Properties

There are a few extra asset properties accessible in templates:

* *flickr_photo_id* - external photo id
* *flickr_photo_user_nsid* - external photo owner's id
* *flickr_photo_user_path_alias* - external photo owner's alias

    <mt:AssetProperty property="flickr_photo_id">

## Thumbnails

Each photo is typically available in multiple sizes that are created and managed by the Flickr service, so this plugin does not handle or scale images internally.

Template designers can use standard Movable Type's tag *AssetThumbnailURL* to get image URLs as usual. In addition to *width* and *height* attributes, the plugin allows to set a Flickr image version explicitly via the *size* attribute:

    <img src="<mt:AssetThumbnailURL width="500">" width="<mt:FlickrPhotoWidth width="500">" ... />
 
    <img src="<mt:AssetThumbnailURL size="Medium 800">" width="<mt:FlickrPhotoWidth size="Medium 800">" height="<mt:FlickrPhotoHeight size="Medium 800">" ... />

The plugin will find the best-fitting image version available for a photo in cases when requested image with exact dimensions or size name doesn't exist.

## Flickr photo sizes

    | Name         | Suffix | Size, px. |
    | Square       | s      | 75        |
    | Large Square | q      | 150       |
    | Thumbnail    | t      | 100       |
    | Small        | m      | 240       |
    | Small 320    | n      | 320       |
    | Medium       | ''     | 500       |
    | Medium 640   | z      | 640       |
    | Medium 800   | c      | 800       |
    | Large        | b      | 1024      |

See [this doc](http://www.flickr.com/services/api/misc.urls.html) for more details.

Template tag *AssetThumbnailURL* and tags provided by this plugin accept both name and letter suffix as *size* attribute.

The default size is *Medium 640*.

## Tag *FlickrPhotoWidth*

Returns width of a photo asset in template context. Accepts attributes *size* or *width* and/or *height* just like the *AssetThumbnailURL* tag.

## Tag *FlickrPhotoHeight*

Returns height of a photo asset in template context. Accepts attributes *size* or *width* and/or *height* just like the *AssetThumbnailURL* tag.

## Tag *FlickrPhotoPage*

Returns URL of the Flickr page for a photo asset in template context. Accepts attributes *size* or *width* and/or *height* just like the *AssetThumbnailURL* tag.
