/****************************
All NU contact reports; fast due to no householding
****************************/

Create Or Replace View v_contact_reports_fast As

With

/* Prospect Entity; active records only */
pe As (
  Select pre.*
  From prospect_entity pre
  Inner Join prospect p On p.prospect_id = pre.prospect_id
  Where p.active_ind = 'Y'
)

/* ARD staff */
, ard_staff_ids As (
  -- Best guess of ARD staff
  Select
    id_number
    , report_name
  From table(ksm_pkg.tbl_nu_ard_staff)
  Union
  -- KSM frontline staff start/stop dates
  Select
    id_number
    , report_name
  From table(ksm_pkg.tbl_frontline_ksm_staff)
)
, ard_staff As (
  Select
    asi.id_number
    , asi.report_name
    , staff.job_title
    , staff.employer_unit
  From ard_staff_ids asi
  Left Join table(ksm_pkg.tbl_nu_ard_staff) staff On staff.id_number = asi.id_number
)

/* Main query */
Select
  contact_rpt_credit.id_number As credited
  , contacter.report_name As credited_name
  , ard_staff.job_title
  , ard_staff.employer_unit
  , tms_ctype.short_desc As contact_type
  , tms_cpurp.short_desc As contact_purpose
  -- Contact report fields
  , contact_report.report_id
  , contact_report.id_number
  , contact_report.contacted_name
  , contacted_entity.report_name
  , contact_report.prospect_id
  , pe.primary_ind
  , prospect.prospect_name
  , prospect.prospect_name_sort
  , contact_report.contact_date
  , rpt_pbh634.ksm_pkg.get_fiscal_year(contact_report.contact_date) As fiscal_year
  , contact_report.description
  , dbms_lob.substr(contact_report.summary, 2000, 1) As summary
  -- Prospect fields
  , prs.officer_rating
  , prs.evaluation_rating
  , strat.university_strategy
  -- Custom variables
  , Case When ard_staff.report_name Is Not Null Or ksm_staff.report_name Is Not Null Then 'Y' End
    As ard_staff
  , Case When ksm_staff.report_name Is Not Null Then 'Y' End
    As frontline_ksm_staff
  , Case
      When tms_ctype.contact_type In ('A', 'E') Then 'Attempted, E-mail, or Social'
      Else tms_ctype.short_desc
    End As contact_type_category
  , Case When contact_report.contact_type = 'V' Then
      Case When contact_report.contact_purpose_code = '1' Then 'Qualification' Else 'Visit' End
      Else Null
    End As visit_type
  , rpt_pbh634.ksm_pkg.get_prospect_rating_bin(prs.id_number) As rating_bin
  , cal.curr_fy
  , cal.prev_fy_start
  , cal.curr_fy_start
  , cal.next_fy_start
  , cal.yesterday
  , cal.ninety_days_ago
From contact_report
Cross Join v_current_calendar cal
Inner Join contact_rpt_credit On contact_rpt_credit.report_id = contact_report.report_id
Inner Join tms_contact_rpt_purpose tms_cpurp On tms_cpurp.contact_purpose_code = contact_report.contact_purpose_code
Inner Join tms_contact_rpt_type tms_ctype On tms_ctype.contact_type = contact_report.contact_type
Inner Join nu_prs_trp_prospect prs On prs.id_number = contact_report.id_number
Inner Join entity contacted_entity On contacted_entity.id_number = contact_report.id_number
Inner Join entity contacter On contacter.id_number = contact_rpt_credit.id_number
Left Join ard_staff On ard_staff.id_number = contact_rpt_credit.id_number
Left Join table(ksm_pkg.tbl_frontline_ksm_staff) ksm_staff On ksm_staff.id_number = ard_staff.id_number
Left Join prospect On prospect.prospect_id = prs.prospect_id
Left Join pe On pe.id_number = prs.id_number
Left Join table(ksm_pkg.tbl_university_strategy) strat On strat.prospect_id = contact_report.prospect_id
;

/****************************
All NU contact reports with householding
****************************/

Create Or Replace View v_contact_reports As

With

/* KSM households -- only those with contact reports */
hh As (
  Select Distinct
    contact_report.id_number
    , hhs.report_name
    , hhs.household_id
  From contact_report
  Inner Join table(rpt_pbh634.ksm_pkg.tbl_entity_households_ksm) hhs On hhs.id_number = contact_report.id_number
)

/* Main query */
Select
  credited
  , credited_name
  , job_title
  , employer_unit
  , contact_type
  , contact_purpose
  -- Contact report fields
  , report_id
  , vcrf.id_number
  , contacted_name
  , vcrf.report_name
  , hh.household_id
  , prospect_id
  , primary_ind
  , prospect_name
  , prospect_name_sort
  , contact_date
  , fiscal_year
  , description
  , summary
  -- Prospect fields
  , officer_rating
  , evaluation_rating
  , university_strategy
  -- Custom variables
  , ard_staff
  , frontline_ksm_staff
  , contact_type_category
  , visit_type
  , rating_bin
  , curr_fy
  , prev_fy_start
  , curr_fy_start
  , next_fy_start
  , yesterday
  , ninety_days_ago
From v_contact_reports_fast vcrf
Inner Join hh On hh.id_number = vcrf.id_number
;

/****************************
ARD-specific contact reports
****************************/

Create Or Replace View v_ard_contact_reports As

/* Main query */
Select
  credited
  , credited_name
  , job_title
  , employer_unit
  , contact_type
  , contact_purpose
  , report_id
  , id_number
  , contacted_name
  , report_name
  , household_id
  , prospect_id
  , primary_ind
  , prospect_name
  , prospect_name_sort
  , contact_date
  , fiscal_year
  , description
  , summary
  , officer_rating
  , evaluation_rating
  , university_strategy
  , ard_staff
  , frontline_ksm_staff
  , contact_type_category
  , visit_type
  , rating_bin
  , curr_fy
  , prev_fy_start
  , curr_fy_start
  , next_fy_start
  , yesterday
  , ninety_days_ago
From v_contact_reports cr
Where ard_staff = 'Y'
;

/****************************
KSM-specific contact reports
Only recent FY
****************************/

Create Or Replace View v_ksm_contact_reports As

/* Main query */
Select
  credited
  , credited_name
  , job_title
  , employer_unit
  , contact_type
  , contact_purpose
  , report_id
  , id_number
  , contacted_name
  , report_name
  , household_id
  , prospect_id
  , primary_ind
  , prospect_name
  , prospect_name_sort
  , contact_date
  , fiscal_year
  , description
  , summary
  , officer_rating
  , evaluation_rating
  , university_strategy
  , ard_staff
  , frontline_ksm_staff
  , contact_type_category
  , visit_type
  , rating_bin
  , curr_fy
  , prev_fy_start
  , curr_fy_start
  , next_fy_start
  , yesterday
  , ninety_days_ago
From v_ard_contact_reports ard
Where frontline_ksm_staff = 'Y'
  And contact_date Between prev_fy_start And yesterday
;
