--1 Какие самолеты имеют более 50 посадочных мест?

select *
from (select a.aircraft_code, a.model, count(s.seat_no)
		from aircrafts a 
		join seats s on s.aircraft_code = a.aircraft_code 
		group by a.aircraft_code) t1 
where t1.count > 50


--2 В каких аэропортах есть рейсы, в рамках которых можно добраться бизнес - классом дешевле, чем эконом - классом?
--  - CTE

with cte as (
		select min(amount) min_amount_b, flight_id, fare_conditions 
		from ticket_flights 
		where fare_conditions = 'Business'
		group by flight_id, fare_conditions),
cte1 as (
		select max(amount) max_amount_e, flight_id, fare_conditions 
		from ticket_flights 
		where fare_conditions = 'Economy'
		group by flight_id, fare_conditions)		
select fv.departure_airport_name, *
from cte
join cte1 on cte.flight_id = cte1.flight_id
join flights_v fv on fv.flight_id = cte1.flight_id
where cte.min_amount_b < cte1.max_amount_e


--3 Есть ли самолеты, не имеющие бизнес - класса?
-- array_agg 

select *
from (select s.aircraft_code as air, a.model, array_agg(s.fare_conditions::text) as pfp 
		from aircrafts a 
		join seats s on s.aircraft_code = a.aircraft_code 
		group by air, a.model) t
where array['Economy', 'Comfort'] @> t.pfp


--4 Найдите количество занятых мест для каждого рейса,
-- процентное отношение количества занятых мест к общему количеству мест в самолете,
-- добавьте накопительный итог вывезенных пассажиров по каждому аэропорту на каждый день.
-- - Оконная функция
-- - Подзапрос


select t.count_seats_occupied, f.flight_id, ((t.count_seats_occupied::numeric / t1.count_seats_all::numeric) * 100) as percentages ,
	 f.actual_departure::date, f.departure_airport,
	sum(t.count_seats_occupied) over (partition by f.departure_airport, f.actual_departure::date order by f.actual_departure::date, f.flight_id)
from flights f 
join (select count(seat_no) as count_seats_occupied, flight_id 
		from boarding_passes bp
		group by flight_id) t on t.flight_id = f.flight_id 
join (select count(seat_no) as count_seats_all, s.aircraft_code 
		from seats s 
		group by aircraft_code) t1 on t1.aircraft_code = f.aircraft_code 
where f.status = 'Departed' or f.status = 'Arrived'


--5 Найдите процентное соотношение перелетов по маршрутам от общего количества перелетов. 
--Выведите в результат названия аэропортов и процентное отношение.
-- - Оконная функция
-- - Оператор ROUND


select round(((count(flight_id) over (partition by flight_no)::numeric / count(flight_id) over ()::numeric) * 100), 3) as percentages,
		a.airport_name, f.flight_no 
from flights f  
join airports a on a.airport_code = f.departure_airport



--6 Выведите количество пассажиров по каждому коду сотового оператора,
-- если учесть, что код оператора - это три символа после +7

select substring(t.number from 4 for 3) as "код оператора", count(t.passenger_id)
from (select (contact_data -> 'phone')::text as number, passenger_id
from tickets) t
group by substring(t.number from 4 for 3)


--7 Между какими городами не существует перелетов?
-- - Декартово произведение
-- - Оператор EXCEPT


select distinct r.departure_city , r2.arrival_city
from routes r , routes r2  
where r.departure_city != r2.arrival_city
except
select distinct r.departure_city , r.arrival_city
from routes r 



--8 Классифицируйте финансовые обороты (сумма стоимости билетов) по маршрутам:
--До 50 млн - low
--От 50 млн включительно до 150 млн - middle
--От 150 млн включительно - high
--Выведите в результат количество маршрутов в каждом классе.
-- - Оператор CASE

select *
from (select t."класс", count(t.flight_no) over (partition by t."класс")
		from (select flight_no, sum(tf.amount),
					case when sum(tf.amount) < 50000000 then 'low'
						 when sum(tf.amount) >= 50000000 and sum(tf.amount) < 150000000 then 'middle'
						 else 'high'
					end as "класс"
				from flights f 
				join ticket_flights tf on tf.flight_id = f.flight_id 
				group by flight_no ) t) t1
group by t1."класс", t1.count


--9 Выведите пары городов между которыми расстояние более 5000 км
-- - Оператор RADIANS или использование sind/cosd


select distinct a.city , a2.city
from airports a , airports a2 
where a.city != a2.city and
(6371 * (acos(sind(a.latitude) * sind(a2.latitude) + cosd(a.latitude) * cosd(a2.latitude) * cosd(a.longitude - a2.longitude)))) > 5000


