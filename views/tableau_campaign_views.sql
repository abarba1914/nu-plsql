/*******************************
KSM Campaign transactions view
Based on Bill Taylor's code
********************************/

Create Or Replace View vt_ksm_campaign_2008_fast As

With 

/* KSM-specific campaign new gifts & commitments definition */
ksm_data As (
  Select *
  From table(ksm_pkg.tbl_gift_credit_campaign)
)

/* Additional KSM-specific derived fields */
Select
  ksm_data.*
  -- Prospect data fields
  , entity.report_name
  , entity.institutional_suffix
  , prs.business_title
  , trim(prs.employer_name1 || ' ' || prs.employer_name2) As employer_name
  , prs.pref_state
  , prs.preferred_country
  , prs.evaluation_rating
  , prs.evaluation_date
  , prs.officer_rating
  -- Fiscal year-to-date indicator
  , ksm_pkg.fytd_indicator(date_of_record) As ftyd_ind
  -- Calendar objects
  , cal.curr_fy
  -- Giving bin
  , Case
      When amount >= 1000000 Then 'A $1M+'
      When amount >= 100000  Then 'B $100K-$999.9K'
      When amount >= 50000   Then 'C $50K-$99.9K'
      When amount >= 2500    Then 'D $2.5K-$49.9K'
      When amount <  2500    Then 'E <$2.5K'
    End As giving_band
  -- Campaign priority coding
  , priorities.ksm_campaign_category
  -- Replace null ksm_source_donor with id_number
  , NVL(ksm_pkg.get_gift_source_donor_ksm(ksm_data.rcpt_or_plg_number), ksm_data.id_number) As ksm_source_donor
From ksm_data
Cross Join v_current_calendar cal
Inner Join entity On ksm_data.id_number = entity.id_number
Left Join v_ksm_campaign_priorities priorities
  On priorities.rcpt_or_plg_number = ksm_data.rcpt_or_plg_number
  And priorities.alloc_code = ksm_data.alloc_code
Left Join nu_prs_trp_prospect prs
  On prs.id_number = ksm_data.id_number
;

-- Householded version of above

Create Or Replace View vt_ksm_campaign_2008_gifts As

With 

ksm_campaign As (
  Select *
  From vt_ksm_campaign_2008_fast
)

/* Main query */
Select
  ksm_campaign.*
  , hh.household_id
  , hh.household_name
  , hh.household_rpt_name
  , hh.household_ksm_year
  , hh.household_program_group
  , hh.household_suffix
  , hh.household_spouse
  , hh.household_spouse_suffix
  , hh.household_city
  , hh.household_state
  , hh.household_country
  , hh.household_geo_primary_desc
  -- Record type
  , Case
      When household_record = 'ST' Then '3 Students'
      When household_record In ('AL', 'FA') Then '1 Alumni'
      When household_record In ('NA', 'FN') Then '2 Non-Alumni'
      When household_record In ('CP', 'CF') Then '4 Corporations'
      When household_record = 'FP' Then '5 Foundations'
      Else '6 Other Organizations'
      End
    As hh_source_ksm
  -- Calendar
  , yesterday
From ksm_campaign
Cross Join v_current_calendar cal
Inner Join v_entity_ksm_households hh
  On ksm_campaign.ksm_source_donor = hh.id_number
;

/*******************************
KSM Campaign progress to goal crosstab
Based on Bill Taylor's code
********************************/

Create Or Replace View vt_ksm_campaign_2008_progress As

With

/* Pull campaign transactions */
campaign As (
  Select
    rcpt_or_plg_number
    , amount
    , 'Raised' As field
    -- Campaign category grouper
    , Case
        When ksm_campaign_category Is Null Or ksm_campaign_category = '' Then 'TBD'
        When ksm_campaign_category Like 'Education%' Then 'Educational Mission'
        When ksm_campaign_category Like 'Global Innovation%' Then 'Global Innovation'
        Else ksm_campaign_category
      End As priority
  From vt_ksm_campaign_2008_gifts
  Where amount > 0
)

/* Campaign goals */
, goals As (
  Select 'TBD' As priority, 'Goal' As field, 0 As amount From DUAL
  Union
  Select 'Educational Mission' As priority, 'Goal' As field, 60000000 As amount From DUAL
  Union
  Select 'Global Innovation', 'Goal', 30000000 From DUAL
  Union
  Select 'Global Hub', 'Goal', 220000000 From DUAL
  Union
  Select 'Thought Leadership', 'Goal', 40000000 From DUAL
)

/* Summed and binned results */
(
-- Raised to date
Select
  campaign.priority
  , campaign.field
  , sum(campaign.amount) As amount
  , sum(campaign.amount) As overall
  , goals.amount As goal_amt
  , yesterday
From campaign
Cross Join v_current_calendar cal
Inner Join goals On campaign.priority = goals.priority
Group By
  campaign.priority
  , campaign.field
  , goals.amount
  , yesterday
) Union All (
-- Goals
Select
  priority
  , field
  , amount
  , NULL
  , NULL
  , yesterday
From goals
Cross Join v_current_calendar cal
)
;

/*******************************
Campaign donors list
********************************/

Create Or Replace View vt_ksm_campaign_donors As

Select
  gc.id_number
  , gc.report_name
  , entity.record_status_code
  , entity.person_or_org
  , entity.institutional_suffix
  , gc.degrees_concat
  , gc.household_id
  , gc.household_rpt_name
  , gc.household_state
  , gc.household_country
  , prs.prospect_manager
  , gc.campaign_giving
  , gc.campaign_legal_giving
  , gc.campaign_steward_giving
  , gc.campaign_nonanonymous
  , gc.campaign_discounted_bequests
From v_ksm_giving_campaign gc
Inner Join entity
  On entity.id_number = gc.id_number
Left Join nu_prs_trp_prospect prs
  On prs.id_number = gc.id_number
;
