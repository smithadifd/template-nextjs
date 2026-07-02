/**
 * Example hand-rolled component (the family prefers hand-rolled over component
 * libs). Server Component by default — add `'use client'` only when a component
 * needs interactivity.
 */

import { greet } from '@/components/greet';

export function Greeting({ name }: { name: string }) {
  return <p className="mt-4 text-base">{greet(name)}</p>;
}
