Create Or Replace View v_af_gifts_srcdnr_5fy As
With

/* Core Annual Fund transaction-level view; current and previous 5 fiscal years. Rolls data up to the household giving source donor
   level, e.g. Kellogg-specific giving source donor, then householded for married entities.
   2017-07-17: added ytd_dts; removing function call from select led to ~32x speed-up! */

-- Kellogg Annual Fund allocations as defined in ksm_pkg
ksm_cru_allocs As (
  Select allocation_code, af_flag
  From table(ksm_pkg.tbl_alloc_curr_use_ksm)
),

-- Calendar date range from current_calendar
cal As (
  Select curr_fy - 7 As prev_fy, curr_fy, yesterday
  From v_current_calendar
),
ytd_dts As (
  Select to_date('09/01/' || (cal.prev_fy - 1), 'mm/dd/yyyy') + rownum - 1 As dt,
    ksm_pkg.fytd_indicator(to_date('09/01/' || (cal.prev_fy - 1), 'mm/dd/yyyy') + rownum - 1) As ytd_ind
  From cal
  Connect By
    rownum <= (to_date('09/01/' || cal.curr_fy, 'mm/dd/yyyy') - to_date('09/01/' || (cal.prev_fy - 1), 'mm/dd/yyyy'))
),

-- KSM householding
households As (
  Select *
  From table(ksm_pkg.tbl_entity_households_ksm)
),

-- Formatted giving tables
ksm_cru_trans As (
  Select Distinct tx_number, cal.curr_fy, cal.yesterday,
    ksm_pkg.get_gift_source_donor_ksm(tx_number) As id_src_dnr, -- giving source donor as defined by ksm_pkg
    ytd_dts.ytd_ind -- year to date flag
  From nu_gft_trp_gifttrans gft
  Cross Join cal
  Inner Join ksm_cru_allocs cru On cru.allocation_code = gft.allocation_code
  Inner Join ytd_dts On ytd_dts.dt = trunc(date_of_record)
  Where
    -- Drop pledges
    tx_gypm_ind <> 'P'
    -- Only pull KSM current use gifts in recent fiscal years
    And fiscal_year Between cal.prev_fy And cal.curr_fy
),
ksm_cru_gifts As (
  Select cru.allocation_code, cru.af_flag,
    gft.alloc_short_name, gft.alloc_purpose_desc, gft.tx_number, gft.tx_sequence, gft.tx_gypm_ind,
    gft.fiscal_year, trunc(gft.date_of_record) As date_of_record, trans.ytd_ind,
    gft.legal_amount, gft.credit_amount, gft.nwu_af_amount,
    gft.id_number As legal_dnr_id,
    trans.id_src_dnr,
    households.household_id As id_hh_src_dnr,
    trans.curr_fy, trans.yesterday
  From nu_gft_trp_gifttrans gft
  Inner Join ksm_cru_allocs cru On cru.allocation_code = gft.allocation_code
  Inner Join ksm_cru_trans trans On trans.tx_number = gft.tx_number
  Inner Join households On households.id_number = trans.id_src_dnr
)

-- Gift receipts and biographic information
Select
  -- Giving fields
  af.allocation_code, af.af_flag, af.alloc_short_name, af.alloc_purpose_desc, af.tx_number, af.tx_sequence, af.tx_gypm_ind, af.fiscal_year,
  af.date_of_record, af.ytd_ind,
  af.legal_dnr_id, af.legal_amount, af.credit_amount, af.nwu_af_amount,
  -- Household source donor entity fields
  af.id_hh_src_dnr, hh.pref_mail_name, e_src_dnr.pref_name_sort, e_src_dnr.report_name, e_src_dnr.person_or_org, e_src_dnr.record_status_code,
  e_src_dnr.institutional_suffix,
  hh.household_state As master_state,
  hh.household_country As master_country,
  e_src_dnr.gender_code, hh.spouse_id_number, hh.spouse_pref_mail_name,
  -- KSM alumni flag
  Case When hh.household_program_group Is Not Null Then 'Y' Else 'N' End As ksm_alum_flag,
  -- Fiscal year number
  curr_fy, yesterday As data_as_of
From ksm_cru_gifts af
Inner Join entity e_src_dnr On af.id_hh_src_dnr = e_src_dnr.id_number
Inner Join households hh On hh.id_number = af.id_hh_src_dnr
Where legal_amount > 0
