# Feed Fiddler

For fiddling with podcast feeds.

This was inspired by my wanting to be able to filter out some episodes from podcast feeds.

It's designed to be run periodically, where it'll fetch all the feeds it is to fiddle with, do the fiddling, and then write out an rss file, ideally to somewhere you can configure your podcast app to download it from.

## Config

Configuring is in the `feeds.yaml` file, where a list of feeds is defined, each with a list of filters. The path to this file can be set with the env var `CONFIG_FILE`

More Or Less is a show on Radio 4 about numbers. The BBC World Service puts out a 9 minute excerpt, too. Their podcast feed is mede up of both the R4 and the World Service transmissions, which means each short episode is just a repeat of a part of a longer episode. Here, we filter out those short repeats:

```
feeds:
  - name: more or less
    feed_url: https://podcasts.files.bbci.co.uk/p02nrss1.rss
    file_name: moreorless.rss
    filters:
    - filter: duration
      config:
        minutes: 10
        operator: lessThan
    fiddles:
    - fiddle: append_to_title
      config:
        string: "[fiddled]"
```


Richard Herring's Leicester Square Theatre Podcast is a show where he interviews comedians. There's a series where he interviews them about their books, none of which I have read. This config removes the Book Club episodes:

```
  - name: rhlstp
    feed_url: https://access.acast.com/rss/aacb15fc-f2a9-43e6-9d0f-521463063cef/
    file_name: rhlstp.rss
    filters:
    - filter: regex_exclude
      config:
        field: title
        pattern: '^RHLSTP Book Club'
    fiddles:
    - fiddle: append_to_title
      config:
        string: "[fiddled]"
```

For each of these, 'name' is an arbitrary string of your choosing, only currently used in logs, the `feed_url` is the URL to the RSS feed, and then `filters` is an array of filter definitions.

## Filters

A filter is a function that accepts two arguments, `episode` is a dictionary of the fields from the entry in the channel, and `config` is the config block from the feeds.yaml.

There are currently two filters:

* `duration` Removes episodes based on the duration

The `config` blog has two keys. One is one of `seconds`, `minutes` or `hours`, setting the length to use as a threshold. The other is the `operator` key, one of `lessThan`, `lessThanOrEqualTo`, `greaterThan`, `greaterThanOrEqualTo`, `equalTo`, `notEqualTo`.

For each episode with a `duration` field, the `duration` is compared with the threshold; those matching it are filtered out. Episodes without a `duration` field are always kept.

* `regex_exclude` Removes episodes where a field matches a regex.

The `config` block has a `field` and a `pattern` argument; if the `field` of an episode is matched by the `pattern`, that episode is dropped from the feed.

## Fiddles

A fiddle is a function that accepts to arguments, 'feed' is the parsed feed, and 'config is the config block from the feeds.yaml

* `append_to_title` appends a string to the title of the podcast

* `feed_image` sets a different image URL
