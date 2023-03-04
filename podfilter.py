#! /usr/bin/env python
import os
import feedparser
import yaml
import logging
import re

import xml.etree.ElementTree as ET
import urllib.request

import json


def filter_rss_feed(url):

    response = urllib.request.urlopen(url)
    data = response.read();
    rss = data.decode('utf-8')

    root = ET.fromstring(rss)

    #for item in root.findall('./channel/item'):
    channel = root.find('channel')
    for item in root.iter(tag='item'):
        episode = {}
        for field in item.findall('./'):
            tag=re.sub('{\S+}', '', field.tag)
            if tag in episode:
               logging.error(f"Tag '{tag}' already defined (as '{episode['tag']}') in feed")
            episode[tag] = field.text

        keep = 1
        for filter in feed['filters']:
            keep = filter_dispatch[filter['filter']]( episode, filter['config'] )
            if keep < 1:
               logging.info(f"Removing '{episode['guid']}'")
               channel.remove(item)
               #root.remove( root.findall(""))

    return root

# Filter out episodes that are too short. This was triggered by the More or Less
# podcast where the World Service programme is a ~9min excerpt from the Radio 4
# one, and both are on the same feed
#
# Expects a single key in the config, one of 'minutes', 'seconds' or 'hours' and
# filters out any episode whose 'duration' field is shorter than that
def filter_shorter_than(episode, config):

    logging.debug(f"Running shorter_than filter on '{episode['title']}' with config '{config}'");
    duration_seconds = -1
    if 'seconds' in config:
      duration_seconds = int(config['seconds'])
    elif 'minutes' in config:
      duration_seconds = int(config['minutes']) * 60
    elif 'hours' in config:
      duration_seconds = int(config['hours']) * 60 * 60

    if duration_seconds < 0:
        logging.debug("Could not parse duration out of value; aborting filter")
        logging.debug(f"Value: {config}")
        return 1

    #TODO: Find other ways duration might be encoded
    if 'duration' in episode:
        episode_duration = int(episode['duration'])
        if episode_duration < duration_seconds:
            logging.info(f"Filtering out '{episode['title']}'; duration of '{episode['duration']}' shorter than filter value of '{duration_seconds}' seconds)")
            return 0
    else:
        logging.info(f"Retaining '{episode['title']}'; it has no 'itunes duration' field");
        return 0

    logging.debug(f"Retaining '{episode['title']}'; duration of '{episode['duration']}' greater than or equal to filter value of '{duration_seconds}' seconds ")
    return 1

# Filter out episodes with particular phrases in the fields. This was triggered by a
# few series doing a set of 'Book Club' episodes that are all about books I haven't read
#
# Config should have two keys, a 'pattern', and a 'field' to apply it to, and optionally
# a 'case_insensitive' which, if set, will cause the match to be case-insensitive
def filter_regex_exclude(episode, config):
    logging.debug(f"Running regex_exclude filter on '{episode['title']}' with config '{config}'")

    field_name = config['field']
    pattern = config['pattern']

    if re.search( pattern, episode[field_name] ):
        logging.info(f"Filtering out '{episode['title']}'; field '{field_name}' matches pattern '{pattern}'");
        logging.debug(f"Field '{field_name}': {episode[field_name]}' ")
        return 0

    logging.debug(f"Retaining '{episode['title']}'; field '{field_name}' does not match pattern '{pattern}'");
    return 1


filter_dispatch = {
    'regex_exclude': filter_regex_exclude,
    'shorter_than': filter_shorter_than,
}

# # #
# #
#
logging.basicConfig(encoding='utf-8', level=logging.INFO)
if os.environ['LOGLEVEL']:
    logging.getLogger().setLevel(os.environ['LOGLEVEL'])

config_file = './feeds.yaml'
config = {}

with open(config_file, "r") as file:
  try:
      config = yaml.safe_load(file)
  except yaml.YAMLError as err:
      print(err)

for feed in config['feeds']:
    logging.info(f"Processing feed '{feed['name']}' from '{feed['feed_url']}'")
    root = filter_rss_feed( feed['feed_url'])
    with open(feed['file_name'], "w") as f:
        print(ET.tostring(root, encoding='unicode', method='xml'), file=f)
