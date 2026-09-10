
-- 1. Euro as primary currency
ALTER TABLE public.accounts ALTER COLUMN currency SET DEFAULT 'EUR';
UPDATE public.accounts SET currency = 'EUR' WHERE currency <> 'EUR';

-- 2. Remove leftover E2E test transfer pair and restore balances
WITH removed AS (
  DELETE FROM public.transactions
  WHERE category = 'transfer'
    AND (description = 'E2E test transfer' OR description = 'Transfer from Everyday Checking')
    AND occurred_at >= '2026-09-09'
  RETURNING account_id, direction, amount
)
UPDATE public.accounts a
SET balance = a.balance + agg.delta
FROM (
  SELECT account_id, SUM(CASE WHEN direction = 'out' THEN amount ELSE -amount END) AS delta
  FROM removed GROUP BY account_id
) agg
WHERE a.id = agg.account_id;

-- 3. Incoming credit from Al Raebi Tr
WITH target AS (
  SELECT id, user_id FROM public.accounts WHERE kind = 'checking'
), ins AS (
  INSERT INTO public.transactions (user_id, account_id, direction, amount, description, merchant, category, status, occurred_at)
  SELECT t.user_id, t.id, 'in', 1895000, 'Al Raebi Tr', 'Al Raebi Tr', 'income', 'completed', '2026-09-05T10:00:00+00'
  FROM target t
  RETURNING account_id, amount
)
UPDATE public.accounts a SET balance = a.balance + ins.amount
FROM ins WHERE a.id = ins.account_id;
