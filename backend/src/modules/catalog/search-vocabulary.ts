const SEARCH_SYNONYMS: Readonly<Record<string, readonly string[]>> = {
  ac: ["air conditioning", "air conditioner", "ac repair", "ac service"],
  "air conditioner": ["air conditioning", "ac repair", "ac service"],
  "not cooling": ["ac repair", "air conditioning repair", "cooling repair"],
  "ac not cooling": ["ac repair", "air conditioning repair", "cooling repair"],
  plumbing: ["plumber", "pipe repair", "leak repair"],
  plumber: ["plumbing", "pipe repair", "leak repair"],
  electrician: ["electrical repair", "electrician service", "wiring"],
  electrical: ["electrician", "electrical repair", "wiring"],
  cleaning: ["home cleaning", "deep cleaning", "house cleaning"],
  carpenter: ["carpentry", "furniture repair", "woodwork"],
  "pest control": ["pest treatment", "termite control", "insect control"]
};

const TYPO_VOCABULARY = Object.keys(SEARCH_SYNONYMS);

export function normalizeSearchText(value: string): string {
  return value
    .normalize("NFKC")
    .toLocaleLowerCase("en")
    .replace(/\ba\s*\/\s*c\b/gu, "ac")
    .replace(/[^\p{L}\p{M}\p{N}]+/gu, " ")
    .trim()
    .replace(/\s+/g, " ");
}

export function expandSearchQuery(value: string): string[] {
  const query = normalizeSearchText(value);
  if (!query) return [];

  const terms = new Set<string>([query]);
  const addSynonyms = (phrase: string) => {
    const synonyms = SEARCH_SYNONYMS[phrase];
    if (synonyms) for (const synonym of synonyms) terms.add(synonym);
  };

  addSynonyms(query);
  if (query.includes("not cooling")) addSynonyms("not cooling");

  for (const token of query.split(" ")) {
    addSynonyms(token);
    if (token.length < 5) continue;
    for (const known of TYPO_VOCABULARY) {
      if (known.includes(" ")) continue;
      if (editDistanceAtMostOne(token, known)) {
        terms.add(known);
        addSynonyms(known);
      }
    }
  }

  return [...terms].slice(0, 10);
}

function editDistanceAtMostOne(left: string, right: string): boolean {
  if (left === right) return false;
  if (Math.abs(left.length - right.length) > 1) return false;

  let leftIndex = 0;
  let rightIndex = 0;
  let edits = 0;
  while (leftIndex < left.length && rightIndex < right.length) {
    if (left[leftIndex] === right[rightIndex]) {
      leftIndex += 1;
      rightIndex += 1;
      continue;
    }
    edits += 1;
    if (edits > 1) return false;
    if (left.length > right.length) leftIndex += 1;
    else if (right.length > left.length) rightIndex += 1;
    else {
      leftIndex += 1;
      rightIndex += 1;
    }
  }
  if (leftIndex < left.length || rightIndex < right.length) edits += 1;
  return edits === 1;
}

export function searchRelevanceScore(name: string, query: string): number {
  const normalizedName = normalizeSearchText(name);
  const normalizedQuery = normalizeSearchText(query);
  if (!normalizedQuery || !normalizedName) return 0;
  if (normalizedName === normalizedQuery) return 100;
  if (normalizedName.startsWith(normalizedQuery)) return 80;
  if (` ${normalizedName} `.includes(` ${normalizedQuery} `)) return 60;
  const queryWords = normalizedQuery.split(" ");
  const nameWords = normalizedName.split(" ");
  const matchingWords = queryWords.filter((word) => nameWords.some((nameWord) => nameWord.startsWith(word)));
  return matchingWords.length === queryWords.length ? 40 : matchingWords.length * 10;
}
