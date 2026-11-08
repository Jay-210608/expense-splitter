USE expense_splitter;

-- 1. Who owes whom, per expense
SELECT e.description, u.name AS owes, p.name AS paid_by, s.share
FROM Splits s
JOIN Users u ON s.user_id = u.user_id
JOIN Expenses e ON s.expense_id = e.expense_id
JOIN Users p ON e.paid_by = p.user_id
WHERE s.user_id <> e.paid_by;

-- 2. Total paid by each user
SELECT u.name, COALESCE(SUM(e.amount), 0) AS total_paid
FROM Users u
LEFT JOIN Expenses e ON e.paid_by = u.user_id
GROUP BY u.user_id, u.name;

-- 3. Total share owed by each user
SELECT u.name, COALESCE(SUM(s.share), 0) AS total_share
FROM Users u
LEFT JOIN Splits s ON s.user_id = u.user_id
GROUP BY u.user_id, u.name;

-- 4. Net balance (positive = gets money back, negative = owes money)
SELECT u.name,
  COALESCE((SELECT SUM(amount) FROM Expenses WHERE paid_by = u.user_id), 0)
  - COALESCE((SELECT SUM(share) FROM Splits WHERE user_id = u.user_id), 0)
  AS net_balance
FROM Users u;