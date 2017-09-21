With

/* Degree strings */
degs As (
  Select id_number, stewardship_years As yrs
  From table(ksm_pkg.tbl_entity_degrees_concat_ksm) deg
),

/* Household data */
hhs As (
  Select *
  From table(ksm_pkg.tbl_entity_households_ksm)
),
hh As (
  Select hhs.*,
    entity.gender_code As gender, entity_s.gender_code As gender_spouse,
    entity.person_or_org, entity.record_status_code As record_status, entity_s.record_status_code As record_status_spouse,
    -- Is either spouse no joint gifts?
    Case When hhs.household_spouse_rpt_name Is Not Null And
      (entity.jnt_gifts_ind = 'N' Or entity_s.jnt_gifts_ind = 'N') Then 'Y' End As no_joint_gifts_flag,
    -- First Middle Last Suffix 'YY
    trim(
      trim(
      trim(trim(trim(trim(entity.first_name) || ' ' || trim(entity.middle_name)) || ' ' || trim(entity.last_name)) || ' ' || entity.pers_suffix)
      || ' ' || degs.yrs)
      || (Case When entity.record_status_code = 'D' Then '<DECEASED>' End)
    ) As primary_name,
    trim(
      trim(
      trim(trim(trim(trim(entity_s.first_name) || ' ' || trim(entity_s.middle_name)) || ' ' || trim(entity_s.last_name)) || ' ' || entity_s.pers_suffix)
      || ' ' || degs_s.yrs)
      || (Case When entity_s.record_status_code = 'D' Then '<DECEASED>' End)
    ) As primary_name_spouse,
    degs.yrs, degs_s.yrs As yrs_spouse
  From hhs hhs
  -- Names and strings for formatting
  Inner Join entity On entity.id_number = hhs.household_id
  Left Join entity entity_s On entity_s.id_number = hhs.household_spouse_id
  Left Join degs On degs.id_number = hhs.household_id
  Left Join degs degs_s On degs_s.id_number = hhs.household_spouse_id
  -- Exclude purgable entities
  Where hhs.record_status_code <> 'X'
),

/* Anonymous */
anon As (
  Select Distinct hh.household_id, tms.short_desc As anon
  From handling
  Inner Join hh On hh.id_number = handling.id_number
  Inner Join tms_handling_type tms On tms.handling_type = handling.hnd_type_code
  Where hnd_type_code = 'AN'
    And hnd_status_code = 'A'
),

/* Deceased spouses */
dec_spouse As (
  Select Distinct id_number, spouse_id_number
  From former_spouse
  Where marital_status_code In (
    Select marital_status_code From tms_marital_status Where lower(short_desc) Like '%death%'
  )
),
dec_spouse_conc As (
  Select id_number,
    Listagg(spouse_id_number, '; ') Within Group (Order By spouse_id_number) As dec_spouse_ids
  From dec_spouse
  Group By id_number
),

/* Deceased spouse TABLE -- update rpt_pbh634.tbl_ir_fy17_dec_spouse */
dec_spouse_ids As (
  Select ds.id_number, hh.gender, hh.primary_name As pn, hh.yrs, hh.household_rpt_name As sn,
    ds.id_join, hhd.gender As gender_join, hhd.primary_name As pnj, hhd.yrs As yrs_join, hhd.household_rpt_name As snj
  From rpt_pbh634.tbl_ir_fy17_dec_spouse ds
  Inner Join hh On hh.id_number = ds.id_number
  Inner Join hh hhd On hhd.id_number = ds.id_join
),

/* Prospect assignments */
assign As (
  Select Distinct hh.household_id, assignment.prospect_id, office_code, assignment_id_number, entity.report_name
  From assignment
  Inner Join entity On entity.id_number = assignment.assignment_id_number
  Inner Join prospect_entity On prospect_entity.prospect_id = assignment.prospect_id
  Inner Join hh On hh.id_number = prospect_entity.id_number
  Where active_ind = 'Y'
    And assignment_type In ('PP', 'PM')
),
assign_conc As (
  Select household_id,
    Listagg(report_name, ';  ') Within Group (Order By report_name) As managers
  From assign
  Group By household_id
),

/* KLC entities */
young_klc As (
  Select klc.*
  From table(ksm_pkg.tbl_klc_history) klc
  Where fiscal_year Between 2012 And 2017
),
fy_klc As (
  Select Distinct household_id, '<KLC17>' As klc
  From young_klc
  Where fiscal_year = 2017
),

/* Loyal households */
loyal_giving As (
  Select Distinct hhs.household_id,
    -- WARNING: includes new gifts and commitments as well as cash
    sum(Case When fiscal_year = 2017 Then hh_credit Else 0 End) As stewardship_cfy,
    sum(Case When fiscal_year = 2016 Then hh_credit Else 0 End) As stewardship_pfy1,
    sum(Case When fiscal_year = 2015 Then hh_credit Else 0 End) As stewardship_pfy2
  From hhs
  Cross Join v_current_calendar cal
  Inner Join v_ksm_giving_trans_hh gfts On gfts.household_id = hhs.household_id
  Group By hhs.household_id
),
loyal As (
  Select loyal_giving.*,
    Case When stewardship_cfy > 0 And stewardship_pfy1 > 0 And stewardship_pfy2 > 0 Then '<LOYAL>' End As loyal
  From loyal_giving
),

/* Campaign giving amounts */
cgft As (
  Select gft.*,
  -- Giving level string
  Case
    When entity.person_or_org = 'O' Then 'Z. Org'
    When campaign_steward_thru_fy17 >= 10000000 Then 'A. 10M+'
    When campaign_steward_thru_fy17 >=  5000000 Then 'B. 5M+'
    When campaign_steward_thru_fy17 >=  2500000 Then 'C. 2.5M+'
    When campaign_steward_thru_fy17 >=  1000000 Then 'D. 1M+'
    When campaign_steward_thru_fy17 >=   500000 Then 'E. 500K+'
    When campaign_steward_thru_fy17 >=   250000 Then 'F. 250K+'
    When campaign_steward_thru_fy17 >=   100000 Then 'G. 100K+'
    When campaign_steward_thru_fy17 >=    50000 Then 'H. 50K+'
    When campaign_steward_thru_fy17 >=    25000 Then 'I. 25K+'
    When campaign_steward_thru_fy17 >=    10000 Then 'J. 10K+'
    When campaign_steward_thru_fy17 >=     5000 Then 'K. 5K+'
    Else 'L. 2.5K+'
  End As proposed_giving_level,
  Case
    When entity.person_or_org = 'O' Then 'Z. Org'
    When nonanon_steward_thru_fy17 >= 10000000 Then 'A. 10M+'
    When nonanon_steward_thru_fy17 >=  5000000 Then 'B. 5M+'
    When nonanon_steward_thru_fy17 >=  2500000 Then 'C. 2.5M+'
    When nonanon_steward_thru_fy17 >=  1000000 Then 'D. 1M+'
    When nonanon_steward_thru_fy17 >=   500000 Then 'E. 500K+'
    When nonanon_steward_thru_fy17 >=   250000 Then 'F. 250K+'
    When nonanon_steward_thru_fy17 >=   100000 Then 'G. 100K+'
    When nonanon_steward_thru_fy17 >=    50000 Then 'H. 50K+'
    When nonanon_steward_thru_fy17 >=    25000 Then 'I. 25K+'
    When nonanon_steward_thru_fy17 >=    10000 Then 'J. 10K+'
    When nonanon_steward_thru_fy17 >=     5000 Then 'K. 5K+'
    Else 'L. 2.5K+'
  End As nonanon_giving_level
  From v_ksm_giving_campaign gft
  Inner Join entity On entity.id_number = gft.id_number
),

/* Cash giving amounts */
cash As (
  Select Distinct hhs.id_number, hhs.household_id, hhs.household_rpt_name, hhs.household_spouse_id, hhs.household_spouse,
    -- Cash giving for KLC young alumni determination
    sum(Case When fiscal_year = 2012 And tx_gypm_ind <> 'P' Then hh_credit Else 0 End) As cash_fy12,
    sum(Case When fiscal_year = 2013 And tx_gypm_ind <> 'P' Then hh_credit Else 0 End) As cash_fy13,
    sum(Case When fiscal_year = 2014 And tx_gypm_ind <> 'P' Then hh_credit Else 0 End) As cash_fy14,
    sum(Case When fiscal_year = 2015 And tx_gypm_ind <> 'P' Then hh_credit Else 0 End) As cash_fy15,
    sum(Case When fiscal_year = 2016 And tx_gypm_ind <> 'P' Then hh_credit Else 0 End) As cash_fy16,
    sum(Case When fiscal_year = 2017 And tx_gypm_ind <> 'P' Then hh_credit Else 0 End) As cash_fy17
  From hhs
  Inner Join v_ksm_giving_trans_hh gfts On gfts.household_id = hhs.household_id
  Group By hhs.id_number, hhs.household_id, hhs.household_rpt_name, hhs.household_spouse_id, hhs.household_spouse
),

/* Combine all criteria */
donorlist As (
  (
  -- $2500+ cumulative campaign giving
  Select cgft.*, hh.record_status_code, hh.household_spouse_rpt_name, hh.household_suffix, hh.household_spouse_suffix,
    hh.household_masters_year, hh.primary_name, hh.gender, hh.primary_name_spouse, hh.gender_spouse,
    hh.person_or_org, hh.yrs, hh.yrs_spouse, hh.fmr_spouse_id, hh.fmr_spouse_name, hh.fmr_marital_status,
    hh.no_joint_gifts_flag
  From cgft
  Inner Join hh On hh.id_number = cgft.id_number
  Where cgft.campaign_steward_thru_fy17 >= 2500
  ) Union All (
  -- Young alumni giving $1000+ from FY12 on
  Select cgft.*, hh.record_status_code, hh.household_spouse_rpt_name, hh.household_suffix, hh.household_spouse_suffix,
    hh.household_masters_year, hh.primary_name, hh.gender, hh.primary_name_spouse, hh.gender_spouse,
    hh.person_or_org, hh.yrs, hh.yrs_spouse, hh.fmr_spouse_id, hh.fmr_spouse_name, hh.fmr_marital_status,
    no_joint_gifts_flag
  From cgft
  Inner Join hh On hh.id_number = cgft.id_number
  Left Join cash On cash.id_number = cgft.id_number
  -- Graduated within "past" 5 years and gave at least $1000 "this" year
  Where cgft.household_id In (Select Distinct household_id From young_klc)
    And (
         ((hh.last_noncert_year Between 2007 And 2012 Or hh.spouse_last_noncert_year Between 2007 And 2012)
          And (campaign_fy12 >= 1000 Or cash_fy12 >= 1000))
      Or ((hh.last_noncert_year Between 2008 And 2013 Or hh.spouse_last_noncert_year Between 2008 And 2013)
          And (campaign_fy13 >= 1000 Or cash_fy13 >= 1000))
      Or ((hh.last_noncert_year Between 2009 And 2014 Or hh.spouse_last_noncert_year Between 2009 And 2014)
          And (campaign_fy14 >= 1000 Or cash_fy14 >= 1000))
      Or ((hh.last_noncert_year Between 2010 And 2015 Or hh.spouse_last_noncert_year Between 2010 And 2015)
          And (campaign_fy15 >= 1000 Or cash_fy15 >= 1000))
      Or ((hh.last_noncert_year Between 2011 And 2016 Or hh.spouse_last_noncert_year Between 2011 And 2016)
          And (campaign_fy16 >= 1000 Or cash_fy16 >= 1000))
      Or ((hh.last_noncert_year Between 2012 And 2017 Or hh.spouse_last_noncert_year Between 2012 And 2017)
          And (campaign_fy17 >= 1000 Or cash_fy17 >= 1000))
    )
  )
),

/* Name ordering helper */
rec_name_logic As (
  Select donorlist.id_number, donorlist.report_name, donorlist.household_id, donorlist.household_spouse_id,
    primary_name, primary_name_spouse, household_rpt_name, household_spouse_rpt_name,
    id_join,
    -- Name ordering based on rules we had discussed: alum first, if both or neither are alums then female first
    Case
      -- Anonymous donors take precedence
      When anon.anon Is Not Null Or lower(primary_name) Like '%anonymous%donor%' Then 'Anon'
      -- Organizations next
      When donorlist.person_or_org = 'O' Then 'Org'
      -- If no joint gift indicator, self only
      When no_joint_gifts_flag Is Not Null Then 'No Joint'
      -- If on deceased spouse list, override
      When dec_spouse_ids.id_number Is Not Null Then 'Dec Spouse'
      -- If no spouse, use own name
      When donorlist.primary_name_spouse Is Null Then 'Self'
      -- If spouse, check if either/both have degrees
      When donorlist.primary_name_spouse Is Not Null Then
        Case
          -- If primary is only one with degrees, order is primary spouse
          When donorlist.yrs Is Not Null And donorlist.yrs_spouse Is Null Then 'Self Spouse'
          -- If spouse is only one with degrees, order is spouse primary
          When donorlist.yrs Is Null And donorlist.yrs_spouse Is Not Null Then 'Spouse Self'
          -- Check gender
          Else Case
            -- If primary is female list primary first
            When donorlist.gender = 'F' Then 'Self Spouse'
            -- If spouse is female list spouse first
            When donorlist.gender_spouse = 'F' Then 'Spouse Self'
            -- Fallback
            Else 'Self Spouse'
          End
        End
    End As name_order  
  From donorlist
  Left Join dec_spouse_ids On dec_spouse_ids.id_number = donorlist.id_number
  Left Join anon On anon.household_id = donorlist.household_id
),
rec_name As (
  Select rn.id_number, rn.name_order, anon.anon,
    -- Custom name flag
    Case When cust_name.id_number Is Not Null Then 'Y' End As manually_named,
    -- Proposed recognition name
    (Case
      -- If custom name, use that instead
      When cust_name.id_number Is Not Null Then cust_name.custom_name
      -- Fully anonymous donors are just Anonymous
      When rn.name_order = 'Anon' Then 'Anonymous'
      -- Orgs get their full name
      When rn.name_order = 'Org' Then household_rpt_name
      -- If no joint gift indicator, use personal name
      When rn.name_order = 'No Joint' Then Case
        When rn.id_number = rn.household_id Then trim(primary_name)
        Else trim(primary_name_spouse)
      End
      -- Deceased spouses -- have to manually join
      When rn.name_order = 'Dec Spouse' Then
        Case
          When dec_spouse_ids.yrs Is Not Null and yrs_join Is Null Then trim(pn || ' and ' || pnj)
          When dec_spouse_ids.yrs Is Null and yrs_join Is Not Null Then trim(pnj || ' and ' || pn)
          When dec_spouse_ids.gender = 'F' Then trim(pn || ' and ' || pnj)
          When dec_spouse_ids.gender_join = 'F' Then trim(pnj || ' and ' || pn)
          Else trim(pn || ' and ' || pnj)
        End
      -- Everyone else
      When rn.name_order = 'Self' Then trim(primary_name)
      When rn.name_order = 'Self Spouse' Then trim(primary_name || ' and ' || primary_name_spouse)
      When rn.name_order = 'Spouse Self' Then trim(primary_name_spouse || ' and ' || primary_name)
    End
      -- Add loyal tag if applicable
      || (Case When rn.name_order <> 'Anon' And cust_name.override_suffixes Is Null Then loyal.loyal End)
      -- Add KLC tag if applicable
      || (Case When rn.name_order Not In('Anon', 'Org') And cust_name.override_suffixes Is Null Then fy_klc.klc End)
    ) As proposed_recognition_name,
    -- Proposed sort name within groups
    Case
      When rn.name_order = 'Anon' Then ' ' -- Single space sorts before double space, 0-9, A-z, etc.
      When rn.name_order = 'Org' Then household_rpt_name
      When rn.name_order = 'No Joint' Then report_name
      When rn.name_order = 'Dec Spouse' Then
        Case
          When dec_spouse_ids.yrs Is Not Null and yrs_join Is Null Then trim(sn || '; ' || snj)
          When dec_spouse_ids.yrs Is Null and yrs_join Is Not Null Then trim(snj || '; ' || sn)
          When dec_spouse_ids.gender = 'F' Then trim(sn || '; ' || snj)
          When dec_spouse_ids.gender_join = 'F' Then trim(snj || '; ' || sn)
          Else trim(sn || '; ' || snj)
        End
      When rn.name_order = 'Self' Then household_rpt_name
      When rn.name_order = 'Self Spouse' Then household_rpt_name || '; ' || household_spouse_rpt_name
      When rn.name_order = 'Spouse Self' Then household_spouse_rpt_name || '; ' || household_rpt_name
    End As proposed_sort_name,
    -- Concatenated IDs for deduping
    Case
      When rn.name_order = 'Anon' Then rn.household_id || rn.household_spouse_id -- Single space sorts before double space, 0-9, A-z, etc.
      When rn.name_order = 'Org' Then rn.household_id
      When rn.name_order = 'No Joint' Then rn.id_number
      When rn.name_order = 'Dec Spouse' Then
        Case
          When dec_spouse_ids.yrs Is Not Null and yrs_join Is Null Then trim(dec_spouse_ids.id_number || dec_spouse_ids.id_join)
          When dec_spouse_ids.yrs Is Null and yrs_join Is Not Null Then trim(dec_spouse_ids.id_join || dec_spouse_ids.id_number)
          When dec_spouse_ids.gender = 'F' Then trim(dec_spouse_ids.id_number || dec_spouse_ids.id_join)
          When dec_spouse_ids.gender_join = 'F' Then trim(dec_spouse_ids.id_join || dec_spouse_ids.id_number)
          Else trim(dec_spouse_ids.id_number || dec_spouse_ids.id_join)
        End
      When rn.name_order = 'Self' Then rn.household_id
      When rn.name_order = 'Self Spouse' Then rn.household_id || rn.household_spouse_id
      When rn.name_order = 'Spouse Self' Then rn.household_spouse_id || rn.household_id
    End As ids_for_deduping
  From rec_name_logic rn
  Left Join dec_spouse_ids On dec_spouse_ids.id_number = rn.id_number
  Left Join fy_klc On fy_klc.household_id = rn.household_id
  Left Join loyal On loyal.household_id = rn.household_id
  Left Join anon On anon.household_id = rn.household_id
  Left Join tbl_IR_FY17_custom_name cust_name On cust_name.id_number = rn.id_number
)

/* Main query */
Select Distinct
  -- Print in IR flag, for household deduping
  ids_for_deduping,
  dense_rank() Over(Partition By ids_for_deduping
    Order By proposed_giving_level Asc, rec_name.proposed_sort_name Asc, rec_name.proposed_recognition_name Desc, donorlist.id_number Asc) As name_rank,
  Case
    When dense_rank() Over(Partition By ids_for_deduping
      Order By proposed_giving_level Asc, rec_name.proposed_sort_name Asc, rec_name.proposed_recognition_name Desc, donorlist.id_number Asc) = 1 Then 'Y'
  End As print_in_report,
  -- Recognition name string
  rec_name.proposed_sort_name,
  rec_name.proposed_recognition_name,
  -- Giving level string
  proposed_giving_level,
  -- Anonymous flags
  Case When proposed_giving_level <> nonanon_giving_level And rec_name.anon Is Null Then nonanon_giving_level End As different_nonanon_level,
  rec_name.anon,
  anon_steward_thru_fy17,
  nonanon_steward_thru_fy17,
  -- Fields
  campaign_steward_thru_fy17,
  Case When rec_name.name_order = 'Dec Spouse' Then 'Y' End As manually_householded,
  rec_name.manually_named,
  Case
    When proposed_sort_name = ' ' Then NULL
    When dense_rank() Over(Partition By proposed_sort_name Order By proposed_giving_level Asc, donorlist.id_number Asc) > 1
      And dense_rank() Over(Partition By ids_for_deduping
        Order By proposed_giving_level Asc, rec_name.proposed_sort_name Asc, rec_name.proposed_recognition_name Desc, donorlist.id_number Asc) = 1
      Then 'Y'
  End As possible_dupe,
  no_joint_gifts_flag,
  assign_conc.managers,
  donorlist.id_number,
  report_name,
  degrees_concat,
  dec_spouse_conc.dec_spouse_ids,
  fmr_spouse_id,
  fmr_spouse_name,
  fmr_marital_status,
  donorlist.household_id,
  person_or_org,
  record_status_code,
  household_rpt_name,
  household_suffix,
  primary_name,
  yrs,
  gender,
  household_masters_year,
  household_spouse_id,
  household_spouse_rpt_name,
  household_spouse_suffix,
  primary_name_spouse,
  yrs_spouse,
  gender_spouse,
  loyal.stewardship_cfy,
  loyal.stewardship_pfy1,
  loyal.stewardship_pfy2,
  campaign_steward_giving,
  campaign_anonymous,
  campaign_nonanonymous,
  campaign_giving,
  campaign_reachbacks,
  campaign_fy08,
  campaign_fy09,
  campaign_fy10,
  campaign_fy11,
  campaign_fy12,
  campaign_fy13,
  campaign_fy14,
  campaign_fy15,
  campaign_fy16,
  campaign_fy17,
  campaign_fy18
From donorlist
Inner Join rec_name On rec_name.id_number = donorlist.id_number
Left Join assign_conc On assign_conc.household_id = donorlist.household_id
Left Join loyal On loyal.household_id = donorlist.household_id
Left Join dec_spouse_conc On dec_spouse_conc.id_number = donorlist.id_number
Order By proposed_giving_level Asc, rec_name.proposed_sort_name Asc