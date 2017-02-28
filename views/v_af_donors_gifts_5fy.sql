Create Or Replace View v_af_donors_gifts_5fy As
With

/* Core Annual Fund transaction-level view; current and previous 5 fiscal years. Rolls data up to the household giving source donor
   level, e.g. Kellogg-specific giving source donor, then householded for married entities. */

-- Kellogg Annual Fund allocations as defined in ksm_pkg
ksm_af_allocs As (
  Select COLUMN_VALUE As allocation_code
  From table(ksm_pkg.tbl_alloc_annual_fund_ksm)
),

-- Calendar date range from current_calendar
cal As (
  Select curr_fy - 5 As prev_fy5, curr_fy, yesterday
  From v_current_calendar
),

-- KSM householding
households As (
  Select id_number, household_id, household_ksm_year, household_program_group
  From table(ksm_pkg.tbl_entity_households_ksm)
),

-- Formatted giving table
ksm_af_gifts As (
  Select ksm_af_allocs.allocation_code, alloc_short_name, tx_number, tx_sequence, tx_gypm_ind, fiscal_year, date_of_record,
    legal_amount, credit_amount, nwu_af_amount, nu_gft_trp_gifttrans.id_number,
    ksm_pkg.get_gift_source_donor_ksm(tx_number) As ksm_src_dnr_id,
    households.household_id As ksm_household_src_dnr,
    curr_fy, yesterday
  From cal, nu_gft_trp_gifttrans
    Inner Join ksm_af_allocs
      On ksm_af_allocs.allocation_code = nu_gft_trp_gifttrans.allocation_code
    Inner Join households On households.id_number = ksm_pkg.get_gift_source_donor_ksm(tx_number)
  -- Only pull KSM AF gifts in recent fiscal years
  Where nu_gft_trp_gifttrans.allocation_code = ksm_af_allocs.allocation_code
    And fiscal_year Between cal.prev_fy5 And cal.curr_fy
    -- Drop pledges
    And tx_gypm_ind != 'P'
)

-- Gift receipts and biographic information
Select
  -- Giving fields
  af.allocation_code, af.alloc_short_name, af.tx_number, af.tx_sequence, af.tx_gypm_ind, af.fiscal_year, af.date_of_record,
  ksm_pkg.fytd_indicator(af.date_of_record) As ytd_ind, -- year to date flag
  af.id_number As legal_dnr_id, af.legal_amount, af.credit_amount, af.nwu_af_amount,
  -- Household source donor entity fields
  af.ksm_household_src_dnr, e_src_dnr.pref_name_sort, e_src_dnr.person_or_org, e_src_dnr.record_status_code, e_src_dnr.institutional_suffix,
  ksm_pkg.get_entity_address(e_src_dnr.id_number, 'state_code') As master_state,
  ksm_pkg.get_entity_address(e_src_dnr.id_number, 'country') As master_country,
  e_src_dnr.gender_code, e_src_dnr.spouse_id_number,
  -- KSM alumni flag
  Case When ksm_pkg.get_entity_degrees_concat_fast(e_src_dnr.id_number) Is Not Null Then 'Y' Else 'N' End As ksm_alum_flag,
  -- Fiscal year number
  curr_fy, yesterday As data_as_of
From ksm_af_gifts af
  Inner Join entity e_src_dnr On af.ksm_household_src_dnr = e_src_dnr.id_number
Where legal_amount > 0
