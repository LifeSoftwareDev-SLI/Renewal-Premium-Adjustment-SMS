create or replace PROCEDURE PREMIUM_DELETION_SMS
AS
smsNo VARCHAR2(10):= '1';
premium NUMBER(12,2);
sms_text VARCHAR2(250);
sms_category VARCHAR(20);
row_count INTEGER := 0;

cursor cur1 is
SELECT LLPOL, TO_DATE(TO_CHAR(LLDUE), 'YYYYMM') AS LLDUE, PNSTA, PNINT, PNSUR, MOBILE_NUMBER, TO_DATE(TO_CHAR(LLDAT), 'YYYYMMDD') AS  LLDAT
FROM (
    SELECT L.LLPOL, L.LLDUE, P.PNSTA, P.PNINT, P.PNSUR, L.LLDAT,
        (
            SELECT PP.MOBILE_PHONE
            FROM LUND.POLPERSONAL PP
            WHERE PP.POLNO = L.LLPOL
            
            AND (PP.PRPERTYPE = 1 OR NOT EXISTS (SELECT 1 FROM LUND.POLPERSONAL WHERE POLNO = L.LLPOL AND PRPERTYPE = 1))
            AND ROWNUM = 1
        ) AS MOBILE_NUMBER
    FROM
        LPHS.PHNAME P
        JOIN LCLM.LEDGERHIS L ON P.PNPOL = L.LLPOL
        JOIN LPHS.ADJPAYMAS A ON L.LLREC = A.LPREC
                                     AND L.LLPOL = A.LPPOL
                                     AND L.LLDAT = A.LPPDT
                                     AND A.LPSTA = 1 
                                     AND (A.LPBTP = 28 OR A.LPBTP = 30)
    WHERE
        L.LLDAT = TO_CHAR((SYSDATE - 1), 'YYYYMMDD')
        AND L.LLPOL IN (SELECT PMPOL FROM LPHS.PREMAST)
        AND (A.LPBTP = 28 OR A.LPBTP = 30)
);

BEGIN

for rec1 in cur1 loop
row_count := row_count + 1;

IF rec1.MOBILE_NUMBER IS NOT NULL THEN
sms_category := 'DSMS';
sms_text := 'Dear ' || rec1.PNSTA || ' ' || rec1.PNINT || ' ' || rec1.PNSUR || ',' || CHR(10) || 'Renewal adjustment made for your Life Insurance Policy No. '|| rec1.LLPOL ||' for the month of ' || to_char(rec1.LLDUE, 'yyyy/mm') || ' has been reversed.';

--INSERT INTO SMS.SMS_GATEWAY @LIVE (APPLICATION_ID, JOB_CATEGORY, SMS_TYPE, MOBILE_NUMBER, TEXT_MESSAGE, SHORT_CODE) 
--VALUES('PHS', 'CAT151', 'I', '94'||SUBSTR(rec1.MOBILE_NUMBER,2,9), sms_text, 'SLIC%20LIFE');

INSERT INTO LPHS.PREMIUM_ADJUSTMENT_SMS
(POLICY_NO, SEND_DATE, DUEDATE, SMS_CATEGORY) 
VALUES (rec1.LLPOL, sysdate, to_char(rec1.LLDUE, 'yyyy/mm'), sms_category);

end IF;
end loop;

IF row_count > 0 THEN
COMMIT;
END IF;

END;
