--Задание 1
--Получите количество проектов, подписанных в 2023 году.
--В результат вывести одно значение количества.
select count(project_id)
from project 
where extract(year from sign_date) = '2023'

--Задание 2
--Получите общий возраст сотрудников, нанятых в 2022 году.
--Результат вывести одним значением в виде "... years ... months ... days"
--Использование более 2х функций для работы с типом данных дата и время будет являться ошибкой.
select  Sum(age(now ( )::date , person.birthdate))
from employee
join person on employee.person_id = person.person_id 
where extract(year from hire_date) = '2022'

--Задание 3
--Получите сотрудников, у которого фамилия начинается на М, всего в фамилии 8 букв и который работает дольше других.
--Если таких сотрудников несколько, выведите одного случайного.
--В результат выведите два столбца, в первом должны быть имя и фамилия через пробел, во втором дата найма.
select concat(Q1.last_name, ' ', Q1.first_name), employee.hire_date 
from employee
join (select * from person where person.last_name like 'М%' and char_length(person.last_name)=8) Q1
on employee.person_id = Q1.person_id 
where dismissal_date is null
order by hire_date, random()
limit 1

--Задание 4
--Получите среднее значение полных лет сотрудников, которые уволены и не задействованы на проектах.
--В результат вывести одно среднее значение. Если получаете null, то в результат нужно вывести 0.
select COALESCE(avg(extract(year from age(now ( )::date , person.birthdate))), 0)
from employee
join person on employee.person_id = person.person_id
where dismissal_date is not null 
and  employee.employee_id NOT IN (
select distinct unnest(employees_id)
from project)

--Задание 5
--Чему равна сумма полученных платежей от контрагентов из Жуковский, Россия.
--В результат вывести одно значение суммы.
select sum(pp.amount)
from project_payment pp 
join project p on p.project_id = pp.project_id 
join customer cu on p.customer_id = cu.customer_id
join address on cu.address_id = address.address_id
join city c on address.city_id = c.city_id 
join  country co on c.country_id = co.country_id 
where c.city_name like 'Жуковский' and co.country_name like 'Россия'

--Задание 6
--Пусть руководитель проекта получает премию в 1% от стоимости завершенных проектов.
--Если взять завершенные проекты, какой руководитель проекта получит самый большой бонус?
--В результат нужно вывести идентификатор руководителя проекта, его ФИО и размер бонуса.
--Если таких руководителей несколько, предусмотреть вывод всех.
with cte1 as(
	select e.employee_id, pr.full_fio, sum(p.project_cost*0.01) as precent
	from project p 
	join employee e on p.project_manager_id = e.employee_id 
	join person pr on e.person_id = pr.person_id 
	where p.status = 'Завершен'
	group by e.employee_id, pr.person_id 
	order by precent desc
),
cte2 as 
(select cte1.employee_id, cte1.full_fio, cte1.precent, rank() over( order by cte1.precent desc) as ranker
from cte1)
select cte2.employee_id, cte2.full_fio, cte2.precent
from cte2
where ranker = 1

--Задание 7
--Получите накопительный итог планируемых авансовых платежей на каждый месяц в отдельности.
--Выведите в результат те даты планируемых платежей, которые идут после преодаления накопительной суммой значения в 30 000 000
with cte1 as (
	select plan_payment_date, sum(pp.amount) over (partition by extract(month from plan_payment_date), extract(year from plan_payment_date)  order by plan_payment_date) as incsum
	from project_payment pp 
	where pp."payment_type" = 'Авансовый'
	order by plan_payment_date
),
cte2 as (
	select cte1.plan_payment_date, cte1.incsum, first_value (cte1.plan_payment_date) over (partition by date_trunc ('month',cte1.plan_payment_date)) as fval
	from cte1
	where cte1.incsum>30000000
)
	
select distinct cte2.plan_payment_date, cte2.incsum
from cte2
where cte2.plan_payment_date = fval

--Задание 8
--Используя рекурсию посчитайте сумму фактических окладов сотрудников из структурного подразделения с id равным 17 и всех дочерних подразделений.
--В результат вывести одно значение суммы.
with recursive units as (
    select *, 0 as level
    from company_structure
    where unit_id = 17

    union
    
    select cs.*, level +1 as level
    from units u
    join company_structure cs on u.unit_id = cs.parent_id 
   )
select sum(salary)
from units un
left join "position" p on un.unit_id = p.unit_id
left join employee_position ep  on p.position_id = p.position_id 
where p.is_vacant is false

--Задание 9
--Задание выполняется одним запросом.
--Сделайте сквозную нумерацию фактических платежей по проектам на каждый год в отдельности в порядке даты платежей.
--Получите платежи, сквозной номер которых кратен 5.
--Выведите скользящее среднее размеров платежей с шагом 2 строки назад и 2 строки вперед от текущей.
--Получите сумму скользящих средних значений.
--Получите сумму стоимости проектов на каждый год.
--Выведите в результат значение года (годов) и сумму проектов, где сумма проектов меньше, чем сумма скользящих средних значений.
with cte1 as (
	select *,
	row_number() over (partition by pp.project_id order by extract( year from pp.fact_transaction_timestamp) ) as rwcount
	from project_payment pp 
	where pp.fact_transaction_timestamp is not null
	order by pp.fact_transaction_timestamp
),
cte2 as(
	select *
	from cte1
	where cte1.rwcount = 5
),
cte3 as (
	select *, lag(cte2.amount, 2) over() as twob, lead(cte2.amount, 2) over() as twof
	from cte2
),
cte4 as (
	select sum(coalesce (cte3.twob, 0)+coalesce (cte3.twof, 0)) as megasum
	from cte3
	join project_payment ppp on cte3.project_payment_id = ppp.project_id
)
select *
from (
select distinct extract(year from sign_date),sum(project_cost) over (partition by extract(year from sign_date)) as supersum
from project p ) Q1
where Q1.supersum < (select cte4.megasum from cte4)

--Задание 10
--Создайте материализованное представление, которое будет хранить отчет следующей структуры:
--идентификатор проекта
--название проекта
--дата последней фактической оплаты по проекту
--размер последней фактической оплаты
--ФИО руководителей проектов
--Названия контрагентов
--В виде строки названия типов работ по каждому контрагенту
create materialized view projagent as
	with cte1 as (
		select *, row_number () over(partition by pp.project_id order by pp.fact_transaction_timestamp::date desc) as cnt
		from project_payment pp 
		where pp.fact_transaction_timestamp is not null
	)
	select p.project_id, p.project_name,cte1.fact_transaction_timestamp::date as "дата последнего платежа", cte1.amount as "размер последнего платежа",
	concat(per.last_name, ' ',per.first_name,' ',per.middle_name) as "ФИО руководителя проекта", c.customer_name as "Название контрагента", q1.sagr as "Типы работ"
	from cte1
	left join project p on cte1.project_id = p.project_id
	join employee e  on p.project_manager_id = e.employee_id
	join person per on e.person_id = per.person_id 
	join customer c on p.customer_id = c.customer_id
	join (
		select c.customer_id, string_agg(tow.type_of_work_name, ' ') as sagr
		from customer c 
		join customer_type_of_work ctow on c.customer_id = ctow.customer_id 
		join type_of_work tow  on ctow.type_of_work_id = tow.type_of_work_id 
		group by c.customer_id
	) q1 on c.customer_id = q1.customer_id
	where cnt=1
with no data



