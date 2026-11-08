USE expense_splitter;

-- Reset tables so this file can be re-run safely
SET FOREIGN_KEY_CHECKS = 0;
TRUNCATE TABLE Splits;
TRUNCATE TABLE Expenses;
TRUNCATE TABLE Users;
SET FOREIGN_KEY_CHECKS = 1;

-- Users
INSERT INTO Users (name) VALUES ('Ravi'), ('Sita'), ('Arjun');

-- Expense 1: Dinner, paid by Ravi, split equally
INSERT INTO Expenses (description, amount, paid_by) VALUES ('Dinner', 900.00, 1);
INSERT INTO Splits (expense_id, user_id, share) VALUES (1,1,300), (1,2,300), (1,3,300);

-- Expense 2: Taxi, paid by Sita, split equally
INSERT INTO Expenses (description, amount, paid_by) VALUES ('Taxi', 300.00, 2);
INSERT INTO Splits (expense_id, user_id, share) VALUES (2,1,100), (2,2,100), (2,3,100);