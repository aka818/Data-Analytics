--Creating New Database for the given dataset
Create Database CovidData;

Use CovidData;


--Imported Dataset and renamed the table to CovidDeathCounts and used following query to check the first 10 records of the data.
Select Top 20* From CovidDeathCounts;




--Data Cleaning
--1. Renaming Group field to TimeGroup 
  --for ease of use in queries as Group is also reserved word



--2. Replacing '/' with '-' in Dates for uniformity
Update CovidDeathCounts
Set data_period_start = Replace(data_period_start, '/', '-');


Update CovidDeathCounts
Set data_period_end =  Replace(data_period_end, '/', '-'); 




--3. Converting string to date
Update CovidDeathCounts
Set data_as_of = CONVERT(date, data_as_of, 110);

Update CovidDeathCounts
Set data_period_start = CONVERT(date, data_period_start, 110);

Update CovidDeathCounts
Set data_period_end = CONVERT(date, data_period_end, 110);



--4. Making blank values as Null
Update CovidDeathCounts
Set COVID_deaths = Null, COVID_pct_of_total = Null, pct_change_wk = Null, pct_diff_wk = Null, crude_COVID_rate = NUll, aa_COVID_rate = Null
Where footnote = 'Death counts between 1-9 are suppressed. Rates for deaths counts <20 are unreliable.'


Update CovidDeathCounts
Set crude_COVID_rate = NUll, aa_COVID_rate = Null
Where footnote = 'Rates for deaths counts <20 are unreliable.'




--Data Profiling 
--1. No. of records
Select Count(*) From CovidDeathCounts;
--21952


--2. Different Residential Jurisdictions and Total no. of jurisdictions.
Select Distinct Jurisdiction_Residence From CovidDeathCounts Order by Jurisdiction_Residence;

Select Count(Distinct Jurisdiction_Residence)From CovidDeathCounts;
--64


--3. Latest Date
Select Max(data_period_end) From CovidDeathCounts;




--------------------------------------------------------------------------------------------------------------------------------------------------
--Data Analysis
--1.Retrieve the jurisdiction residence with the highest number of COVID deaths for the latest data period end date.

Select Jurisdiction_Residence, COVID_deaths 
From CovidDeathCounts 
Where data_period_end = (Select Max(data_period_end) From CovidDeathCounts)
And COVID_deaths = (Select Max(COVID_deaths) From CovidDeathCounts);



---------------------------------------------------------------------------------------------------------------------------------------------
--2. Calculate the week-over-week percentage change in crude COVID rate for all jurisdictions and groups, sorted by the highest percentage 
--change first. 

SELECT a.Jurisdiction_Residence, 
b.data_period_end as CurrWeekDate, 
(Round(100.0*(b.crude_COVID_rate - a.crude_COVID_rate)/a.crude_COVID_rate, 2)) AS WeeklyPerChange
FROM CovidDeathCounts a, CovidDeathCounts b 
	WHERE a.Jurisdiction_Residence = b.Jurisdiction_Residence 
	AND a.data_period_end = DATEADD(WEEK, -1, b.data_period_end) 
	AND a.TimeGroup = 'weekly' and b.TimeGroup = 'weekly'
	AND a.crude_COVID_rate <> 0
ORDER BY WeeklyPerChange Desc;


Select * 
From CovidDeathCounts
Where Jurisdiction_Residence = 'Michigan'
And TimeGroup = 'Weekly'
And data_period_end = '2020-03-28';
----------------------------------------------------------------------------------------------------------------------------------------------
--3. Retrieve the top 5 jurisdictions with the highest percentage difference in aa_COVID_rate compared to the overall crude COVID rate for the 
--latest data period end date.

--Temporary table 

--Drop Table #CovidRatesComparison
Create Table #CovidRatesComparison 
(Jurisdiction varchar(50), 
AA_CovidRate float, 
PerChange float) 


--Creating a CTE for Overall crude Covid rate
WIth OverAllCrudeRate (AvgCrudeRate)
As
(Select Avg(crude_COVID_rate) 
From CovidDeathCounts
Where data_period_end = (Select Max(data_period_end) From CovidDeathCounts)
And TimeGroup = 'total'
)

--Inserting values in Temp Table created
Insert into #CovidRatesComparison
Select Jurisdiction_Residence, 
aa_COVID_rate, 
(100*(aa_COVID_rate - (Select * From OverAllCrudeRate))/(Select * From OverAllCrudeRate)) As PerDiff --Calculation of % change
From CovidDeathCounts
Where data_period_end = (Select Max(data_period_end) From CovidDeathCounts)
And TimeGroup = 'total'


--Calculating Absolute % diff in rates 
Select Top 5 * , 
Case 
	When PerChange < 0 Then PerChange * -1
	Else PerChange
End As AbsDiff
From #CovidRatesComparison
Order by 4 Desc;



-------------------------------------------------------------------------------------------------------------------------------------------
--4. Calculate the average COVID deaths per week for each jurisdiction residence and group, for the latest 4 data period end dates. 

Select Jurisdiction_Residence, 
Avg(COVID_deaths) As AvgPerWeek
From CovidDeathCounts
Where Timegroup = 'weekly' 
And
data_period_end <= (Select Max(data_period_end) From CovidDeathCounts)
and data_period_end > (Select DATEADD(WEEK, -4, (Select Max(data_period_end) From CovidDeathCounts)))
Group by Jurisdiction_Residence
Order by 2 Desc;



----------------------------------------------------------------------------------------------------------------------------------------------
--5. Retrieve the data for the latest data period end date, but exclude any jurisdictions that had zero COVID deaths and have missing values
--in any other column. 

Select * 
From CovidDeathCounts
Where data_period_end = (Select Max(data_period_end) From CovidDeathCounts) and
COVID_deaths <> 0 and
COVID_deaths is not Null and
COVID_pct_of_total is not Null and
pct_change_wk is not Null and
pct_diff_wk is not Null and
crude_COVID_rate is not NUll and 
aa_COVID_rate is not Null ;



------------------------------------------------------------------------------------------------------------------------------------------------
--6. Calculate the week-over-week percentage change in COVID_pct_of_total for all jurisdictions and groups, but only for the data period start 
--dates after March 1, 2020. 

Create View WeekorverWeek
As
SELECT a.Jurisdiction_Residence, 
b.data_period_end as CurrWeekDate, 
(Round(100.0*(b.COVID_pct_of_total - a.COVID_pct_of_total)/a.COVID_pct_of_total, 2)) AS WeeklyChange
FROM CovidDeathCounts a, CovidDeathCounts b 
	WHERE a.Jurisdiction_Residence = b.Jurisdiction_Residence 
	AND a.data_period_end = DATEADD(WEEK, -1, b.data_period_end) 
	AND a.TimeGroup = 'weekly' and b.TimeGroup = 'weekly'
	AND a.COVID_pct_of_total <> 0;


Select * 
From WeekorverWeek
Where CurrWeekDate > '2020-03-01'
ORDER BY WeeklyChange Desc;



-------------------------------------------------------------------------------------------------------------------------------------------------
--7. Group the data by jurisdiction residence and calculate the cumulative COVID deaths for each jurisdiction, but only up to the latest data 
--period end date. 

Select Jurisdiction_Residence, Sum(Covid_deaths) as CummlativeNo
From CovidDeathCounts
Where TimeGroup = 'weekly'
Group by Jurisdiction_Residence
Order by 2 Desc;

Select * 
From CovidDeathCounts
Where Jurisdiction_Residence = 'Region 7'
And data_period_end = '2023-04-08'

--------------------------------------------------------------------------------------------------------------------------------------------------
--8. Identify the jurisdiction with the highest percentage increase in COVID deaths from the previous week, and provide the actual numbers of 
--deaths for each week. This would require a subquery to calculate the previous week's deaths.

--CTE with data for current and previous week 
With CurrVsPrevWeek (Jurisdiction, CurrWeekDate, CurrWeekDeaths, PrevWeekDeaths )
As
(Select a.Jurisdiction_Residence, a.data_period_end, a.covid_deaths, 
		(SELECT  b.COVID_deaths 
		FROM CovidDeathCounts b 
		Where b.data_period_end =  DATEADD(Week, -1, a.data_period_end )
		And TimeGroup = 'weekly'
		And a.Jurisdiction_Residence = b.Jurisdiction_Residence) 
FROM CovidDeathCounts a
Where TimeGroup = 'weekly')


--Calculation of % change
Select *,
((CurrWeekDeaths - PrevWeekDeaths)*100/PrevWeekDeaths) As PerChange
From CurrVsPrevWeek
Where PrevWeekDeaths <> 0
Order by PerChange Desc;



---------------------------------------------------------------------------------------------------------------------------------------------------
--9. Compare the crude COVID death rates for different age groups, but only for jurisdictions where the total number of deaths exceeds a
--certain threshold (e.g. 100). 

Select Jurisdiction_Residence, crude_COVID_rate, COVID_deaths
From CovidDeathCounts  
Where TimeGroup = 'total'
And data_period_end = (Select Max(data_period_end) From CovidDeathCounts)
And COVID_deaths > 10000
Order by 3 Desc;



------------------------------------------------------------------------------------------------------------------------------------------------
--10. Implementation of Function & Procedure-
--"Create a stored procedure that takes in a date range and calculates the average weekly percentage change in COVID deaths for each jurisdiction. 
--The procedure should return the average weekly percentage change along with the jurisdiction and date range as output. 
--Additionally, create a user-defined function that takes in a jurisdiction as input and returns the average crude COVID rate for that jurisdiction 
--over the entire dataset. Use both the stored procedure and the user-defined function to compare the average weekly percentage change in COVID 
--deaths for each jurisdiction to the average crude COVID rate for that jurisdiction. 


--Creating Stored Procedure 
Drop Procedure AvgWeeklyChange
Create Procedure AvgWeeklyChange
@FirstDate date,
@LastDate date,
@Jurisdiction varchar(50)
As
SELECT a.Jurisdiction_Residence, Avg((b.COVID_deaths - a.COVID_deaths)*100.0/a.COVID_deaths) as AvgWeeklyChange, 
@FirstDate as FirstDAte, @LastDate as LastDate
FROM CovidDeathCounts a, CovidDeathCounts b 
	WHERE a.Jurisdiction_Residence = b.Jurisdiction_Residence 
	AND a.data_period_end = DATEADD(WEEK, -1, b.data_period_end) 
	AND a.TimeGroup = 'weekly' and b.TimeGroup = 'weekly'
	And a.data_period_end >= @FirstDate and b.data_period_end <= @LastDate
	AND a.Jurisdiction_Residence = @Jurisdiction
Group by a.Jurisdiction_Residence;


--Creating User Defined Function 
Drop Function AvgCrudeRate
Create Function AvgCrudeRate
(@Jurisdiction Varchar(50))
Returns Table
As
Return
	Select Avg(crude_COVID_rate) As CrudeRateAvg
	From CovidDeathCounts
	Where TimeGroup = 'Weekly'
	And Jurisdiction_Residence = @Jurisdiction
;


--Executing the Stored Procedure
Exec AvgWeeklyChange 
@FirstDate = '2022-06-12',
@LastDate = '2022-07-09', 
@Jurisdiction = 'Region 1';


--Executing the function created
Select *
From dbo.AvgCrudeRate('Region 1');



---------------------------------------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------------------------

