-- =====================================================================
-- Expense Splitter - database schema
-- Requires MySQL 8.0.16+ (CHECK constraints are enforced from this version)
--
-- WARNING: development reset. This file DROPS the whole database and
-- recreates it, so every run starts clean. Do not run it after you have
-- entered data you want to keep.
-- =====================================================================

DROP DATABASE IF EXISTS expense_splitter;

CREATE DATABASE expense_splitter
  DEFAULT CHARACTER SET utf8mb4
  DEFAULT COLLATE utf8mb4_unicode_ci;

USE expense_splitter;

-- ---------------------------------------------------------------------
-- users: people who use the app
-- ---------------------------------------------------------------------
CREATE TABLE users (
  user_id       INT PRIMARY KEY AUTO_INCREMENT,
  name          VARCHAR(50)  NOT NULL,
  email         VARCHAR(100) NOT NULL UNIQUE,
  password_hash VARCHAR(255) NOT NULL,          -- store a hash, never the plain password
  created_at    TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- ---------------------------------------------------------------------
-- expense_groups: a trip, a flat, a friend circle, etc.
-- (named expense_groups because GROUPS is a reserved word in MySQL 8)
-- ---------------------------------------------------------------------
CREATE TABLE expense_groups (
  group_id    INT PRIMARY KEY AUTO_INCREMENT,
  group_name  VARCHAR(60) NOT NULL,
  created_by  INT         NOT NULL,
  created_at  TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_groups_creator
    FOREIGN KEY (created_by) REFERENCES users(user_id)
);

-- ---------------------------------------------------------------------
-- group_members: many-to-many link between users and groups
-- ---------------------------------------------------------------------
CREATE TABLE group_members (
  group_id   INT       NOT NULL,
  user_id    INT       NOT NULL,
  joined_at  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (group_id, user_id),              -- a user can join a group only once
  CONSTRAINT fk_gm_group
    FOREIGN KEY (group_id) REFERENCES expense_groups(group_id) ON DELETE CASCADE,
  CONSTRAINT fk_gm_user
    FOREIGN KEY (user_id)  REFERENCES users(user_id)
);

-- ---------------------------------------------------------------------
-- expenses: one row per shared expense (who paid and who owes live in
-- expense_payers and expense_splits)
-- ---------------------------------------------------------------------
CREATE TABLE expenses (
  expense_id    INT PRIMARY KEY AUTO_INCREMENT,
  group_id      INT           NOT NULL,
  description   VARCHAR(100)  NOT NULL,
  place         VARCHAR(100)  NULL,
  category      VARCHAR(30)   NULL,
  total_amount  DECIMAL(10,2) NOT NULL,
  expense_date  DATE          NOT NULL DEFAULT (CURRENT_DATE),
  created_by    INT           NOT NULL,         -- who entered it into the app
  created_at    TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT chk_expense_total CHECK (total_amount > 0),
  CONSTRAINT fk_expenses_group
    FOREIGN KEY (group_id)   REFERENCES expense_groups(group_id) ON DELETE CASCADE,
  CONSTRAINT fk_expenses_creator
    FOREIGN KEY (created_by) REFERENCES users(user_id),
  INDEX idx_expenses_group_date (group_id, expense_date)
);

-- ---------------------------------------------------------------------
-- expense_payers: who paid, and how much (one or more rows per expense)
-- ---------------------------------------------------------------------
CREATE TABLE expense_payers (
  expense_id   INT           NOT NULL,
  user_id      INT           NOT NULL,
  amount_paid  DECIMAL(10,2) NOT NULL,
  PRIMARY KEY (expense_id, user_id),
  CONSTRAINT chk_payer_amount CHECK (amount_paid > 0),
  CONSTRAINT fk_payers_expense
    FOREIGN KEY (expense_id) REFERENCES expenses(expense_id) ON DELETE CASCADE,
  CONSTRAINT fk_payers_user
    FOREIGN KEY (user_id)    REFERENCES users(user_id)
);

-- ---------------------------------------------------------------------
-- expense_splits: who took part, and how much each person owes
-- (only participants get a row; the payer need not appear here)
-- ---------------------------------------------------------------------
CREATE TABLE expense_splits (
  expense_id   INT           NOT NULL,
  user_id      INT           NOT NULL,
  amount_owed  DECIMAL(10,2) NOT NULL,
  PRIMARY KEY (expense_id, user_id),            -- no duplicate person per expense
  CONSTRAINT chk_split_amount CHECK (amount_owed >= 0),
  CONSTRAINT fk_splits_expense
    FOREIGN KEY (expense_id) REFERENCES expenses(expense_id) ON DELETE CASCADE,
  CONSTRAINT fk_splits_user
    FOREIGN KEY (user_id)    REFERENCES users(user_id)
);

-- ---------------------------------------------------------------------
-- settlements: a direct payment from one member to another
-- (paid_by pays paid_to; this reduces what paid_by owes)
-- ---------------------------------------------------------------------
CREATE TABLE settlements (
  settlement_id  INT PRIMARY KEY AUTO_INCREMENT,
  group_id       INT           NOT NULL,
  paid_by        INT           NOT NULL,
  paid_to        INT           NOT NULL,
  amount         DECIMAL(10,2) NOT NULL,
  settled_on     DATE          NOT NULL DEFAULT (CURRENT_DATE),
  created_at     TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT chk_settlement_amount CHECK (amount > 0),
  CONSTRAINT chk_settlement_people CHECK (paid_by <> paid_to),
  CONSTRAINT fk_settle_group
    FOREIGN KEY (group_id) REFERENCES expense_groups(group_id) ON DELETE CASCADE,
  CONSTRAINT fk_settle_from
    FOREIGN KEY (paid_by)  REFERENCES users(user_id),
  CONSTRAINT fk_settle_to
    FOREIGN KEY (paid_to)  REFERENCES users(user_id)
);

-- ---------------------------------------------------------------------
-- group_balances (view): the balance of every member in every group
--   net_balance = total_paid - total_owed + settled_out - settled_in
--   positive  -> the member gets money back
--   negative  -> the member owes money
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW group_balances AS
SELECT
  gm.group_id,
  gm.user_id,
  u.name,
  COALESCE(p.total_paid, 0)   AS total_paid,
  COALESCE(o.total_owed, 0)   AS total_owed,
  COALESCE(so.amount_out, 0)  AS settled_out,
  COALESCE(si.amount_in, 0)   AS settled_in,
  COALESCE(p.total_paid, 0)
    - COALESCE(o.total_owed, 0)
    + COALESCE(so.amount_out, 0)
    - COALESCE(si.amount_in, 0) AS net_balance
FROM group_members gm
JOIN users u ON u.user_id = gm.user_id
LEFT JOIN (
  SELECT e.group_id, ep.user_id, SUM(ep.amount_paid) AS total_paid
  FROM expense_payers ep
  JOIN expenses e ON e.expense_id = ep.expense_id
  GROUP BY e.group_id, ep.user_id
) p ON p.group_id = gm.group_id AND p.user_id = gm.user_id
LEFT JOIN (
  SELECT e.group_id, es.user_id, SUM(es.amount_owed) AS total_owed
  FROM expense_splits es
  JOIN expenses e ON e.expense_id = es.expense_id
  GROUP BY e.group_id, es.user_id
) o ON o.group_id = gm.group_id AND o.user_id = gm.user_id
LEFT JOIN (
  SELECT group_id, paid_by AS user_id, SUM(amount) AS amount_out
  FROM settlements
  GROUP BY group_id, paid_by
) so ON so.group_id = gm.group_id AND so.user_id = gm.user_id
LEFT JOIN (
  SELECT group_id, paid_to AS user_id, SUM(amount) AS amount_in
  FROM settlements
  GROUP BY group_id, paid_to
) si ON si.group_id = gm.group_id AND si.user_id = gm.user_id;

SHOW TABLES;
