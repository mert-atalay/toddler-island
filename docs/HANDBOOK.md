# Toddler Island: the parent's handbook

Everything about playing and looking after the game: controls, what there is to do, test runs and where
the pictures, models and sounds came from. The first time it opens, Godot imports the assets (a few minutes).

Open it with **Play Toddler Island.bat** (full screen).

## Controls

| What | Keyboard | Xbox controller |
| --- | --- | --- |
| Walk / run | W A S D or arrows, Shift to run | left stick, right trigger to run |
| Turn the camera | mouse drag, Q and E | right stick |
| Her button (whatever the card at the bottom says: pick up, feed, ride, swing...) | Space or any letter | A B X Y |
| Call the animals | C | shoulder button |
| Sticker book | Tab | View button |
| Parent menu (day length, volumes, record your voice, quiet launch) | P | Menu button |
| Photo (saved to Pictures\Toddler Island) | F12 | right stick click |
| Hop | H | left stick click |
| Stroll for me: she walks to the next place by herself | hold T | hold d-pad up |
| Picture map | M | d-pad down |
| Next stage of the Moon trip | N (during the trip) | shoulder button |
| Change the music (Happy, Adventure, Cosy, Music box, Off) | N | Share button |
| Full screen on/off | F11 | |
| Quit | Esc | |

## What there is to do

Nothing happens by accident: when something can be done, a card at the bottom of the screen shows a picture,
the button and what will happen ("Pick up an apple", "Feed the horse", "Ride the horse!"). Her button does it.

- **Animals:** stroke them, feed them (apples from the crates or shaken from the apple trees, carrots from the garden, hay, seed). The third stroke in a row is
  special: a ride on the horse or donkey, a spin from the dog and the cat, a happy jump from the others.
- **Toys and activities:** the swing (she sits on the seat and it really swings), slide, merry-go-round, spring horse and seesaw behind the cottage; rowing the
  boat round the pond; fishing off the jetty; sandcastles on the beach; the kite on the windmill hill (she holds the string and it follows her about) and the telescope;
  the pumpkin patch, scarecrow, tent, campfire, mushrooms, mailbox, rover, signposts, benches (sit down), flowers
  (smell them), beehives (buzz) and the lighthouse bell all answer with a word.
- **Adventures board** by the cottage: three picture cards. Each one done earns a souvenir for the shelf next to it.
- **The Moon:** press her button at the red gantry in the rocket meadow. Mercan and the dog climb in, countdown,
  lift-off, Earth from orbit, a look back at the Earth getting smaller, the Moon, landing, the dog hops out in his helmet,
  a low-gravity walk under a deep starry sky with the Earth over the horizon, a flag, and home. Ten steps on the Moon
  bring **"You are my moonshine, Mercan"**: the words glow in letter by letter over a little music-box tune (no computer
  voice), a photo goes to Pictures\Toddler Island, then a golden sticker, a moon rock on the shelf and a sparkle on the
  island's Moon at night. The name is the save setting `child_name`.
- **Wild life:** rabbits that hop away if she comes too close, squirrels that dash up the trees, ducks and ducklings
  paddling on the pond, seagulls over the beach and flocks crossing the sky, small birds, bees, dragonflies, frogs and
  crabs, jumping fish, fireflies at dusk. Seeing each one earns its sticker.
- **Safari plain** (west, past the farm): elephants (a mother and baby), giraffes (a mother and baby), a lion and her
  cub by their rock, a hippo at the waterhole, a rhino and a tiger, under flat-topped acacias. A safari hide on stilts with
  a ramp: her button there looks slowly across the plain. The big animals were still models; they get a skeleton and
  walk, graze, nod and wag in code (`game/lib/autorig.gd`), and the elephant swings and lifts its trunk.
- **Treehouse camp** (deep in the eastern wood, past the tall oak): a giant tree with a little red-roofed house, a ramp
  up and a slide down, a campfire with log seats (warm her hands), tents, a frog pool with lily pads and hopping frogs,
  an owl that hoots back, fireflies; a fox pair, a raccoon, a bear cub and a friendly wolf.
- **The world:** a green valley ringed by mountains, a waterfall and river, the lake, the lookout and the fairy hollow.
- **Sound:** footsteps that match the ground, the stream and the wind, and the parent's own recorded voice on happy
  moments. **Music** has five choices in the parent menu (or press N, or the controller's Share button): Happy,
  Adventure, Cosy, Music box (the lullabies) and Off. After sunset the lively music turns cosy.

## Test runs (for development)

```
Godot_v4.7.2-stable_win64_console.exe --path game res://corner/corner.tscn -- --shots <dir>   # photo tour
Godot_v4.7.2-stable_win64_console.exe --path game res://corner/corner.tscn -- --trip <dir>    # Moon trip tour
Godot_v4.7.2-stable_win64_console.exe --path game res://corner/corner.tscn -- --bench         # speed check
Godot_v4.7.2-stable_win64_console.exe --path game res://corner/corner.tscn -- --soak          # 20-minute animal test
Godot_v4.7.2-stable_win64_console.exe --path game res://corner/corner.tscn -- --play-test <dir> # every activity, photographed
Godot_v4.7.2-stable_win64_console.exe --path game res://corner/corner.tscn -- --audit         # overlaps, paths, water, draw calls
```

The trip tour writes the moonshine achievement into the real save; clear it afterwards (it lives in
`%APPDATA%\Godot\app_userdata\Toddler Island\save.json`).

## Where things came from

- Animals: Quaternius (Ultimate Animated Animal Pack, Farm Animals, and the fox, wolf, alpaca, raccoon, frog and crab),
  via Poly Pizza and itch.io; the rabbit, squirrel, ducks, seagull, lion, elephant, giraffe, hippo, rhino, tiger, bear cub
  and owl from Poly Pizza (Poly by Google, Noah Lewis; CC BY).
- Music: Kevin MacLeod (incompetech.com), CC BY 4.0: Fluffing a Duck, Monkeys Spinning Monkeys, Carefree, Merry Go,
  Happy Alley, Quirky Dog, Cheery Monday, Easy Lemon, Daily Beetle, Dreamer, Bright Wish, Gymnopedie No 1, Pixelland,
  Itty Bitty 8 Bit, Overworld, Life of Riley, Amazing Plan, Hamster March.
- Nature, buildings, props: Quaternius Stylized Nature MegaKit and Farm Buildings; Kenney Nature, Survival, Water,
  Space and Food kits; Tiny Treats playground and picnic packs; Poly Pizza lighthouse, telescope, bird, frog and crab.
- Space pictures: Solar System Scope 8k Earth (day, night, clouds), Moon and Milky Way maps.
- Sounds: Wikimedia Commons animal recordings picked in the step 1 sound picker; Kenney footstep, impact and jingle packs.
  The music box and the stream, wind and rocket sounds are made in code.

The step 1 asset check pages (`npm run dev`, then http://localhost:5180) and the tools in `tools/` rebuild the model and
sound lists.

## Notes for whoever looks after it

- If the game ever freezes, `%APPDATA%\Godot\app_userdata\Toddler Island\heartbeat.txt` holds its last status (every
  2 seconds) and the last 30 things that happened. Quitting (Esc, the close button, Alt+F4) always closes it: if the
  engine hangs while shutting down, a watchdog ends it after 2.5 seconds. Everything is saved as it happens.
- The generated music is kept in `...\Toddler Island\music`; delete that folder to make it again.
- Speed at 1920×1080 on the RTX 3050 laptop: about 92 fps on average across twelve walking spots, 70 at the busiest
  (the hill top looking over the island). Trees are the biggest cost, then shadows.
