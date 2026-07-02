import { describe, expect, it } from 'vitest';
import { greet } from '@/components/greet';
import fixture from './fixtures/greet.json';

describe('greet', () => {
  it('greets a named person', () => {
    expect(greet('Andrew')).toBe('Hello, Andrew!');
  });

  it('trims surrounding whitespace', () => {
    expect(greet('  world  ')).toBe('Hello, world!');
  });

  it('falls back for an empty name', () => {
    expect(greet('   ')).toBe('Hello, there!');
  });

  it('matches the fixture cases', () => {
    for (const { input, expected } of fixture.cases) {
      expect(greet(input)).toBe(expected);
    }
  });
});
