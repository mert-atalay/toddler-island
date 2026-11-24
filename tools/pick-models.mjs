// node tools/pick-models.mjs
// Chooses up to 3 Poly Pizza candidates per animal (animated first, then Quaternius, then others),
// downloads the GLBs to public/models/candidates/<animal>/ and writes public/models/candidates.json.
import fs from 'node:fs';
import path from 'node:path';

const all = [
  ...JSON.parse(fs.readFileSync('downloads/polypizza-candidates.json', 'utf8')),
  ...JSON.parse(fs.readFileSync('downloads/pp2.json', 'utf8')),
];
// animal -> title words that count as that animal
const animals = {
  cow: ['cow', 'bull'], horse: ['horse'], donkey: ['donkey'], sheep: ['sheep'], pig: ['pig'],
  goat: ['goat'], rooster: ['rooster', 'chicken'], hens: ['hen', 'chicken'],
  dog: ['dog', 'shiba', 'husky', 'beagle', 'puppy'], cat: ['cat', 'kitten'], rabbit: ['rabbit', 'bunny'],
  duck: ['duck', 'mallard'], goose: ['goose'], frog: ['frog'],
  fox: ['fox'], deer: ['deer', 'stag'], owl: ['owl'], bear: ['bear'], wolf: ['wolf'],
  elephant: ['elephant'], lion: ['lion'], giraffe: ['giraffe'], monkey: ['monkey', 'chimpanzee', 'capuchin'],
};
const bad = /rubber|robot|mech|bacon|piggy|bank|egg|coop|foot|drumstick|kfc|gun|ears|man\b|guy|head|claw|panda|sea lion|fish|mountain|arctic|island|minecraft|voxel|giga|ballistic|chungus|furry|cyan|character|t-pose|plane|lessons|combat|loaf|marsey|dingus|vr/i;
const seen = new Set();
const uniq = all.filter((x) => !seen.has(x.id) && seen.add(x.id) && x.glb);
const score = (x) => (x.animated ? 100 : 0) + (x.creator === 'Quaternius' ? 50 : 0) + (x.creator === 'Poly by Google' ? 10 : 0);

const out = {};
for (const [animal, words] of Object.entries(animals)) {
  const hits = uniq
    .filter((x) => words.some((w) => new RegExp(`\\b${w}`, 'i').test(x.title)) && !bad.test(x.title))
    .sort((a, b) => score(b) - score(a))
    .slice(0, 3);
  out[animal] = [];
  for (const x of hits) {
    const dir = path.join('public/models/candidates', animal);
    fs.mkdirSync(dir, { recursive: true });
    const file = path.join(dir, `${x.id}.glb`);
    if (!fs.existsSync(file)) {
      const buf = Buffer.from(await fetch(x.glb).then((r) => r.arrayBuffer()));
      fs.writeFileSync(file, buf);
    }
    out[animal].push({ id: x.id, title: x.title, creator: x.creator, licence: x.licence,
      animated: x.animated, page: x.page, file: `/models/candidates/${animal}/${x.id}.glb` });
  }
  console.log(animal.padEnd(9), out[animal].map((x) => `${x.title} (${x.creator}${x.animated ? ', animated' : ''})`).join('; ') || 'NONE');
}
fs.writeFileSync('public/models/candidates.json', JSON.stringify(out, null, 1));
