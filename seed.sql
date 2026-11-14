USE expense_splitter;

-- Reset tables so this file can be re-run safely
-- (TRUNCATE also restarts the AUTO_INCREMENT counters, which the fixed IDs below rely on)
SET FOREIGN_KEY_CHECKS = 0;
TRUNCATE TABLE settlements;
TRUNCATE TABLE expense_splits;
TRUNCATE TABLE expense_payers;
TRUNCATE TABLE expenses;
TRUNCATE TABLE group_members;
TRUNCATE TABLE expense_groups;
TRUNCATE TABLE users;
SET FOREIGN_KEY_CHECKS = 1;

-- ---------------------------------------------------------------------
-- Users (1 Ravi, 2 Sita, 3 Arjun, 4 Meena)
-- password_hash values are placeholders for testing only, not real hashes
-- ---------------------------------------------------------------------
INSERT INTO users (name, email, password_hash) VALUES
  ('Ravi',  'ravi@example.com',  'SEED_ONLY_NOT_A_REAL_HASH'),
  ('Sita',  'sita@example.com',  'SEED_ONLY_NOT_A_REAL_HASH'),
  ('Arjun', 'arjun@example.com', 'SEED_ONLY_NOT_A_REAL_HASH'),
  ('Meena', 'meena@example.com', 'SEED_ONLY_NOT_A_REAL_HASH');

-- ---------------------------------------------------------------------
-- Groups (1 Goa Trip, 2 Flatmates) and their members
-- ---------------------------------------------------------------------
INSERT INTO expense_groups (group_name, created_by) VALUES
  ('Goa Trip', 1),
  ('Flatmates', 1);

INSERT INTO group_members (group_id, user_id) VALUES
  (1, 1), (1, 2), (1, 3), (1, 4),     -- Goa Trip: Ravi, Sita, Arjun, Meena
  (2, 1), (2, 2), (2, 3);             -- Flatmates: Ravi, Sita, Arjun

-- ---------------------------------------------------------------------
-- Expenses
-- ---------------------------------------------------------------------
INSERT INTO expenses (group_id, description, place, category, total_amount, expense_date, created_by) VALUES
  (1, 'Breakfast', 'Beach Cafe',    'Food',          400.00, '2026-11-01', 1),   -- expense 1
  (1, 'Taxi',      'Airport',       'Travel',        600.00, '2026-11-01', 2),   -- expense 2
  (1, 'Dinner',    'Seafood Shack', 'Food',          900.00, '2026-11-02', 3),   -- expense 3
  (1, 'Tickets',   'Water Park',    'Entertainment', 800.00, '2026-11-03', 1),   -- expense 4
  (2, 'Dinner',    NULL,            'Food',          900.00, '2026-11-05', 1),   -- expense 5
  (2, 'Taxi',      NULL,            'Travel',        300.00, '2026-11-06', 2);   -- expense 6

-- ---------------------------------------------------------------------
-- Who paid (expense 4 has two payers)
-- ---------------------------------------------------------------------
INSERT INTO expense_payers (expense_id, user_id, amount_paid) VALUES
  (1, 1, 400),                 -- Breakfast: Ravi paid all
  (2, 2, 600),                 -- Taxi: Sita paid all
  (3, 3, 900),                 -- Dinner: Arjun paid all
  (4, 1, 500), (4, 4, 300),    -- Tickets: Ravi paid 500, Meena paid 300
  (5, 1, 900),                 -- Flatmates dinner: Ravi paid all
  (6, 2, 300);                 -- Flatmates taxi: Sita paid all

-- ---------------------------------------------------------------------
-- Who took part and how much each owes (different people each time)
-- ---------------------------------------------------------------------
INSERT INTO expense_splits (expense_id, user_id, amount_owed) VALUES
  (1, 1, 100), (1, 2, 100), (1, 3, 100), (1, 4, 100),   -- Breakfast: all 4
  (2, 1, 200), (2, 2, 200), (2, 3, 200),                -- Taxi: Meena stayed behind
  (3, 2, 300), (3, 3, 300), (3, 4, 300),                -- Dinner: Ravi left early
  (4, 1, 200), (4, 2, 200), (4, 3, 200), (4, 4, 200),   -- Tickets: all 4
  (5, 1, 300), (5, 2, 300), (5, 3, 300),                -- Flatmates dinner
  (6, 1, 100), (6, 2, 100), (6, 3, 100);                -- Flatmates taxi

-- ---------------------------------------------------------------------
-- A settlement: Meena paid Ravi 100 in the Goa Trip group
-- ---------------------------------------------------------------------
INSERT INTO settlements (group_id, paid_by, paid_to, amount, settled_on) VALUES
  (1, 4, 1, 100, '2026-11-04');

-- ---------------------------------------------------------------------
-- Expected net balances (check these against queries.sql, query 5)
--   Goa Trip  : Ravi +300, Sita -200, Arjun +100, Meena -200   (sum 0)
--               (before the settlement: +400, -200, +100, -300)
--   Flatmates : Ravi +500, Sita -100, Arjun -400               (sum 0)
-- ---------------------------------------------------------------------
