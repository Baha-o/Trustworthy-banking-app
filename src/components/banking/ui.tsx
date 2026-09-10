import type { ReactNode } from "react";
import { cn } from "@/lib/utils";
import { titleCase } from "@/lib/banking";

export function PageHeader({
  eyebrow,
  title,
  subtitle,
  action,
}: {
  eyebrow: string;
  title: string;
  subtitle?: string;
  action?: ReactNode;
}) {
  return (
    <div className="flex flex-wrap items-end justify-between gap-4">
      <div>
        <p className="font-mono text-[11px] uppercase tracking-[0.18em] text-steel">{eyebrow}</p>
        <h1 className="mt-2 font-serif text-3xl font-semibold tracking-tight text-ink sm:text-4xl">
          {title}
        </h1>
        {subtitle ? <p className="mt-2 max-w-[60ch] text-sm text-steel">{subtitle}</p> : null}
      </div>
      {action}
    </div>
  );
}

export function Panel({ className, children }: { className?: string; children: ReactNode }) {
  return (
    <section className={cn("rounded-2xl border border-ink/10 bg-white p-6 shadow-sm", className)}>
      {children}
    </section>
  );
}

const statusTone: Record<string, string> = {
  completed: "bg-emerald-50 text-emerald-700 ring-emerald-600/20",
  paid: "bg-emerald-50 text-emerald-700 ring-emerald-600/20",
  pending: "bg-amber-50 text-amber-700 ring-amber-600/20",
  scheduled: "bg-amber-50 text-amber-700 ring-amber-600/20",
  failed: "bg-rose-50 text-rose-700 ring-rose-600/20",
  active: "bg-emerald-50 text-emerald-700 ring-emerald-600/20",
};

export function StatusBadge({ status }: { status: string }) {
  return (
    <span
      className={cn(
        "rounded-full px-2.5 py-1 font-mono text-[10px] uppercase tracking-[0.12em] ring-1 ring-inset",
        statusTone[status] ?? "bg-ink/5 text-steel ring-ink/10",
      )}
    >
      {status}
    </span>
  );
}

export function CategoryChip({ category }: { category: string }) {
  return (
    <span className="rounded-full bg-paper-2 px-2.5 py-1 text-[11px] text-steel">
      {titleCase(category)}
    </span>
  );
}

export const fieldClass =
  "w-full rounded-[10px] border border-ink/15 bg-white px-3.5 py-2.5 text-sm text-ink outline-none transition-colors placeholder:text-steel/60 focus:border-gold";

export const labelClass =
  "mb-1.5 block font-mono text-[11px] uppercase tracking-[0.14em] text-steel";

export const primaryButtonClass =
  "rounded-[10px] bg-ink px-4 py-2.5 text-sm font-medium text-paper transition-transform hover:-translate-y-px disabled:cursor-not-allowed disabled:opacity-50";

export const ghostButtonClass =
  "rounded-[10px] border border-ink/15 px-4 py-2.5 text-sm text-ink transition-colors hover:bg-paper-2 disabled:opacity-50";

export function Note({ tone, children }: { tone: "error" | "success"; children: ReactNode }) {
  if (!children) return null;
  return (
    <p
      role={tone === "error" ? "alert" : "status"}
      className={cn(
        "rounded-[10px] px-3.5 py-2.5 text-sm",
        tone === "error"
          ? "bg-rose-50 text-rose-700 ring-1 ring-inset ring-rose-600/20"
          : "bg-emerald-50 text-emerald-700 ring-1 ring-inset ring-emerald-600/20",
      )}
    >
      {children}
    </p>
  );
}

export function EmptyState({ title, hint }: { title: string; hint?: string }) {
  return (
    <div className="rounded-2xl border border-dashed border-ink/15 px-6 py-10 text-center">
      <p className="font-serif text-lg text-ink">{title}</p>
      {hint ? <p className="mt-1 text-sm text-steel">{hint}</p> : null}
    </div>
  );
}

export function Loading({ label = "Loading…" }: { label?: string }) {
  return <p className="py-10 text-center text-sm text-steel">{label}</p>;
}
