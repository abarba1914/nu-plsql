/****************************************
KSM Campaign gifts booked and open proposals in one view
****************************************/

Create Or Replace View vt_ksm_mg_fy_metrics As

With
cal As (
  Select *
  From rpt_pbh634.v_current_calendar
)

/* Proposal status and year-to-date new gifts and commitments for KSM MG metrics */
(
  -- Gift data
  Select
    ytd.rcpt_or_plg_number As tx_or_proposal_number
    , sum(amount) As amount
    , to_number(year_of_giving) As fiscal_year
    , cal.curr_fy
    , ytd_ind
    , gift_bin As bin
    , 'Booked' As cat
    , 'Campaign Giving' As src
  From v_ksm_giving_post_campaign_ytd ytd
  Cross Join cal
  Where year_of_giving Between 2007 And cal.curr_fy -- FY 2007 and 2020 as first and last campaign gift dates
    And amount > 0
  Group By
    ytd.rcpt_or_plg_number
    , year_of_giving
    , cal.curr_fy
    , ytd_ind
    , gift_bin
) Union All (
  -- Proposal data
  -- Includes proposals expected to close in current and previous fiscal year as current fiscal year
  Select
    to_char(v_ksm_proposal_history.proposal_id)
    , final_anticipated_or_ask_amt
    , cal.curr_fy As fiscal_year
    , cal.curr_fy
    , 'Y'
    , ksm_bin
    , proposal_status As cat
    , 'Proposals' As src
  From rpt_pbh634.v_ksm_proposal_history
  Cross Join cal
  Where proposal_in_progress = 'Y'
    And proposal_active = 'Y'
    And close_fy Between cal.curr_fy - 1 And cal.curr_fy -- Do not include historical proposal data which is not helpful
)
;

/****************************************
Kellogg prospect pool definition plus giving,
proposal, etc. fields
****************************************/

Create Or Replace View rpt_abm1914.ksm_prs_pool As

With

/* v_ksm_prospect_pool with a few giving-related fields appended
   Also includes strategy and current proposals
   Fairly slow to refresh due to multiple views */

/* Geocoded data */
geocode As (
  Select *
  From rpt_pbh634.v_addr_geocoding
)

/* Proposal data */
, nu_proposal As (
  Select
    prospect_id
    , count(proposal_id) As open_proposals
  From rpt_pbh634.v_proposal_history_fast
  Where proposal_active_calc = 'Active'
  Group By prospect_id
)
, ksm_proposal As (
  Select
    prospect_id
    , count(proposal_id) As open_ksm_proposals
    , sum(total_ask_amt) As total_asks
    , sum(total_anticipated_amt) As total_anticipated
    , sum(ksm_or_univ_ask) As total_ksm_asks
    , sum(ksm_or_univ_anticipated) As total_ksm_anticipated
    , min(proposal_id)
      keep(dense_rank First Order By hierarchy_order Desc, date_modified Desc, proposal_id Asc)
      As most_recent_proposal_id
    , min(proposal_manager)
      keep(dense_rank First Order By hierarchy_order Desc, date_modified Desc, proposal_id Asc)
      As recent_proposal_manager
    , min(proposal_assist)
      keep(dense_rank First Order By hierarchy_order Desc, date_modified Desc, proposal_id Asc)
      As recent_proposal_assist
    , min(proposal_status)
      keep(dense_rank First Order By hierarchy_order Desc, date_modified Desc, proposal_id Asc)
      As recent_proposal_status
    , min(start_date)
      keep(dense_rank First Order By hierarchy_order Desc, date_modified Desc, proposal_id Asc)
      As recent_start_date
    , min(ask_date)
      keep(dense_rank First Order By hierarchy_order Desc, date_modified Desc, proposal_id Asc)
      As recent_ask_date
    , min(close_date)
      keep(dense_rank First Order By hierarchy_order Desc, date_modified Desc, proposal_id Asc)
      As recent_close_date
    , min(date_modified)
      keep(dense_rank First Order By hierarchy_order Desc, date_modified Desc, proposal_id Asc)
      As recent_date_modified
    , min(ksm_or_univ_ask)
      keep(dense_rank First Order By hierarchy_order Desc, date_modified Desc, proposal_id Asc)
      As recent_ksm_ask
    , min(ksm_or_univ_anticipated)
      keep(dense_rank First Order By hierarchy_order Desc, date_modified Desc, proposal_id Asc)
      As recent_ksm_anticipated
    , min(proposal_id)
      keep(dense_rank First Order By close_date Asc, hierarchy_order Desc, date_modified Desc, proposal_id Asc)
      As next_proposal_id
    , min(proposal_manager)
      keep(dense_rank First Order By close_date Asc, hierarchy_order Desc, date_modified Desc, proposal_id Asc)
      As next_proposal_manager
    , min(close_date)
      keep(dense_rank First Order By close_date Asc, hierarchy_order Desc, date_modified Desc, proposal_id Asc)
      As next_close_date
    , min(ksm_or_univ_ask)
      keep(dense_rank First Order By close_date Asc, hierarchy_order Desc, date_modified Desc, proposal_id Asc)
      As next_ksm_ask
    , min(ksm_or_univ_anticipated)
      keep(dense_rank First Order By close_date Asc, hierarchy_order Desc, date_modified Desc, proposal_id Asc)
      As next_ksm_anticipated
  From rpt_pbh634.v_proposal_history_fast
  Where proposal_in_progress = 'Y'
    And ksm_proposal_ind = 'Y'
  Group By prospect_id
)

/* Assignment IDs */
, assign As (
  Select Distinct
    ah.prospect_id
    , ah.id_number
    , ah.assignment_id_number
    , ah.assignment_report_name
  From rpt_pbh634.v_assignment_history ah
  Where ah.assignment_active_calc = 'Active' -- Active assignments only
    And assignment_type In
      -- Program Manager (PP), Prospect Manager (PM), Leadership Giving Officer (LG)
      -- Annual Fund Officer (AF) is defunct as of 2020-04-14; removed
      ('PP', 'PM', 'LG')
    And ah.assignment_report_name Is Not Null -- Real managers only
)

/* Contact data */
, ard_contacts As (
  Select
    vcrf.credited
    , vcrf.credited_name
    , vcrf.contact_credit_type
    , vcrf.contact_credit_desc
    , vcrf.job_title
    , vcrf.employer_unit
    , vcrf.contact_type_code
    , vcrf.contact_type
    , vcrf.contact_purpose
    , vcrf.report_id
    , vcrf.id_number
    , vcrf.contacted_name
    , vcrf.report_name
    , vcrf.prospect_id
    , vcrf.primary_ind
    , vcrf.prospect_name
    , vcrf.prospect_name_sort
    , vcrf.contact_date
    , vcrf.fiscal_year
    , vcrf.description
    , vcrf.summary
    , vcrf.officer_rating
    , vcrf.evaluation_rating
    , vcrf.university_strategy
    , vcrf.ard_staff
    , vcrf.frontline_ksm_staff
    , vcrf.contact_type_category
    , vcrf.visit_type
    , vcrf.rating_bin
    , vcrf.curr_fy
    , vcrf.prev_fy_start
    , vcrf.curr_fy_start
    , vcrf.next_fy_start
    , vcrf.yesterday
    , vcrf.ninety_days_ago
  From rpt_pbh634.v_contact_reports_fast vcrf
  Where ard_staff = 'Y'
)
, recent_contact As (
  Select
    id_number
    -- Outreach in last 365 days
    , sum(Case When contact_date Between yesterday - 365 And yesterday Then 1 Else 0 End)
        As ard_contact_last_365_days
    -- Outreach in last 3 years (amy) 
    , SUM(CASE WHEN CONTACT_DATE BETWEEN yesterday-1095 AND yesterday THEN 1 else 0 END)
        AS ard_contact_last_3_yrs
    -- Most recent contact report
    , min(credited_name) Keep(dense_rank First Order By contact_date Desc)
        As last_credited_name
    , min(employer_unit) Keep(dense_rank First Order By contact_date Desc)
        As last_credited_unit
    , min(frontline_ksm_staff) Keep(dense_rank First Order By contact_date Desc)
        As last_credited_ksm
    , min(contact_type) Keep(dense_rank First Order By contact_date Desc)
        As last_contact_type
    , min(contact_type_category) Keep(dense_rank First Order By contact_date Desc)
        As last_contact_category
    , min(contact_date) Keep(dense_rank First Order By contact_date Desc)
        As last_contact_date
    , min(contact_purpose) Keep(dense_rank First Order By contact_date Desc)
        As last_contact_purpose
    , min(description) Keep(dense_rank First Order By contact_date Desc)
        As last_contact_desc
  From ard_contacts
  Where contact_type <> 'Visit'
  Group By id_number
)
, recent_assn_contacts As (
  Select
    ac.id_number
    -- Most recent contact report from an assigned manager
    , min(credited_name) Keep(dense_rank First Order By contact_date Desc)
        As last_assigned_credited_name
    , min(employer_unit) Keep(dense_rank First Order By contact_date Desc)
        As last_assigned_credited_unit
    , min(frontline_ksm_staff) Keep(dense_rank First Order By contact_date Desc)
        As last_assigned_credited_ksm
    , min(contact_type) Keep(dense_rank First Order By contact_date Desc)
        As last_assigned_contact_type
    , min(contact_type_category) Keep(dense_rank First Order By contact_date Desc)
        As last_assigned_contact_category
    , min(contact_date) Keep(dense_rank First Order By contact_date Desc)
        As last_assigned_contact_date
    , min(contact_purpose) Keep(dense_rank First Order By contact_date Desc)
        As last_assigned_contact_purpose
    , min(description) Keep(dense_rank First Order By contact_date Desc)
        As last_assigned_contact_desc
  From ard_contacts ac
  Inner Join assign
    On assign.id_number = ac.id_number
    And assign.assignment_id_number = ac.credited
  Where contact_type <> 'Visit'
    And assign.assignment_id_number Is Not Null
  Group By ac.id_number       
)
, recent_visit As (
  Select
    id_number
    -- Visits in last 365 days
    , sum(Case When contact_date Between yesterday - 365 And yesterday Then 1 Else 0 End)
        As ard_visit_last_365_days
    -- VIsits in last 3 years (AMY)
    , SUM(CASE WHEN contact_date BETWEEN yesterday - 1095 AND Yesterday then 1 else 0 END)
        AS ard_visit_last_3_yrs
    -- Most recent contact report
    , min(credited_name) Keep(dense_rank First Order By contact_date Desc, visit_type Asc)
        As last_visit_credited_name
    , min(frontline_ksm_staff) Keep(dense_rank First Order By contact_date Desc)
        As last_visit_credited_ksm
    , min(employer_unit)  Keep(dense_rank First Order By contact_date Desc, visit_type Asc)
        As last_visit_credited_unit
    , min(contact_type) Keep(dense_rank First Order By contact_date Desc, visit_type Asc)
        As last_visit_contact_type
    , min(contact_type_category) Keep(dense_rank First Order By contact_date Desc, visit_type Asc)
        As last_visit_category
    , min(contact_date)  Keep(dense_rank First Order By contact_date Desc, visit_type Asc)
        As last_visit_date
    , min(contact_purpose) Keep(dense_rank First Order By contact_date Desc, visit_type Asc)
        As last_visit_purpose
    , min(visit_type)  Keep(dense_rank First Order By contact_date Desc, visit_type Asc)
        As last_visit_type
    , min(description) Keep(dense_rank First Order By contact_date Desc, visit_type Asc)
        As last_visit_desc
  From ard_contacts
  Where contact_type = 'Visit'
  Group By id_number
)

/* Tasks from the current and previous FY (v_ksm_tasks) */
, tasks As (
  Select
    prospect_id
    -- Count of open tasks
    , count(Distinct task_id)
      As tasks_open
    -- Count of open tasks where responsible entity is a KSM GO
    , count(Distinct Case When current_mgo_ind = 'Y' Then task_id Else NULL End)
      As tasks_open_ksm
  From rpt_pbh634.v_ksm_tasks
  Where task_code <> 'ST' -- Exclude university overall strategy
    And active_task_ind = 'Y'
  Group By
    prospect_id
)
, next_outreach_task As (
  Select
    prospect_id
    -- Count of KSM GO outreach tasks
    , count(Distinct task_id)
      As tasks_open_ksm_outreach
    -- Next KSM GO outreach task
    , min(task_id) keep(dense_rank First Order By sched_date Asc, task_id Asc, task_responsible Asc)
      As task_outreach_next_id
    , min(sched_date) keep(dense_rank First Order By sched_date Asc, task_id Asc, task_responsible Asc)
      As task_outreach_sched_date
    , min(task_responsible) keep(dense_rank First Order By sched_date Asc, task_id Asc, task_responsible Asc)
      As task_outreach_responsible
    , min(task_description) keep(dense_rank First Order By sched_date Asc, task_id Asc, task_responsible Asc)
      As task_outreach_desc
  From rpt_pbh634.v_ksm_tasks
  Where task_code = 'CO'
    And active_task_ind = 'Y'
    And current_mgo_ind = 'Y'
  Group By
    prospect_id
)

-- Intermediate joins

, pp As (
  Select *
  From rpt_pbh634.v_ksm_prospect_pool
)

, prs As (
  Select
    pp.*
    -- Campaign giving fields
    , cmp.campaign_giving
    , cmp.campaign_steward_giving As campaign_giving_recognition
    -- Giving summary fields
    , gft.ngc_lifetime_full_rec As ksm_lifetime_recognition
    , gft.af_status
    , gft.af_cfy
    , gft.af_pfy1
    , gft.af_pfy2
    , gft.af_pfy3
    , gft.af_pfy4
    , gft.ngc_cfy
    , gft.ngc_pfy1
    , gft.ngc_pfy2
    , gft.ngc_pfy3
    , gft.ngc_pfy4
    , gft.last_gift_tx_number
    , gft.last_gift_date
    , gft.last_gift_type
    , gft.last_gift_recognition_credit
  From pp
  Left Join rpt_pbh634.v_ksm_giving_summary gft On gft.id_number = pp.id_number
  Left Join rpt_pbh634.v_ksm_giving_campaign cmp On cmp.id_number = pp.id_number
)

, visits As (
  Select
    pp.id_number
    -- Recent contact data
    , recent_visit.ard_visit_last_365_days
    , recent_visit.ard_visit_last_3_yrs -- Added by Amy
    , recent_contact.ard_contact_last_365_days
    , recent_contact.ard_contact_last_3_yrs -- Added by Amy
    , recent_visit.last_visit_credited_name
    , recent_visit.last_visit_credited_unit
    , recent_visit.last_visit_credited_ksm
    , recent_visit.last_visit_contact_type
    , recent_visit.last_visit_category
    , recent_visit.last_visit_date
    , recent_visit.last_visit_purpose
    , recent_visit.last_visit_type
    , recent_visit.last_visit_desc
    , recent_contact.last_credited_name
    , recent_contact.last_credited_unit
    , recent_contact.last_credited_ksm
    , recent_contact.last_contact_type
    , recent_contact.last_contact_category
    , recent_contact.last_contact_date
    , recent_contact.last_contact_purpose
    , recent_contact.last_contact_desc
    , recent_assn_contacts.last_assigned_credited_name
    , recent_assn_contacts.last_assigned_credited_unit
    , recent_assn_contacts.last_assigned_credited_ksm
    , recent_assn_contacts.last_assigned_contact_type
    , recent_assn_contacts.last_assigned_contact_category
    , recent_assn_contacts.last_assigned_contact_date
    , recent_assn_contacts.last_assigned_contact_purpose
    , recent_assn_contacts.last_assigned_contact_desc
  From pp
  Left Join recent_contact On recent_contact.id_number = pp.id_number
  Left Join recent_assn_contacts On recent_assn_contacts.id_number = pp.id_number
  Left Join recent_visit On recent_visit.id_number = pp.id_number
)

/* Main query */
Select Distinct
  prs.*
  -- Latitude/longitude
  , geocode.latitude
  , geocode.longitude
  -- Proposal history fields
  , nu_proposal.open_proposals
  , ksm_proposal.open_ksm_proposals
  , ksm_proposal.total_asks
  , ksm_proposal.total_anticipated
  , ksm_proposal.total_ksm_asks
  , ksm_proposal.total_ksm_anticipated
  , ksm_proposal.most_recent_proposal_id
  , ksm_proposal.recent_proposal_manager
  , ksm_proposal.recent_proposal_assist
  , ksm_proposal.recent_proposal_status
  , ksm_proposal.recent_start_date
  , ksm_proposal.recent_ask_date
  , ksm_proposal.recent_close_date
  , ksm_proposal.recent_date_modified
  , ksm_proposal.recent_ksm_ask
  , ksm_proposal.recent_ksm_anticipated
  , ksm_proposal.next_proposal_id
  , ksm_proposal.next_proposal_manager
  , ksm_proposal.next_close_date
  , ksm_proposal.next_ksm_ask
  , ksm_proposal.next_ksm_anticipated
  -- Recent contact data
  , visits.ard_visit_last_365_days
  , visits.ard_visit_last_3_yrs -- added by Amy
  , visits.ard_contact_last_365_days
  , visits.ard_contact_last_3_yrs -- added by Amy
  , visits.last_visit_credited_name
  , visits.last_visit_credited_unit
  , visits.last_visit_credited_ksm
  , visits.last_visit_contact_type
  , visits.last_visit_category
  , visits.last_visit_date
  , visits.last_visit_purpose
  , visits.last_visit_type
  , visits.last_visit_desc
  , visits.last_credited_name
  , visits.last_credited_unit
  , visits.last_credited_ksm
  , visits.last_contact_type
  , visits.last_contact_category
  , visits.last_contact_date
  , visits.last_contact_purpose
  , visits.last_contact_desc
  , visits.last_assigned_credited_name
  , visits.last_assigned_credited_unit
  , visits.last_assigned_credited_ksm
  , visits.last_assigned_contact_type
  , visits.last_assigned_contact_category
  , visits.last_assigned_contact_date
  , visits.last_assigned_contact_purpose
  , visits.last_assigned_contact_desc
  -- Tasks data
  , tasks.tasks_open
  , tasks.tasks_open_ksm
  , next_outreach_task.tasks_open_ksm_outreach
  , next_outreach_task.task_outreach_next_id
  , next_outreach_task.task_outreach_sched_date
  , next_outreach_task.task_outreach_responsible
  , next_outreach_task.task_outreach_desc
  -- Current calendar
  , cal.yesterday
  , cal.curr_fy
From prs
Cross Join rpt_pbh634.v_current_calendar cal
Inner Join visits On visits.id_number = prs.id_number
Left Join geocode On geocode.id_number = prs.id_number
  And geocode.xsequence = prs.xsequence
Left Join nu_proposal On nu_proposal.prospect_id = prs.prospect_id
Left Join ksm_proposal On ksm_proposal.prospect_id = prs.prospect_id
Left Join tasks On tasks.prospect_id = prs.prospect_id
Left Join next_outreach_task On next_outreach_task.prospect_id = prs.prospect_id
;

/****************************************
Only vt_ksm_prs_pool rows where a KSM GO has been active
****************************************/

Create Or Replace View rpt_abm1914.ksm_prs_pool_gos As

With

/* Assigned v_ksm_prospect_pool joined with KSM current frontline staff activity
per prospect */

/* GO tasks */
tasks As (
  Select
    prospect_id
    , task_responsible_id
    , count(Distinct task_id)
      As own_open_tasks
    , count(Distinct Case When task_code = 'CO' Then task_id Else NULL End)
      As own_open_tasks_outreach
  From rpt_pbh634.v_ksm_tasks v
  Where task_code <> 'ST' -- Exclude university overall strategy
    And active_task_ind = 'Y'
  Group By
    prospect_id
    , task_responsible_id
)

Select Distinct
  pool.*
  , mgo.gift_officer
  , mgo.assigned
  , Case
      When mgo.gift_officer_id = pool.prospect_manager_id Then 'PM'
      When pool.manager_ids Like ('%' || mgo.gift_officer_id || '%') Then 'PPM'
      Else NULL
    End As pm_or_ppm
  -- Only fill in metrics for the primary prospect
  , Case When pool.primary_ind = 'Y' Then mgo.visits_last_365_days End
      As visits_last_365_days
  --ADDED BY AMY FOR LAST 3 YRS
  , CASE WHEN pool.primary_ind = 'Y' THEN mgo.visits_last_3_yrs END
      AS visits_last_3_yrs
  , Case When pool.primary_ind = 'Y' Then mgo.quals_last_365_days End
      As quals_last_365_days
  , Case When pool.primary_ind = 'Y' Then mgo.visits_this_py End
      As visits_this_py
  , Case When pool.primary_ind = 'Y' Then mgo.quals_this_py End
      As quals_this_py
  , Case When pool.primary_ind = 'Y' Then mgo.total_open_proposals End
      As total_open_proposals
  , Case When pool.primary_ind = 'Y' Then mgo.total_open_asks End
      As total_open_asks
  , Case When pool.primary_ind = 'Y' Then mgo.total_open_ksm_asks End
      As total_open_ksm_asks
  , Case When pool.primary_ind = 'Y' Then mgo.total_cfy_ksm_ant_ask End
      As total_cfy_ksm_ant_ask
  , Case When pool.primary_ind = 'Y' Then mgo.total_cfy_ksm_approved End
      As total_cfy_ksm_approved
  , Case When pool.primary_ind = 'Y' Then mgo.total_cfy_ksm_funded End
      As total_cfy_ksm_funded
  , Case When pool.primary_ind = 'Y' Then mgo.total_cpy_ant_ask End
      As total_cpy_ant_ask
  , Case When pool.primary_ind = 'Y' Then mgo.total_cpy_approved End
      As total_cpy_approved
  , Case When pool.primary_ind = 'Y' Then mgo.total_cpy_funded End
      As total_cpy_funded
  , Case When pool.primary_ind = 'Y' Then tasks.own_open_tasks End
      As own_open_tasks
  , Case When pool.primary_ind = 'Y' Then tasks.own_open_tasks_outreach End
      As own_open_tasks_outreach
From ksm_prs_pool pool
Inner Join rpt_abm1914.ksm_mgo_own_activity_by_prs mgo On mgo.prospect_id = pool.prospect_id
Left Join tasks On tasks.prospect_id = mgo.prospect_id
  And tasks.task_responsible_id = mgo.gift_officer_id
;

/****************************************
ARD prospect assignments and university strategy updates
****************************************/

Create Or Replace View vt_ard_prospect_timeline As

With
/* Prospect assignments and strategies over time */

-- PM assignments
assignments As (
  Select
    prospect_id
    , id_number
    , report_name
    , primary_ind
    , 'Assignment' As type
    , assignment_id As id
    , start_date
    , stop_date
    , start_dt_calc
    , stop_dt_calc
    , Case
        When assignment_active_ind = 'Y' Then 'Active'
        Else 'Inactive'
      End As status
    , assignment_active_calc As status_summary
    , assignment_id_number As responsible_id
    , assignment_report_name As responsible_report_name
    , description
  From v_assignment_history
  Where assignment_type In
    -- Program Manager (PP), Prospect Manager (PM), Annual Fund Officer (AF), Leadership Giving Officer (LG)
    -- Keep AF here since this is a historical assignment table
    ('PP', 'PM', 'AF', 'LG')
)

-- University strategies
, tr_conc As (
  Select
    tr.task_id
    , Listagg(tr.id_number, '; ') Within Group (Order By tr.date_added Asc)
      As task_responsible_ids
    , Listagg(entity.report_name, '; ') Within Group (Order By tr.date_added Asc)
      As task_responsible_names
  From task_responsible tr
  Inner Join entity On entity.id_number = tr.id_number
  Group By tr.task_id
)
, strategies As (
  Select
    task.prospect_id
    , prospect_entity.id_number
    , entity.report_name
    , prospect_entity.primary_ind
    , 'Strategy' As type
    , task.task_id
    , task.sched_date
    , task.completed_date
    -- Calculated start date: use date_added if sched_date unavailable
    , Case
        When task.sched_date Is Not Null Then trunc(task.sched_date)
        Else trunc(task.date_added)
      End As start_dt_calc
    -- Calculated stop date: use date_modified if completed_date unavailable
    , Case
        When task.completed_date Is Not Null Then trunc(task.completed_date)
        When task.task_status_code = 4 Then trunc(task.date_modified) -- 4 = completed
        Else NULL
      End As stop_dt_calc
    , tms_ts.short_desc As status
    , Case
        When task.task_status_code = 4 Then 'Inactive'
        When task.completed_date < cal.today Then 'Inactive'
        When task.task_status_code In (1, 2, 3) Then 'Active'
        Else NULL
      End As status_summary
    , tr.task_responsible_ids
    , tr.task_responsible_names
    , task_description
  From task
  Cross Join v_current_calendar cal
  Inner Join tms_task_status tms_ts On tms_ts.task_status_code = task.task_status_code
  Inner Join prospect_entity On prospect_entity.prospect_id = task.prospect_id
  Inner Join entity On entity.id_number = prospect_entity.id_number
  Inner Join entity owner On owner.id_number = task.owner_id_number
  Left Join tr_conc tr On tr.task_id = task.task_id
  Where task_code = 'ST' -- University Overall Strategy
    And task.task_status_code <> 5 -- Not Cancelled (5) status
)

-- Main query
Select assignments.* From assignments
Union
Select strategies.* From strategies
;

/****************************************
Prospect activity "swim lanes"
****************************************/

Create Or Replace View vt_prospect_activity_lanes As

With

/* Tableau view to show prospect activity by type and "swim lane" */

-- Current calendar
-- Return data from beginning of previous FY (bofy_prev) to end of next FY (eofy_next)
cal As (
  Select
    prev_fy_start As bofy_prev
    , curr_fy_start As bofy_curr
    , next_fy_start As bofy_next
    , add_months(next_fy_start, 12) - 1 As eofy_next
    , yesterday
    , ninety_days_ago
  From v_current_calendar
)

-- Householding
, hh As (
  Select
    id_number
    , household_id
    , household_rpt_name
  From table(ksm_pkg_tmp.tbl_entity_households_ksm)
)

-- Prospect entity deduped
, pe As (
  Select pre.*
  From prospect_entity pre
  Inner Join prospect p On p.prospect_id = pre.prospect_id
  Where p.active_ind = 'Y'
)

-- Prospect data
, prospects As (
  Select
    prospect_id
    , hh.household_id
    , hh.household_rpt_name
    , tl.id_number
    , report_name
    , primary_ind
    , rpt_pbh634.ksm_pkg_tmp.get_prospect_rating_bin(tl.id_number) As rating_bin
    -- Data point description
    , type
    -- Additional description detail
    , NULL As additional_desc
    -- Category summary
    , 'Prospect' As category
    -- Tableau color field
    , 'Prospect' As color
    -- Unique identifier
    , id
    -- Use date_added as start_date if unavailable
    , start_dt_calc As start_date
    -- Use date_modified as stop_date if unavailable, but only for inactive/completed status
    , stop_dt_calc As stop_date
    -- Status detail
    , status
    -- Credited entity
    , responsible_id
    , responsible_report_name
    -- Summary text detail
    , description
    -- Symbol to use in Tableau; first letter
    , substr(type, 1, 1) As symbol
    -- Uniform calendar dates for axis alignment
    , cal.*
  From vt_ard_prospect_timeline tl
  Cross Join cal
  Inner Join hh On hh.id_number = tl.id_number
  Where start_date Between cal.bofy_prev And cal.eofy_next
    And primary_ind = 'Y'
)

-- ARD contact report data
, contacts As (
  Select
    prospect_id
    , hh.household_id
    , hh.household_rpt_name
    , cr.id_number
    , report_name
    , primary_ind
    , rating_bin
    -- Data point description
    , contact_type_category
    -- Additional description detail
    , visit_type As additional_desc
    -- Category summary
    , 'Contact'
    -- Tableau color field
    , contact_type_category As color
    -- Unique identifier
    , report_id
    -- Uniform start date for axis alignment
    , contact_date
    -- Uniform stop date for axis alignment
    , NULL
    -- Status detail
    , contact_purpose
    -- Credited entity
    , credited
    , credited_name
    -- Summary text detail
    , description
    -- Tableau symbol
    , substr(contact_type_category, 1, 1) As symbol
    -- Uniform calendar dates for axis alignment
    , cal.*
  From v_contact_reports_fast cr
  Cross Join cal
  Inner Join hh On hh.id_number = cr.id_number
  Where contact_date Between cal.bofy_prev And cal.eofy_next
    And cr.ard_staff = 'Y'
)

-- Historical KSM proposal data
, ksm_proposals As (
  Select
    prp.prospect_id
    , hh.household_id
    , hh.household_rpt_name
    , pe.id_number
    , entity.report_name
    , pe.primary_ind
    , rpt_pbh634.ksm_pkg_tmp.get_prospect_rating_bin(pe.id_number) As rating_bin
    -- Data point description
    , proposal_status
    , ksm_or_univ_orig_ask
    , total_original_ask_amt
    , ksm_or_univ_ask
    , total_ask_amt
    , ksm_or_univ_anticipated
    , total_anticipated_amt
    , ksm_linked_amounts
    , 'Proposal' As category
    -- Tableau color field
    , 'Proposal' As color
    -- Unique identifier
    , proposal_id
    , start_date
    , ask_date
    , close_date
    , prop_purposes
    , proposal_manager_id
    , proposal_manager
    , initiatives
    -- Uniform calendar dates for axis alignment
    , cal.*
  From v_ksm_proposal_history prp
  Cross Join cal
  Inner Join pe On pe.prospect_id = prp.prospect_id
  Inner Join hh On hh.id_number = pe.id_number
  Inner Join entity On entity.id_number = pe.id_number
  Where pe.primary_ind = 'Y'
    And (
      start_date Between cal.bofy_prev And cal.eofy_next
      Or ask_date Between cal.bofy_prev And cal.eofy_next
      Or close_date Between cal.bofy_prev And cal.eofy_next
    )
)
, proposal_starts As (
  Select
    prospect_id
    , hh.household_id
    , hh.household_rpt_name
    , prp.id_number
    , report_name
    , primary_ind
    , rating_bin
    -- Data point description
    , 'Proposal Start' As type
    -- Additional description detail
    , Case
        When ksm_or_univ_orig_ask > 0 Then to_char(ksm_or_univ_orig_ask, '$999,999,999,999')
        Else to_char(ksm_or_univ_ask, '$999,999,999,999')
      End As original_ask
    -- Category summary
    , category
    -- Tableau color field
    , color
    -- Unique identifier
    , proposal_id
    -- Uniform start date for axis alignment
    , start_date
    -- Uniform stop date for axis alignment
    , NULL
    -- Status detail
    , proposal_status
    -- Credited entity
    , proposal_manager_id
    , proposal_manager
    -- Summary text detail
    , initiatives
    -- Tableau symbol
    , '+' As symbol
    -- Uniform calendar dates for axis alignment
    , cal.*
  From ksm_proposals prp
  Cross Join cal
  Inner Join hh On hh.id_number = prp.id_number
  Where start_date Between cal.bofy_prev And cal.eofy_next
)
, proposal_asks As (
  Select
    prospect_id
    , household_id
    , household_rpt_name
    , id_number
    , report_name
    , primary_ind
    , rating_bin
    -- Data point description
    , 'Proposal Ask' As type
    -- Additional description detail
    , to_char(ksm_or_univ_ask, '$999,999,999,999') As ask
    -- Category summary
    , category
    -- Tableau color field
    , color
    -- Unique identifier
    , proposal_id
    -- Uniform start date for axis alignment
    , ask_date
    -- Uniform stop date for axis alignment
    , NULL
    -- Status detail
    , proposal_status
    -- Credited entity
    , proposal_manager_id
    , proposal_manager
    -- Summary text detail
    , initiatives
    -- Tableau symbol
    , 'a' As symbol
    -- Uniform calendar dates for axis alignment
    , cal.*
  From ksm_proposals
  Cross Join cal
  Where ask_date Between cal.bofy_prev And cal.eofy_next
)
, proposal_closes As (
  Select
    prospect_id
    , household_id
    , household_rpt_name
    , id_number
    , report_name
    , primary_ind
    , rating_bin
    -- Data point description
    , 'Proposal Close' As type
    -- Additional description detail
    , to_char(ksm_linked_amounts, '$999,999,999,999') As closed
    -- Category summary
    , category
    -- Tableau color field
    , color
    -- Unique identifier
    , proposal_id
    -- Uniform start date for axis alignment
    , close_date
    -- Uniform stop date for axis alignment
    , NULL
    -- Status detail
    , proposal_status
    -- Credited entity
    , proposal_manager_id
    , proposal_manager
    -- Summary text detail
    , initiatives
    -- Tableau symbol
    , 'x' As symbol
    -- Uniform calendar dates for axis alignment
    , cal.*
  From ksm_proposals
  Cross Join cal
  Where close_date Between cal.bofy_prev And cal.eofy_next
)

-- Historical KSM gifts, including pledges/payments
, ksm_giving As (
  Select
    pe.prospect_id
    , gft.household_id
    , hh.household_rpt_name
    , gft.id_number
    , entity.report_name
    , pe.primary_ind
    , rpt_pbh634.ksm_pkg_tmp.get_prospect_rating_bin(pe.prospect_id) As rating_bin
    , gft.transaction_type As type
    , to_char(gft.recognition_credit, '$999,999,999,999') As recognition_credit
    , gft.tx_gypm_ind
    , 'Gift' As category
    , 'Gift' As color
    -- Unique identifier
    , to_number(gft.tx_number) As tx_number
    , gft.date_of_record
    , tms_ps.short_desc As pledge_status
    , gft.transaction_type
    , trim(gft.alloc_short_name || ' (' || gft.allocation_code || ')
      ' || gft.gift_comment) As description
    , gft.proposal_id
  From v_ksm_giving_trans_hh gft
  Cross Join cal
  Inner Join hh On hh.id_number = gft.id_number
  Left Join pe On pe.id_number = gft.id_number
  Inner Join entity On entity.id_number = gft.id_number
  Left Join tms_pledge_status tms_ps On tms_ps.pledge_status_code = gft.pledge_status
  Where gft.date_of_record Between cal.bofy_prev And cal.eofy_next
    And gft.legal_amount > 0
)
, ksm_gift As (
  Select
    prospect_id
    , household_id
    , household_rpt_name
    , id_number
    , report_name
    , primary_ind
    , rating_bin
    -- Data point description
    , 'Gift' As type
    -- Additional description detail
    , recognition_credit
    -- Category summary
    , category
    -- Tableau color field
    , color
    -- Unique identifier
    , tx_number
    -- Uniform start date for axis alignment
    , date_of_record
    -- Uniform stop date for axis alignment
    , NULL
    -- Status detail
    , transaction_type As status
    -- Credited entity
    , NULL
    , NULL
    -- Summary text detail
    , description
    -- Tableau symbol
    , '$' As symbol
    -- Uniform calendar dates for axis alignment
    , cal.*
  From ksm_giving
  Cross Join cal
  Where ksm_giving.tx_gypm_ind = 'G'
)
, ksm_payment As (
  Select
    prospect_id
    , household_id
    , household_rpt_name
    , id_number
    , report_name
    , primary_ind
    , rating_bin
    -- Data point description
    , 'Payment' As type
    -- Additional description detail
    , recognition_credit
    -- Category summary
    , category
    -- Tableau color field
    , color
    -- Unique identifier
    , tx_number
    -- Uniform start date for axis alignment
    , date_of_record
    -- Uniform stop date for axis alignment
    , NULL
    -- Status detail
    , transaction_type As status
    -- Credited entity
    , NULL
    , NULL
    -- Summary text detail
    , description
    -- Tableau symbol
    , 'Y' As symbol
    -- Uniform calendar dates for axis alignment
    , cal.*
  From ksm_giving
  Cross Join cal
  Where ksm_giving.tx_gypm_ind = 'Y'
)
, ksm_match As (
  Select
    prospect_id
    , household_id
    , household_rpt_name
    , id_number
    , report_name
    , primary_ind
    , rating_bin
    -- Data point description
    , 'Match' As type
    -- Additional description detail
    , recognition_credit
    -- Category summary
    , category
    -- Tableau color field
    , color
    -- Unique identifier
    , tx_number
    -- Uniform start date for axis alignment
    , date_of_record
    -- Uniform stop date for axis alignment
    , NULL
    -- Status detail
    , transaction_type As status
    -- Credited entity
    , NULL
    , NULL
    -- Summary text detail
    , description
    -- Tableau symbol
    , 'M' As symbol
    -- Uniform calendar dates for axis alignment
    , cal.*
  From ksm_giving
  Cross Join cal
  Where ksm_giving.tx_gypm_ind = 'M'
)
, ksm_plg As (
  Select
    prospect_id
    , household_id
    , household_rpt_name
    , id_number
    , report_name
    , primary_ind
    , rating_bin
    -- Data point description
    , 'Pledge' As type
    -- Additional description detail
    , recognition_credit
    -- Category summary
    , category
    -- Tableau color field
    , color
    -- Unique identifier
    , tx_number
    -- Uniform start date for axis alignment
    , date_of_record
    -- Uniform stop date for axis alignment
    , NULL
    -- Status detail
    , transaction_type || ' (' || pledge_status || ')' As status
    -- Credited entity
    , NULL
    , NULL
    -- Summary text detail
    , description
    -- Tableau symbol
    , 'P' As symbol
    -- Uniform calendar dates for axis alignment
    , cal.*
  From ksm_giving
  Cross Join cal
  Where ksm_giving.tx_gypm_ind = 'P'
)

-- Recent tasks
, tasks As (
  Select
    t.prospect_id
    , hh.household_id
    , hh.household_rpt_name
    , t.id_number
    , entity.report_name
    , pe.primary_ind
    , rpt_pbh634.ksm_pkg_tmp.get_prospect_rating_bin(pe.prospect_id) As rating_bin
    -- Data point description
    , 'Task' As type
    -- Additional description detail
    , t.task_code_desc
    -- Category summary
    , 'Task' As category
    -- Tableau color field
    , Case
        When t.task_status_code In (1, 2, 3) Then 'Task (active)'
        When t.task_status_code = 4 Then 'Task (completed)'
      End As color
    -- Unique identifier
    , t.task_id
    -- Uniform start date for axis alignment
    , t.sched_date
    -- Uniform stop date for axis alignment
    , t.completed_date
    -- Status detail
    , t.task_status
    -- Credited entity
    , t.task_responsible_id
    , t.task_responsible
    -- Summary text detail
    , t.task_description
    -- Tableau symbol
    , 'T' As symbol
    -- Uniform calendar dates for axis alignment
    , cal.*
  From v_ksm_tasks t
  Inner Join pe On pe.prospect_id = t.prospect_id
  Inner Join hh On hh.id_number = pe.id_number
  Inner Join entity On entity.id_number = pe.id_number
  Cross Join cal
  Where t.task_status_code In (1, 2, 3, 4)
    And t.sched_date Between cal.bofy_prev And cal.eofy_next
)

-- Main query
Select * From prospects
Union
Select * From contacts
Union
Select * From proposal_starts
Union
Select * From proposal_asks
Union
Select * From proposal_closes
Union
Select * From ksm_gift
Union
Select * From ksm_payment
Union
Select * From ksm_match
Union
Select * From ksm_plg
Union
Select * From tasks
;
