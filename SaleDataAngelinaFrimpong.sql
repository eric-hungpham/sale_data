--inspecting Data
Select * from sales_data..sales_data_sample

--checking unique values
select distinct status from sales_data..sales_data_sample --nice one to plot
select distinct year_id from sales_data..sales_data_sample
select distinct PRODUCTLINE from sales_data..sales_data_sample --nice to plot
select distinct COUNTRY from sales_data..sales_data_sample --nice to plot
select distinct DEALSIZE from sales_data..sales_data_sample --nice to plot
select distinct TERRITORY from sales_data..sales_data_sample --nice to plot

--ANALYSIS
----let's start by grouping sales by productline, by year, by dealsize
SELECT PRODUCTLINE, ROUND(SUM(sales),2) as Revenue from sales_data..sales_data_sample
GROUP BY PRODUCTLINE
ORDER BY Revenue desc


SELECT YEAR_ID, ROUND(SUM(sales),2) as Revenue from sales_data..sales_data_sample
GROUP BY YEAR_ID
ORDER BY 2 desc

SELECT DEALSIZE, ROUND(SUM(sales),2) as Revenue from sales_data..sales_data_sample
GROUP BY DEALSIZE
ORDER BY 2 desc

---what is the best month for sales in a specific year? How much was earned that month ?
SELECT month_id, sum(sales) as revenue, count(orderlinenumber) Frequency from sales_data..sales_data_sample
where year_id = 2003 --change year to see the rest
group by MONTH_ID
order by 2 desc

--november seems to the month, what product do they sell most in november?
select productline, count(orderlinenumber) Frequency, sum(sales) as Revenue from sales_data..sales_data_sample
where month_id = 11 and year_id =2004 --change year to see the rest
group by month_id, PRODUCTLINE
order by 3 desc


--who is our best customer (this could be best answered with RFM: Recency (last order date), Frequency (count of total orders), Monetary value (total spend))
DROP TABLE if EXISTS #rfm
;with rfm as
(
	select 
		CUSTOMERNAME,
		sum(sales) MonetaryValue,
		avg(sales) AvgMonetaryValue,
		count(ORDERNUMBER) Frequency,
		max(ORDERDATE) last_order_date,
		(select max(ORDERDATE) from sales_data..sales_data_sample) max_order_date,
		DATEDIFF(DD,max(ORDERDATE), (select max(ORDERDATE) from sales_data..sales_data_sample)) Recency
		--datediff: calculate how many days from start day to end day
	from sales_data..sales_data_sample
	GROUP BY CUSTOMERNAME
),
rfm_calc as
(
	select r.*,
		NTILE(4) OVER (ORDER BY Recency desc) rfm_recency,
		NTILE(4) OVER (ORDER BY Frequency) rfm_Frequency,
		NTILE(4) OVER (ORDER BY MonetaryValue) rfm_Monetary
		---NTILE: chia làm đều số lượng các bản ghi thành 4 nhóm, sau đó đưa vào từng nhóm
	from rfm r
)

select 
	c.*, rfm_recency + rfm_Frequency + rfm_Monetary as rfm_cell,
	cast(rfm_recency as varchar) + cast(rfm_Frequency as varchar) + cast(rfm_Monetary as varchar) as rfm_cell_string
into #rfm
from rfm_calc c



select CUSTOMERNAME, rfm_recency, rfm_Frequency, rfm_Monetary, --recency: 1: rat lau roi chua mua, 4: moi vua mua
																--frequency so luong mua 1: mua it, 4: mua nhieu
																--montary:	1: it tien 4: nhieu tien
	case
		when rfm_cell_string in (111, 112, 121, 123, 132, 211, 212, 114, 141) then 'lost_customers' --lost customers
		when rfm_cell_string in (133, 134, 143, 244, 334, 343, 344, 144) then 'slipping away, cannot lose' --(big spenders who haven't purchased lately) slipping way
		when rfm_cell_string in (311, 411, 331 ) then 'new_customer'
		when rfm_cell_string in (222, 223, 233, 322) then 'potential_churners'
		when rfm_cell_string in (323, 333, 321, 422, 332, 432) then 'active' --(customers who buy often & recently, but at low price point)
		when rfm_cell_string in (433, 434, 443, 444) then 'loyal'
	end rfm_segment
from #rfm
