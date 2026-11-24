// node tools/fetch-sounds.mjs
// Downloads candidate animal recordings from Wikimedia Commons into public/sounds/candidates/<animal>/
// and writes public/sounds/candidates.json (the manifest the sound picker reads).
// Files named in the plan doc come first; a Commons search adds a few extra options per animal.
import fs from 'node:fs';
import path from 'node:path';

const UA = 'toddler-island-asset-check/0.1 (home project)';
const plan = {
  cow: ['Mudchute cow 1.ogg', 'Single Cow Moo.ogg'],
  horse: ['Mares-Prefer-the-Voices-of-Highly-Fertile-Stallions-pone.0118468.s004.oga'],
  donkey: ['Домашний Осёл, Киприотский.ogg'],
  sheep: ['Sheep bleating.ogg'],
  pig: ['Mudchute pig 1.ogg'],
  goat: ['Herd of goats bleating.ogg'],
  rooster: ['Medium rooster crowing.ogg'],
  hens: ['Chickens demanding food.ogg', 'Hens leaving coop.ogg'],
  dog: ['Barking of a dog.ogg'],
  cat: ['Meow normalized.opus', 'Jupey purring.wav'],
  rabbit: ['Lautäußerung Kaninchen.flac'],
  duck: ['Mallard (Anas platyrhynchos) (W1CDR0001518 BD17).ogg'],
  goose: ['Geese Honking (loud).ogg'],
  frog: ['Single Frog Croak.oga'],
  fox: ['FuchsSchreit.mp3'],
  deer: ['Red Deer (Cervus elaphus) (W1CDR0001424 BD3).ogg'],
  owl: ['Bubo virginianus - Great Horned Owl XC450919.mp3'],
  bear: ['Bear growl.ogg'],
  wolf: ['Wolf howls.ogg'],
  elephant: ['Elephant voice - trumpeting.ogg'],
  lion: ['Lion raring-sound1TamilNadu178.ogg'],
  giraffe: ['Giraffehum3.oga'],
  monkey: ['Mantled Howler Monkey (Alouatta palliata) (W ALOUATTA PALLIATA R1 C2).ogg'],
  background: ['30goldfinch.ogg', 'Wood pigeon call 128.ogg', 'Hummel bee.ogg'],
};
// Extra searches, aimed at the gaps the plan names (short pig clip, fox scream, howler roar).
const search = {
  cow: 'cow moo|Bos taurus', horse: 'horse neigh|whinny|Equus caballus', donkey: 'donkey bray', sheep: 'sheep baa', pig: 'pig oink grunt',
  goat: 'goat bleat|Capra hircus', rooster: 'rooster crow', hens: 'hen clucking', dog: 'dog bark', cat: 'cat meow',
  rabbit: 'rabbit|Oryctolagus', duck: 'duck quack|Anas platyrhynchos', goose: 'goose honk|Anser', frog: 'frog croak|Rana',
  fox: 'fox bark|Vulpes vulpes', deer: 'deer call|Cervus|Capreolus', owl: 'owl hoot', bear: 'bear|Ursus', wolf: 'wolf howl|Canis lupus',
  elephant: 'elephant trumpet|Loxodonta|Elephas', lion: 'lion roar|Panthera leo', giraffe: 'giraffe', monkey: 'monkey chatter|macaque|Macaca|capuchin',
};
const EXTRA = 4;
const MAX_SECONDS = 70;

async function api(params) {
  const u = new URL('https://commons.wikimedia.org/w/api.php');
  for (const [k, v] of Object.entries({ format: 'json', formatversion: '2', ...params })) u.searchParams.set(k, v);
  for (let t = 0; t < 6; t++) {
    const r = await fetch(u, { headers: { 'User-Agent': UA } });
    if (r.ok) return r.json();
    await new Promise((res) => setTimeout(res, 10000 * (t + 1)));
  }
  throw new Error('api failed ' + u);
}
async function info(titles) {
  const j = await api({ action: 'query', prop: 'imageinfo', iiprop: 'url|size|mime|extmetadata|mediatype',
    titles: titles.map((t) => 'File:' + t).join('|') });
  return (j.query?.pages || []).filter((p) => p.imageinfo).map((p) => {
    const ii = p.imageinfo[0]; const m = ii.extmetadata || {};
    const strip = (s) => (s || '').replace(/<[^>]+>/g, '').trim();
    return { title: p.title.replace(/^File:/, ''), url: ii.url, mime: ii.mime, mediatype: ii.mediatype,
      seconds: ii.duration ?? null, licence: strip(m.LicenseShortName?.value), author: strip(m.Artist?.value).slice(0, 120),
      page: 'https://commons.wikimedia.org/wiki/File:' + encodeURIComponent(p.title.replace(/^File:/, '').replace(/ /g, '_')) };
  });
}
async function searchAudio(q) {
  const j = await api({ action: 'query', list: 'search', srnamespace: '6', srlimit: '25',
    srsearch: `${q} filetype:audio` });
  return (j.query?.search || []).map((s) => s.title.replace(/^File:/, ''));
}

const manifest = {};
for (const animal of Object.keys(plan)) {
  const chosen = await info(plan[animal]);
  for (const c of chosen) c.fromPlan = true;
  if (search[animal]) {
    const queries = search[animal].split('|');
    const block = /anthem|tractor|sparrow|dance|capuchinbird|calfbird|rana (deuba|tharu)|shamsher|arzu|puran|avk|-agu|can.t bark|mento/i;
    const key = queries.map((q) => q.split(' ')[0]).join('|');
    const junk = /^[A-Z][a-z]{1,2}(-[a-z]{2})?-|fart|alarm|song|michigan|kong|article|spoken|pronunciation|music|choir|poem|recitation|interview|news|suno|purple|vezo|baa|bah|man |phleng|whistle|fifth|5th|.mid$|lyric|vocal|instrumental|segregation|wikipedia|in [A-Z][a-z]+.(ogg|oga)$/i;
    const titles = (await Promise.all(queries.map(searchAudio))).flat()
      .filter((t) => !plan[animal].includes(t) && new RegExp(key, 'i').test(t) && !junk.test(t) && !block.test(t));
    const uniqTitles = [...new Set(titles)];
    const found = [];
    for (let i = 0; i < Math.min(uniqTitles.length, 50); i += 25) found.push(...await info(uniqTitles.slice(i, i + 25)));
    for (const f of found) {
      if (chosen.length >= plan[animal].length + EXTRA) break;
      if (chosen.some((c) => c.title === f.title)) continue;
      if (f.mediatype !== 'AUDIO' && !/audio|ogg|opus|flac|wav|mpeg/.test(f.mime)) continue;
      if (/video|webm/.test(f.mime)) continue;
      if (f.seconds && f.seconds > MAX_SECONDS) continue;
      chosen.push({ ...f, fromPlan: false });
    }
  }
  // Commons throttles bulk script downloads, so the picker streams each file straight from
  // upload.wikimedia.org (it allows browser cross-origin reads). Only the chosen clips get downloaded later.
  manifest[animal] = chosen.map((c) => ({ ...c, file: c.url }));
  await new Promise((res) => setTimeout(res, 1500));
  console.log(animal.padEnd(10), manifest[animal].map((c) => `${c.fromPlan ? '*' : ''}${c.title.slice(0, 40)}`).join(' | '));
}
fs.writeFileSync('public/sounds/candidates.json', JSON.stringify(manifest, null, 1));
