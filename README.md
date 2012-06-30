# Flickr Assets

Flickr Assets is a Movable Type plugin that allows users to import and use Flickr photos as image assets in the Movable Type Asset Manager.  It is part of the SuperAssets series of plugins from After6 Services LLC.

# Installation

After downloading and uncompressing this package:

1. Upload the entire FlickrAssets directory within the plugins directory of this distribution to the corresponding plugins directory within the Movable Type installation directory.
    * UNIX example:
        * Copy mt-plugin-flickr-assets/plugins/FlickrAssets/ into /var/wwww/cgi-bin/mt/plugins/.
    * Windows example:
        * Copy mt-plugin-flickr-assets/plugins/FlickrAssets/ into C:\webroot\mt-cgi\plugins\ .
2. Upload the entire FlickrAssets directory within the mt-static directory of this distribution to the corresponding mt-static/plugins directory that your instance of Movable Type is configured to use.  Refer to the StaticWebPath configuration directive within your mt-config.cgi file for the location of the mt-static directory.
    * UNIX example: If the StaticWebPath configuration directive in mt-config.cgi is: **StaticWebPath  /var/www/html/mt-static/**,
        * Copy mt-plugin-flickr-assets/mt-static/plugins/FlickrAssets/ into /var/www/html/mt-static/plugins/.
    * Windows example: If the StaticWebPath configuration directive in mt-config.cgi is: **StaticWebPath D:/htdocs/mt-static/**,
        * Copy mt-plugin-flickr-assets/mt-static/plugins/FlickrAssets/ into D:/htdocs/mt-static/.

# Configuration

Flickr Assets requires a Flickr API key in order to operate on images stored on Flickr.com.

After completely installing Flickr Assets:

1. Obtain a Flickr API key for use with this Movable Type instance by following the instructions at [http://www.flickr.com/services/api/keys/](http://www.flickr.com/services/api/keys/).
2. Visit the System Plugin Settings page at ~/mt/mt.cgi?__mode=cfg_plugins for your Movable Type instance.
3. Click on the plugin name "Flickr Assets" in the "Individual Plugins" section.
4. Click on the link labeled "Settings" to expose the Flickr Assets plugin settings pane.
5. Enter the API Key that you received from Flickr in the "API Key" field.
6. Enter the API Secret that you received from Flickr in the "API Secret" field.  The API Secret should be kept confidential and not shared with anyone who is not a System Administrator for this Movable Type instance.
7. Click the "Save Changes" button.

# Usage

## Template Tags

### Overview

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

    <mt:Assets type="flickr_photo" lastn="1">
    ...
    </mt:Assets>

### Properties

There are a few extra asset properties accessible in templates:

* *flickr_photo_id* - external photo id
* *flickr_photo_user_nsid* - external photo owner's id
* *flickr_photo_user_path_alias* - external photo owner's alias

    <mt:AssetProperty property="flickr_photo_id">

### Thumbnails

Each photo is typically available in multiple sizes that are created and managed by the Flickr service, so this plugin does not handle or scale images internally.

Template designers can use standard Movable Type's tag *AssetThumbnailURL* to get image URLs as usual. In addition to *width* and *height* attributes, the plugin allows to set a Flickr image version explicitly via the *size* attribute:

    <img src="<mt:AssetThumbnailURL width="500">" width="<mt:FlickrPhotoWidth width="500">" ... />
 
    <img src="<mt:AssetThumbnailURL size="Medium 800">" width="<mt:FlickrPhotoWidth size="Medium 800">" height="<mt:FlickrPhotoHeight size="Medium 800">" ... />

The plugin will find the best-fitting image version available for a photo in cases when requested image with exact dimensions or size name doesn't exist.

### Flickr photo sizes

    Name         | Suffix | Size, px
    -------------+--------+---------
    Square       | s      | 75       
    Large Square | q      | 150      
    Thumbnail    | t      | 100      
    Small        | m      | 240      
    Small 320    | n      | 320      
    Medium       | ''     | 500      
    Medium 640   | z      | 640      
    Medium 800   | c      | 800      
    Large        | b      | 1024     

See the [Flickr Services](http://www.flickr.com/services/api/misc.urls.html) information page in the [Flickr App Garden](http://www.flickr.com/services/) for more information about photo source URLs, size suffixes, webpage URLs, and a number of other useful details about Flickr.

Template tag *AssetThumbnailURL* and tags provided by this plugin accept both name and letter suffix as *size* attribute.

The default size is *Medium 640*.

### Tag *FlickrPhotoWidth*

Returns width of a photo asset in template context. Accepts attributes *size* or *width* and/or *height* just like the *AssetThumbnailURL* tag.

### Tag *FlickrPhotoHeight*
2
Returns height of a photo asset in template context. Accepts attributes *size* or *width* and/or *height* just like the *AssetThumbnailURL* tag.

### Tag *FlickrPhotoPage*

Returns URL of the Flickr page for a photo asset in template context. Accepts attributes *size* or *width* and/or *height* just like the *AssetThumbnailURL* tag.

# Support

This plugin has not been tested with any version of Movable Type prior to Movable Type 4.38.

Although After6 Services LLC has developed this plugin, After6 only provides support for this plugin as part of a Movable Type support agreement that references this plugin by name.

# License

This plugin is licensed under The BSD 2-Clause License, http://www.opensource.org/licenses/bsd-license.php.  See LICENSE.md for the exact license.

# Authorship

Flickr Assets was originally written by Arseni Mouchinski with help from Dave Aiello and Jeremy King.

# Copyright

Copyright &copy; 2012, After6 Services LLC.  All Rights Reserved.

Flickr is a registered trademark of Yahoo! Inc.

SuperAssets is a trademark of After6 Services LLC.

Movable Type is a registered trademark of Six Apart Limited.

Trademarks, product names, company names, or logos used in connection with this repository are the property of their respective owners and references do not imply any endorsement, sponsorship, or affiliation with After6 Services LLC unless otherwise specified.
