/** Trivial pure helper — exists so the example Vitest spec has real logic to test. */
export function greet(name: string): string {
  const trimmed = name.trim();
  if (!trimmed) return 'Hello, there!';
  return `Hello, ${trimmed}!`;
}
