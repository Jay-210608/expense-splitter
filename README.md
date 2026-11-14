# Expense Splitter (DBMS Case Study)

A database application that tracks shared expenses inside groups (a trip, a flat, a friend circle) and calculates who owes whom. Each expense can have one or more payers and a different set of participants, and settlements reduce the balances.

## Tables
| Table | Purpose |
|-------|---------|
| `users` | People who use the app (name, unique email, password hash) |
| `expense_groups` | Groups such as "Goa Trip" |
| `group_members` | Which users belong to which group (many-to-many) |
| `expenses` | One row per expense: description, place, category, total, date |
| `expense_payers` | Who paid and how much (one or more rows per expense) |
| `expense_splits` | Who took part and how much each person owes |
| `settlements` | A direct payment from one member to another |
| `group_balances` (view) | Net balance of every member in every group |

## Relationships
- A user can belong to many groups, and a group has many users (`group_members`).
- A group has many expenses.
- An expense has one or more payers (`expense_payers`) and one or more participants (`expense_splits`).
- A settlement belongs to a group and links a payer user to a receiver user.

## How balances are calculated
```
net_balance = total_paid - total_owed + settlements_paid - settlements_received
```
A positive balance means the member gets money back. A negative balance means the member owes money. The balances of a group always add up to zero.

## How to run
Requires **MySQL 8.0.16 or newer** (earlier versions ignore `CHECK` constraints).
1. Run `schema.sql` to create the database, tables and view. **It drops and recreates the `expense_splitter` database**, so use it only for development.
2. Run `seed.sql` to load sample data.
3. Run `queries.sql` to see the results.

## Expected results (sample data)
Query 5 (net balance per member) should show:

| Group | Member | Net balance |
|-------|--------|-------------|
| Goa Trip | Ravi | +300 |
| Goa Trip | Arjun | +100 |
| Goa Trip | Sita | -200 |
| Goa Trip | Meena | -200 |
| Flatmates | Ravi | +500 |
| Flatmates | Sita | -100 |
| Flatmates | Arjun | -400 |

Queries 10 and 11 are integrity checks and should return no rows.

## Rules the Java application enforces
These cannot be expressed as simple column constraints, so the application checks them before saving, inside one transaction:
- The payer amounts add up to the expense total.
- The split amounts add up to the expense total.
- Every payer and participant is a member of the expense's group.
- Each expense has at least one payer and one participant.
- Equal splits that leave a remainder (for example 100 / 3) follow one fixed rounding rule.

## Queries
1. All expenses, grouped by group
2. Who paid what, per expense
3. Who owes what, per expense
4. Total paid and total owed by each member
5. Net balance per member, per group (includes settlements)
6. Settlement history
7. Members of each group
8. Groups with total spending above 1500 (`GROUP BY` + `HAVING`)
9. Spending by category
10. Integrity check: payer and split amounts match the total
11. Integrity check: group balances add up to zero

## Tools
MySQL, MySQL Workbench, VS Code, Git

## Team
M.JAYIN MANIDEEP REDDY
