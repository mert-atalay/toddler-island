// node tools/polypizza-search.mjs > downloads/polypizza-candidates.json
// Searches Poly Pizza for each animal and records title, creator, licence and whether it is animated.
const terms = process.argv.slice(2).length ? process.argv.slice(2) : [
  'cow', 'horse', 'donkey', 'sheep', 'pig', 'goat', 'chicken', 'rooster', 'hen',
  'dog', 'cat', 'rabbit', 'bunny', 'duck', 'goose', 'frog',
  'fox', 'deer', 'owl', 'bear', 'wolf',
  'elephant', 'lion', 'giraffe', 'monkey',
];
const unesc = (s) => s.replace(/\\u002F/g, '/');
const out = [];
const seen = new Set();
for (const term of terms) {
  let html = "";
  for (let t = 0; t < 4 && !html.includes("publicID"); t++) {
    if (t) await new Promise((r) => setTimeout(r, 3000 * t));
    html = await fetch(`https://poly.pizza/search/${encodeURIComponent(term)}`).then((r) => r.text()).catch(() => "");
  }
  if (!html.includes("publicID")) console.error("no results for", term);
  const chunks = html.split('"title":"').slice(1);
  let n = 0;
  for (const c of chunks) {
    if (n >= 12) break;
    const g = (r) => (c.slice(0, 1500).match(r) || [])[1];
    const title = c.slice(0, c.indexOf('"'));
    const creator = g(/"username":"([^"]+)"/), id = g(/"publicID":"([^"]+)"/);
    const licence = g(/"licence":"([^"]+)"/), preview = g(/"previewUrl":"([^"]+)"/);
    if (!id || !preview) continue;
    if (seen.has(id)) continue;
    seen.add(id); n++;
    const page = await fetch(`https://poly.pizza/m/${id}`).then((r) => r.text());
    const animated = /"Animated":true/.test(page);
    const tri = (page.match(/"TriCount":(\d+)/) || [])[1];
    const uuid = unesc(preview).match(/static\.poly\.pizza\/([0-9a-f-]+)\.webp/)?.[1];
    out.push({ term, title, creator, licence, animated, tris: tri ? +tri : null, id,
      page: `https://poly.pizza/m/${id}`, glb: uuid ? `https://static.poly.pizza/${uuid}.glb` : null,
      preview: unesc(preview) });
  }
}
console.log(JSON.stringify(out, null, 1));
