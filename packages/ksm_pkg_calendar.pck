Create Or Replace Package ksm_pkg_calendar Is

/*************************************************************************
Author  : PBH634
Created : 4/14/2025
Purpose : Provide key NU and KSM dates to other code in a consistent way.
  Combined into a package for ease of parameter checks/updates.
Dependencies: ksm_pkg_utility

Suggested naming conventions:
  Pure functions: [function type]_[description]
  Row-by-row retrieval (slow): get_[object type]_[action or description] e.g.
  Table or cursor retrieval (fast): tbl_[object type]_[action or description]
*************************************************************************/

/*************************************************************************
Public constant declarations
*************************************************************************/

pkg_name Constant varchar2(64) := 'ksm_pkg_calendar';

-- Fiscal and performance start months
fy_start_month Constant number := 9; -- fiscal start month, 9 = September
py_start_month Constant number := 5; -- performance start month, 5 = May
py_start_month_py21 Constant number := 6; -- performance start month, 6 = June in PY2021 (COVID adjustment)

/*************************************************************************
Public type declarations
*************************************************************************/

Type rec_calendar Is Record (
  today date
  , yesterday date
  , yesterday_last_year date
  , ninety_days_ago date
  , curr_fy number
  , prev_fy_start date
  , curr_fy_start date
  , next_fy_start date
  , curr_py number
  , prev_py_start date
  , curr_py_start date
  , next_py_start date
  , prev_fy_today date
  , next_fy_today date
  , prev_week_start date
  , curr_week_start date
  , next_week_start date
  , prev_month_start date
  , curr_month_start date
  , next_month_start date
);

/*************************************************************************
Public table declarations
*************************************************************************/

Type calendar Is Table Of rec_calendar;

/*************************************************************************
Public function declarations
*************************************************************************/

-- Returns numeric constants
Function get_numeric_constant(
  const_name In varchar2 -- Name of constant to retrieve
) Return number Deterministic;

-- Based on fy_start_month
Function fytd_indicator(
  dt In date
  , day_offset In number Default -1 -- default offset in days, -1 means up to yesterday is year-to-date, 0 up to today, etc.
) Return character; -- Y or N

-- Compute fiscal or performance quarter from date
Function get_quarter(
  dt In date
  , fisc_or_perf In varchar2 Default 'fiscal' -- 'f'iscal or 'p'erformance quarter
) Return number; -- Quarter, 1-4

-- Compute fiscal month from date
Function get_fiscal_month(
  dt In date
) Return number; -- Translates chronological calendar month to fiscal month

-- Takes a date or string and returns the fiscal year
-- Date version
Function get_fiscal_year(
  dt In date
) Return number; -- Fiscal year part of date
-- String version
Function get_fiscal_year(
  dt In varchar2
  , format In varchar2 Default 'yyyy/mm/dd'
) Return number; -- Fiscal year part of date

-- Takes a date and returns the performance year
-- Date version
Function get_performance_year(
  dt In date
) Return number; -- Performance year part of date

/*************************************************************************
Public pipelined functions declarations
*************************************************************************/

-- Returns a 1-row table with selectable date objects (safe to cross join)
-- Pipelined version
Function tbl_current_calendar
  Return calendar Pipelined;

End ksm_pkg_calendar;
/
Create Or Replace Package Body ksm_pkg_calendar Is

/*************************************************************************
Private cursors -- data definitions
*************************************************************************/

-- Compiles useful dates together for use in other functions.
-- Naming convention:
--  curr_, or no prefix, for current year, e.g. today, curr_fy
--  prev_fy, prev_fy2, prev_fy3, etc. for 1, 2, 3 years ago, e.g. prev_fy_today
--  next_fy, next_fy2, next_fy3, etc. for 1, 2, 3 years in the future, e.g. next_fy_today
Cursor c_current_calendar (
  fy_start_month In integer
  , py_start_month In integer
  ) Is
  With
  -- Store today from sysdate and calculate current fiscal year, always year + 1 unless the FY starts in Jan
  curr_date As (
    Select
      trunc(sysdate) As today
      -- Current fiscal year, uses fy_start_month constant
      , ksm_pkg_calendar.get_fiscal_year(sysdate)
        As yr
      -- Current performance year, uses py_start_month constant
      , ksm_pkg_calendar.get_performance_year(sysdate)
        As perf_yr
      -- Correction for starting after January
      , Case
        When fy_start_month != 1 Then 1 Else 0
      End As yr_dif
    From DUAL
  )
  -- Final table with definitions
  Select
    -- Current day
    curr_date.today As today
    -- Yesterday
    , curr_date.today - 1 As yesterday
    , add_months(curr_date.today - 1, -12) As yesterday_last_year
    -- 90 days ago (for clearance)
    , curr_date.today - 90 As ninety_days_ago
    -- Current fiscal year
    , curr_date.yr As curr_fy
    -- Start of fiscal year objects
    , to_date(fy_start_month || '/01/' || (curr_date.yr - yr_dif - 1), 'mm/dd/yyyy')
      As prev_fy_start
    , to_date(fy_start_month || '/01/' || (curr_date.yr - yr_dif + 0), 'mm/dd/yyyy')
      As curr_fy_start
    , to_date(fy_start_month || '/01/' || (curr_date.yr - yr_dif + 1), 'mm/dd/yyyy')
      As next_fy_start
    -- Current performance year
    , curr_date.perf_yr As curr_py
    -- Start of performance year objects
    -- Previous PY correction for 2021
    , Case
        When perf_yr - 1 = 2021
          Then to_date(py_start_month_py21 || '/01/' || (curr_date.perf_yr - yr_dif - 1), 'mm/dd/yyyy')
        Else to_date(py_start_month || '/01/' || (curr_date.perf_yr - yr_dif - 1), 'mm/dd/yyyy')
        End
      As prev_py_start
    , Case
        When perf_yr = 2021
          Then to_date(py_start_month_py21 || '/01/' || (curr_date.perf_yr - yr_dif + 0), 'mm/dd/yyyy')
        Else to_date(py_start_month || '/01/' || (curr_date.perf_yr - yr_dif + 0), 'mm/dd/yyyy')
        End
      As curr_py_start
    , Case
        When perf_yr + 1 = 2021
          Then to_date(py_start_month_py21 || '/01/' || (curr_date.perf_yr - yr_dif + 1), 'mm/dd/yyyy')
        Else to_date(py_start_month || '/01/' || (curr_date.perf_yr - yr_dif + 1), 'mm/dd/yyyy')
        End
      As next_py_start
    -- Year-to-date objects
    , add_months(trunc(sysdate), -12) As prev_fy_today
    , add_months(trunc(sysdate), 12) As next_fy_today
    -- Start of week objects
    , trunc(sysdate, 'IW') - 7 As prev_week_start
    , trunc(sysdate, 'IW') As curr_week_start
    , trunc(sysdate, 'IW') + 7 As next_week_start
    -- Start of month objects
    , add_months(trunc(sysdate, 'Month'), -1) As prev_month_start
    , add_months(trunc(sysdate, 'Month'), 0) As curr_month_start
    , add_months(trunc(sysdate, 'Month'), 1) As next_month_start
  From curr_date
  ;

/*************************************************************************
Functions
*************************************************************************/

-- Retrieve one of the named constants from the package 
-- Requires a quoted constant name
Function get_numeric_constant(const_name In varchar2)
  Return number Deterministic Is
  -- Declarations
  val number;
  var varchar2(100);
  
  Begin
    -- If const_name doesn't include ksm_pkg, prepend it
    If substr(lower(const_name), 1, length(pkg_name)) <> pkg_name
      Then var := pkg_name || '.' || const_name;
    Else
      var := const_name;
    End If;
    -- Run command
    Execute Immediate
      'Begin :val := ' || var || '; End;'
      Using Out val;
      Return val;
  End;

--------------------------------------
-- Fiscal year to date indicator: Takes as an argument any date object and returns Y/N
Function fytd_indicator(dt In date, day_offset In number)
  Return character Is
  -- Declarations
  output character;
  today_fisc_day number;
  today_fisc_mo number;
  dt_fisc_day number;
  dt_fisc_mo number;

  Begin
    -- extract dt fiscal month and day
    today_fisc_day := extract(day from sysdate);
    today_fisc_mo  := ksm_pkg_utility.mod_math(m => extract(month from sysdate) - fy_start_month, n => 12) + 1;
    dt_fisc_day    := extract(day from dt);
    dt_fisc_mo     := ksm_pkg_utility.mod_math(m => extract(month from dt) - fy_start_month, n => 12) + 1;
    -- logic to construct output
    If dt_fisc_mo < today_fisc_mo Then
      -- if dt_fisc_mo is earlier than today_fisc_mo no need to continue checking
      output := 'Y';
    ElsIf dt_fisc_mo > today_fisc_mo Then
      output := 'N';
    ElsIf dt_fisc_mo = today_fisc_mo Then
      If dt_fisc_day <= today_fisc_day + day_offset Then
        output := 'Y';
      Else
        output := 'N';
      End If;
    Else
      -- fallback condition
      output := NULL;
    End If;
    
    Return(output);
  End;

--------------------------------------
-- Compute fiscal or performance quarter from date
-- Defaults to fiscal quarter
Function get_quarter(dt In date, fisc_or_perf In varchar2 Default 'fiscal')
  Return number Is
  -- Declarations
  this_month number;
  chron_month number;
  
  Begin
    this_month := extract(month from dt);
    -- Convert to chronological month number, where FY/PY start month = 1
    If lower(fisc_or_perf) Like 'f%' Then
      chron_month := ksm_pkg_utility.mod_math(this_month - fy_start_month, 12) + 1;
    ElsIf lower(fisc_or_perf) Like 'p%' Then
      chron_month := ksm_pkg_utility.mod_math(this_month - py_start_month, 12) + 1;
    End If;
    -- Return appropriate quarter corresponding to month; 3 months per quarter
    Return ceil(chron_month / 3);
  End;

--------------------------------------
-- Compute fiscal month from date
Function get_fiscal_month(
  dt In date
) Return number Is
  -- Declarations
  this_month number;
  
  Begin
    this_month := extract(month from dt);
    -- Modulo 12, add 1 so range is 1-12 instead of 0-11
    Return ksm_pkg_utility.mod_math(this_month - fy_start_month, 12) + 1;
  End;

--------------------------------------
-- Compute fiscal year from date parameter
-- Date version
Function get_fiscal_year(dt In date)
  Return number Is
  -- Declarations
  this_year number;
  
  Begin
    this_year := extract(year from dt);
    -- If month is before fy_start_month, return this_year
    If extract(month from dt) < fy_start_month
      Or fy_start_month = 1 Then
      Return this_year;
    End If;
    -- Otherwise return out_year + 1
    Return (this_year + 1);
  End;
-- String version
Function get_fiscal_year(dt In varchar2, format In varchar2 Default 'yyyy/mm/dd')
  Return number Is
  -- Declarations
  this_year number;
  
  Begin
    this_year := extract(year from ksm_pkg_utility.to_date2(dt, format));
    -- If month is before fy_start_month, return this_year
    If extract(month from ksm_pkg_utility.to_date2(dt, format)) < fy_start_month
      Or fy_start_month = 1 Then
      Return this_year;
    End If;
    -- Otherwise return out_year + 1
    Return (this_year + 1);
  End;

--------------------------------------
-- Compute performance year from date parameter
-- Date version
Function get_performance_year(dt In date)
  Return number Is
  -- Declarations
  this_year number;
  
  Begin
    this_year := extract(year from dt);
    -- If year is 2020, check for py_start_month_py21
    If this_year = 2020 Then
      If extract(month from dt) < py_start_month_py21 Then
        Return this_year;
      End If;
      Return (this_year + 1);
    End If;
    -- If month is before fy_start_month, return this_year
    If extract(month from dt) < py_start_month
      Or py_start_month = 1 Then
      Return this_year;
    End If;
    -- Otherwise return out_year + 1
    Return (this_year + 1);
  End;

/*************************************************************************
Pipelined functions
*************************************************************************/

-- Pipelined function returning the current calendar definition
Function tbl_current_calendar
  Return calendar Pipelined As
  -- Declarations
  cal calendar;
    
  Begin
    Open c_current_calendar(fy_start_month, py_start_month);
      Fetch c_current_calendar Bulk Collect Into cal;
    Close c_current_calendar;
    For i in 1..(cal.count) Loop
      Pipe row(cal(i));
    End Loop;
    Return;
  End;

End ksm_pkg_calendar;
/
