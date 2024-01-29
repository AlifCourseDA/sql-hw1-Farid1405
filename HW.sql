-- 1.Use the Invoice table to determine the countries that have the lowest
-- invoices. Provide a table of BillingCountry and Invoices ordered by the
-- number of invoices for each country. The country with the most invoices
-- should appear last

SELECT COUNT(*), billingcountry
FROM invoice
GROUP BY billingcountry
ORDER BY 1;

-- 2. We would not like to throw a promotional Music Festival in the city we made
-- the least money. Write a query that returns the 5 city that has the lowest sum
-- of invoice totals. Return both the city name and the sum of all invoice totals.

SELECT SUM(total), billingcity
FROM invoice
GROUP BY billingcity
ORDER BY 1
    FETCH FIRST 5 ROWS ONLY;

-- 3. The customer who has spent the least money will be declared the worst
-- customer. Build a query that returns the person who has spent the least
-- money. I found the solution by linking the following three: Invoice, InvoiceLine,
-- and Customer tables to retrieve this information, but you can probably do it
-- with fewer!

WITH worst_customer AS (SELECT SUM(total) AS total_spent
                             , customerid
                        FROM invoice
                        GROUP BY customerid
                        ORDER BY SUM(total)
                        LIMIT 1)
SELECT customerid
     , firstname
     , lastname
     , (SELECT total_spent FROM worst_customer)
FROM customer
WHERE customerid = (SELECT customerid FROM worst_customer)
;


-- 4.The team at Chinook would like to identify all the customers who listen to
-- Rock music. Write a query to return the email, first name, last name, and
-- Genre of all Rock Music listeners. Return your list ordered alphabetically by
-- email address starting with 'S'

WITH rock_listeners AS (SELECT DISTINCT customerid, genre.name
                        FROM track
                                 JOIN genre
                                      ON track.genreid = genre.genreid
                                 JOIN invoiceline
                                      ON track.trackid = invoiceline.trackid
                                 JOIN invoice
                                      ON invoiceline.invoiceid = invoice.invoiceid
                        WHERE UPPER(genre.name) = 'ROCK')
SELECT email
     , firstname
     , lastname
     , (SELECT name
        FROM rock_listeners
        LIMIT 1) AS genre_name
FROM customer
WHERE customerid IN (SELECT customerid FROM rock_listeners) AND
      email LIKE 's%'
ORDER BY 1;

-- 5.Write a query that determines the customer that has spent the most on
-- music for each country. Write a query that returns the country along with the
-- top customer and how much they spent. For countries where the top amount
-- spent is shared, provide all customers who spent this amount.

WITH total_spending AS (SELECT SUM(total) AS total, invoice.customerid, billingcountry
                        FROM invoice
                                 JOIN customer
                                      ON invoice.customerid = customer.customerid
                        GROUP BY billingcountry, invoice.customerid),
     maximum_spendings AS (SELECT MAX(total_spending.total) AS max_spend, billingcountry
                           FROM total_spending
                           GROUP BY billingcountry)
SELECT customer.customerid, lastname, total_spending.billingcountry, total
FROM total_spending
         JOIN maximum_spendings
              ON maximum_spendings.max_spend = total_spending.total AND
                 total_spending.billingcountry = maximum_spendings.billingcountry
         JOIN customer
              ON total_spending.customerid = customer.customerid;

-- Part 2;

-- 1. How many tracks appeared 5 times, 4 times, 3 times....?

SELECT COUNT(*), name
FROM track
GROUP BY name
ORDER BY 1 DESC;

-- 2. Which album generated the most revenue?

WITH most_prof_album AS (SELECT SUM(total) as total_earned, album.albumid
                         FROM album
                                  JOIN track
                                       ON album.albumid = track.albumid
                                  JOIN invoiceline
                                       ON track.trackid = invoiceline.trackid
                                  JOIN invoice
                                       ON invoiceline.invoiceid = invoice.invoiceid
                         GROUP BY album.albumid
                         ORDER BY 1 DESC
                             FETCH FIRST 1 ROW ONLY)
SELECT title, (SELECT total_earned FROM most_prof_album)
FROM album
WHERE albumid IN (SELECT albumid FROM most_prof_album)
;

-- 3. Which countries have the highest sales revenue? What percent of total
-- revenue does each country make up

WITH total_by_country AS (SELECT SUM(total) AS total, billingcountry
                          FROM invoice
                          GROUP BY billingcountry),
     total_all AS (SELECT SUM(total) AS total_sum
                   FROM total_by_country)
SELECT total, ROUND(total / (SELECT total_sum FROM total_all) * 100, 3) AS percentage, billingcountry
FROM total_by_country
ORDER BY total DESC
;

-- 4. How many customers did each employee support, what is the average
-- revenue for each sale, and what is their total sale?

WITH customers_amount AS (SELECT COUNT(customerid) AS number_of_customers
                               , employeeid
                          FROM employee
                                   JOIN customer
                                        ON employee.employeeid = customer.supportrepid
                          GROUP BY employeeid)
   , sales_per_employee AS (SELECT SUM(total)       AS total
                                 , COUNT(invoiceid) AS sales_number
                                 , employeeid
                            FROM invoice
                                     JOIN customer
                                          ON invoice.customerid = customer.customerid
                                     JOIN employee
                                          ON customer.supportrepid = employee.employeeid
                            GROUP BY employeeid)
SELECT customers_amount.employeeid
     , firstname
     , lastname
     , number_of_customers
     , ROUND(total / sales_number, 3) AS average_per_sale
     , total
FROM customers_amount
         JOIN sales_per_employee
              ON customers_amount.employeeid = sales_per_employee.employeeid
         JOIN employee
              ON customers_amount.employeeid = employee.employeeid
;

-- 5. Do longer or shorter length albums tend to generate more revenue?

SELECT SUM(milliseconds) AS duration, SUM(total) AS total, album.albumid
FROM album
         JOIN track
              ON album.albumid = track.albumid
         JOIN invoiceline
              ON track.trackid = invoiceline.trackid
         JOIN invoice
              ON invoiceline.invoiceid = invoice.invoiceid
GROUP BY album.albumid
ORDER BY total DESC, duration;

-- 6. Is the number of times a track appear in any playlist a good indicator of sales?

WITH appereance_times AS (SELECT COUNT(track.trackid) AS num_times
                               , track.trackid
                          FROM playlist
                                   JOIN playlisttrack
                                        ON playlist.playlistid = playlisttrack.playlistid
                                   JOIN track
                                        ON playlisttrack.trackid = track.trackid
                          GROUP BY track.trackid
                          ORDER BY 1 DESC)
   , revenue_per_track AS (SELECT SUM(unitprice * quantity) AS total_revenue
                                , invoiceline.trackid
                           FROM invoiceline
                                    JOIN invoice
                                         ON invoiceline.invoiceid = invoice.invoiceid
                           GROUP BY invoiceline.trackid, invoiceline.trackid)
SELECT track.trackid, name, num_times, total_revenue
FROM appereance_times
         JOIN revenue_per_track
              ON appereance_times.trackid = revenue_per_track.trackid
         JOIN track
              ON appereance_times.trackid = track.trackid
ORDER BY total_revenue DESC
;

-- 7. How much revenue is generated each year, and what is its percent change from the previous year?
SELECT SUM(total)                                                      AS total_sales_per_year
     , DATE_PART('year', invoicedate)
     , 100 - (100 * LAG(SUM(total), 1)
                    OVER (
                        ORDER BY DATE_PART('year',
                                           invoicedate))) / SUM(total) AS change_percentage
FROM invoice
GROUP BY DATE_PART('year', invoicedate)
ORDER BY date_part
;

