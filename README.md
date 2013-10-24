---
title: Banner Images with Hakyll
tags: howto, hakyll, images, imagemagick, haskell
excerpt: 
  This post demonstrates one approach to associate banner images with posts in
  a Hakyll site, produce multiple versions of them with ImageMagick, and use
  them in templates.
---

This repository contains a small "proof of concept" site built with the
[Hakyll][] static site generator. It demonstrates a technique which allows a
developer to associate a "banner" image with each post in their site. The
generated site will contain several versions of each image in different sizes,
etc.

[Hakyll]: http://hackage.haskell.org/package/hakyll

Each post in the site is represented by a directory containing an `index.md`
Markdown file and, optionally, a `banner.png` image file. This repository
contains two posts, one with and one without an image:

    posts/2013-10-23-post-without-banner/index.md
    posts/2013-10-24-post-with-banner/banner.png
    posts/2013-10-24-post-with-banner/index.md

The `site.hs` Haskell program contains only the most basic Hakyll directives to
process the Markdown files (indeed, I haven't even bothered to override the
date code; you'll need to put the date in the Markdown file metadata). In
addition, it contains the proof-of-concept code to handle the banner images.

The `imageProcessor` function is a helper to construct the Hakyll `Rules ()` to
process a set of banner images and the `Context a` allowing them to be used in
the associated posts and templates. This function takes a `Pattern` which
matches the banner images and a list describing the different versions to
generate of each image.

````{.haskell}
let (postImages, postImageField) = imageProcessor "posts/*/banner.png"
                                     [ ("small" , Just (200,100))
                                     , ("medium", Just (600,300))
                                     , ("full"  , Nothing)
                                     ]
````

The first argument to `imageProcessor` is the pattern identifying the image to
be processed. This pattern *must* end in a full filename. The second argument
is a list of versions to create. Each version has a name (the `String`) and
image processing instructions (`Nothing` to copy the image, `Just (x,y)` to
scale and crop the image to the given dimensions using ImageMagick's `convert`
command). This generates a `Rules ()` value to process the images (`postImages`
in the code) and a `Context a` to make them available in posts and templates.

The `Rules ()` value can be "run" just like any `create` or `match` statement
and the `Context a` value can be used in the context of post with a path that
matches the image pattern (ignoring the filename). This context defines one
variable for each of the image versions being generated. In this code, the
variables are:

- `banner-small` is a 200x100 image.
- `banner-medium` is a 600x300 image.
- `banner-full` is the original image.

These names are generated from the filename `banner.png` in the image pattern
(this is why the pattern must have a filename) and the name of each version.

