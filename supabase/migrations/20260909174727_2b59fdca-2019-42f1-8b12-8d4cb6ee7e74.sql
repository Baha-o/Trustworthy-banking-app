-- 1. Identify duplicate accounts (keep earliest per user_id + number_masked)
CREATE TEMP TABLE _dup_accounts ON COMMIT DROP AS
SELECT id FROM (
  SELECT id, row_number() OVER (PARTITION BY user_id, number_masked ORDER BY created_at, id) AS rn
  FROM public.accounts
) t WHERE rn > 1;

DELETE FROM public.bill_payments WHERE account_id IN (SELECT id FROM _dup_accounts);
DELETE FROM public.transactions WHERE account_id IN (SELECT id FROM _dup_accounts);
DELETE FROM public.cards WHERE account_id IN (SELECT id FROM _dup_accounts);
DELETE FROM public.accounts WHERE id IN (SELECT id FROM _dup_accounts);

-- 2. Duplicate billers / recipients / cards
DELETE FROM public.bill_payments bp
WHERE bp.biller_id IN (
  SELECT id FROM (
    SELECT id, row_number() OVER (PARTITION BY user_id, name ORDER BY created_at, id) AS rn
    FROM public.billers
  ) t WHERE rn > 1
);

DELETE FROM public.billers WHERE id IN (
  SELECT id FROM (
    SELECT id, row_number() OVER (PARTITION BY user_id, name ORDER BY created_at, id) AS rn
    FROM public.billers
  ) t WHERE rn > 1
);

DELETE FROM public.recipients WHERE id IN (
  SELECT id FROM (
    SELECT id, row_number() OVER (PARTITION BY user_id, account_masked ORDER BY created_at, id) AS rn
    FROM public.recipients
  ) t WHERE rn > 1
);

DELETE FROM public.cards WHERE id IN (
  SELECT id FROM (
    SELECT id, row_number() OVER (PARTITION BY user_id, number_masked ORDER BY created_at, id) AS rn
    FROM public.cards
  ) t WHERE rn > 1
);

-- 3. Uniqueness guards
CREATE UNIQUE INDEX IF NOT EXISTS accounts_user_number_uidx ON public.accounts (user_id, number_masked);
CREATE UNIQUE INDEX IF NOT EXISTS billers_user_name_uidx ON public.billers (user_id, name);
CREATE UNIQUE INDEX IF NOT EXISTS recipients_user_account_uidx ON public.recipients (user_id, account_masked);
CREATE UNIQUE INDEX IF NOT EXISTS cards_user_number_uidx ON public.cards (user_id, number_masked);

-- 4. Idempotent seeding under an advisory lock
CREATE OR REPLACE FUNCTION public.ensure_demo_data()
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  _uid uuid := auth.uid();
  _checking uuid; _savings uuid; _custody uuid;
  _name text;
  i int;
  _merchants text[] := ARRAY['Blue Bottle Coffee','Whole Foods Market','Transit Authority','Apple Services','Shell Energy','Aurora Pharmacy','Kindred Books','Metro Taxi','Lumen Fitness','Nordic Home'];
  _cats text[] := ARRAY['dining','groceries','transport','subscriptions','utilities','health','shopping','transport','health','shopping'];
BEGIN
  IF _uid IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;

  PERFORM pg_advisory_xact_lock(hashtextextended(_uid::text, 0));

  IF EXISTS (SELECT 1 FROM public.accounts WHERE user_id = _uid) THEN RETURN; END IF;

  SELECT COALESCE(NULLIF(full_name,''), 'Aegis Customer') INTO _name FROM public.profiles WHERE id = _uid;
  _name := COALESCE(_name, 'Aegis Customer');

  INSERT INTO public.accounts (user_id, name, kind, number_masked, number_full, balance)
  VALUES (_uid, 'Everyday Checking', 'checking', '•••• 4821', '4000 1123 8890 4821', 12480.55) RETURNING id INTO _checking;
  INSERT INTO public.accounts (user_id, name, kind, number_masked, number_full, balance)
  VALUES (_uid, 'Reserve Savings', 'savings', '•••• 7304', '4000 5561 2210 7304', 48210.00) RETURNING id INTO _savings;
  INSERT INTO public.accounts (user_id, name, kind, number_masked, number_full, balance)
  VALUES (_uid, 'Custody Portfolio', 'custody', '•••• 9017', '4000 8842 6675 9017', 156300.25) RETURNING id INTO _custody;

  INSERT INTO public.cards (user_id, account_id, holder_name, number_masked, number_full, expiry, cvv, spending_limit)
  VALUES (_uid, _checking, _name, '•••• •••• •••• 4821', '4921 8830 1174 4821', '09/29', '318', 6000)
  ON CONFLICT DO NOTHING;

  INSERT INTO public.recipients (user_id, name, bank_name, account_masked) VALUES
    (_uid, 'Elena Marsh', 'Northbank', '•••• 2214'),
    (_uid, 'Harbor Studio LLC', 'First Meridian', '•••• 8830'),
    (_uid, 'Tomas Iyer', 'Cascade Credit Union', '•••• 5567')
  ON CONFLICT DO NOTHING;

  INSERT INTO public.billers (user_id, name, category, account_reference) VALUES
    (_uid, 'Shell Energy', 'utilities', 'ACC-49213'),
    (_uid, 'Cityline Water', 'utilities', 'CW-88134'),
    (_uid, 'Fiberlink Internet', 'internet', 'FL-22190'),
    (_uid, 'Meridian Insurance', 'insurance', 'MI-77021')
  ON CONFLICT DO NOTHING;

  FOR i IN 1..42 LOOP
    INSERT INTO public.transactions (user_id, account_id, direction, amount, description, merchant, category, status, occurred_at)
    VALUES (
      _uid,
      CASE WHEN i % 7 = 0 THEN _savings ELSE _checking END,
      CASE WHEN i % 9 = 0 THEN 'in' ELSE 'out' END,
      ROUND((random() * 320 + 8)::numeric, 2),
      CASE WHEN i % 9 = 0 THEN 'Salary deposit' ELSE _merchants[1 + (i % 10)] END,
      CASE WHEN i % 9 = 0 THEN 'Aegis Payroll' ELSE _merchants[1 + (i % 10)] END,
      CASE WHEN i % 9 = 0 THEN 'income' ELSE _cats[1 + (i % 10)] END,
      CASE WHEN i = 1 THEN 'pending' WHEN i = 5 THEN 'failed' ELSE 'completed' END,
      now() - (i * interval '2 days') - (i * interval '37 minutes')
    );
  END LOOP;

  INSERT INTO public.notification_prefs (user_id) VALUES (_uid) ON CONFLICT DO NOTHING;
END;
$function$;