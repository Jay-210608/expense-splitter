CREATE DATABASE IF NOT EXISTS expense_splitter;
USE expense_splitter;

CREATE TABLE IF NOT EXISTS Users (
  user_id INT PRIMARY KEY AUTO_INCREMENT,
  name VARCHAR(50) NOT NULL
);

CREATE TABLE IF NOT EXISTS Expenses (
  expense_id INT PRIMARY KEY AUTO_INCREMENT,
  description VARCHAR(100) NOT NULL,
  amount DECIMAL(10,2) NOT NULL,
  paid_by INT NOT NULL,
  FOREIGN KEY (paid_by) REFERENCES Users(user_id)
);

CREATE TABLE IF NOT EXISTS Splits (
  split_id INT PRIMARY KEY AUTO_INCREMENT,
  expense_id INT NOT NULL,
  user_id INT NOT NULL,
  share DECIMAL(10,2) NOT NULL,
  FOREIGN KEY (expense_id) REFERENCES Expenses(expense_id),
  FOREIGN KEY (user_id) REFERENCES Users(user_id)
);

SHOW TABLES;