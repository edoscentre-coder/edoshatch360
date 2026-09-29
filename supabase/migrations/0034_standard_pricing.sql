-- One price list across every EDOS product. See the matching migration in
-- EDOS CRM (0020_standard_pricing.sql) for the full reasoning.
--
--   Starter  4,499/month   up to 5 users
--   Growth   7,499/month   up to 20 users
--   Pro     11,499/month   unlimited
--
-- Onboarding is quoted per organisation, never published.
--
-- Hatch360 priced itself well below the rest of the estate — 1,500 / 2,500 /
-- 7,500 — and carried a fourth "Enterprise" tier quoted on application. Three tiers and one price list now, matching every other
-- product, so a customer asking about two EDOS systems is told the same
-- numbers for both.
--
-- What is NOT levelled: max_farms, max_houses and max_birds. Those are real
-- entitlements specific to poultry and have no equivalent elsewhere, so they
-- stay as they are. Only the user ladder is aligned, because that is the
-- limit every product shares.
--
-- 'professional' keeps its code and is renamed to Pro. The code is what
-- subscriptions reference, so renaming the display text is safe while changing
-- the code would not be. 'enterprise' is deactivated rather than deleted — it
-- has no subscribers, and a deleted plan would break any historic row that
-- ever pointed at it. Set is_active back to true to bring it out of retirement.

alter table public.edoshatch360_plans
  add column if not exists onboarding_fee_cents bigint;

update public.edoshatch360_plans
   set price_cents          = 449900,
       max_users            = 5,
       name                 = 'Starter'
 where code = 'starter';

update public.edoshatch360_plans
   set price_cents          = 749900,
       max_users            = 20,
       name                 = 'Growth'
 where code = 'growth';

update public.edoshatch360_plans
   set price_cents          = 1149900,
       max_users            = null,
       name                 = 'Pro'
 where code = 'professional';

update public.edoshatch360_plans
   set is_active = false
 where code = 'enterprise';
--
-- Onboarding is NOT published. `onboarding_fee_cents` stays null, which this
-- schema already defines as "quoted per organisation rather than published".
-- What the work costs depends on the plan taken and on what the customer is
-- carrying across, and neither is known until we have spoken to them — so it
-- is agreed with the customer and put in writing before they commit. A
-- published figure would be wrong for most of them.
