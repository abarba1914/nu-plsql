/*************************************************
Kellogg lifetime giving transactions
*************************************************/
Create Or Replace View v_ksm_giving_trans As
-- View implementing ksm_pkg Kellogg gift credit
Select
  g.*
  , cal.today
  , cal.yesterday
  , cal.curr_fy
From table(ksm_pkg.tbl_gift_credit_ksm) g
Cross Join table(ksm_pkg.tbl_current_calendar) cal
;

/*************************************************
Householded Kellogg lifetime giving transactions
*************************************************/
Create Or Replace View v_ksm_giving_trans_hh As
-- View implementing ksm_pkg Kellogg gift credit, with household ID (slower than tbl_gift_credit_ksm)
Select
  g.*
  , cal.today
  , cal.yesterday
  , cal.curr_fy
From table(ksm_pkg.tbl_gift_credit_hh_ksm) g
Cross Join table(ksm_pkg.tbl_current_calendar) cal
;

/*************************************************
Householded top giving allocations
*************************************************/

Create Or Replace View v_ksm_giving_top_allocs As
-- View showing top Kellogg allocations for each donor household
With

-- HH giving trans
hh_giving As (
  Select *
  From v_ksm_giving_trans_hh
)
-- Giving by allocation
, allocs As (
  Select
    household_id
    , id_number
    , allocation_code
    , alloc_short_name
    , sum(hh_credit) As alloc_giving
  From hh_giving
  Where tx_gypm_ind <> 'Y'
  Group By
    household_id
    , id_number
    , allocation_code
    , alloc_short_name
)
, top_allocs As (
  Select
    household_id
    , id_number
    , max(allocs.allocation_code) keep(dense_rank First Order By alloc_giving Desc, allocs.alloc_short_name Asc)
      As top_alloc_code
    , max(allocs.alloc_short_name) keep(dense_rank First Order By alloc_giving Desc, allocs.alloc_short_name Asc)
      As top_alloc
    , max(allocs.alloc_giving) keep(dense_rank First Order By alloc_giving Desc, allocs.alloc_short_name Asc)
      As top_alloc_amt
  From allocs
  Group By
    household_id
    , id_number
)

Select
  household_id
  , id_number
  , top_alloc_code
  , top_alloc
  , top_alloc_amt
From top_allocs
;

/*************************************************
Householded entity giving summaries
*************************************************/
Create Or Replace View v_ksm_giving_summary As
-- View implementing Kellogg gift credit, householded, with several common types
With
-- Parameters defining KLC years/amounts
params As (
  Select
    2500 As klc_amt -- Edit this
    , 1000 As young_klc_amt -- Edit this
    , 5 As young_klc_yrs
  From DUAL
)
-- HH giving trans
, hh_giving As (
  Select *
  From v_ksm_giving_trans_hh
)
-- Sum transaction amounts
, trans As (
  Select Distinct
    hh.id_number
    , hh.household_id
    , hh.household_rpt_name
    , hh.household_spouse_id
    , hh.household_spouse
    , hh.household_last_masters_year
    , max(Case When household_last_masters_year >= cal.curr_fy - young_klc_yrs Then 'Y' End)
      As af_young_alum
    , max(Case When household_last_masters_year >= cal.curr_fy - young_klc_yrs - 1 Then 'Y' End)
      As af_young_alum1
    , max(Case When household_last_masters_year >= cal.curr_fy - young_klc_yrs - 2 Then 'Y' End)
      As af_young_alum2
    , max(Case When household_last_masters_year >= cal.curr_fy - young_klc_yrs - 3 Then 'Y' End)
      As af_young_alum3
    , sum(Case When tx_gypm_ind != 'Y' Then hh_credit Else 0 End) As ngc_lifetime
    , sum(Case When tx_gypm_ind != 'Y' Then hh_recognition_credit Else 0 End) -- Count bequests at face value and internal transfers at > $0
      As ngc_lifetime_full_rec
    , sum(Case When tx_gypm_ind != 'Y' And anonymous Not In (Select Distinct anonymous_code From tms_anonymous) Then hh_recognition_credit Else 0 End)
      As ngc_lifetime_nonanon_full_rec
    , max(nu_giving.lifetime_giving) As nu_max_hh_lifetime_giving
    , sum(Case When tx_gypm_ind != 'P' Then hh_credit Else 0 End) As cash_lifetime
    , sum(Case When tx_gypm_ind != 'Y' And cal.curr_fy = fiscal_year     Then hh_credit Else 0 End) As ngc_cfy
    , sum(Case When tx_gypm_ind != 'Y' And cal.curr_fy = fiscal_year + 1 Then hh_credit Else 0 End) As ngc_pfy1
    , sum(Case When tx_gypm_ind != 'Y' And cal.curr_fy = fiscal_year + 2 Then hh_credit Else 0 End) As ngc_pfy2
    , sum(Case When tx_gypm_ind != 'Y' And cal.curr_fy = fiscal_year + 3 Then hh_credit Else 0 End) As ngc_pfy3
    , sum(Case When tx_gypm_ind != 'Y' And cal.curr_fy = fiscal_year + 4 Then hh_credit Else 0 End) As ngc_pfy4
    , sum(Case When tx_gypm_ind != 'Y' And cal.curr_fy = fiscal_year + 5 Then hh_credit Else 0 End) As ngc_pfy5
    , sum(Case When tx_gypm_ind != 'P' And cal.curr_fy = fiscal_year     Then hh_credit Else 0 End) As cash_cfy
    , sum(Case When tx_gypm_ind != 'P' And cal.curr_fy = fiscal_year + 1 Then hh_credit Else 0 End) As cash_pfy1
    , sum(Case When tx_gypm_ind != 'P' And cal.curr_fy = fiscal_year + 2 Then hh_credit Else 0 End) As cash_pfy2
    , sum(Case When tx_gypm_ind != 'P' And cal.curr_fy = fiscal_year + 3 Then hh_credit Else 0 End) As cash_pfy3
    , sum(Case When tx_gypm_ind != 'P' And cal.curr_fy = fiscal_year + 4 Then hh_credit Else 0 End) As cash_pfy4
    , sum(Case When tx_gypm_ind != 'P' And cal.curr_fy = fiscal_year + 5 Then hh_credit Else 0 End) As cash_pfy5
    -- Annual Fund cash totals
    , sum(Case When tx_gypm_ind != 'P' And cal.curr_fy = fiscal_year     And af_flag = 'Y' Then hh_credit Else 0 End) As af_cfy
    , sum(Case When tx_gypm_ind != 'P' And cal.curr_fy = fiscal_year + 1 And af_flag = 'Y' Then hh_credit Else 0 End) As af_pfy1
    , sum(Case When tx_gypm_ind != 'P' And cal.curr_fy = fiscal_year + 2 And af_flag = 'Y' Then hh_credit Else 0 End) As af_pfy2
    , sum(Case When tx_gypm_ind != 'P' And cal.curr_fy = fiscal_year + 3 And af_flag = 'Y' Then hh_credit Else 0 End) As af_pfy3
    , sum(Case When tx_gypm_ind != 'P' And cal.curr_fy = fiscal_year + 4 And af_flag = 'Y' Then hh_credit Else 0 End) As af_pfy4
    , sum(Case When tx_gypm_ind != 'P' And cal.curr_fy = fiscal_year + 5 And af_flag = 'Y' Then hh_credit Else 0 End) As af_pfy5
    -- Current Use cash totals
    , sum(Case When tx_gypm_ind != 'P' And cal.curr_fy = fiscal_year     And cru_flag = 'Y' Then hh_credit Else 0 End) As cru_cfy
    , sum(Case When tx_gypm_ind != 'P' And cal.curr_fy = fiscal_year + 1 And cru_flag = 'Y' Then hh_credit Else 0 End) As cru_pfy1
    , sum(Case When tx_gypm_ind != 'P' And cal.curr_fy = fiscal_year + 2 And cru_flag = 'Y' Then hh_credit Else 0 End) As cru_pfy2
    , sum(Case When tx_gypm_ind != 'P' And cal.curr_fy = fiscal_year + 3 And cru_flag = 'Y' Then hh_credit Else 0 End) As cru_pfy3
    , sum(Case When tx_gypm_ind != 'P' And cal.curr_fy = fiscal_year + 4 And cru_flag = 'Y' Then hh_credit Else 0 End) As cru_pfy4
    , sum(Case When tx_gypm_ind != 'P' And cal.curr_fy = fiscal_year + 5 And cru_flag = 'Y' Then hh_credit Else 0 End) As cru_pfy5
    -- KLC cash totals; count matching gift credit in year of matched gift
    , sum(Case When tx_gypm_ind != 'P' And cru_flag = 'Y' And (
        (cal.curr_fy = fiscal_year     And tx_gypm_ind != 'M') Or (cal.curr_fy = matched_fiscal_year     And tx_gypm_ind = 'M')
      ) Then hh_credit Else 0 End) As klc_cfy
    , sum(Case When tx_gypm_ind != 'P' And cru_flag = 'Y' And (
        (cal.curr_fy = fiscal_year + 1 And tx_gypm_ind != 'M') Or (cal.curr_fy = matched_fiscal_year + 1 And tx_gypm_ind = 'M')
      ) Then hh_credit Else 0 End) As klc_pfy1
    , sum(Case When tx_gypm_ind != 'P' And cru_flag = 'Y' And (
        (cal.curr_fy = fiscal_year + 2 And tx_gypm_ind != 'M') Or (cal.curr_fy = matched_fiscal_year + 2 And tx_gypm_ind = 'M')
      ) Then hh_credit Else 0 End) As klc_pfy2
    , sum(Case When tx_gypm_ind != 'P' And cru_flag = 'Y' And (
        (cal.curr_fy = fiscal_year + 3 And tx_gypm_ind != 'M') Or (cal.curr_fy = matched_fiscal_year + 3 And tx_gypm_ind = 'M')
      ) Then hh_credit Else 0 End) As klc_pfy3
    , sum(Case When tx_gypm_ind != 'P' And cru_flag = 'Y' And (
        (cal.curr_fy = fiscal_year + 4 And tx_gypm_ind != 'M') Or (cal.curr_fy = matched_fiscal_year + 4 And tx_gypm_ind = 'M')
      ) Then hh_credit Else 0 End) As klc_pfy4
    , sum(Case When tx_gypm_ind != 'P' And cru_flag = 'Y' And (
        (cal.curr_fy = fiscal_year + 5 And tx_gypm_ind != 'M') Or (cal.curr_fy = matched_fiscal_year + 5 And tx_gypm_ind = 'M')
      ) Then hh_credit Else 0 End) As klc_pfy5
    -- Stewardship giving, defined as new gifts and commitments plus pledge payments where the NGC was not already counted
    -- in the current year.
    -- WARNING: includes new gifts and commitments as well as cash
    , sum(Case When cal.curr_fy = fiscal_year     Then hh_stewardship_credit Else 0 End) As stewardship_cfy
    , sum(Case When cal.curr_fy = fiscal_year + 1 Then hh_stewardship_credit Else 0 End) As stewardship_pfy1
    , sum(Case When cal.curr_fy = fiscal_year + 2 Then hh_stewardship_credit Else 0 End) As stewardship_pfy2
    , sum(Case When cal.curr_fy = fiscal_year + 3 Then hh_stewardship_credit Else 0 End) As stewardship_pfy3
    , sum(Case When cal.curr_fy = fiscal_year + 4 Then hh_stewardship_credit Else 0 End) As stewardship_pfy4
    , sum(Case When cal.curr_fy = fiscal_year + 5 Then hh_stewardship_credit Else 0 End) As stewardship_pfy5
    -- Anonymous stewardship giving per FY
    -- WARNING: includes new gifts and commitments as well as cash
    , sum(Case When cal.curr_fy = fiscal_year     And anonymous <> ' ' Then hh_stewardship_credit Else 0 End) As anonymous_cfy
    , sum(Case When cal.curr_fy = fiscal_year + 1 And anonymous <> ' ' Then hh_stewardship_credit Else 0 End) As anonymous_pfy1
    , sum(Case When cal.curr_fy = fiscal_year + 2 And anonymous <> ' ' Then hh_stewardship_credit Else 0 End) As anonymous_pfy2
    , sum(Case When cal.curr_fy = fiscal_year + 3 And anonymous <> ' ' Then hh_stewardship_credit Else 0 End) As anonymous_pfy3
    , sum(Case When cal.curr_fy = fiscal_year + 4 And anonymous <> ' ' Then hh_stewardship_credit Else 0 End) As anonymous_pfy4
    , sum(Case When cal.curr_fy = fiscal_year + 5 And anonymous <> ' ' Then hh_stewardship_credit Else 0 End) As anonymous_pfy5
    -- Giving history
    , min(gfts.fiscal_year) As fy_giving_first_yr
    , max(gfts.fiscal_year) As fy_giving_last_yr
    , count(Distinct gfts.fiscal_year) As fy_giving_yr_count
    , min(Case When tx_gypm_ind != 'P' Then gfts.fiscal_year Else NULL End) As fy_giving_first_cash_yr
    , max(Case When tx_gypm_ind != 'P' Then gfts.fiscal_year Else NULL End) As fy_giving_last_cash_yr
    , count(Distinct Case When tx_gypm_ind != 'P' Then gfts.fiscal_year Else NULL End) As fy_giving_yr_cash_count
    -- Last KSM gift
    , min(gfts.tx_number) keep(dense_rank First Order By gfts.date_of_record Desc, gfts.tx_number Asc)
      As last_gift_tx_number
    , min(gfts.date_of_record) keep(dense_rank First Order By gfts.date_of_record Desc, gfts.tx_number Asc)
      As last_gift_date
    , min(gfts.transaction_type) keep(dense_rank First Order By gfts.date_of_record Desc, gfts.tx_number Asc)
      As last_gift_type
    , min(gfts.allocation_code) keep(dense_rank First Order By gfts.date_of_record Desc, gfts.tx_number Asc, gfts.alloc_short_name Asc)
      As last_gift_alloc_code
    , min(gfts.alloc_short_name) keep(dense_rank First Order By gfts.date_of_record Desc, gfts.tx_number Asc, gfts.alloc_short_name Asc)
      As last_gift_alloc
    , sum(gfts.hh_recognition_credit) keep(dense_rank First Order By gfts.date_of_record Desc, gfts.tx_number Asc)
      As last_gift_recognition_credit
  From v_entity_ksm_households hh
  Cross Join v_current_calendar cal
  Cross Join params
  Inner Join hh_giving gfts
    On gfts.household_id = hh.household_id
  Left Join nu_rpt_t_lifetime_giving nu_giving
    On nu_giving.id_number = hh.id_number
  Group By
    hh.id_number
    , hh.household_id
    , hh.household_rpt_name
    , hh.household_spouse_id
    , hh.household_spouse
    , hh.household_last_masters_year
)
-- Main query
Select
  trans.*
  -- AF status categorizer
  , Case
      When af_cfy > 0 Then 'Donor'
      When af_pfy1 > 0 Then 'LYBUNT'
      When af_pfy2 + af_pfy3 + af_pfy4 > 0 Then 'PYBUNT'
      When af_cfy + af_pfy1 + af_pfy2 + af_pfy3 + af_pfy4 = 0 Then 'Lapsed/Non'
    End As af_status
  -- AF status last year
  , Case
      When af_pfy1 > 0 Then 'LYBUNT'
      When af_pfy2 + af_pfy3 + af_pfy4 > 0 Then 'PYBUNT'
      When af_pfy1 + af_pfy2 + af_pfy3 + af_pfy4 = 0 Then 'Lapsed/Non'
    End As af_status_fy_start
  -- AF KLC flag
  , Case
      When klc_cfy >= klc_amt
        Then 'Y'
      When af_young_alum = 'Y'
        And klc_cfy >= young_klc_amt
        Then 'Y'
      End
    As klc_current
  -- AF KLC LYBUNT flag
  , Case
      When klc_pfy1 >= klc_amt
        Then 'Y'
      When af_young_alum = 'Y'
        And klc_pfy1 >= young_klc_amt
        Then 'Y'
      When af_young_alum1 = 'Y'
        And klc_pfy1 >= young_klc_amt
        Then 'Y'
      End
    As klc_lybunt
  -- AF giving segment
  , Case
      -- $2500+ for 3 years is KLC
      When cru_pfy1 >= klc_amt
        And cru_pfy2 >= klc_amt
        And cru_pfy3 >= klc_amt
          Then 'KLC Loyal 3+'
      -- Check for KLC young alum loyal
      When af_young_alum = 'Y'
        And cru_pfy1 >= young_klc_amt
        And cru_pfy2 >= young_klc_amt
        And cru_pfy3 >= young_klc_amt
          Then 'KLC YA Loyal 3+'
      -- Check for KLC young alum -1 loyal
      When af_young_alum1 = 'Y'
        And cru_pfy1 >= young_klc_amt
        And cru_pfy2 >= young_klc_amt
        And cru_pfy3 >= young_klc_amt
          Then 'KLC YA1 Loyal 3+'
      -- Check for KLC young alum -2 loyal
      When af_young_alum2 = 'Y'
        And cru_pfy1 >= klc_amt
        And cru_pfy2 >= young_klc_amt
        And cru_pfy3 >= young_klc_amt
          Then 'KLC YA2 Loyal 3+'
      -- Check for KLC young alum -3 loyal
      When af_young_alum3 = 'Y'
        And cru_pfy1 >= klc_amt
        And cru_pfy2 >= klc_amt
        And cru_pfy3 >= young_klc_amt
          Then 'KLC YA3 Loyal 3+'
      -- $2500+ 2 of 3 is KLC loyal
      When (cru_pfy1 >= klc_amt And cru_pfy2 >= klc_amt)
        Or (cru_pfy1 >= klc_amt And cru_pfy3 >= klc_amt)
        Or (cru_pfy2 >= klc_amt And cru_pfy3 >= klc_amt)
          Then 'KLC Loyal 2 of 3'
      -- Check for KLC young alum loyal
      When af_young_alum = 'Y'
        And (
          (cru_pfy1 >= young_klc_amt And cru_pfy2 >= young_klc_amt)
          Or (cru_pfy1 >= young_klc_amt And cru_pfy3 >= young_klc_amt)
          Or (cru_pfy2 >= young_klc_amt And cru_pfy3 >= young_klc_amt)
        )
          Then 'KLC YA Loyal 2 of 3'
      -- Check for KLC young alum -1 loyal
      When af_young_alum1 = 'Y'
        And (
          (cru_pfy1 >= young_klc_amt And cru_pfy2 >= young_klc_amt)
          Or (cru_pfy1 >= young_klc_amt And cru_pfy3 >= young_klc_amt)
          Or (cru_pfy2 >= young_klc_amt And cru_pfy3 >= young_klc_amt)
        )
          Then 'KLC YA1 Loyal 2 of 3'
      -- Check for KLC young alum -2 loyal
      When af_young_alum2 = 'Y'
        And (
          (cru_pfy1 >= klc_amt And cru_pfy2 >= young_klc_amt)
          Or (cru_pfy1 >= klc_amt And cru_pfy3 >= young_klc_amt)
          Or (cru_pfy2 >= young_klc_amt And cru_pfy3 >= young_klc_amt)
        )
          Then 'KLC YA2 Loyal 2 of 3'
      -- Check for KLC young alum -3 loyal
      When af_young_alum3 = 'Y'
        And (
          (cru_pfy1 >= klc_amt And cru_pfy2 >= klc_amt)
          Or (cru_pfy1 >= klc_amt And cru_pfy3 >= young_klc_amt)
          Or (cru_pfy2 >= klc_amt And cru_pfy3 >= young_klc_amt)
        )
          Then 'KLC YA3 Loyal 2 of 3'
      -- KLC LYBUNT designation
      When cru_pfy1 >= klc_amt
        Then 'KLC LYBUNT'
      When af_young_alum = 'Y'
        And cru_pfy1 >= young_klc_amt
          Then 'KLC YA LYBUNT'
      When af_young_alum1 = 'Y'
        And cru_pfy1 >= young_klc_amt
          Then 'KLC YA1 LYBUNT'
      When af_young_alum2 = 'Y'
        And cru_pfy1 >= klc_amt
          Then 'KLC YA2 LYBUNT'
      When af_young_alum3 = 'Y'
        And cru_pfy1 >= klc_amt
          Then 'KLC YA3 LYBUNT'
      -- KLC PYBUNT designation
      When cru_pfy2 >= klc_amt
        Or cru_pfy3 >= klc_amt
        Or cru_pfy4 >= klc_amt
        Or cru_pfy5 >= klc_amt
          Then 'KLC PYBUNT'
      -- KLC YA PYBUNT designation
      When af_young_alum = 'Y'
        And (
          cru_pfy2 >= young_klc_amt
          Or cru_pfy3 >= young_klc_amt
          Or cru_pfy4 >= young_klc_amt
          Or cru_pfy5 >= young_klc_amt
        )
          Then 'KLC YA PYBUNT'
      -- KLC YA PYBUNT -1
      When af_young_alum1 = 'Y'
        And (
          cru_pfy2 >= young_klc_amt
          Or cru_pfy3 >= young_klc_amt
          Or cru_pfy4 >= young_klc_amt
          Or cru_pfy5 >= young_klc_amt
        )
          Then 'KLC YA1 PYBUNT'
      -- KLC YA PYBUNT -2
      When af_young_alum2 = 'Y'
        And (
          cru_pfy2 >= young_klc_amt
          Or cru_pfy3 >= young_klc_amt
          Or cru_pfy4 >= young_klc_amt
          Or cru_pfy5 >= young_klc_amt
        )
          Then 'KLC YA2 PYBUNT'
      -- KLC YA PYBUNT -3
      When af_young_alum3 = 'Y'
        And (
          cru_pfy2 >= klc_amt
          Or cru_pfy3 >= young_klc_amt
          Or cru_pfy4 >= young_klc_amt
          Or cru_pfy5 >= young_klc_amt
        )
          Then 'KLC YA3 PYBUNT'
      -- 3 years in a row is loyal
      When cru_pfy1 > 0
        And cru_pfy2 > 0
        And cru_pfy3 > 0
          Then 'Loyal 3+'
      -- 2 of 3 is loyal
      When (cru_pfy1 > 0 And cru_pfy2 > 0)
        Or (cru_pfy1 > 0 And cru_pfy3 > 0)
        Or (cru_pfy2 > 0 And cru_pfy3 > 0)
          Then 'Loyal 2 of 3'
      -- Standard designation
      When cru_pfy1 > 0
        Then 'LYBUNT'
      When cru_pfy2 > 0
        Then 'PYBUNT-2'
      When cru_pfy3 > 0
        Then 'PYBUNT-3'
      When cru_pfy4 > 0
        Then 'PYBUNT-4'
      When cru_pfy1 + cru_pfy2 + cru_pfy3 + cru_pfy4 = 0
        Then 'Lapsed/Non'
      Else 'Never'
      End
    As af_giving_segment
  -- Stewardship flags
  , shc.ksm_stewardship_issue
  -- Anonymous flags
  , shc.anonymous_donor
  , Case When anonymous_cfy > 0 Then 'Y' End As anonymous_cfy_flag
  , Case When anonymous_pfy1 > 0 Then 'Y' End As anonymous_pfy1_flag
  , Case When anonymous_pfy2 > 0 Then 'Y' End As anonymous_pfy2_flag
  , Case When anonymous_pfy3 > 0 Then 'Y' End As anonymous_pfy3_flag
  , Case When anonymous_pfy4 > 0 Then 'Y' End As anonymous_pfy4_flag
  , Case When anonymous_pfy5 > 0 Then 'Y' End As anonymous_pfy5_flag
From trans
Cross Join params
Left Join table(ksm_pkg.tbl_special_handling_concat) shc
  On shc.id_number = trans.id_number
;

/*************************************************
KSM lifetime giving
Kept for historical purposes for past queries that reference v_ksm_giving_lifetime
*************************************************/
Create Or Replace View v_ksm_giving_lifetime As
-- Replacement lifetime giving view, based on giving summary to household lifetime giving amounts. Kept for historical purposes.
Select
  ksm.id_number
  , entity.report_name
  , ksm.ngc_lifetime As credit_amount
  , ksm.ngc_lifetime_full_rec As credit_amount_full_rec
From v_ksm_giving_summary ksm
Inner Join entity On entity.id_number = ksm.id_number
;

/*************************************************
Kellogg Transforming Together Campaign giving transactions
*************************************************/
Create Or Replace View v_ksm_giving_campaign_trans As
-- Campaign transactions
Select *
From table(ksm_pkg.tbl_gift_credit_campaign)
;

/*************************************************
Householded Kellogg campaign giving transactions
*************************************************/
Create Or Replace View v_ksm_giving_campaign_trans_hh As
-- Householded campaign transactions
Select *
From table(ksm_pkg.tbl_gift_credit_hh_campaign)
;

/*************************************************
Kellogg Campaign giving summaries
*************************************************/
Create or Replace View v_ksm_giving_campaign As
With
manual_dates As (
  Select to_date('20210630', 'yyyymmdd') As transforming_together_end_dt
  From DUAL
)
, hh As (
  Select *
  From table(ksm_pkg.tbl_entity_households_ksm)
)
, cgft As (
  Select *
  From v_ksm_giving_campaign_trans_hh
)
, legal As (
  Select id_number, sum(legal_amount) As campaign_legal_giving
  From cgft
  Group By id_number
)
-- Giving by allocation
, allocs As (
  Select
    household_id
    , allocation_code
    , alloc_short_name
    , sum(hh_credit) As alloc_giving
  From cgft
  Where tx_gypm_ind <> 'Y'
  Group By
    household_id
    , allocation_code
    , alloc_short_name
)
, top_allocs As (
  Select
    household_id
    , max(allocs.allocation_code) keep(dense_rank First Order By alloc_giving Desc, allocs.alloc_short_name Asc)
      As top_alloc_code
    , max(allocs.alloc_short_name) keep(dense_rank First Order By alloc_giving Desc, allocs.alloc_short_name Asc)
      As top_alloc
    , max(allocs.alloc_giving) keep(dense_rank First Order By alloc_giving Desc, allocs.alloc_short_name Asc)
      As top_alloc_amt
  From allocs
  Group By household_id
)
-- View implementing householded campaign giving based on new gifts & commitments
, trans As (
  Select Distinct
    hh.id_number
    , entity.report_name
    , hh.degrees_concat
    , cgft.household_id
    , hh.household_rpt_name
    , hh.person_or_org
    , hh.household_spouse_id
    , hh.household_spouse
    , hh.household_state
    , hh.household_country
    , hh.household_continent
    -- Legal giving is for the individual
    , legal.campaign_legal_giving
    -- All other giving is for the household
    , sum(cgft.hh_credit) As campaign_giving
    , sum(Case When cgft.anonymous In (Select Distinct anonymous_code From tms_anonymous) Then hh_credit Else 0 End) As campaign_anonymous
    , sum(Case When cgft.anonymous Not In (Select Distinct anonymous_code From tms_anonymous) Then hh_credit Else 0 End) As campaign_nonanonymous
    , sum(Case When cal.curr_fy = fiscal_year     Then hh_credit Else 0 End) As campaign_cfy
    , sum(Case When cal.curr_fy = fiscal_year + 1 Then hh_credit Else 0 End) As campaign_pfy1
    , sum(Case When cal.curr_fy = fiscal_year + 2 Then hh_credit Else 0 End) As campaign_pfy2
    , sum(Case When cal.curr_fy = fiscal_year + 3 Then hh_credit Else 0 End) As campaign_pfy3
    , sum(Case When fiscal_year < 2008 Then hh_credit Else 0 End) As campaign_reachbacks
    , sum(Case When fiscal_year = 2008 Then hh_credit Else 0 End) As campaign_fy08
    , sum(Case When fiscal_year = 2009 Then hh_credit Else 0 End) As campaign_fy09
    , sum(Case When fiscal_year = 2010 Then hh_credit Else 0 End) As campaign_fy10
    , sum(Case When fiscal_year = 2011 Then hh_credit Else 0 End) As campaign_fy11
    , sum(Case When fiscal_year = 2012 Then hh_credit Else 0 End) As campaign_fy12
    , sum(Case When fiscal_year = 2013 Then hh_credit Else 0 End) As campaign_fy13
    , sum(Case When fiscal_year = 2014 Then hh_credit Else 0 End) As campaign_fy14
    , sum(Case When fiscal_year = 2015 Then hh_credit Else 0 End) As campaign_fy15
    , sum(Case When fiscal_year = 2016 Then hh_credit Else 0 End) As campaign_fy16
    , sum(Case When fiscal_year = 2017 Then hh_credit Else 0 End) As campaign_fy17
    , sum(Case When fiscal_year = 2018 Then hh_credit Else 0 End) As campaign_fy18
    , sum(Case When fiscal_year = 2019 Then hh_credit Else 0 End) As campaign_fy19
    , sum(Case When fiscal_year = 2020 Then hh_credit Else 0 End) As campaign_fy20
    , sum(Case When fiscal_year = 2021 And date_of_record <= manual_dates.transforming_together_end_dt Then hh_credit Else 0 End) As campaign_fy21
    -- Recognition amounts for stewardship purposes; includes face value of bequests and life expectancy intentions
    , sum(cgft.hh_recognition_credit - cgft.hh_credit) As campaign_discounted_bequests
    , sum(cgft.hh_recognition_credit) As campaign_steward_giving
    , sum(Case When fiscal_year <= 2008 Then hh_recognition_credit Else 0 End) As campaign_steward_thru_fy08
    , sum(Case When fiscal_year <= 2009 Then hh_recognition_credit Else 0 End) As campaign_steward_thru_fy09
    , sum(Case When fiscal_year <= 2010 Then hh_recognition_credit Else 0 End) As campaign_steward_thru_fy10
    , sum(Case When fiscal_year <= 2011 Then hh_recognition_credit Else 0 End) As campaign_steward_thru_fy11
    , sum(Case When fiscal_year <= 2012 Then hh_recognition_credit Else 0 End) As campaign_steward_thru_fy12
    , sum(Case When fiscal_year <= 2013 Then hh_recognition_credit Else 0 End) As campaign_steward_thru_fy13
    , sum(Case When fiscal_year <= 2014 Then hh_recognition_credit Else 0 End) As campaign_steward_thru_fy14
    , sum(Case When fiscal_year <= 2015 Then hh_recognition_credit Else 0 End) As campaign_steward_thru_fy15
    , sum(Case When fiscal_year <= 2016 Then hh_recognition_credit Else 0 End) As campaign_steward_thru_fy16
    , sum(Case When fiscal_year <= 2017 Then hh_recognition_credit Else 0 End) As campaign_steward_thru_fy17
    , sum(Case When fiscal_year <= 2017 And cgft.anonymous In (Select Distinct anonymous_code From tms_anonymous) Then hh_recognition_credit Else 0 End)
      As anon_steward_thru_fy17
    , sum(Case When fiscal_year <= 2017 And cgft.anonymous Not In (Select Distinct anonymous_code From tms_anonymous) Then hh_recognition_credit Else 0 End)
      As nonanon_steward_thru_fy17
    , sum(Case When fiscal_year <= 2018 Then hh_recognition_credit Else 0 End)
      As campaign_steward_thru_fy18
    , sum(Case When fiscal_year <= 2018 And cgft.anonymous In (Select Distinct anonymous_code From tms_anonymous) Then hh_recognition_credit Else 0 End)
      As anon_steward_thru_fy18
    , sum(Case When fiscal_year <= 2018 And cgft.anonymous Not In (Select Distinct anonymous_code From tms_anonymous) Then hh_recognition_credit Else 0 End)
      As nonanon_steward_thru_fy18
    , sum(Case When fiscal_year <= 2019 Then hh_recognition_credit Else 0 End)
      As campaign_steward_thru_fy19
    , sum(Case When fiscal_year <= 2019 And cgft.anonymous In (Select Distinct anonymous_code From tms_anonymous) Then hh_recognition_credit Else 0 End)
      As anon_steward_thru_fy19
    , sum(Case When fiscal_year <= 2019 And cgft.anonymous Not In (Select Distinct anonymous_code From tms_anonymous) Then hh_recognition_credit Else 0 End)
      As nonanon_steward_thru_fy19
    , sum(Case When fiscal_year <= 2020 Then hh_recognition_credit Else 0 End)
      As campaign_steward_thru_fy20
    , sum(Case When fiscal_year <= 2020 And cgft.anonymous In (Select Distinct anonymous_code From tms_anonymous) Then hh_recognition_credit Else 0 End)
      As anon_steward_thru_fy20
    , sum(Case When fiscal_year <= 2020 And cgft.anonymous Not In (Select Distinct anonymous_code From tms_anonymous) Then hh_recognition_credit Else 0 End)
      As nonanon_steward_thru_fy20
    , sum(Case When fiscal_year <= 2021 And cgft.date_of_record <= manual_dates.transforming_together_end_dt Then hh_recognition_credit Else 0 End)
      As campaign_steward_thru_fy21
    , sum(Case When fiscal_year <= 2021 And cgft.date_of_record <= manual_dates.transforming_together_end_dt And cgft.anonymous In (Select Distinct anonymous_code From tms_anonymous) Then hh_recognition_credit Else 0 End)
      As anon_steward_thru_fy21
    , sum(Case When fiscal_year <= 2021 And cgft.date_of_record <= manual_dates.transforming_together_end_dt And cgft.anonymous Not In (Select Distinct anonymous_code From tms_anonymous) Then hh_recognition_credit Else 0 End)
      As nonanon_steward_thru_fy21
  From hh
  Cross Join v_current_calendar cal
  Cross Join manual_dates
  Inner Join cgft On cgft.household_id = hh.household_id
  Left Join legal On legal.id_number = hh.id_number
  Inner Join top_allocs On top_allocs.household_id = hh.household_id
  Inner Join entity On entity.id_number = hh.id_number
  Group By
    hh.id_number
    , entity.report_name
    , hh.degrees_concat
    , cgft.household_id
    , hh.household_rpt_name
    , hh.person_or_org
    , hh.household_spouse_id
    , hh.household_spouse
    , hh.household_state
    , hh.household_country
    , hh.household_continent
    , legal.campaign_legal_giving
)
-- Main query
Select
  trans.*
  -- Top allocations
  , top_alloc_code
  , top_alloc
  , top_alloc_amt
From trans
Inner Join top_allocs On top_allocs.household_id = trans.household_id
;

/*************************************************
Kellogg Campaign transactions with additional detail columns and a YTD indicator
*************************************************/
Create Or Replace View v_ksm_giving_campaign_ytd As
With
-- View implementing YTD KSM Campaign giving
-- Year-to-date calculator
cal As (
  Select 2007 As prev_fy, curr_fy As curr_fy, yesterday -- FY 2007 and 2020 as first and last campaign gift dates
  From v_current_calendar
)
, ytd_dts As (
  Select to_date('09/01/' || (cal.prev_fy - 1), 'mm/dd/yyyy') + rownum - 1 As dt,
    ksm_pkg.fytd_indicator(to_date('09/01/' || (cal.prev_fy - 1), 'mm/dd/yyyy') + rownum - 1) As ytd_ind
  From cal
  Connect By
    rownum <= (to_date('09/01/' || cal.curr_fy, 'mm/dd/yyyy') - to_date('09/01/' || (cal.prev_fy - 1), 'mm/dd/yyyy'))
)
-- Kellogg degrees
, deg As (
  Select id_number, degrees_concat
  From v_entity_ksm_degrees
)
-- Main query
Select
  gft.*
  , cal.curr_fy
  , ytd_dts.ytd_ind
  , entity.report_name
  , entity.institutional_suffix
  , deg.degrees_concat
  , prs.prospect_manager
  , allocation.short_name As allocation_name
  , Case
      When unsplit_amount >= 10E6 Then 10
      When unsplit_amount >= 5E6 Then 5
      When unsplit_amount >= 2E6 Then 2
      When unsplit_amount >= 1E6 Then 1
      When unsplit_amount >= 500E3 Then .5
      When unsplit_amount >= 250E3 Then .25
      When unsplit_amount >= 100E3 Then .1
      Else 0
    End As gift_bin
From v_ksm_giving_campaign_trans gft
Cross Join v_current_calendar cal
Inner Join ytd_dts On ytd_dts.dt = trunc(gft.date_of_record)
Inner Join entity On entity.id_number = gft.id_number
Inner Join allocation On allocation.allocation_code = gft.alloc_code
Left Join deg On deg.id_number = entity.id_number
Left Join nu_prs_trp_prospect prs On prs.id_number = entity.id_number
;

/*************************************************
Same as v_ksm_giving_campaign_ytd but includes gifts after the close of the campaign
*************************************************/
Create Or Replace View v_ksm_giving_post_campaign_ytd As
With
-- View implementing YTD KSM Campaign giving
-- Year-to-date calculator
cal As (
  Select
    -- FY 2007 and 2020 as first and last campaign gift dates
    2007 As prev_fy
    , curr_fy As curr_fy
    , yesterday
    , to_date('20210630', 'yyyymmdd') As campaign_end_dt
  From v_current_calendar
)
, ytd_dts As (
  Select to_date('09/01/' || (cal.prev_fy - 1), 'mm/dd/yyyy') + rownum - 1 As dt,
    ksm_pkg.fytd_indicator(to_date('09/01/' || (cal.prev_fy - 1), 'mm/dd/yyyy') + rownum - 1) As ytd_ind
  From cal
  Connect By
    rownum <= (to_date('09/01/' || cal.curr_fy, 'mm/dd/yyyy') - to_date('09/01/' || (cal.prev_fy - 1), 'mm/dd/yyyy'))
)
-- Kellogg degrees
, deg As (
  Select id_number, degrees_concat
  From v_entity_ksm_degrees
)
-- Unsplit amount - from ksm_pkg
, unsplit As (
  Select
    gt.tx_number
    , sum(legal_amount)
      As unsplit_amount
  From v_ksm_giving_trans gt
  Cross Join cal
  Where gt.date_of_record > campaign_end_dt
  Group By gt.tx_number
)
-- Union
, gift_union As (
  Select
    cgft.*
  From v_ksm_giving_campaign_trans cgft
  Union
  Select
    gt.id_number
    , entity.record_type_code
    , entity.person_or_org
    , entity.birth_dt
    , gt.tx_number
    , gt.tx_sequence
    , gt.anonymous
    , gt.legal_amount
    , gt.credit_amount
    , unsplit.unsplit_amount
    , to_char(gt.fiscal_year)
    , gt.date_of_record
    , gt.allocation_code
    , allocation.alloc_school
    , allocation.alloc_purpose
    , allocation.annual_sw
    , allocation.restrict_code
    , gt.transaction_type_code
    , gt.transaction_type
    , gt.pledge_status
    , gt.tx_gypm_ind
    , 'CHECK' As matched_donor_id
    , gt.matched_tx_number
    , NULL
    , NULL
    , 'KM'
    , NULL
  From v_ksm_giving_trans gt
  Cross Join cal
  Inner Join entity
    On entity.id_number = gt.id_number
  Inner Join allocation
    On allocation.allocation_code = gt.allocation_code
  Left Join unsplit
    On unsplit.tx_number = gt.tx_number
  Where gt.date_of_record > campaign_end_dt
    And gt.tx_gypm_ind <> 'Y'
)
-- Main query
Select
  gft.*
  , cal.curr_fy
  , ytd_dts.ytd_ind
  , entity.report_name
  , entity.institutional_suffix
  , deg.degrees_concat
  , prs.prospect_manager
  , allocation.short_name As allocation_name
  , Case
      When unsplit_amount >= 10E6 Then 10
      When unsplit_amount >= 5E6 Then 5
      When unsplit_amount >= 2E6 Then 2
      When unsplit_amount >= 1E6 Then 1
      When unsplit_amount >= 500E3 Then .5
      When unsplit_amount >= 250E3 Then .25
      When unsplit_amount >= 100E3 Then .1
      Else 0
    End As gift_bin
From gift_union gft
Cross Join v_current_calendar cal
Inner Join ytd_dts On ytd_dts.dt = trunc(gft.date_of_record)
Inner Join entity On entity.id_number = gft.id_number
Inner Join allocation On allocation.allocation_code = gft.alloc_code
Left Join deg On deg.id_number = entity.id_number
Left Join nu_prs_trp_prospect prs On prs.id_number = entity.id_number
;
