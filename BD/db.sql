CREATE TABLESPACE task_data DATAFILE 'task_data.dbf' SIZE 100M AUTOEXTEND ON NEXT 10M;
CREATE TABLESPACE task_index DATAFILE 'task_index.dbf' SIZE 50M AUTOEXTEND ON NEXT 5M;

CREATE USER task IDENTIFIED BY task_pass DEFAULT TABLESPACE task_data TEMPORARY TABLESPACE temp;
GRANT CONNECT, RESOURCE TO task;
ALTER USER task QUOTA UNLIMITED ON task_data;
ALTER USER task QUOTA UNLIMITED ON task_index;


CREATE TABLE Angajati (
    angajat_id NUMBER PRIMARY KEY,
    nume VARCHAR2(100) NOT NULL,
    email VARCHAR2(100) UNIQUE,
    salariu NUMBER(8,2) CHECK (salariu > 0),
    data_angajare DATE DEFAULT SYSDATE
) TABLESPACE task_data;



CREATE TABLE Proiecte (
    proiect_id NUMBER PRIMARY KEY,
    nume_proiect VARCHAR2(150) NOT NULL,
    buget NUMBER(10,2) CHECK (buget >= 1000),
    descriere_xml XMLTYPE  
) TABLESPACE task_data;


CREATE TABLE Tipuri_Activitati (
    activitate_id NUMBER PRIMARY KEY,
    denumire VARCHAR2(100) NOT NULL,
    activ VARCHAR2(1) DEFAULT 'Y' CHECK (activ IN ('Y', 'N'))
) TABLESPACE task_data;



CREATE OR REPLACE TRIGGER trg_chk_data_pontaj
BEFORE INSERT OR UPDATE ON Pontaje
FOR EACH ROW
BEGIN
    IF :NEW.data_pontaj > TRUNC(SYSDATE) THEN
        RAISE_APPLICATION_ERROR(-20001, 'Data pontaj nu poate fi în viitor.');
    END IF;
END;
/


CREATE OR REPLACE VIEW View_Ore_Pontate AS
SELECT 
  a.nume AS angajat,
  p.pontaj_id,
  pr.nume_proiect,
  p.data_pontaj,
  p.ore_lucrate
FROM Angajati a
JOIN Pontaje p ON a.angajat_id = p.angajat_id
JOIN Proiecte pr ON p.proiect_id = pr.proiect_id;


CREATE OR REPLACE VIEW View_Ore_Lunare AS
SELECT 
  a.nume,
  TO_CHAR(p.data_pontaj, 'YYYY-MM') AS luna,
  SUM(p.ore_lucrate) AS total_ore
FROM Angajati a
JOIN Pontaje p ON a.angajat_id = p.angajat_id
GROUP BY a.nume, TO_CHAR(p.data_pontaj, 'YYYY-MM');



CREATE OR REPLACE VIEW View_Ore_Pe_Activitati AS
SELECT 
  t.denumire AS activitate,
  SUM(p.ore_lucrate) AS total_ore
FROM Pontaje p
JOIN Tipuri_Activitati t ON p.activitate_id = t.activitate_id
GROUP BY t.denumire;



BEGIN
  INSERT INTO Pontaje VALUES (99990, 1, 1, 1, TO_DATE('2030-01-01', 'YYYY-MM-DD'), 5, 'Test future', '{"test":"future"}');
EXCEPTION
  WHEN OTHERS THEN
    ROLLBACK;
END;
/



BEGIN
  INSERT INTO Pontaje VALUES (100000, 1, 1, 1, SYSDATE, 3, 'Ore reale', '{"info":"test"}');
  COMMIT;
END;
/


CREATE INDEX IX_Pontaje_Angajat ON Pontaje(angajat_id) TABLESPACE task_index;



CREATE MATERIALIZED VIEW View_Materializat_OreAngajati
BUILD IMMEDIATE
REFRESH COMPLETE ON DEMAND
ENABLE QUERY REWRITE
AS
SELECT 
  a.angajat_id,
  a.nume,
  COUNT(*) AS nr_pontari,
  SUM(p.ore_lucrate) AS total_ore
FROM Angajati a
JOIN Pontaje p ON a.angajat_id = p.angajat_id
GROUP BY a.angajat_id, a.nume;



INSERT INTO Angajati VALUES (1, 'Iuliana Raluca', 'iuliana.butnariu@endava.com', 7500, TO_DATE('2022-05-10', 'YYYY-MM-DD'));
INSERT INTO Angajati VALUES (2, 'Polina Ciuma', 'polina_ciumac@endava.com', 8200, TO_DATE('2021-09-15', 'YYYY-MM-DD'));


INSERT INTO Proiecte VALUES (1, 'Timesheet', 50000, XMLTYPE('<descriere>Refactorizare sistem pontaj vechi</descriere>'));
INSERT INTO Proiecte VALUES (2, 'Payroll API', 30000, XMLTYPE('<descriere>Integrare API calcul salarii</descriere>'));


INSERT INTO Tipuri_Activitati VALUES (1, 'Dezvoltare', 'Y');
INSERT INTO Tipuri_Activitati VALUES (2, 'Testare', 'Y');
INSERT INTO Tipuri_Activitati VALUES (3, 'Documentatie', 'Y');


INSERT INTO Pontaje VALUES (1, 1, 1, 1, TO_DATE('2024-06-01', 'YYYY-MM-DD'), 8, 'Sprint finalizat', '{"ticket":"TS-1001"}');
INSERT INTO Pontaje VALUES (2, 1, 1, 2, TO_DATE('2024-06-02', 'YYYY-MM-DD'), 4, 'Teste automate', '{"test_case":"Ts-231"}');
INSERT INTO Pontaje VALUES (3, 2, 2, 3, TO_DATE('2024-06-01', 'YYYY-MM-DD'), 6, 'Documentatie API', '{"doc_id":"ID-55"}');




/*
 The query below returns the total number of hours worked by each employee in each month.
I included a grouping by employee name and month, expressed in the 'YYYY-MM' format,
and for each group, the total number of recorded hours is calculated.
In the context of this query, I used a GROUP BY operation to aggregate the data so that
I get one row for each unique combination of employee and month,
allowing the calculation of total hours for each case.
Finally, the results are ordered by employee name and month.
*/
SELECT 
  a.nume AS angajat,
  TO_CHAR(p.data_pontaj, 'YYYY-MM') AS luna,
  SUM(p.ore_lucrate) AS total_ore
FROM Angajati a
JOIN Pontaje p ON a.angajat_id = p.angajat_id
GROUP BY a.nume, TO_CHAR(p.data_pontaj, 'YYYY-MM')
ORDER BY a.nume, luna;


/*
The query below displays the list of all employees, along with their timesheet data and the number of hours worked, if such data exists.
I used a LEFT JOIN to include employees who do not yet have any records in the Pontaje table.
In other words, I wanted to display all employees, even if they haven't logged any work hours yet, in which case the fields from the Pontaje table will appear as NULL.

*/

SELECT 
  a.angajat_id,
  a.nume,
  p.data_pontaj,
  p.ore_lucrate
FROM Angajati a
LEFT JOIN Pontaje p ON a.angajat_id = p.angajat_id
ORDER BY a.angajat_id, p.data_pontaj;



/*
In the following query, I calculated the top employees for each month based on the total number of hours worked.
I grouped the data by employee name and month, and computed the sum of hours logged for each combination.
Then, I used the RANK() function to determine the position of each employee within that month's ranking.
I applied PARTITION BY on the month so that the ranking is calculated separately for each month,
and the ordering is done in descending order based on the total number of hours worked.
Outside the subquery, I filtered only the top 3 employees for each month.
*/

SELECT *
FROM (
    SELECT 
        a.nume AS angajat,
        TO_CHAR(p.data_pontaj, 'YYYY-MM') AS luna,
        SUM(p.ore_lucrate) AS total_ore,
        RANK() OVER (
            PARTITION BY TO_CHAR(p.data_pontaj, 'YYYY-MM')
            ORDER BY SUM(p.ore_lucrate) DESC
        ) AS pozitie_in_luna
    FROM Angajati a
    JOIN Pontaje p ON a.angajat_id = p.angajat_id
    GROUP BY a.nume, TO_CHAR(p.data_pontaj, 'YYYY-MM')
)
WHERE pozitie_in_luna <= 3
ORDER BY luna, pozitie_in_luna;



/*
In this query, I obtained the total number of hours worked by each employee, grouped both by month and by year.
I used the GROUPING SETS function to perform two different levels of aggregation within a single query:
the total hours per month (year + month + employee), and the total hours for the entire year (year + employee).
To extract the year and month, I used the TO_CHAR function applied to the timesheet date.
The results are ordered by year, month, and employee name.
*/

SELECT 
  TO_CHAR(p.data_pontaj, 'YYYY') AS an,
  TO_CHAR(p.data_pontaj, 'MM') AS luna,
  a.nume AS angajat,
  SUM(p.ore_lucrate) AS total_ore
FROM Pontaje p
INNER JOIN Angajati a ON p.angajat_id = a.angajat_id
GROUP BY GROUPING SETS (
  (TO_CHAR(p.data_pontaj, 'YYYY'), TO_CHAR(p.data_pontaj, 'MM'), a.nume),  
  (TO_CHAR(p.data_pontaj, 'YYYY'), a.nume)                                 
)
ORDER BY an, luna, angajat;





/*
The query below transforms the timesheet records so that I can see how many hours each employee worked on each type of activity.
To achieve this, I used the PIVOT clause, which helped me turn the values from the activitate (activity) column into separate columns.
Inside the subquery, I selected the employee name, the activity name, and the hours worked.
Then, in the PIVOT section, I specified that I want to calculate the sum of hours worked for each activity and display them as individual columns.
The final result shows how many hours each employee worked on each type of activity, all displayed on the same row.
*/

SELECT *
FROM (
    SELECT 
        a.nume AS angajat,
        t.denumire AS activitate,
        p.ore_lucrate
    FROM Pontaje p
    JOIN Angajati a ON p.angajat_id = a.angajat_id
    JOIN Tipuri_Activitati t ON p.activitate_id = t.activitate_id
)
PIVOT (
    SUM(ore_lucrate)
    FOR activitate IN ('Dezvoltare' AS DEZV, 'Testare' AS TEST, 'Documentatie' AS DOC)
)
ORDER BY angajat;



/*
The query below extracts information from the json_extra_info column in the Pontaje table,
where I stored semi-structured data in JSON format.
I used the JSON_TABLE function, which allowed me to parse the contents of the JSON and extract the values
into a relational table format, as separate columns.
Inside the JSON_TABLE, I specified the root path $ of the JSON object and defined the columns to be extracted: 'ticket', 'test_case', and 'doc_id'.
*/


SELECT p.pontaj_id, a.nume AS angajat, t.*
FROM Pontaje p
JOIN Angajati a ON p.angajat_id = a.angajat_id,
     JSON_TABLE(
         p.json_extra_info,
         '$'
         COLUMNS (
           ticket VARCHAR2(50) PATH '$.ticket',
           test_case VARCHAR2(50) PATH '$.test_case',
           doc_id VARCHAR2(50) PATH '$.doc_id'
         )
     ) t;
     
     

/*
In this query, I extracted the information from the descriere_xml column of type XML in the Proiecte table,
where I stored the project description using XML format.
I used the XMLTABLE function to navigate the XML structure and extract the content of the <descriere> node.
The XPath path '/descriere' indicates that I want to access the root node, and with PATH '.' I extract the text content,
thus obtaining a descriere column that contains the plain text from the XML.
*/

SELECT 
  p.proiect_id,
  p.nume_proiect,
  x.descriere
FROM Proiecte p,
     XMLTABLE(
       '/descriere'
       PASSING p.descriere_xml
       COLUMNS descriere VARCHAR2(200) PATH '.'
     ) x;

