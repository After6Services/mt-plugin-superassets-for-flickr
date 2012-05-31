#!/usr/bin/perl -w

##########
#
# Copyright (C) 2012, After6 Services LLC. All Rights Reserved.
# This code cannot be redistributed without permission from http://www.after6services.com/.
# For more information, consult your agreement with After6 Services.
#
##########

package MT::Tool::Convert_Custom_Field_Flickr_Photos;
use strict;

use lib qw( extlib lib );
use base qw( MT::Tool );
use Carp qw(confess);
use MT;
use MT::Entry;
use MT::Category;
use MT::Placement;
require Flickr::API2;

sub usage { '[--customfield <your-custom-field>] [--blog_id <id>] [--author <name>]' }

sub help {
    return q{
        Converts all of the flickr photos contained in a specific custom field into image assets managed by the Asset Manager.

        --customfield <your-custom-field>           Custom field basename from which Flickr photos are to be taken.  Examples: page_social_media_flickr_url,
                                                    category_social_media_flickr_url.
                                                    
        --blog_id <id>                              Process all assets in the listed blog ID.
        --api-key <key>                             The Flickr API key to enable processing.
        --api-secret <secret>                       The secret corresponding to the Flickr API key.
        --author                                    Username of an author with System Administrator privileges.
    };
}

##########
#
# Default options
#
##########

my ($customfield);
my $all = 0;
my $blog_id = 1;
my $api_key = '';
my $api_secret = '';
my $author = '';

############
#
# This function is called from the base object (MT::Tool) to pick up the command line options in this tool script.
#
############

sub options {
    return (
      'customfield=s'   =>      \$customfield,
      'blog_id=s'       =>      \$blog_id,
      'api_key=s'       =>      \$api_key,
      'api_secret=s'    =>      \$api_secret,
      'author=s'        =>      \$author
    );
}

sub main {
    
    ############
    #
    # Invoke the base object's main method
    #
    ############

    my $class = shift;
    my ($verbose) = $class->SUPER::main(@_);
    
    ############
    #
    # Tell what this tool script does
    #
    ############

    print "\nconvert-custom-field-flickr-photos -- Converts all of the flickr photos contained in a specific custom field into image assets managed by the Asset Manager.\n\n";
   
    unless ($author) {
        print "Please set --author to the Username for a System Administrator who is disassociating entries from a category.  ie: convert-custom-field-flickr-photos ... --author Melody\n";
        exit;
    }
    
    unless ($customfield) {
        print "Please set --customfield to the basename of a custom field from which Flickr photos are to be taken.";
        print "ie: convert-custom-field-flickr-photos ... --customfield page_social_media_flickr_url\n";
        exit;
    }
    
    unless ($api_key) {
        print "Please set --api_key to the The Flickr API key to enable processing.";
        print "ie: convert-custom-field-flickr-photos ... --api_key an2example2flickr2api2key2\n";
        exit;    
    }
        
    unless ($api_secret) {
        print "Please set --api_secret to the The Flickr secret corresponding to the API Key.";
        print "ie: convert-custom-field-flickr-photos ... --api_secret s00p3rs3cr3t\n";
        exit;    
    }
    
    my $api = Flickr::API2->new({
                key    => $api_key,
                secret => $api_secret
            });
            
    my $api_response = $api->execute_method( 'flickr.test.echo' );
    
    if ($api_response =~ qr/Invalid API Key/i)
    {
        print $api_response . "  Please try again.";
        exit;
    }

    my $mt = MT->instance();
    
    ##########
    #
    # Look up the author
    #
    ##########

    my $author_id;
    if ($author) {
        require MT::BasicAuthor;
        my $a = MT::BasicAuthor->load({name => $author})
            or die "The user $author is not found:" . MT::BasicAuthor->errstr;
        $author_id = $a->id;
        
        ##########
        #
        # See if the author that was chosen is a System Administrator on this MT instance.
        #
        ##########
        
        unless ($a->is_superuser) {
            print "$author is not an author with System Administrator rights in this MT instance.\n";
            exit;
        }
        
    }
    
    ##########
    #
    # Load the blogs that you want to operate on.
    #
    ##########

    my ($iter, $entry_iter);
    #$MT::DebugMode = 7;
    
    $iter = MT::Blog->load_iter( { id => $blog_id });
        
    my $count;
    
    my (@cats, $parent, $cat, $cat_depth, $existing_category);
    
    ##########
    #
    # Iterate through the selected blogs.
    #
    ##########
    
    while ( my $blog = $iter->() ) {
        
        ##########
        #
        # Look up the category that is supposed to be disassociated with each entry.
        #
        ##########
        
        @cats = split( /\:\:/, $customfield );
        
        # $parent is set to 0 at this stage because this is either the only category label
        # or the first category label in a hierarchy that's being processed.
        
        # $cat_depth represents the place in the Category label hierarchy we are currently processing.
        # If $cat_depth == $#cats, then the category belongs in the $place_hash shown below.
        my $parent = 0;
        my $cat_depth = 0;
        
        foreach my $cat_label (@cats) {
            $cat_label =~ s/\+/ /igs;
            
            # If $parent is not set, attempt to load the Category according to its label.
            # If $parent is set, attempt to load the Category according to its label as a subcategory of $parent->id.
            if ($parent == 0) {
                $existing_category = MT::Category->load( { blog_id => $blog->id, label => $cat_label } );
            } else {
                $existing_category = MT::Category->load( { blog_id => $blog->id, label => $cat_label, parent => $parent->id } );
            }
            
            # If the Category exists already, assign it to $cat, otherwise there is a problem and we need to report it to the user.
            if ($existing_category) {
                $cat = $existing_category;
            } else {
                
                $cat = 0;
                
                print "Warning: There is no category labeled '$cat_label' ";
                print "with parent '", $parent->label, "'" if $parent != 0;
                print "in the blog called '", $blog->name, "'.\n";
            }
            
            $parent = $cat;
            $cat_depth++;

        }
        
        # When we hit the bottom of the $cat_label loop, $cat is the category whose association needs to be removed.  Make sure $cat exists
        
        if ($cat != 0) {
            
            print "Disassociating all entries from category ", $cat->label, ".\n";
            
            MT::Placement->remove({ category_id => $cat->id });
            
        }
        
        print "Looking for entries in ", $blog->name , " that have no primary category.\n";
        
        $entry_iter = MT::Entry->load_iter( { blog_id => $blog->id } );
        
        while ( my $entry = $entry_iter->() ) {
            my $primary_count = MT::Placement->count({ entry_id => $entry->id,
                                                        is_primary => '1' });
            
            if ($primary_count == 0) {
                
                print "Found no primary category for ", $entry->title, ".  Trying to designate one.\n";
                
                my $new_primary_category = MT::Placement->load( { entry_id => $entry->id },
                                                                { 'sort' => 'id',
                                                                    'direction' => 'ascend',
                                                                    limit => '1' });
                
                if ($new_primary_category) {
                    $new_primary_category->is_primary('1');
                    $new_primary_category->save;
                }
            }
            
            
        }

    $count++;

    }
    
##########
#
# Script finishes up here.
#
##########

print "\nremove-category-association complete!\n\n";
}

##########
#
# Invoke main subroutine to start the script.
#
##########

__PACKAGE__->main() unless caller;

1;
