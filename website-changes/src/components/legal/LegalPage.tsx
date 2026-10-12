import React from "react";
import { LEGAL_EFFECTIVE_DATE } from "@/lib/legal";

/** Shared layout for /terms and /privacy. */
export function LegalPage({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <main className="max-w-3xl mx-auto px-6 py-16">
      <h1 className="text-3xl font-bold text-[#001049]">{title}</h1>
      <p className="text-sm text-gray-500 mt-2">Effective {LEGAL_EFFECTIVE_DATE}</p>
      <div className="mt-10 space-y-10 text-gray-700 leading-relaxed">{children}</div>
    </main>
  );
}

export function LegalSection({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <section className="space-y-3">
      <h2 className="text-xl font-semibold text-[#001049]">{title}</h2>
      {children}
    </section>
  );
}

export function LegalList({ items }: { items: React.ReactNode[] }) {
  return (
    <ul className="list-disc pl-6 space-y-1.5">
      {items.map((item, i) => (
        <li key={i}>{item}</li>
      ))}
    </ul>
  );
}
