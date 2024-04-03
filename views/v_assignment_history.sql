/**************************************
NU historical assignments, including inactive
**************************************/

Create Or Replace View v_assignment_history As

With

-- Active prospects from prospect_entity
active_pe As (
  Select
    pre.id_number
    , pre.prospect_id
    , pre.primary_ind
  From prospect_entity pre
  Inner Join prospect p On p.prospect_id = pre.prospect_id
  Where p.active_ind = 'Y'
)

Select
    -- Display prospect depending on whether prospect_id is filled in
    Case
      When trim(assignment.prospect_id) Is Not Null Then assignment.prospect_id
      When trim(active_pe.prospect_id) Is Not Null Then active_pe.prospect_id
    End As prospect_id
  -- Display entity depending on whether id_number is filled in
  , Case
      When trim(assignment.id_number) Is Not Null Then assignment.id_number
      When prospect_entity.id_number Is Not Null Then prospect_entity.id_number
    End As id_number
  , Case
      When trim(assignment.id_number) Is Not Null Then entity.report_name
      When prospect_entity.id_number Is Not Null Then pe_entity.report_name
    End As report_name
  , Case
      When trim(assignment.prospect_id) Is Not Null Then prospect_entity.primary_ind
      When trim(active_pe.prospect_id) Is Not Null Then active_pe.primary_ind
    End As primary_ind
  , assignment.assignment_id
  , assignment.assignment_type
  , assignment.proposal_id
  , tms_at.short_desc As assignment_type_desc
  , trunc(assignment.start_date) As start_date
  , trunc(assignment.stop_date) As stop_date
  -- Calculated start date: use date_added if start_date unavailable
  , Case
      When assignment.start_date Is Not Null Then trunc(assignment.start_date)
      -- For proposal managers (PA), use start date of the associated proposal
      When assignment.start_date Is Null And assignment.assignment_type = 'PA' Then 
        Case
          When proposal.start_date Is Not Null Then trunc(proposal.start_date)
          Else trunc(proposal.date_added)
        End
      -- Fallback
      Else trunc(assignment.date_added)
    End As start_dt_calc
  -- Calculated stop date: use date_modified if stop_date unavailable
  , Case
      When assignment.stop_date Is Not Null Then trunc(assignment.stop_date)
      -- For proposal managers (PA), use stop date of the associated proposal
      When assignment.stop_date Is Null And assignment.assignment_type = 'PA' Then 
        Case
          When proposal.stop_date Is Not Null Then trunc(proposal.stop_date)
          When proposal.active_ind <> 'Y' Then trunc(proposal.date_modified)
          Else NULL
        End
      -- For inactive assignments with null date use date_modified
      When assignment.active_ind <> 'Y' Then trunc(assignment.date_modified)
      Else NULL
    End As stop_dt_calc
  -- Active or inactive assignment
  , assignment.active_ind As assignment_active_ind
  -- Active or inactive computation
  , Case
      When assignment.active_ind = 'Y' And proposal.active_ind = 'Y' Then 'Active'
      When assignment.active_ind = 'Y' And proposal.active_ind = 'N' Then 'Inactive'
      When assignment.active_ind = 'Y' And assignment.stop_date Is Null Then 'Active'
      When assignment.active_ind = 'Y' And assignment.stop_date > cal.yesterday Then 'Active'
      Else 'Inactive'
    End As assignment_active_calc
  , assignment.assignment_id_number
  , assignee.report_name As assignment_report_name
  , assignment.office_code
  , tms_o.short_desc As office_desc
  , assignment.committee_code
  , committee_header.short_desc As committee_desc
  , assignment.xcomment As description
From assignment
Cross Join v_current_calendar cal
Inner Join tms_assignment_type tms_at On tms_at.assignment_type = assignment.assignment_type
Left Join entity On entity.id_number = assignment.id_number
Left Join entity assignee On assignee.id_number = assignment.assignment_id_number
Left Join prospect_entity On prospect_entity.prospect_id = assignment.prospect_id
Left Join active_pe On active_pe.id_number = assignment.id_number
Left Join entity pe_entity On pe_entity.id_number = prospect_entity.id_number
Left Join proposal On proposal.proposal_id = assignment.proposal_id
Left Join committee_header On committee_header.committee_code = assignment.committee_code
Left Join tms_office tms_o On tms_o.office_code = assignment.office_code
