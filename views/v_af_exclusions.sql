-- Create Or Replace View v_af_exclusions As

With

-- Manual exclusions
manual_exclusions_pre As (
  Select
    id_number
    , report_name
  From entity
  Where id_number In (
    NULL
------ ADD ID NUMBERS BELOW HERE ------
    , '0000299349' -- DSB
    , '0000225195' -- DDJ
    , '0000499489' -- DDJ spouse
------ ADD ID NUMBERS ABOVE HERE ------
  )
)
, manual_exclusions As (
    Select
      id_number
      , 'Y' As manual_exclusion
    From manual_exclusions_pre
  Union
    Select
      entity.id_number
      , 'Y' As manual_exclusion
    From entity
    Inner Join manual_exclusions_pre mep On mep.id_number = entity.spouse_id_number
)

-- Deceased
, deceased As (
  Select
    id_number
    , record_status_code As deceased
  From entity
  Where record_status_code = 'D'
)

-- Special handling
, spec_hnd As (
  Select
    id_number
    , spouse_id_number
    , special_handling_concat
    , mailing_list_concat
    , no_contact
    , no_solicit
    , never_engaged_forever
    , exc_all_comm
    , exc_all_sols
  From table(ksm_pkg.tbl_special_handling_concat) shc
  Where no_contact = 'Y'
    Or no_solicit = 'Y'
    Or never_engaged_forever = 'Y'
    Or exc_all_comm = 'Y'
    Or exc_all_sols = 'Y'
)

-- Global Advisory Board
, gab As (
  Select
    id_number
    , Listagg(
        trim('GAB ' || role)
      , '; ') Within Group (Order By tcg.role Asc)
      As gab
  From table(ksm_pkg.tbl_committee_gab) tcg
  Group By id_number
)

-- Trustee
, trustee As (
  Select
    id_number
    , Listagg(
        Case
          When a.affil_code = 'TR' Then
            Case
              When tms_al.affil_level_code Is Not Null Then tms_al.short_desc
              Else 'Trustee'
            End
          When a.affil_code = 'TS' Then trim(tms_ac.short_desc || ' ' || tms_al.short_desc)
        End
      , '; ') Within Group (Order By a.affil_code Asc)
      As trustee
  From affiliation a
  Left Join tms_affil_code tms_ac On tms_ac.affil_code = a.affil_code
  Left Join tms_affiliation_level tms_al On tms_al.affil_level_code = a.affil_level_code
  Where a.affil_code In ('TR', 'TS') -- Trustee and Trustee Relation
    And a.affil_status_code In ('C', 'A') -- Current and Active (deprecated) only
  Group By id_number
)

-- Pledges/recurring gifts
, nu_pledges As (
    -- Pledge donor
    Select
      p.pledge_donor_id As id_number
      , p.pledge_pledge_number As pledge_number
      , p.pledge_pledge_type As pledge_type
      , tms_pt.short_desc As pledge_type_desc
    From pledge p
    Inner Join primary_pledge pp On p.pledge_pledge_number = pp.prim_pledge_number
    Inner Join tms_pledge_type tms_pt On tms_pt.pledge_type_code = p.pledge_pledge_type
    Where pp.prim_pledge_status = 'A' -- Active pledges only
      And p.pledge_pledge_type Not In ('BE', 'LE') -- Ignore planned giving
  Union
    -- Pledge donor spouse
    Select
      e.id_number
      , p.pledge_pledge_number As pledge_number
      , p.pledge_pledge_type As pledge_type
      , tms_pt.short_desc As pledge_type_desc
    From entity e
    Inner Join pledge p On p.pledge_donor_id = e.spouse_id_number
    Inner Join primary_pledge pp On p.pledge_pledge_number = pp.prim_pledge_number
    Inner Join tms_pledge_type tms_pt On tms_pt.pledge_type_code = p.pledge_pledge_type
    Where pp.prim_pledge_status = 'A' -- Active pledges only
      And p.pledge_pledge_type Not In ('BE', 'LE') -- Ignore planned giving
)
, pledge_counts As (
  Select
    id_number
    , count(Distinct pledge_number)
      As active_pledges
  From nu_pledges
  Group By id_number
)

-- Open proposal data
/* -- Currently on the slow side; can I optimize v_ksm_proposal_history?
, ksm_proposals As (
  Select
    prospect_id
    -- Submitted and approved by donor proposals
    , count(Distinct Case When hierarchy_order In (20, 60) Then proposal_id End)
      As proposals_submitted_approved
    -- Anticipated proposal, close date in next 18 months
    , count(Distinct Case When hierarchy_order = 10 And close_date <= add_months(cal.today, 18) Then proposal_id End)
      As proposals_anticipated_18_mos
  From v_ksm_proposal_history vph
  Cross Join v_current_calendar cal
  Where proposal_active = 'Y'
    And proposal_in_progress = 'Y'
  Group By prospect_id
)*/

-- Degree removals
, degree_exclusion_ids As (
    -- Alumni with a PhD or IEMBA or certificate
    Select id_number
    From degrees
    Where institution_code = '31173'
      And school_code In ('BUS', 'KSM')
      And (
        degree_code In ('PHD', 'MSMS')
        Or campus_code In ('CAN', 'ISL', 'HK', 'GER')
        Or degree_level_code = 'C'
      )
  Minus
    -- Exclude alumni with a different degree
    Select id_number
    From degrees
    Where institution_code = '31173'
      And school_code In ('BUS', 'KSM')
      And degree_level_code Not In ('C')
      And degree_code Not In ('PHD', 'MSMS')
      And campus_code Not In ('CAN', 'ISL', 'HK', 'GER')
)
, degree_exclusion As (
  Select
    dei.id_number
    , deg.degrees_concat
    , deg.program As degree_program
  From degree_exclusion_ids dei
  Inner Join v_entity_ksm_degrees deg On deg.id_number = dei.id_number
)

-- Merged ids
, ids As (
    -- Manual exclusions
    Select id_number
    From manual_exclusions
  Union
    -- Deceased
    Select id_number
    From deceased
  Union
    -- Special handling
    Select id_number
    From spec_hnd
  Union
    -- Spouse special handling
    Select spouse_id_number
    From spec_hnd
    Where no_contact = 'Y'
      Or exc_all_comm = 'Y'
      Or never_engaged_forever = 'Y'
  Union
    -- Current GAB members
    Select id_number
    From gab
  Union
    -- Current trustees/spouses
    Select id_number
    From trustee
  Union
    -- Pledges
    Select id_number
    From pledge_counts
  Union
    -- Proposals
    -- Degrees
    Select id_number
    From degree_exclusion
)

-- Final query
Select
  entity.id_number
  , entity.report_name
  , me.manual_exclusion
  , deceased.deceased
  , sh.special_handling_concat
  , shs.special_handling_concat As special_handling_spouse
  , sh.no_contact 
  , shs.no_contact As no_contact_spouse
  , sh.no_solicit 
  , shs.no_solicit As no_solicit_spouse
  , sh.never_engaged_forever
  , shs.never_engaged_forever As never_engaged_forever_spouse
  , sh.exc_all_comm
  , shs.exc_all_comm As exc_all_comm_spouse
  , sh.exc_all_sols
  , shs.exc_all_sols As exc_all_sols_spouse
  , gab.gab
  , trustee.trustee
  , dex.degrees_concat
  , dex.degree_program
  , pc.active_pledges
From ids
Inner Join entity On entity.id_number = ids.id_number
Left Join manual_exclusions me On me.id_number = ids.id_number
Left Join deceased On deceased.id_number = ids.id_number
Left Join spec_hnd sh On sh.id_number = ids.id_number
Left Join spec_hnd shs On shs.spouse_id_number = ids.id_number
Left Join gab On gab.id_number = ids.id_number
Left Join trustee On trustee.id_number = ids.id_number
Left Join degree_exclusion dex On dex.id_number = ids.id_number
Left Join pledge_counts pc On pc.id_number = ids.id_number
