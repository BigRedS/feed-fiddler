# Feed Fiddler

For fiddling with podcast feeds.

This was inspired by my wanting to be able to filter out some episodes from podcast feeds. It's a way of creating a new feed based on some modifications to an existing one.

It's designed to be run periodically, where it'll fetch all the feeds it is to fiddle with, do the fiddling, and then write out an rss file, hopefully to somewhere you can configure your podcast app to download it from.

## Config

Configuration is in the `feeds.yaml` file, where a list of feeds is defined, each of which has a series of configurations. Some examples:

More Or Less is a show on Radio 4 about numbers. The BBC World Service puts out a 9 minute excerpt, too. Their podcast feed is mede up of both the R4 and the World Service transmissions, which means each short episode is just a repeat of a part of a longer episode. Here, we filter out those short repeats and create a file in /var/www/html:

```
feeds:
  - name: more or less
    feed_url: https://podcasts.files.bbci.co.uk/p02nrss1.rss
    fiddles:
    - fiddle: append_to_title
      config:
        string: "[fiddled]"
    filters:
    - filter: duration
      config:
        minutes: 10
        operator: lessThan
    output:
      file:
        file_path: /var/www/html/moreorless.rss
```


Richard Herring's Leicester Square Theatre Podcast is a show where he interviews comedians. There's a series where he interviews them about their books. Here, we split that feed into a Book Club feed, and a 'normal' feed without those Book Club episodes:

```
feeds:
  - name: rhlstp
    feed_url: https://access.acast.com/rss/aacb15fc-f2a9-43e6-9d0f-521463063cef/
    filters:
    - filter: regex
      config:
        field: title
        pattern: '^RHLSTP Book Club'
        action: exclude
    outputs:
      s3:
        bucket: my-custom-feeds
        object: rhlstp.rss

  - name: rhlstp-books
    feed_url: https://access.acast.com/rss/aacb15fc-f2a9-43e6-9d0f-521463063cef/
    fiddles:
    - fiddle: append_to_title
      config:
        string: "Book Club"
    filters:
    - filter: regex
      config:
        field: title
        pattern: '^RHLSTP Book Club'
        action: include
    outputs:
      s3:
        bucket: my-custom-feeds
        object: rhlstp-book-club.rss
```

Each feed has a `name`, an arbitrary string of your choosing only used in log output, a `feed_url` to set where to get the feed from, a list of `fiddles` which define changes to make to the feed, a list of `filters` which define ways of removing episodes from the feed, and a list of `outputs` which defines where to put the resulting feed.

The environment variable `CONFIG_FILE` can be set to point to this file; `./feeds.yaml` is read by default

## Filters

`filter`s are used to remove episodes from feeds. Each filter has a `config` block that is used to configure that filter:

There are currently two filters:

### `duration` Filters episodes based on their duration

The config block has two keys:

* `seconds`, `minutes`, or `hours`: the episode duration (as an integer) to use as a threshold
* `operator`: one of `lessThan`, `lessThanOrEqualTo`, `greaterThan`, `greaterThanOrEqualTo`, `equalTo`, `notEqualTo`.

For each episode with a `duration` field, the `duration` is compared with the threshold; those matching it are filtered out. Episodes without a `duration` field are always kept.

### `regex` Filters episodes where a field matches a regex.

The config block has three keys:
* `field`: the name of the field to match ('title' is a common one)
* `pattern`: a regex to match the field's contents with
* `action`: one of `exclude` or `include`; whether the resulting feed should have nothing that matches, or only those episodes that match, respectively.

## Fiddles

`Fiddles` make modifications to the feed, they each have a config block:

### `append_to_title` appends a string to the title of the podcast

The config block has one key:

* `string`,  a string to append to the podcast title. There will be a single space between the original title and this append string

### `feed_image` sets a different image URL

The config block has one key:

* `url`: the URL to insert into the feed as its image. No checking is performed of the validity of this URL.

## Outputs

An RSS feed is created at the end of this, what happens with it is defined in the 'outputs' array of the feed.

There are currently two options, each may be set multiple times to have the same feed written to ddifferent places:

### `file` writes out a local file

It should have one element, a path:
```
output:
  file:
    file_path: /var/www/podcasts/myfeed.rss
```

### `s3` puts the feed in an S3 bucket.

It should have two elements, a bucket name and an object name:

```
output:
  s3:
    object: myfeed.rss
    bucket: mybucketname
```

feed-fiddler sets a public-read ACL on the uploaded object, so the bucket must allow the setting of ACLs on objects

# Testing

When testing changes, you can pass the `name` of a feed (or a list of them) as arguments to cause only those to be processed.

Some environment variables are supported:

* `FF_FEED_TO_STDOUT` being set to anything causes feed-fiddler to ignore the feed-writing config, and write each feed to STDOUT
* `FF_NO_WRITE_FEED` being set to anything causes feed-fiddler to just discard the created feeds, not writing the anywhere. This overrides FF_FEED_TO_STDOUT.
* `LOGLEVEL` is provided by the `logging` library; set this to `DEBUG` to get a lot of output from the filtering and fiddling processes
