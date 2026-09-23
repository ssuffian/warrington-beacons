"""Build the static, browsable image library served at /images/."""
import argparse
import html
import json
from pathlib import Path
from urllib.parse import quote


ROOT = Path(__file__).resolve().parents[1]
BASE_URL = "https://trails.warringtoneac.org/"
IMAGE_EXTENSIONS = {".gif", ".jpeg", ".jpg", ".png", ".webp"}


def image_files(server_dir):
    return sorted(
        path for path in server_dir.glob("*/images/*")
        if path.is_file() and path.suffix.lower() in IMAGE_EXTENSIONS
    )


def image_url(relative_path):
    return BASE_URL + "/".join(quote(part) for part in relative_path.parts)


def build(server_dir):
    data = json.loads((server_dir / "warrington-trails.json").read_text(encoding="utf-8"))
    uses = {}
    for landmark in data.get("landmarks", []):
        uses.setdefault(landmark.get("imagePath", ""), []).append(landmark.get("name", ""))

    cards = []
    for path in image_files(server_dir):
        relative = path.relative_to(server_dir)
        relative_text = relative.as_posix()
        url = image_url(relative)
        names = sorted(set(filter(None, uses.get(relative_text, []))))
        location = relative.parts[0]
        location_label = "Lions Pride Park" if location == "lions-pride-park" else "US-202 Trail"
        used_text = ", ".join(names) if names else "Available for use"
        cards.append(f"""
        <article class="card" data-search="{html.escape((path.name + ' ' + location_label + ' ' + used_text).lower())}" data-location="{html.escape(location)}">
          <a class="preview" href="{html.escape(url)}" target="_blank" rel="noopener">
            <img src="{html.escape(url)}" alt="{html.escape(used_text)}" loading="lazy">
          </a>
          <div class="details">
            <h2>{html.escape(path.name)}</h2>
            <p class="location">{html.escape(location_label)}</p>
            <p class="used">{html.escape(used_text)}</p>
            <label>Image URL<input value="{html.escape(url)}" readonly></label>
            <button type="button" data-copy="{html.escape(url)}">Copy image URL</button>
          </div>
        </article>""")

    page = f"""<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Talking Trails image library</title>
  <style>
    :root {{ color-scheme: light; font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; color: #17342d; background: #f5f7f3; }}
    * {{ box-sizing: border-box; }}
    body {{ margin: 0; }}
    header {{ background: #24475a; color: white; padding: 2.5rem max(1rem, calc((100vw - 1200px) / 2)); }}
    header h1 {{ margin: 0 0 .5rem; font-size: clamp(1.8rem, 4vw, 2.8rem); }}
    header p {{ margin: .35rem 0; max-width: 52rem; line-height: 1.5; }}
    header a {{ color: #d9f2e6; }}
    main {{ max-width: 1200px; margin: 0 auto; padding: 1.5rem 1rem 3rem; }}
    .controls {{ display: grid; grid-template-columns: minmax(220px, 1fr) auto; gap: .75rem; margin-bottom: 1.25rem; }}
    input, select, button {{ font: inherit; }}
    #search, #location {{ width: 100%; border: 1px solid #aab8b2; border-radius: .5rem; background: white; padding: .75rem; }}
    #count {{ margin: 0 0 1rem; color: #52645e; }}
    .grid {{ display: grid; grid-template-columns: repeat(auto-fill, minmax(260px, 1fr)); gap: 1rem; }}
    .card {{ overflow: hidden; border: 1px solid #d2dcd7; border-radius: .75rem; background: white; box-shadow: 0 2px 8px rgb(25 55 45 / 8%); }}
    .preview {{ display: block; height: 190px; background: #e8eeeb; }}
    .preview img {{ width: 100%; height: 100%; object-fit: cover; }}
    .details {{ padding: 1rem; }}
    h2 {{ margin: 0; font-size: 1.05rem; overflow-wrap: anywhere; }}
    .location {{ margin: .35rem 0; color: #386852; font-weight: 650; }}
    .used {{ min-height: 2.6em; margin: .5rem 0 .85rem; color: #52645e; line-height: 1.3; }}
    label {{ display: block; color: #52645e; font-size: .82rem; }}
    label input {{ width: 100%; margin-top: .25rem; padding: .55rem; border: 1px solid #cad4cf; border-radius: .35rem; color: #314940; background: #f8faf9; }}
    button {{ width: 100%; margin-top: .65rem; border: 0; border-radius: .4rem; padding: .65rem; color: white; background: #2f6b52; cursor: pointer; font-weight: 650; }}
    button:hover {{ background: #24543f; }}
    .empty {{ padding: 2rem; text-align: center; color: #52645e; }}
    @media (max-width: 560px) {{ .controls {{ grid-template-columns: 1fr; }} }}
  </style>
</head>
<body>
  <header>
    <h1>Talking Trails image library</h1>
    <p>Browse the images available to the trail apps. Copy an image URL and paste it into the master spreadsheet’s <strong>imagePath</strong> cell. The spreadsheet link opens the full image; deployment converts it to the app-compatible path.</p>
    <p>To add an image, send the original JPG, PNG or WebP file with a descriptive filename. <a href="/talking-trails.kml">Download the KML</a>.</p>
  </header>
  <main>
    <div class="controls">
      <input id="search" type="search" placeholder="Search filename or landmark" aria-label="Search images">
      <select id="location" aria-label="Filter by location">
        <option value="">All locations</option>
        <option value="lions-pride-park">Lions Pride Park</option>
        <option value="us-202">US-202 Trail</option>
      </select>
    </div>
    <p id="count">{len(cards)} images</p>
    <section class="grid" id="grid">{''.join(cards)}</section>
    <p class="empty" id="empty" hidden>No images match that search.</p>
  </main>
  <script>
    const search = document.querySelector('#search');
    const locationFilter = document.querySelector('#location');
    const cards = [...document.querySelectorAll('.card')];
    const count = document.querySelector('#count');
    const empty = document.querySelector('#empty');
    function filter() {{
      const term = search.value.trim().toLowerCase();
      const location = locationFilter.value;
      let visible = 0;
      for (const card of cards) {{
        const show = (!term || card.dataset.search.includes(term)) && (!location || card.dataset.location === location);
        card.hidden = !show;
        if (show) visible++;
      }}
      count.textContent = `${{visible}} image${{visible === 1 ? '' : 's'}}`;
      empty.hidden = visible !== 0;
    }}
    search.addEventListener('input', filter);
    locationFilter.addEventListener('change', filter);
    document.addEventListener('click', async event => {{
      const button = event.target.closest('[data-copy]');
      if (!button) return;
      await navigator.clipboard.writeText(button.dataset.copy);
      const previous = button.textContent;
      button.textContent = 'Copied';
      setTimeout(() => button.textContent = previous, 1200);
    }});
  </script>
</body>
</html>
"""
    output = server_dir / "images" / "index.html"
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(page, encoding="utf-8")
    return output, len(cards)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--server-dir", type=Path, default=ROOT / "server")
    args = parser.parse_args()
    output, count = build(args.server_dir.resolve())
    print(f"Built {output} with {count} images")


if __name__ == "__main__":
    main()
