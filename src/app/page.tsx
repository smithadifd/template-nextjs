import { Greeting } from '@/components/Greeting';

export default function HomePage() {
  return (
    <main className="mx-auto max-w-2xl p-8">
      <h1 className="text-2xl font-semibold">template-nextjs</h1>
      <p className="mt-2 text-sm opacity-70">
        A Next.js 16 App Router scaffold. Replace this page with your app.
      </p>
      <Greeting name="world" />
      <ul className="mt-6 list-disc pl-5 text-sm opacity-70">
        <li>
          Health check: <code>/health</code>
        </li>
        <li>
          Schema (source of truth): <code>src/db/schema.ts</code>
        </li>
        <li>
          Env config: <code>src/config/env.ts</code>
        </li>
      </ul>
    </main>
  );
}
