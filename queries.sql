USE expense_splitter;

-- 1. All expenses, grouped by group
SELECT g.group_name, e.expense_id, e.description, e.category, e.place,
       e.expense_date, e.total_amount, u.name AS recorded_by
FROM expenses e
JOIN expense_groups g ON g.group_id = e.group_id
JOIN users u          ON u.user_id  = e.created_by
ORDER BY g.group_name, e.expense_date, e.expense_id;

-- 2. Who paid what, per expense (an expense can have several payers)
SELECT e.expense_id, e.description, u.name AS paid_by, ep.amount_paid
FROM expense_payers ep
JOIN expenses e ON e.expense_id = ep.expense_id
JOIN users u    ON u.user_id    = ep.user_id
ORDER BY e.expense_id, u.name;

-- 3. Who owes what, per expense (only the people who took part)
SELECT e.expense_id, e.description, u.name AS participant, es.amount_owed
FROM expense_splits es
JOIN expenses e ON e.expense_id = es.expense_id
JOIN users u    ON u.user_id    = es.user_id
ORDER BY e.expense_id, u.name;

-- 4. Total paid and total owed by each member, per group
SELECT g.group_name, v.name, v.total_paid, v.total_owed
FROM group_balances v
JOIN expense_groups g ON g.group_id = v.group_id
ORDER BY g.group_name, v.name;

-- 5. Net balance per member, per group (includes settlements)
--    positive = gets money back, negative = owes money
SELECT g.group_name, v.name, v.net_balance,
       CASE
         WHEN v.net_balance > 0 THEN 'gets back'
         WHEN v.net_balance < 0 THEN 'owes'
         ELSE 'settled'
       END AS status
FROM group_balances v
JOIN expense_groups g ON g.group_id = v.group_id
ORDER BY g.group_name, v.net_balance DESC;

-- 6. Settlement history
SELECT g.group_name, f.name AS paid_by, t.name AS paid_to, s.amount, s.settled_on
FROM settlements s
JOIN expense_groups g ON g.group_id = s.group_id
JOIN users f          ON f.user_id  = s.paid_by
JOIN users t          ON t.user_id  = s.paid_to
ORDER BY s.settled_on, s.settlement_id;

-- 7. Members of each group
SELECT g.group_name,
       COUNT(gm.user_id) AS member_count,
       GROUP_CONCAT(u.name ORDER BY u.name SEPARATOR ', ') AS members
FROM expense_groups g
JOIN group_members gm ON gm.group_id = g.group_id
JOIN users u          ON u.user_id   = gm.user_id
GROUP BY g.group_id, g.group_name;

-- 8. Groups whose total spending is above 1500 (GROUP BY + HAVING)
SELECT g.group_name,
       COUNT(e.expense_id)  AS expense_count,
       SUM(e.total_amount)  AS total_spent
FROM expense_groups g
JOIN expenses e ON e.group_id = g.group_id
GROUP BY g.group_id, g.group_name
HAVING SUM(e.total_amount) > 1500;

-- 9. Spending by category, per group
SELECT g.group_name,
       COALESCE(e.category, 'Uncategorised') AS category,
       SUM(e.total_amount) AS total_spent
FROM expenses e
JOIN expense_groups g ON g.group_id = e.group_id
GROUP BY g.group_id, g.group_name, COALESCE(e.category, 'Uncategorised')
ORDER BY g.group_name, total_spent DESC;

-- ---------------------------------------------------------------------
-- Integrity checks (both should return NO ROWS when the data is correct)
-- ---------------------------------------------------------------------

-- 10. Expenses where the payer amounts or the split amounts do not add up to the total
SELECT e.expense_id, e.description, e.total_amount,
       COALESCE(p.paid_sum, 0) AS payers_sum,
       COALESCE(s.owed_sum, 0) AS splits_sum
FROM expenses e
LEFT JOIN (
  SELECT expense_id, SUM(amount_paid) AS paid_sum
  FROM expense_payers
  GROUP BY expense_id
) p ON p.expense_id = e.expense_id
LEFT JOIN (
  SELECT expense_id, SUM(amount_owed) AS owed_sum
  FROM expense_splits
  GROUP BY expense_id
) s ON s.expense_id = e.expense_id
WHERE COALESCE(p.paid_sum, 0) <> e.total_amount
   OR COALESCE(s.owed_sum, 0) <> e.total_amount;

-- 11. Groups whose net balances do not add up to zero
SELECT group_id, SUM(net_balance) AS should_be_zero
FROM group_balances
GROUP BY group_id
HAVING SUM(net_balance) <> 0;
