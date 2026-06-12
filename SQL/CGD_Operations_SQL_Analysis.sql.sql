create database CGD_operations;
Use CGD_operations;

# Imported % Csv Files in our Database named customers,consumptions,complaints,frs,maintenance 

# Now change Data Types of Columns and set primary Key of Tables

# Customers Table
Alter table customers
modify customer_name varchar(20),
modify customer_id varchar(20) primary key,
modify customer_type varchar(20),
modify zone varchar(20),
modify `area` varchar(20),
modify Frs_name varchar(20),
modify Meter_number varchar(20) unique,
modify `status` varchar(20);

# Consumptions Table

Select * from consumptions;

Alter table consumptions
modify consumption_scm double,
modify Reading_id varchar(20) primary key,
modify reading_date date,
modify customer_id varchar(20),
modify previous_reading double,
modify Corrected_Consumption_SCM double,
modify rate_per_scm int;

# FRS Table

alter table frs
modify Record_id varchar(20) primary key,
modify `Date` date,
modify FRS_name varchar(20),
modify Gas_input_scm double;


# Complaints Table


# Changing blank values into null
update complaints
set tat_hours= null
where tat_hours = '';

update  complaints
set closed_date = null
where closed_date = '';

alter table complaints
modify created_date date,
modify closed_date date,
modify complaint_iD varchar(20) primary key,
modify customer_id varchar(20),
modify complaint_type varchar(20),
modify priority varchar(20),
modify `status`  varchar(20),
modify Tat_hours double;

# Maintenance Table

# Change Inspection Date to Str_to date 
update  maintenance
set Inspection_date = str_to_date(inspection_date, '%m/%d/%Y');


alter table maintenance
modify Inspection_ID varchar(20) primary key,
modify inspection_date date,
modify FRS_name varchar(20),
modify inspection_type varchar(20),
modify issue_found varchar(20),
modify `status` varchar(20);alter table maintenance
modify column Inspection_date date;


# Create FRS_master Table

create table Frs_master as
select distinct Frs_name from Frs;

ALTER TABLE frs_master
ADD PRIMARY KEY(FRS_name);

# Add Foreign Keys

ALTER TABLE consumptions
ADD CONSTRAINT fk_consumption_customer
FOREIGN KEY(customer_id)
REFERENCES customers(customer_id);


ALTER TABLE complaints
ADD CONSTRAINT fk_complaint_customer
FOREIGN KEY(customer_id)
REFERENCES customers(customer_id);


ALTER TABLE frs
ADD CONSTRAINT fk_frs_master
FOREIGN KEY(frs_name)
REFERENCES frs_master(frs_name);


ALTER TABLE maintenance
ADD CONSTRAINT fk_maintenance_frs
FOREIGN KEY(frs_name)
REFERENCES frs_master(frs_name);


# Total Customers

Select Customer_type, 
count(*) as Total_Customers 
from customers
group by customer_type;

# Consumption month by Month

Select month(reading_date) as month,
		round(sum(corrected_consumption_scm),2) as Total_consumption
from Consumptions
group by month(reading_date)
order by month;



# Consumption by Customer Type Month on month

Select date_format(reading_date, '%M-%Y' ) as month,
		round(sum(case 
					when c.customer_type = 'Domestic' 
                    then c1.Corrected_Consumption_SCM 
                    end),2) as Domestic,
        round(sum(case 
					when c.customer_type = 'Industrial' 
                    then c1.Corrected_Consumption_SCM 
                    end),2) as Industrial,
        round(sum(case 
					when c.customer_type = 'commercial' 
                    then c1.Corrected_Consumption_SCM 
                    end),2) as Commercial
       
from Consumptions c1
join customers c
on c.customer_id = c1.customer_id
group by month(reading_date)
;

# Customer Type wise Revenue

(Select C.customer_type,
		round(sum(c1.Total_sales),2) as Total_sales
from Customers c
join consumptions c1
on c1.customer_id = c.customer_id
group by C.customer_type 
order by Total_sales desc
)
Union all 
(Select 'Total' as customer_Type, 
		round(sum(Total_sales),2) as Total_sales
from consumptions)
;

# Total Active and Inactive customers
Select Customer_type, 
		count(case 
				when `status` = 'Active' 
				then 1 
                end ) as Active, 
        count(case 
				when `status` = 'Inactive' 
                then 1 
                end) as Inactive  
from customers
group by customer_type;


# Top  10 Highest Customer by consumption

Select c.customer_id,
		c.customer_type,
        round(sum(c1.Corrected_Consumption_SCM),2) as Total_consumption
from customers c
join consumptions c1
on c1.customer_id= c.customer_id
group by c.customer_id,C.customer_type
order by Total_consumption desc
limit 10;

# Top 3 Customer By customer_type


with customer_rank as(
			select c.Customer_id, C.Customer_name, C.customer_type,
            round(sum(c1.corrected_consumption_scm),2)as Total_consumption,
            rank() over(partition by c.customer_type order by sum(c1.corrected_consumption_scm) desc)
            as Ranking
from customers c
join consumptions C1
on c1.customer_id = c.customer_id
group by Customer_id,  c.customer_name, c.customer_type
)

Select * from customer_rank 
where ranking < 4;



# Toatal Consumption by FRS

Select C.Frs_name, round(sum(c1.Corrected_Consumption_SCM),2) as Total_Consumption
from customers c
join consumptions c1
on c1.customer_id = c.customer_id
group by C.frs_name
;


# Total Gas Input by Frs in 2025 

Select Frs_name , round(sum(gas_input_scm),2) from Frs
group by Frs_name
;


# Month WISE GAs Loss

with frs_temp as(
				select date_format(`date`, '%M-%Y') as Month, 
                round(sum(gas_input_scm),2) as Total_input 
                from frs
                group by month
)
,
Consumptions_temp as( 
				select date_format(reading_date, '%M-%Y') as Month, 
					round(sum(Corrected_Consumption_SCM),2) as Total_Consumption 
                from consumptions
                group by month)

Select f.month as Month, 
		f.Total_input as Total_input, 
        c.Total_Consumption as Total_Consumption, 
        concat(round((f.Total_input - c.Total_Consumption)/ f.Total_input*100,2),'%') as Loss 
from Frs_temp F
join consumptions_temp C
on c.MOnth = f.month;


# FRS WISE GAS LOSS

with frs_temp as(
		Select Frs_name, round(sum(gas_input_scm),2) as Total_output from Frs
		group by Frs_name)
        ,
consumption_temp as (
		Select C.Frs_name , 
				round(sum(c1.Corrected_Consumption_SCM),2) as Total_consumption from customers c
        join consumptions c1
        on c1.customer_id = C.customer_id
        group by C.Frs_name)
        
select f.frs_name, 
		f.Total_output , 
		c.total_consumption ,
		concat(round((f.total_output - c.total_consumption) 
        / 
        f.total_output*100,2), ' %') as Loss_percentage 
from Frs_temp f
join consumption_temp as c
on f.Frs_name = c.frs_name;

# Complaints

# Total Complaints
Select Count(*) as Total_Complaints from complaints;

# Compliants_Type
Select distinct complaint_type from Complaints;

# Complaints based on Complaint Type

Select Complaint_type, Count(*) as Total_complaints from complaints 
group  by complaint_type
order by total_complaints desc;

# Pending Complaints by complaint Types
(Select complaint_type , 
		count( case when `status` = 'pending' then 1 end) as Pending_complaints 
from complaints
group by Complaint_type
order by Pending_complaints)
union all
(Select 'Total' as Complaint_type, 
			count(case when `status` = 'pending' then 1 end) as Pending_complaints 
from complaints);


# SLA Analysis

SELECT
complaint_type,
COUNT(*) Total_Complaints,

COUNT(
CASE
WHEN complaint_type IN ('Gas Leakage','No Gas Supply')
AND tat_hours<=3 THEN 1

WHEN complaint_type='Low Pressure'
AND tat_hours<=24 THEN 1

WHEN complaint_type IN ('Meter Issue','Billing Issue')
AND tat_hours<=168 THEN 1
END
) AS Within_SLA,

ROUND(
COUNT(
CASE
WHEN complaint_type IN ('Gas Leakage','No Gas Supply')
AND tat_hours<=3 THEN 1

WHEN complaint_type='Low Pressure'
AND tat_hours<=24 THEN 1

WHEN complaint_type IN ('Meter Issue','Billing Issue')
AND tat_hours<=168 THEN 1
END
)
/COUNT(*)*100,2) AS SLA_Percentage

FROM complaints
GROUP BY complaint_type;

# Average Turn Around time for Each complaint Type
Select Complaint_type, round(avg(tat_hours)) as Avg_tat_hrs from complaints
where tat_hours is not null
group by complaint_type ;
 

#Total Maintenance Issue
select count(issue_found) as Total_issues from maintenance
where issue_found != 'No issue found';

# Repeated maintenance Issues
Select Frs_name, Issue_found , count(issue_found) Total_Issues from maintenance
where issue_found != 'No Issue Found'
group by Frs_name, Issue_found
having count(issue_found) > 1
order by Total_issues desc