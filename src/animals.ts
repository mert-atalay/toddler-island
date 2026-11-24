// The 23 animals of the island, by area, with a rough real height in metres for fair side-by-side scale.
export type Area = 'Farm meadow' | 'Home garden' | 'Duck pond' | 'Forest' | 'Savanna';

export interface AnimalInfo {
  key: string;
  name: string;
  area: Area;
  height: number;
}

export const ANIMALS: AnimalInfo[] = [
  { key: 'cow', name: 'Cow', area: 'Farm meadow', height: 1.4 },
  { key: 'horse', name: 'Horse', area: 'Farm meadow', height: 1.6 },
  { key: 'donkey', name: 'Donkey', area: 'Farm meadow', height: 1.2 },
  { key: 'sheep', name: 'Sheep', area: 'Farm meadow', height: 0.9 },
  { key: 'pig', name: 'Pig', area: 'Farm meadow', height: 0.8 },
  { key: 'goat', name: 'Goat', area: 'Farm meadow', height: 0.8 },
  { key: 'rooster', name: 'Rooster', area: 'Farm meadow', height: 0.5 },
  { key: 'hens', name: 'Hens', area: 'Farm meadow', height: 0.4 },
  { key: 'dog', name: 'Dog', area: 'Home garden', height: 0.6 },
  { key: 'cat', name: 'Cat', area: 'Home garden', height: 0.3 },
  { key: 'rabbit', name: 'Rabbit', area: 'Home garden', height: 0.3 },
  { key: 'duck', name: 'Duck', area: 'Duck pond', height: 0.35 },
  { key: 'goose', name: 'Goose', area: 'Duck pond', height: 0.6 },
  { key: 'frog', name: 'Frog', area: 'Duck pond', height: 0.15 },
  { key: 'fox', name: 'Fox', area: 'Forest', height: 0.5 },
  { key: 'deer', name: 'Deer', area: 'Forest', height: 1.3 },
  { key: 'owl', name: 'Owl', area: 'Forest', height: 0.5 },
  { key: 'bear', name: 'Bear', area: 'Forest', height: 1.3 },
  { key: 'wolf', name: 'Wolf', area: 'Forest', height: 0.8 },
  { key: 'elephant', name: 'Elephant', area: 'Savanna', height: 3.0 },
  { key: 'lion', name: 'Lion', area: 'Savanna', height: 1.1 },
  { key: 'giraffe', name: 'Giraffe', area: 'Savanna', height: 4.5 },
  { key: 'monkey', name: 'Monkey', area: 'Savanna', height: 0.7 },
];

export const AREAS: Area[] = ['Farm meadow', 'Home garden', 'Duck pond', 'Forest', 'Savanna'];
