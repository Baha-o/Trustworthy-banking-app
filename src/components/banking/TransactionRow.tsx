import { CategoryChip, StatusBadge } from "./ui";
import { money, shortDate, type Transaction } from "@/lib/banking";
import { cn } from "@/lib/utils";

export function TransactionRow({
  tx,
  onSelect,
}: {
  tx: Transaction;
  onSelect?: (tx: Transaction) => void;
}) {
  const incoming = tx.direction === "in";
  return (
    <button
      type="button"
      onClick={() => onSelect?.(tx)}
      className="flex w-full items-center gap-4 px-1 py-3.5 text-left transition-colors hover:bg-paper-2/60"
    >
      <span
        className={cn(
          "grid size-10 shrink-0 place-items-center rounded-full font-mono text-xs",
          incoming ? "bg-emerald-50 text-emerald-700" : "bg-ink/5 text-ink",
        )}
        aria-hidden
      >
        {incoming ? "↓" : "↑"}
      </span>
      <span className="min-w-0 flex-1">
        <span className="block truncate text-sm font-medium text-ink">{tx.description}</span>
        <span className="mt-1 flex flex-wrap items-center gap-2">
          <CategoryChip category={tx.category} />
          <span className="text-xs text-steel">{shortDate(tx.occurred_at)}</span>
        </span>
      </span>
      <span className="shrink-0 text-right">
        <span
          className={cn(
            "block font-mono text-sm",
            incoming ? "text-emerald-700" : "text-ink",
            tx.status === "failed" && "line-through text-steel",
          )}
        >
          {incoming ? "+" : "−"}
          {money(tx.amount)}
        </span>
        <span className="mt-1 block">
          <StatusBadge status={tx.status} />
        </span>
      </span>
    </button>
  );
}
