import { describe, it, expect } from 'vitest';
import { sortedPublishedDesigns, formatReleaseDate } from './designs';

const make = (id: string, iso: string, draft = false) => ({
  id,
  data: { releaseDate: new Date(iso), draft },
});

describe('sortedPublishedDesigns', () => {
  it('sorts by releaseDate descending (newest first)', () => {
    const input = [
      make('older', '2023-01-01'),
      make('newest', '2025-06-01'),
      make('middle', '2024-03-15'),
    ];
    expect(sortedPublishedDesigns(input).map((entry) => entry.id)).toEqual([
      'newest',
      'middle',
      'older',
    ]);
  });

  it('excludes drafts', () => {
    const input = [make('shown', '2024-01-01'), make('hidden', '2025-01-01', true)];
    expect(sortedPublishedDesigns(input).map((entry) => entry.id)).toEqual(['shown']);
  });

  it('does not mutate the input array', () => {
    const input = [make('a', '2023-01-01'), make('b', '2024-01-01')];
    const before = input.map((entry) => entry.id);
    sortedPublishedDesigns(input);
    expect(input.map((entry) => entry.id)).toEqual(before);
  });
});

describe('formatReleaseDate', () => {
  it('formats as a long US date', () => {
    expect(formatReleaseDate(new Date('2024-11-02T00:00:00Z'))).toBe('November 2, 2024');
  });
});
