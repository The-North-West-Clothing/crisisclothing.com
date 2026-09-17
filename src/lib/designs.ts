export type DesignLike = {
  id: string;
  data: { releaseDate: Date; draft: boolean };
};

export function sortedPublishedDesigns<Entry extends DesignLike>(entries: Entry[]): Entry[] {
  return entries
    .filter((entry) => !entry.data.draft)
    .slice()
    .sort((left, right) => right.data.releaseDate.getTime() - left.data.releaseDate.getTime());
}

const releaseDateFormatter = new Intl.DateTimeFormat('en-US', {
  year: 'numeric',
  month: 'long',
  day: 'numeric',
  timeZone: 'UTC',
});

export function formatReleaseDate(date: Date): string {
  return releaseDateFormatter.format(date);
}
