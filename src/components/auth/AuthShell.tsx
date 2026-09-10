import { Link } from "@tanstack/react-router";
import type { ReactNode } from "react";

export function AegisMark({ className = "" }: { className?: string }) {
  return (
    <span className={`flex items-center gap-2.5 ${className}`}>
      <span className="vault-ring grid size-8 place-items-center rounded-[6px] ring-1 ring-black/20">
        <span className="size-3.5 rounded-[3px] bg-ink-2" />
      </span>
      <span className="font-serif text-lg font-semibold tracking-tight text-paper">
        Trust Worthy<span className="text-gold">.</span>
      </span>
    </span>
  );
}

export function AuthShell({
  eyebrow,
  title,
  subtitle,
  children,
  footer,
}: {
  eyebrow: string;
  title: ReactNode;
  subtitle?: ReactNode;
  children: ReactNode;
  footer?: ReactNode;
}) {
  return (
    <div className="vault-face relative min-h-screen font-sans text-paper antialiased">
      <div
        className="pointer-events-none absolute inset-0 opacity-40"
        style={{
          background:
            "radial-gradient(55% 45% at 80% 6%, rgba(198,161,91,0.22) 0%, transparent 70%)",
        }}
      />
      <div className="relative mx-auto flex min-h-screen max-w-6xl flex-col px-6 py-8 lg:px-8">
        <header className="flex items-center justify-between">
          <Link to="/">
            <AegisMark />
          </Link>
          <Link to="/" className="text-sm text-paper/60 transition-colors hover:text-paper">
            Back to site
          </Link>
        </header>

        <main className="flex flex-1 items-center justify-center py-10">
          <div className="fade-up w-full max-w-md">
            <div className="mb-6 inline-flex items-center gap-2 rounded-full border border-gold/25 bg-gold/10 px-3 py-1">
              <span className="size-1.5 rounded-full bg-gold-2" />
              <span className="font-mono text-[11px] uppercase tracking-[0.18em] text-gold-2">
                {eyebrow}
              </span>
            </div>
            <h1 className="font-serif text-3xl font-semibold leading-tight tracking-tight text-balance sm:text-[2.4rem]">
              {title}
            </h1>
            {subtitle ? (
              <p className="mt-3 text-sm leading-relaxed text-paper/65 text-pretty">{subtitle}</p>
            ) : null}

            <div className="card-face mt-8 rounded-2xl border border-paper/10 p-6 shadow-2xl shadow-black/40 sm:p-8">
              {children}
            </div>

            {footer ? <div className="mt-6 text-sm text-paper/60">{footer}</div> : null}
          </div>
        </main>

        <footer className="space-y-1.5 border-t border-paper/10 pt-5 text-xs text-paper/40">
          <p>Trust Worthy Banking Hub Ltd. — Electronic Money Institution.</p>
          <p>
            Regulated by NCA · EMI Licence No. EU-EMI-LT-186593.
          </p>
          <p>
            Electronic money is safeguarded under applicable payment services
            regulations.
          </p>
        </footer>
      </div>
    </div>
  );
}

export const fieldClass =
  "w-full rounded-[10px] border border-paper/15 bg-ink-2/60 px-3.5 py-2.5 text-sm text-paper placeholder:text-paper/35 outline-none transition-colors focus:border-gold/60 focus:ring-1 focus:ring-gold/30";

export const labelClass =
  "mb-1.5 block font-mono text-[11px] uppercase tracking-[0.14em] text-paper/50";

export const primaryButtonClass =
  "inline-flex w-full items-center justify-center rounded-[10px] bg-gold px-5 py-3 text-sm font-semibold text-ink-2 ring-1 ring-gold/40 transition-transform hover:-translate-y-px disabled:cursor-not-allowed disabled:opacity-60 disabled:hover:translate-y-0";

export const ghostButtonClass =
  "inline-flex w-full items-center justify-center rounded-[10px] border border-paper/20 px-5 py-3 text-sm font-medium text-paper transition-colors hover:bg-paper/5 disabled:opacity-60";
