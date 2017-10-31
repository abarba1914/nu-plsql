Create Or Replace View v_ksm_proposal_history As

With

-- Gifts with linked proposals
linked As (
  Select proposal_id,
    Listagg(tx_number, '; ') Within Group (Order By tx_number Asc) As ksm_linked_receipts,
    sum(legal_amount) As ksm_linked_amounts
  From v_ksm_giving_trans
  Where proposal_id Is Not Null
    And legal_amount > 0
  Group By proposal_id
),

-- Current calendar
cal As (
  Select *
  From table(rpt_pbh634.ksm_pkg.tbl_current_calendar)
),

-- Proposal purpose
ksm_purps As (
  Select pp.proposal_id,
    pp.xsequence,
    tms_pp.short_desc As prop_purpose,
    tms_pi.short_desc As initiative,
    pp.prospect_interest_code As initiative_cd,
    pp.ask_amt As program_ask,
    pp.original_ask_amt As program_orig_ask,
    pp.granted_amt As program_anticipated
  From proposal_purpose pp
  Left Join tms_prop_purpose tms_pp On tms_pp.prop_purpose_code = pp.prop_purpose_code
  Left Join tms_prospect_interest tms_pi On tms_pi.prospect_interest_code = pp.prospect_interest_code
  Where program_code = 'KM'
),
ksm_purp As (
  Select proposal_id,
    Listagg(prop_purpose, '; ') Within Group (Order By xsequence Asc) As prop_purposes,
    Listagg(initiative, '; ') Within Group (Order By xsequence Asc) initiatives,
    sum(program_ask) As ksm_ask,
    sum(program_orig_ask) As ksm_orig_ask,
    sum(program_anticipated) As ksm_anticipated,
    sum(Case When initiative Like '%KSM Annual Fund%' Then program_ask Else 0 End) As ksm_af_ask,
    sum(Case When initiative Like '%KSM Annual Fund%' Then program_anticipated Else 0 End) As ksm_af_anticipated,
    sum(Case When initiative_cd = 'KFC' Then program_ask Else 0 End) As ksm_facilities_ask,
    sum(Case When initiative_cd = 'KFC' Then program_anticipated Else 0 End) As ksm_facilities_anticipated
  From ksm_purps
  Group By proposal_id
),
other_purp As (
  Select pp.proposal_id,
    Listagg(tms_program.short_desc, '; ') Within Group (Order By pp.xsequence Asc) As other_programs
  From proposal_purpose pp
  Inner Join ksm_purps On ksm_purps.proposal_id = pp.proposal_id
  Inner Join tms_program On tms_program.program_code = pp.program_code
  Where pp.program_code <> 'KM'
  Group By pp.proposal_id
),

-- Proposal assignments
assn As (
  Select assignment.proposal_id,
    Listagg(entity.report_name, '; ') Within Group (Order By assignment.start_date Desc NULLS Last, assignment.date_modified Desc) As proposal_manager
  From assignment
  Inner Join ksm_purp On ksm_purp.proposal_id = assignment.proposal_id
  Inner Join entity On entity.id_number = assignment.assignment_id_number
  Where assignment.assignment_type = 'PA' -- Proposal Manager (PM is taken by Prospect Manager)
  Group By assignment.proposal_id
),
asst As (
  Select assignment.proposal_id,
    Listagg(entity.report_name, '; ') Within Group (Order By assignment.start_date Desc NULLS Last, assignment.date_modified Desc) As proposal_assist
  From assignment
  Inner Join ksm_purp On ksm_purp.proposal_id = assignment.proposal_id
  Inner Join entity On entity.id_number = assignment.assignment_id_number
  Where assignment.assignment_type = 'AS' -- Proposal Assist
  Group By assignment.proposal_id
),

-- Code to pull university strategy from the task table; BI method plus a cancelled/completed exclusion
strat As (
  Select *
  From table(ksm_pkg.tbl_university_strategy)
),

-- Final KSM proposal amounts; if no non-KSM programs use face value, otherwise sum up KSM program amounts if able
ksm_amts As (
  Select proposal.proposal_id,
    Case
      When other_purp.other_programs Is Null Then proposal.ask_amt
      When ksm_ask > 0  Then ksm_ask
      Else proposal.ask_amt
    End As ksm_or_univ_ask,
    Case
      When other_purp.other_programs Is Null Then proposal.original_ask_amt
      When ksm_orig_ask > 0 Then ksm_orig_ask
      Else proposal.original_ask_amt
    End As ksm_or_univ_orig_ask,
    Case
      When other_purp.other_programs Is Null Then proposal.anticipated_amt
      When ksm_anticipated > 0 Then ksm_anticipated
      Else proposal.anticipated_amt
    End As ksm_or_univ_anticipated
  From proposal
  Inner Join ksm_purp On ksm_purp.proposal_id = proposal.proposal_id
  Left Join other_purp On other_purp.proposal_id = proposal.proposal_id
)

-- Main query
Select
  proposal.prospect_id,
  prs.prospect_name,
  proposal.proposal_id,
  assn.proposal_manager,
  asst.proposal_assist,
  proposal.proposal_status_code,
  tms_ps.hierarchy_order,
  Case
    When proposal.proposal_status_code = 'B' Then 'Submitted' -- Letter of Inquiry Submitted
    When proposal.proposal_status_code = '5' Then 'Verbal' -- Approved by Donor
    Else tms_ps.short_desc
  End As proposal_status,
  proposal.active_ind As proposal_active,
  Case When tms_ps.hierarchy_order < 70 Then 'Y' End As proposal_in_progress, -- Anticipated, Submitted, Deferred, Approved
  ksm_purp.prop_purposes,
  ksm_purp.initiatives,
  other_purp.other_programs,
  strat.university_strategy,
  trunc(start_date) As start_date,
  ksm_pkg.get_fiscal_year(start_date) As start_fy,
  trunc(initial_contribution_date) As ask_date,
  ksm_pkg.get_fiscal_year(initial_contribution_date) As ask_fy,
  trunc(stop_date) As close_date,
  ksm_pkg.get_fiscal_year(stop_date) As close_fy,
  trunc(date_modified) As date_modified,
  linked.ksm_linked_receipts,
  linked.ksm_linked_amounts,
  original_ask_amt As total_original_ask_amt,
  ask_amt As total_ask_amt,
  anticipated_amt As total_anticipated_amt,
  granted_amt As total_granted_amt,
  ksm_purp.ksm_ask,
  ksm_purp.ksm_anticipated,
  ksm_purp.ksm_af_ask,
  ksm_purp.ksm_af_anticipated,
  ksm_purp.ksm_facilities_ask,
  ksm_purp.ksm_facilities_anticipated,
  ksm_amts.ksm_or_univ_ask,
  ksm_amts.ksm_or_univ_orig_ask,
  ksm_amts.ksm_or_univ_anticipated,
  -- Use anticipated amount if available, else ask amount
  Case When ksm_amts.ksm_or_univ_anticipated > 0 Then ksm_amts.ksm_or_univ_anticipated Else ksm_amts.ksm_or_univ_ask End As final_anticipated_or_ask_amt,
  -- Anticipated bin: use anticipated amount if available, otherwise fall back to ask amount
  Case
    When ksm_or_univ_anticipated >= 10000000 Then 10
    When ksm_or_univ_anticipated >=  5000000 Then 5
    When ksm_or_univ_anticipated >=  2000000 Then 2
    When ksm_or_univ_anticipated >=  1000000 Then 1
    When ksm_or_univ_anticipated >=   500000 Then 0.5
    When ksm_or_univ_anticipated >=   100000 Then 0.1
    When ksm_or_univ_anticipated >         0 Then 0 -- Not an error, should be > not >= so we keep going if anticipated is 0
    When ksm_or_univ_ask         >= 10000000 Then 10
    When ksm_or_univ_ask         >=  5000000 Then 5
    When ksm_or_univ_ask         >=  2000000 Then 2
    When ksm_or_univ_ask         >=  1000000 Then 1
    When ksm_or_univ_ask         >=   500000 Then 0.5
    When ksm_or_univ_ask         >=   100000 Then 0.1
    Else 0
  End As ksm_bin
From proposal
Cross Join cal
Inner Join tms_proposal_status tms_ps On tms_ps.proposal_status_code = proposal.proposal_status_code
-- Only KSM proposals
Inner Join ksm_purp On ksm_purp.proposal_id = proposal.proposal_id
Inner Join ksm_amts On ksm_amts.proposal_id = proposal.proposal_id
-- Proposal info
Left Join other_purp On other_purp.proposal_id = proposal.proposal_id
Left Join assn On assn.proposal_id = proposal.proposal_id
Left Join asst On asst.proposal_id = proposal.proposal_id
-- Prospect info
Left Join (Select prospect_id, prospect_name From prospect) prs On prs.prospect_id = proposal.prospect_id
Left Join strat On strat.prospect_id = proposal.prospect_id
-- Linked gift info
Left Join linked On linked.proposal_id = proposal.proposal_id
