#!/usr/bin/env python3
"""Generate index.html from feeds.yaml."""
import os
import yaml

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.dirname(SCRIPT_DIR)


def describe_filter(f):
    ft = f['filter']
    cfg = f.get('config', {})
    if ft == 'duration':
        op = cfg.get('operator', 'lessThan')
        for unit in ('hours', 'minutes', 'seconds'):
            if unit in cfg:
                word = 'under' if op == 'lessThan' else 'over'
                return f'Episodes {word} {cfg[unit]} {unit} removed'
    elif ft == 'regex':
        action = cfg.get('action', 'exclude')
        pattern = cfg.get('pattern', '')
        if action == 'exclude':
            return f'Episodes matching “{pattern}” removed'
        return f'Only episodes matching “{pattern}” kept'
    return f'{ft} filter applied'


def describe_fiddle(f):
    ft = f['fiddle']
    cfg = f.get('config', {})
    if ft == 'append_to_title':
        return f'Feed title suffixed with “{cfg.get("string", "")}”'
    if ft == 'replace_title':
        return f'Feed title replaced with “{cfg.get("title", "")}”'
    if ft == 'replace_feed_image':
        return 'Feed artwork replaced'
    return None


def load_feeds():
    with open(os.path.join(PROJECT_ROOT, 'feeds.yaml')) as fh:
        config = yaml.safe_load(fh)

    feeds = []
    for feed in config.get('feeds', []):
        s3 = feed.get('output', {}).get('s3')
        if not s3:
            continue
        url = f"https://{s3['bucket']}.s3.amazonaws.com/{s3['object']}"
        notes = []
        for filt in feed.get('filters', []):
            notes.append(describe_filter(filt))
        for fiddle in feed.get('fiddles', []):
            desc = describe_fiddle(fiddle)
            if desc:
                notes.append(desc)
        feeds.append({'name': feed['name'], 'url': url, 'notes': notes})
    return feeds


def render_html(feeds):
    cards = ''
    for feed in feeds:
        notes_html = ''
        if feed['notes']:
            items = ''.join(f'<li>{n}</li>' for n in feed['notes'])
            notes_html = f'<ul class="notes">{items}</ul>'
        cards += f'''
  <article class="card">
    <h2>{feed["name"]}</h2>
    {notes_html}
    <div class="url-row">
      <input class="url" type="text" value="{feed["url"]}" readonly>
      <button class="copy" onclick="copy(this)">Copy</button>
      <a class="rss-btn" href="{feed["url"]}" title="Subscribe in podcast app"><svg viewBox="0 0 24 24" width="16" height="16" aria-hidden="true"><circle cx="5" cy="19" r="2.5"/><path d="M4 4a16 16 0 0 1 16 16h-3A13 13 0 0 0 4 7V4z"/><path d="M4 11a9 9 0 0 1 9 9h-3a6 6 0 0 0-6-6v-3z"/></svg> Subscribe</a>
    </div>
  </article>'''

    return f'''<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Feed Fiddler</title>
  <link rel="icon" href="icon.png" type="image/png">
  <link rel="apple-touch-icon" href="icon.png">
  <style>
    *, *::before, *::after {{ box-sizing: border-box; margin: 0; padding: 0; }}
    body {{
      font-family: system-ui, -apple-system, sans-serif;
      background: #f0f0f0;
      color: #222;
      padding: 2rem 1rem;
    }}
    header {{
      max-width: 680px;
      margin: 0 auto 1.5rem;
      display: flex;
      align-items: center;
      gap: 0.9rem;
    }}
    .logo {{ width: 56px; height: 56px; border-radius: 10px; flex-shrink: 0; }}
    h1 {{ font-size: 1.75rem; }}
    header p {{ color: #666; margin-top: 0.25rem; font-size: 0.95rem; }}
    header a {{ color: #666; }}
    .card {{
      max-width: 680px;
      margin: 0 auto 1rem;
      background: #fff;
      border-radius: 8px;
      padding: 1.25rem 1.5rem;
      box-shadow: 0 1px 3px rgba(0,0,0,.08);
    }}
    h2 {{ font-size: 1.05rem; text-transform: capitalize; margin-bottom: 0.5rem; }}
    .notes {{
      font-size: 0.875rem;
      color: #555;
      padding-left: 1.2rem;
      margin-bottom: 0.75rem;
    }}
    .notes li {{ margin-bottom: 0.15rem; }}
    .url-row {{ display: flex; gap: 0.5rem; }}
    .url {{
      flex: 1;
      font-family: monospace;
      font-size: 0.825rem;
      padding: 0.4rem 0.6rem;
      border: 1px solid #ddd;
      border-radius: 4px;
      background: #fafafa;
      color: #333;
      min-width: 0;
    }}
    .copy {{
      padding: 0.4rem 0.8rem;
      background: #0066cc;
      color: #fff;
      border: none;
      border-radius: 4px;
      cursor: pointer;
      font-size: 0.85rem;
      white-space: nowrap;
    }}
    .copy:hover {{ background: #0052a3; }}
    .copy.done {{ background: #2a9d2a; }}
    .rss-btn {{
      display: inline-flex;
      align-items: center;
      gap: 0.3rem;
      padding: 0.4rem 0.8rem;
      background: #ee802f;
      color: #fff;
      border-radius: 4px;
      text-decoration: none;
      font-size: 0.85rem;
      white-space: nowrap;
      fill: currentColor;
    }}
    .rss-btn:hover {{ background: #d06a1e; }}
  </style>
</head>
<body>
  <header>
    <img class="logo" src="icon.png" alt="">
    <div>
      <h1>Feed Fiddler</h1>
      <p>Custom podcast feeds &mdash; filtered and fiddled.</p>
      <p>Want a new one? <a href="https://github.com/bigreds/feed-fiddler/issues">Open an issue on GitHub.</a></p>
    </div>
  </header>
{cards}
  <script>
    function copy(btn) {{
      navigator.clipboard.writeText(btn.previousElementSibling.value).then(() => {{
        btn.textContent = 'Copied!';
        btn.classList.add('done');
        setTimeout(() => {{ btn.textContent = 'Copy'; btn.classList.remove('done'); }}, 2000);
      }});
    }}
  </script>
</body>
</html>
'''


def main():
    feeds = load_feeds()
    html = render_html(feeds)
    out = os.path.join(SCRIPT_DIR, 'index.html')
    with open(out, 'w', encoding='utf-8') as fh:
        fh.write(html)
    print(f'Written {out}')


if __name__ == '__main__':
    main()
