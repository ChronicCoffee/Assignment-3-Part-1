-- Assignment 3 Part 1 (Noah Gallasic, Asfand Khan)

SPOOL A3_Part1.txt

SET SERVEROUTPUT ON
SET LINESIZE 200
SET PAGESIZE 100

-- Displaying styling and data for before processing spool output
PROMPT ===== BEFORE PROCESSING =====
PROMPT

PROMPT #1. Initial NEW_TRANSACTIONS:
SELECT * FROM new_transactions ORDER BY transaction_no, account_no;

PROMPT #2. Initial ACCOUNT Balances:
SELECT account_no, account_name, account_balance 
FROM account 
ORDER BY account_no;

PROMPT #3. Initial TRANSACTION_HISTORY count:
SELECT COUNT(*) FROM transaction_history;

PROMPT #4. Initial TRANSACTION_DETAIL count:
SELECT COUNT(*) FROM transaction_detail;

-- Begin PL/SQL Code For Assignment 3 Part 1
DECLARE
    CURSOR trans_cur IS
        SELECT DISTINCT transaction_no, transaction_date, description
        FROM new_transactions
        ORDER BY transaction_no;
    
    CURSOR trans_lines_cur(p_trans_no NUMBER) IS
        SELECT account_no, transaction_type, transaction_amount
        FROM new_transactions
        WHERE transaction_no = p_trans_no
        ORDER BY account_no;
    
    v_account_type VARCHAR2(2);
    v_default_trans_type CHAR(1);
    v_amount_change NUMBER;
    v_debit_total NUMBER := 0;
    v_credit_total NUMBER := 0;
BEGIN
    FOR trans_rec IN trans_cur LOOP
        v_debit_total := 0;
        v_credit_total := 0;
        
        INSERT INTO transaction_history
        VALUES (trans_rec.transaction_no, trans_rec.transaction_date, trans_rec.description);
        
        FOR line_rec IN trans_lines_cur(trans_rec.transaction_no) LOOP
            SELECT a.account_type_code, at.default_trans_type
            INTO v_account_type, v_default_trans_type
            FROM account a
            JOIN account_type at ON a.account_type_code = at.account_type_code
            WHERE a.account_no = line_rec.account_no;
            
            IF line_rec.transaction_type = v_default_trans_type THEN
                v_amount_change := line_rec.transaction_amount;
            ELSE
                v_amount_change := -line_rec.transaction_amount;
            END IF;
            
            UPDATE account
            SET account_balance = account_balance + v_amount_change
            WHERE account_no = line_rec.account_no;
            
            INSERT INTO transaction_detail
            VALUES (line_rec.account_no, trans_rec.transaction_no, 
                   line_rec.transaction_type, line_rec.transaction_amount);
            
            IF line_rec.transaction_type = 'D' THEN
                v_debit_total := v_debit_total + line_rec.transaction_amount;
            ELSE
                v_credit_total := v_credit_total + line_rec.transaction_amount;
            END IF;
        END LOOP;
        
        DBMS_OUTPUT.PUT_LINE('Processed Transaction #' || trans_rec.transaction_no || 
                            ' (Debits: ' || v_debit_total || 
                            ', Credits: ' || v_credit_total || ')');
    END LOOP;
    
    DELETE FROM new_transactions;
    COMMIT;
    
    DBMS_OUTPUT.PUT_LINE('All transactions processed successfully.');
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('Error processing transactions: ' || SQLERRM);
END;
/

-- Displaying styling and data for after processing spool output
PROMPT
PROMPT ===== AFTER PROCESSING =====
PROMPT

PROMPT #1. Remaining NEW_TRANSACTIONS (should be empty):
SELECT * FROM new_transactions ORDER BY transaction_no, account_no;

PROMPT #2. Updated ACCOUNT Balances:
SELECT account_no, account_name, account_balance 
FROM account 
ORDER BY account_no;

PROMPT #3. New TRANSACTION_HISTORY entries:
SELECT * FROM transaction_history ORDER BY transaction_no;

PROMPT #4. New TRANSACTION_DETAIL entries:
SELECT * FROM transaction_detail ORDER BY transaction_no, account_no;

PROMPT #5. Verification - Debits should equal Credits for each transaction:
SELECT transaction_no, 
       SUM(DECODE(transaction_type, 'D', transaction_amount, 0)) debits,
       SUM(DECODE(transaction_type, 'C', transaction_amount, 0)) credits
FROM transaction_detail
GROUP BY transaction_no
ORDER BY transaction_no;

SPOOL OFF