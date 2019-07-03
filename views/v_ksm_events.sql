-- Event organizers
Create Or Replace View v_nu_event_organizers As

Select Distinct
  -- Use event_organizer if possible, otherwise event_organization
    Case
      When entity.report_name Is Not Null
        Then eo.id_number
      Else eo.organization_id
      End
    As event_organizer_id
  , Case
      When entity.report_name Is Not Null
        Then entity.report_name
      Else ento.report_name
      End
    As event_organizer_name
  , Case
      When lower(entity.report_name) Like lower('%Kellogg%')
        And entity.person_or_org = 'O'
        Then 'Y'
      When lower(ento.report_name) Like lower('%Kellogg%')
        And ento.person_or_org = 'O'
        Then 'Y'
      End
    As kellogg_club
From ep_event_organizer eo
Left Join entity
  On entity.id_number = eo.id_number
Left Join entity ento
  On ento.id_number = eo.organization_id
;

-- Events summary from ep_events
Create Or Replace View v_nu_events As

With

-- All event organizers
organizers As (
  Select
    eo.event_id
    , Case
        When neo1.event_organizer_id Is Not Null
          Then neo1.event_organizer_id
        Else neo2.event_organizer_id
      End
      As event_organizer_id
    , Case
        When neo1.event_organizer_id Is Not Null
          Then neo1.event_organizer_name
        Else neo2.event_organizer_name
        End
      As event_organizer_name
    , Case
        When neo1.event_organizer_id Is Not Null
          Then neo1.kellogg_club
        Else neo2.kellogg_club
        End
      As kellogg_club
  From ep_event_organizer eo
  Left Join v_nu_event_organizers neo1
    On eo.id_number = neo1.event_organizer_id
  Left Join v_nu_event_organizers neo2
    On eo.organization_id = neo2.event_organizer_id
)

-- Organizers concatenated
, organizers_concat As (
  Select
    event_id
    , max(kellogg_club)
      As kellogg_organizers
    , Listagg(event_organizer_name, '; ') Within Group (Order By event_organizer_name)
      As event_organizers
  From organizers
  Group By event_id
)

-- Event IDs with a KSM organizer, OR a KSM organization
, ksm_organizers As (
  Select Distinct
    event_id
  From organizers
  Where kellogg_club = 'Y'
)

Select
  event.event_id
  , event.event_name
  , event.event_type
  , tms_et.short_desc
    As event_type_desc
  , trunc(event.event_start_datetime)
    As start_dt
  , trunc(event.event_stop_datetime)
    As stop_dt
  -- Assume events are one day, so if stop or start date is missing, use the other 
  -- If both are missing could fall back to date added (noisy) or omit
  , ksm_pkg.get_fiscal_year(
      Case
        When event.event_start_datetime Is Not Null
          Then trunc(event.event_start_datetime)
        When event.event_stop_datetime Is Not Null
          Then trunc(event.event_stop_datetime)
        End
    )
    As start_fy_calc
  , ksm_pkg.get_fiscal_year(
      Case
        When event.event_stop_datetime Is Not Null
          Then trunc(event.event_stop_datetime)
        When event.event_start_datetime Is Not Null
          Then trunc(event.event_start_datetime)
        End
    )
    As stop_fy_calc
  -- Check whether event is KSM-specific
  , Case
      When event.event_name Like '%KSM%'
        Or event.event_name Like '%Kellogg%'
        Or ksm_org.event_id Is Not Null
        Then 'Y'
      End
    As ksm_event
  -- Organizers
  , organizers_concat.event_organizers
  , organizers_concat.kellogg_organizers
  -- Master event information
  , event.master_event_id
  , master_event.event_name
    As master_event_name
  , trunc(master_event.event_start_datetime)
    As master_event_start_dt
  , trunc(master_event.event_stop_datetime)
    As master_event_stop_dt
From ep_event event
Left Join tms_event_type tms_et
  On event.event_type = tms_et.event_type
Left Join ksm_organizers ksm_org
  On event.event_id = ksm_org.event_id
Left Join ep_event master_event
  On master_event.event_id = event.master_event_id
Left Join organizers_concat
  On organizers_concat.event_id = event.event_id
;

-- Event participations
Create Or Replace View v_nu_event_participants As

Select
  hh.household_id
  , hh.household_rpt_name
  , hh.household_primary
  , hh.id_number
  , hh.report_name
  , hh.person_or_org
  , hh.institutional_suffix
  , hh.degrees_concat
  , hh.first_ksm_year
  , hh.program_group
  , v_nu_events.event_id
  , v_nu_events.event_name
  , v_nu_events.ksm_event
  , tms_et.short_desc As event_type
  , start_dt
  , stop_dt
  , start_fy_calc
  , stop_fy_calc
From ep_participant ppt
Inner Join v_nu_events
  On v_nu_events.event_id = ppt.event_id -- KSM events
Inner Join v_entity_ksm_households hh
  On hh.id_number = ppt.id_number
Inner Join ep_participation ppn
  On ppn.registration_id = ppt.registration_id
Left Join tms_event_type tms_et
  On tms_et.event_type = v_nu_events.event_type
Where ppn.participation_status_code In (' ', 'P', 'A') -- Blank, Participated, or Accepted
;
