
-- ACCOUNTS
CREATE TABLE public.accounts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  name text NOT NULL,
  kind text NOT NULL DEFAULT 'checking',
  number_masked text NOT NULL,
  number_full text NOT NULL,
  currency text NOT NULL DEFAULT 'USD',
  balance numeric(14,2) NOT NULL DEFAULT 0,
  status text NOT NULL DEFAULT 'active',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.accounts TO authenticated;
GRANT ALL ON public.accounts TO service_role;
ALTER TABLE public.accounts ENABLE ROW LEVEL SECURITY;
CREATE POLICY "own accounts" ON public.accounts FOR ALL TO authenticated USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE TRIGGER accounts_set_updated_at BEFORE UPDATE ON public.accounts FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- RECIPIENTS
CREATE TABLE public.recipients (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  name text NOT NULL,
  bank_name text,
  account_masked text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.recipients TO authenticated;
GRANT ALL ON public.recipients TO service_role;
ALTER TABLE public.recipients ENABLE ROW LEVEL SECURITY;
CREATE POLICY "own recipients" ON public.recipients FOR ALL TO authenticated USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE TRIGGER recipients_set_updated_at BEFORE UPDATE ON public.recipients FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- BILLERS
CREATE TABLE public.billers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  name text NOT NULL,
  category text NOT NULL DEFAULT 'utilities',
  account_reference text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.billers TO authenticated;
GRANT ALL ON public.billers TO service_role;
ALTER TABLE public.billers ENABLE ROW LEVEL SECURITY;
CREATE POLICY "own billers" ON public.billers FOR ALL TO authenticated USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE TRIGGER billers_set_updated_at BEFORE UPDATE ON public.billers FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- TRANSACTIONS
CREATE TABLE public.transactions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  account_id uuid NOT NULL REFERENCES public.accounts(id) ON DELETE CASCADE,
  direction text NOT NULL DEFAULT 'out',
  amount numeric(14,2) NOT NULL,
  description text NOT NULL,
  merchant text,
  category text NOT NULL DEFAULT 'general',
  status text NOT NULL DEFAULT 'completed',
  reference text NOT NULL DEFAULT upper(substr(replace(gen_random_uuid()::text,'-',''),1,12)),
  occurred_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.transactions TO authenticated;
GRANT ALL ON public.transactions TO service_role;
ALTER TABLE public.transactions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "own transactions" ON public.transactions FOR ALL TO authenticated USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE INDEX transactions_user_time_idx ON public.transactions (user_id, occurred_at DESC);
CREATE TRIGGER transactions_set_updated_at BEFORE UPDATE ON public.transactions FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- BILL PAYMENTS
CREATE TABLE public.bill_payments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  biller_id uuid NOT NULL REFERENCES public.billers(id) ON DELETE CASCADE,
  account_id uuid REFERENCES public.accounts(id) ON DELETE SET NULL,
  amount numeric(14,2) NOT NULL,
  due_date date NOT NULL DEFAULT (now()::date),
  recurrence text NOT NULL DEFAULT 'once',
  status text NOT NULL DEFAULT 'scheduled',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.bill_payments TO authenticated;
GRANT ALL ON public.bill_payments TO service_role;
ALTER TABLE public.bill_payments ENABLE ROW LEVEL SECURITY;
CREATE POLICY "own bill payments" ON public.bill_payments FOR ALL TO authenticated USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE TRIGGER bill_payments_set_updated_at BEFORE UPDATE ON public.bill_payments FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- CARDS
CREATE TABLE public.cards (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  account_id uuid REFERENCES public.accounts(id) ON DELETE SET NULL,
  brand text NOT NULL DEFAULT 'Aegis Reserve',
  holder_name text NOT NULL DEFAULT 'Aegis Customer',
  number_masked text NOT NULL,
  number_full text NOT NULL,
  expiry text NOT NULL,
  cvv text NOT NULL,
  frozen boolean NOT NULL DEFAULT false,
  spending_limit numeric(14,2) NOT NULL DEFAULT 5000,
  contactless boolean NOT NULL DEFAULT true,
  online_payments boolean NOT NULL DEFAULT true,
  pin text NOT NULL DEFAULT '4821',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.cards TO authenticated;
GRANT ALL ON public.cards TO service_role;
ALTER TABLE public.cards ENABLE ROW LEVEL SECURITY;
CREATE POLICY "own cards" ON public.cards FOR ALL TO authenticated USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE TRIGGER cards_set_updated_at BEFORE UPDATE ON public.cards FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- NOTIFICATION PREFS
CREATE TABLE public.notification_prefs (
  user_id uuid PRIMARY KEY,
  email_alerts boolean NOT NULL DEFAULT true,
  push_alerts boolean NOT NULL DEFAULT false,
  large_transaction_alerts boolean NOT NULL DEFAULT true,
  large_transaction_threshold numeric(14,2) NOT NULL DEFAULT 1000,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.notification_prefs TO authenticated;
GRANT ALL ON public.notification_prefs TO service_role;
ALTER TABLE public.notification_prefs ENABLE ROW LEVEL SECURITY;
CREATE POLICY "own notification prefs" ON public.notification_prefs FOR ALL TO authenticated USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE TRIGGER notification_prefs_set_updated_at BEFORE UPDATE ON public.notification_prefs FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- TRANSFER
CREATE OR REPLACE FUNCTION public.make_transfer(
  _from_account uuid,
  _amount numeric,
  _to_account uuid DEFAULT NULL,
  _recipient_id uuid DEFAULT NULL,
  _note text DEFAULT NULL
) RETURNS public.transactions
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  _uid uuid := auth.uid();
  _from public.accounts;
  _to public.accounts;
  _label text;
  _ref text := upper(substr(replace(gen_random_uuid()::text,'-',''),1,12));
  _tx public.transactions;
BEGIN
  IF _uid IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;
  IF _amount IS NULL OR _amount <= 0 THEN RAISE EXCEPTION 'Enter an amount greater than zero'; END IF;

  SELECT * INTO _from FROM public.accounts WHERE id = _from_account AND user_id = _uid FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Source account not found'; END IF;
  IF _from.balance < _amount THEN RAISE EXCEPTION 'Insufficient funds in %', _from.name; END IF;

  IF _to_account IS NOT NULL THEN
    SELECT * INTO _to FROM public.accounts WHERE id = _to_account AND user_id = _uid FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'Destination account not found'; END IF;
    _label := 'Transfer to ' || _to.name;
  ELSIF _recipient_id IS NOT NULL THEN
    SELECT name INTO _label FROM public.recipients WHERE id = _recipient_id AND user_id = _uid;
    IF _label IS NULL THEN RAISE EXCEPTION 'Recipient not found'; END IF;
    _label := 'Transfer to ' || _label;
  ELSE
    RAISE EXCEPTION 'Choose where to send the money';
  END IF;

  UPDATE public.accounts SET balance = balance - _amount WHERE id = _from.id;

  INSERT INTO public.transactions (user_id, account_id, direction, amount, description, merchant, category, status, reference)
  VALUES (_uid, _from.id, 'out', _amount, COALESCE(NULLIF(_note,''), _label), _label, 'transfer', 'completed', _ref)
  RETURNING * INTO _tx;

  IF _to.id IS NOT NULL THEN
    UPDATE public.accounts SET balance = balance + _amount WHERE id = _to.id;
    INSERT INTO public.transactions (user_id, account_id, direction, amount, description, merchant, category, status, reference)
    VALUES (_uid, _to.id, 'in', _amount, 'Transfer from ' || _from.name, _from.name, 'transfer', 'completed', _ref);
  END IF;

  RETURN _tx;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.make_transfer(uuid, numeric, uuid, uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.make_transfer(uuid, numeric, uuid, uuid, text) TO authenticated;

-- PAY BILL
CREATE OR REPLACE FUNCTION public.pay_bill(
  _biller_id uuid,
  _account_id uuid,
  _amount numeric,
  _due_date date DEFAULT NULL,
  _recurrence text DEFAULT 'once'
) RETURNS public.bill_payments
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  _uid uuid := auth.uid();
  _acct public.accounts;
  _biller public.billers;
  _when date := COALESCE(_due_date, now()::date);
  _payment public.bill_payments;
BEGIN
  IF _uid IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;
  IF _amount IS NULL OR _amount <= 0 THEN RAISE EXCEPTION 'Enter an amount greater than zero'; END IF;

  SELECT * INTO _biller FROM public.billers WHERE id = _biller_id AND user_id = _uid;
  IF NOT FOUND THEN RAISE EXCEPTION 'Biller not found'; END IF;

  SELECT * INTO _acct FROM public.accounts WHERE id = _account_id AND user_id = _uid FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Account not found'; END IF;

  IF _when <= now()::date THEN
    IF _acct.balance < _amount THEN RAISE EXCEPTION 'Insufficient funds in %', _acct.name; END IF;
    UPDATE public.accounts SET balance = balance - _amount WHERE id = _acct.id;
    INSERT INTO public.transactions (user_id, account_id, direction, amount, description, merchant, category, status)
    VALUES (_uid, _acct.id, 'out', _amount, _biller.name || ' bill payment', _biller.name, _biller.category, 'completed');
    INSERT INTO public.bill_payments (user_id, biller_id, account_id, amount, due_date, recurrence, status)
    VALUES (_uid, _biller.id, _acct.id, _amount, _when, _recurrence, 'paid') RETURNING * INTO _payment;
  ELSE
    INSERT INTO public.bill_payments (user_id, biller_id, account_id, amount, due_date, recurrence, status)
    VALUES (_uid, _biller.id, _acct.id, _amount, _when, _recurrence, 'scheduled') RETURNING * INTO _payment;
  END IF;

  RETURN _payment;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.pay_bill(uuid, uuid, numeric, date, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.pay_bill(uuid, uuid, numeric, date, text) TO authenticated;

-- SEED DEMO DATA (idempotent)
CREATE OR REPLACE FUNCTION public.ensure_demo_data()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  _uid uuid := auth.uid();
  _checking uuid; _savings uuid; _custody uuid;
  _name text;
  i int;
  _merchants text[] := ARRAY['Blue Bottle Coffee','Whole Foods Market','Transit Authority','Apple Services','Shell Energy','Aurora Pharmacy','Kindred Books','Metro Taxi','Lumen Fitness','Nordic Home'];
  _cats text[] := ARRAY['dining','groceries','transport','subscriptions','utilities','health','shopping','transport','health','shopping'];
BEGIN
  IF _uid IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;
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
  VALUES (_uid, _checking, _name, '•••• •••• •••• 4821', '4921 8830 1174 4821', '09/29', '318', 6000);

  INSERT INTO public.recipients (user_id, name, bank_name, account_masked) VALUES
    (_uid, 'Elena Marsh', 'Northbank', '•••• 2214'),
    (_uid, 'Harbor Studio LLC', 'First Meridian', '•••• 8830'),
    (_uid, 'Tomas Iyer', 'Cascade Credit Union', '•••• 5567');

  INSERT INTO public.billers (user_id, name, category, account_reference) VALUES
    (_uid, 'Shell Energy', 'utilities', 'ACC-49213'),
    (_uid, 'Cityline Water', 'utilities', 'CW-88134'),
    (_uid, 'Fiberlink Internet', 'internet', 'FL-22190'),
    (_uid, 'Meridian Insurance', 'insurance', 'MI-77021');

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
$$;
REVOKE EXECUTE ON FUNCTION public.ensure_demo_data() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.ensure_demo_data() TO authenticated;
