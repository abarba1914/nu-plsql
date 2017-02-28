Create Or Replace View v_af_donors_5fy_summary As
With

/* Requires the gift data aggregated in v_af_donors_gifts_5fy. Aggregated by household giving source donor and related fields, with
   each of the recent fiscal years its own column. */ 

-- Degrees concat
deg As (
  Select id_number, degrees_concat, program, program_group
  From table(ksm_pkg.tbl_entity_degrees_concat_ksm)
)

-- Aggregated by entity and fiscal year
Select
  -- Entity fields
  id_hh_src_dnr, pref_name_sort, person_or_org, record_status_code, institutional_suffix,
  entity_deg.degrees_concat As src_dnr_degrees_concat,
  entity_deg.program As src_dnr_program,
  entity_deg.program_group As src_dnr_program_group,
  master_state, master_country, gender_code, spouse_id_number,
  spouse_deg.degrees_concat As spouse_degrees_concat,
  ksm_alum_flag,
  -- Date fields
  curr_fy, data_as_of,
  -- Aggregated giving amounts
  sum(Case When fiscal_year = (curr_fy - 0) Then legal_amount Else 0 End) As ksm_af_curr_fy,
  sum(Case When fiscal_year = (curr_fy - 1) Then legal_amount Else 0 End) As ksm_af_prev_fy1,
  sum(Case When fiscal_year = (curr_fy - 2) Then legal_amount Else 0 End) As ksm_af_prev_fy2,
  sum(Case When fiscal_year = (curr_fy - 3) Then legal_amount Else 0 End) As ksm_af_prev_fy3,
  sum(Case When fiscal_year = (curr_fy - 4) Then legal_amount Else 0 End) As ksm_af_prev_fy4,
  sum(Case When fiscal_year = (curr_fy - 5) Then legal_amount Else 0 End) As ksm_af_prev_fy5,
  -- Aggregated YTD giving amounts
  sum(Case When fiscal_year = (curr_fy - 0) And ytd_ind = 'Y' Then legal_amount Else 0 End) As ksm_af_curr_fy_ytd,
  sum(Case When fiscal_year = (curr_fy - 1) And ytd_ind = 'Y' Then legal_amount Else 0 End) As ksm_af_prev_fy1_ytd,
  sum(Case When fiscal_year = (curr_fy - 2) And ytd_ind = 'Y' Then legal_amount Else 0 End) As ksm_af_prev_fy2_ytd,
  sum(Case When fiscal_year = (curr_fy - 3) And ytd_ind = 'Y' Then legal_amount Else 0 End) As ksm_af_prev_fy3_ytd,
  sum(Case When fiscal_year = (curr_fy - 4) And ytd_ind = 'Y' Then legal_amount Else 0 End) As ksm_af_prev_fy4_ytd,
  sum(Case When fiscal_year = (curr_fy - 5) And ytd_ind = 'Y' Then legal_amount Else 0 End) As ksm_af_prev_fy5_ytd,
  -- Aggregated match amounts
  sum(Case When fiscal_year = (curr_fy - 0) And tx_gypm_ind = 'M' Then legal_amount Else 0 End) As ksm_af_curr_fy_match,
  sum(Case When fiscal_year = (curr_fy - 1) And tx_gypm_ind = 'M' Then legal_amount Else 0 End) As ksm_af_prev_fy1_match,
  sum(Case When fiscal_year = (curr_fy - 2) And tx_gypm_ind = 'M' Then legal_amount Else 0 End) As ksm_af_prev_fy2_match,
  sum(Case When fiscal_year = (curr_fy - 3) And tx_gypm_ind = 'M' Then legal_amount Else 0 End) As ksm_af_prev_fy3_match,
  sum(Case When fiscal_year = (curr_fy - 4) And tx_gypm_ind = 'M' Then legal_amount Else 0 End) As ksm_af_prev_fy4_match,
  sum(Case When fiscal_year = (curr_fy - 5) And tx_gypm_ind = 'M' Then legal_amount Else 0 End) As ksm_af_prev_fy5_match,
  -- Recent gift details
  max(Case When fiscal_year = (curr_fy - 0) then date_of_record Else NULL End) As last_gift_curr_fy,
  max(Case When fiscal_year = (curr_fy - 1) then date_of_record Else NULL End) As last_gift_prev_fy1,
  max(Case When fiscal_year = (curr_fy - 2) then date_of_record Else NULL End) As last_gift_prev_fy2,
  -- Count of gifts per year
  sum(Case When fiscal_year = (curr_fy - 0) then 1 Else 0 End) As gifts_curr_fy,
  sum(Case When fiscal_year = (curr_fy - 1) then 1 Else 0 End) As gifts_prev_fy1,
  sum(Case When fiscal_year = (curr_fy - 2) then 1 Else 0 End) As gifts_prev_fy2
From v_af_gifts_srcdnr_5fy af_gifts
  Left Join deg entity_deg On entity_deg.id_number = af_gifts.id_hh_src_dnr
  Left Join deg spouse_deg On spouse_deg.id_number = af_gifts.spouse_id_number
Group By id_hh_src_dnr, pref_name_sort, person_or_org, record_status_code, institutional_suffix, entity_deg.degrees_concat, entity_deg.program,
  entity_deg.program_group, master_state, master_country, gender_code, spouse_id_number, spouse_deg.degrees_concat, ksm_alum_flag,
  -- Date fields
  curr_fy, data_as_of
Order By pref_name_sort Asc
