import { Link } from "@tanstack/react-router";

const tabs = [
  { to: "/dashboard", label: "Home", glyph: "◈" },
  { to: "/payments", label: "Payments", glyph: "⇄" },
  { to: "/cards", label: "Cards", glyph: "▢" },
  { to: "/profile", label: "Profile", glyph: "◍" },
] as const;

export function BottomNav() {
  return (
    <nav
      aria-label="Primary"
      className="fixed inset-x-0 bottom-0 z-40 border-t border-paper/10 bg-ink-2/95 backdrop-blur md:hidden"
      style={{ paddingBottom: "env(safe-area-inset-bottom)" }}
    >
      <ul className="mx-auto flex max-w-md items-stretch">
        {tabs.map((tab) => (
          <li key={tab.to} className="flex-1">
            <Link
              to={tab.to}
              activeProps={{ className: "text-gold-2" }}
              inactiveProps={{ className: "text-paper/55" }}
              className="flex flex-col items-center gap-1 py-2.5 text-[11px]"
            >
              <span aria-hidden className="text-base leading-none">
                {tab.glyph}
              </span>
              {tab.label}
            </Link>
          </li>
        ))}
      </ul>
    </nav>
  );
}
