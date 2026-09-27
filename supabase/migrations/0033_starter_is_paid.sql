-- Starter is KSh 1,500 a month.
--
-- It was free, which left a new farm with nothing to decide at the end of a
-- trial: the trial granted the full paid product and then dropped to a plan
-- that cost nothing, so there was never a moment to pay. Every plan is now
-- a paid plan except Enterprise, which is priced on a conversation.
--
-- Prices are rows rather than constants — the admin console edits them and
-- the marketing page re-renders from the table (see 0011), so this is a data
-- change, not a code one. The seed in 0011 carries the same figure for a
-- fresh environment.
--
-- Stored in cents, as every amount in this schema is: 150000 = KSh 1,500.
update edoshatch360_plans
set price_cents = 150000,
    description = 'Everything you need to know your birds, your feed and your money.'
where code = 'starter';

-- The pricing FAQ promised Starter was free "for as long as you need it",
-- which is the one place on the site a visitor goes to have exactly this
-- question answered. It now answers the question they will actually have.
update edoshatch360_cms_faqs
set question = 'What happens after the free trial?',
    answer = 'The first two weeks are free and need no card. After that Starter is KSh 1,500 a month for one farm, up to two houses and 500 birds; you only pay more when your farm outgrows it.'
where question = 'Is the Starter plan really free?';
