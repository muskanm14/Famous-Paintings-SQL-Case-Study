-- All tables in the database
SELECT * FROM artist;
SELECT * FROM canvas_size;
SELECT * FROM image_link;
SELECT * FROM museum;
SELECT * FROM museum_hours;
SELECT * FROM product_size;
SELECT * FROM subject;
SELECT * FROM work;

-- Fetch all the paintings which are not displayed on any museums?
SELECT name as painting_name FROM work WHERE museum_id IS null;

-- Are there museums without any paintings?
SELECT * FROM museum 
WHERE museum_id NOT IN (SELECT museum_id FROM work WHERE work_id IS NOT NULL); 

-- Find how many paintings are there in a museum 
SELECT museum.name, museum.city, COUNT(work.work_id) 
    FROM museum
    JOIN work 
    ON museum.museum_id = work.museum_id
    GROUP BY museum.name, museum.city

-- How many paintings have an asking price of more than their regular price?
SELECT * FROM product_size WHERE sale_price>regular_price;

-- Identify the paintings whose asking price is less than 50% of its regular price
SELECT * FROM product_size WHERE sale_price<(regular_price*0.5);

-- Which canva size costs the most?
SELECT cs.label as canva, ps.sale_price
	FROM (SELECT *
		  , rank() OVER(ORDER BY sale_price desc)
		  FROM product_size) ps
	JOIN canvas_size cs ON cs.size_id::text=ps.size_id
	WHERE ps.rank=1;	

-- Delete duplicate records from work, product_size, subject and image_link tables
DELETE FROM work 
WHERE ctid NOT IN (SELECT min(ctid) FROM work GROUP BY work_id );

DELETE FROM product_size 
WHERE ctid NOT IN (SELECT min(ctid) FROM product_size GROUP BY work_id,size_id );

DELETE FROM subject
WHERE ctid NOT IN (SELECT min(ctid) FROM subject GROUP BY work_id,subject );

DELETE FROM image_link
WHERE ctid NOT IN (SELECT min(ctid) FROM image_link GROUP BY work_id);

-- Identify the museums with invalid city information in the given dataset

SELECT * FROM museum 
WHERE city ~ '^[0-9]'

-- Museum_Hours table has 1 invalid entry. Identify it and remove it.
DELETE FROM museum_hours 
WHERE ctid NOT IN (SELECT min(ctid) FROM museum_hours GROUP BY museum_id, day );

-- Fetch the top 10 most famous painting subject
SELECT subject, no_of_paintings  FROM (
		SELECT s.subject,count(1) as no_of_paintings
		,rank() over(order by count(1) desc) as ranking
		FROM work w
		JOIN subject s ON s.work_id=w.work_id
		GROUP BY s.subject ) x
WHERE ranking <= 10;


-- Identify the museums which are open on both Sunday and Monday. Display museum name, city.

SELECT DISTINCT mu.name AS museum_name, mu.city 
FROM museum mu JOIN museum_hours mh ON mu.museum_id=mh.museum_id 
WHERE mh.day IN ('Sunday','Monday') GROUP BY mh.museum_id,mu.name,mu.city 
HAVING count(DISTINCT mh.day)=2; 

-- How many museums are open every single day?

WITH cte AS (
    SELECT museum_id, count(day) from museum_hours
    GROUP by museum_id
    HAVING count(day) = 7
)

SELECT count(1) from cte

-- Which are the top 5 most popular museum? (Popularity is defined based on most no of paintings in a museum)
SELECT museum_name,no_of_paintings FROM ( 
SELECT w.museum_id, m.name as museum_name, count(1) as no_of_paintings ,
rank() over( order by count(w.museum_id) desc ) as ranking  FROM work w JOIN museum m ON w.museum_id=m.museum_id GROUP BY w.museum_id,m.name) x
WHERE ranking<=5;

-- Who are the top 5 most popular artist? (Popularity is defined based on most no of paintings done by an artist)

SELECT artist_name,no_of_paintings FROM ( 
SELECT w.artist_id, a.full_name as artist_name, count(1) as no_of_paintings ,
rank() over( order by count(1) desc ) as ranking FROM work w JOIN artist a ON w.artist_id=a.artist_id  GROUP BY w.artist_id,a.full_name) x
WHERE ranking<=5;

-- Display the 3 least popular canva sizes
SELECT label,ranking,no_of_paintings FROM (
		SELECT cs.size_id,cs.label,count(1) as no_of_paintings
		,dense_rank() over(order by count(1) ) as ranking
		FROM work w
		JOIN product_size ps on ps.work_id=w.work_id
		JOIN canvas_size cs on cs.size_id::text = ps.size_id
		GROUP BY cs.size_id,cs.label) x
WHERE x.ranking<=3;

-- Which museum is open for the longest during a day. Dispay museum name, state and hours open and which day?

SELECT museum_name, state ,day, open, close, duration FROM(
	SELECT m.name as museum_name, m.state, day, open, close
			, to_timestamp(open,'HH:MI AM') 
			, to_timestamp(close,'HH:MI PM') 
			, to_timestamp(close,'HH:MI PM') - to_timestamp(open,'HH:MI AM') as duration
			, rank() over (order by (to_timestamp(close,'HH:MI PM') - to_timestamp(open,'HH:MI AM')) desc) as rnk
			FROM museum_hours mh
		 	JOIN museum m ON m.museum_id=mh.museum_id) x
WHERE x.rnk=1;


-- Which museum has the most no of most popular painting style?
SELECT * from (
SELECT museum.name,work.museum_id, work.style, COUNT(1) as popularity
FROM work 
JOIN museum ON museum.museum_id = work.museum_id
WHERE work.style is not NULL AND work.museum_id is not NULL
GROUP BY museum.name,work.museum_id, work.style
ORDER by popularity DESC
) x LIMIT 1;

-- Identify the artists whose paintings are displayed in multiple countries

with cte as (
    SELECT DISTINCT artist.full_name as artist, museum.country
    FROM artist
    JOIN work ON artist.artist_id = work.artist_id
    JOIN museum on work.museum_id = museum.museum_id
)
SELECT artist, count(1) as number_of_countries, STRING_AGG(country, ', ') as Countries
from cte 
GROUP BY artist
having count(1)>1
ORDER BY 2 DESC

-- Display the country and the city with most no of museums.

with cte_country as (
SELECT country, count(DISTINCT museum_id) as cnt_country_museum
,rank() over(order by count(DISTINCT museum_id) desc) as rnk
FROM museum
GROUP BY country
),
cte_city as (
SELECT city, count(distinct museum_id) as cnt_city_museum
,rank() over(order by count(distinct museum_id) desc) as rnk
FROM museum
GROUP BY city
)
SELECT string_agg(country.country,', ') as top_countries, string_agg(city.city,', ') as top_cities
FROM cte_country country
CROSS JOIN cte_city city
WHERE country.rnk = 1
and city.rnk = 1;

-- Identify the artist and the museum where the most expensive and least expensive painting is placed. 
-- Display the artist name, sale_price, painting name, museum name, museum city and canvas label
with cte as (
SELECT *
,rank() over(order by sale_price ) as rnk
,rank() over(order by sale_price desc) as rnk_dsc
FROM product_size )

SELECT DISTINCT a.full_name as artist, cte.sale_price, w.name as painting, m.name as museum, m.city, cz.label as canvas,rnk,rnk_dsc
FROM cte
JOIN work w on w.work_id=cte.work_id
JOIN museum m on m.museum_id=w.museum_id
JOIN artist a on a.artist_id=w.artist_id
JOIN canvas_size cz on cz.size_id = cast(cte.size_id as int)
WHERE rnk=1 or rnk_dsc=1 ;


-- Which country has the 5th highest no of paintings?

SELECT country, no_of_Paintings FROM (
	SELECT m.country, count(1) as no_of_Paintings, rank() over(order by count(1) desc) as rnk
	FROM work w
	JOIN museum m on m.museum_id=w.museum_id
	GROUP BY m.country) X
WHERE rnk=5;


-- Which are the 3 most popular and 3 least popular painting styles?

with cte as 
(SELECT style, count(1) as cnt
		,rank() over(order by count(1) desc) rnk
		,count(1) over() as no_of_records
		FROM work WHERE style IS NOT null
		GROUP BY style)
SELECT style
	,CASE WHEN rnk <=3 THEN 'Most Popular' ELSE 'Least Popular' END AS remarks 
	FROM cte
	WHERE rnk <=3
	or rnk > no_of_records - 3; 
	

-- Which artist has the most no of Portraits paintings outside USA?. 
-- Display artist name, no of paintings and the artist nationality.

SELECT full_name as artist_name, nationality, no_of_paintings FROM (
	SELECT a.full_name, a.nationality
	,count(1) as no_of_paintings
	,rank() over(order by count(1) desc) as rnk
	FROM work w
	JOIN artist a ON a.artist_id=w.artist_id
	JOIN subject s ON s.work_id=w.work_id
	JOIN museum m ON m.museum_id=w.museum_id
	WHERE s.subject='Portraits'
	AND m.country != 'USA'
	GROUP BY a.full_name, a.nationality) x
WHERE rnk=1;

-- What's the average difference between the sale price and original price in percentage by Work Subject 

with cte as (
    SELECT work.style, ROUND(AVG(product_size.regular_price),2) as avg_regular_Price, ROUND(AVG(product_size.sale_price),2) as avg_sale_Price
    FROM work    
    JOIN product_size ON work.work_id = product_size.work_id 
    GROUP BY work.style
)

SELECT *,
       ROUND(((avg_regular_Price - avg_sale_Price) / NULLIF(avg_regular_Price, 0)) * 100, 2) as Discount
FROM cte;


