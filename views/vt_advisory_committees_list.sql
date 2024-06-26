create or replace view rpt_pbh634.vt_advisory_committees_list as
With

members As (
  Select *
  From rpt_pbh634.v_advisory_committees_members
)

, all_committees As (
  Select *
  From members
)

-- NU yearly NGC giving amounts
, fy_nu_giving As (
  Select
    nugft.id_number
    , sum(Case When fiscal_year = cal.curr_fy - 0 Then nugft.credit_amount Else 0 End)
      As cfy_nult_giving
    , sum(Case When fiscal_year = cal.curr_fy - 1 Then nugft.credit_amount Else 0 End)
      As lfy_nult_giving
    , sum(Case When fiscal_year = cal.curr_fy - 2 Then nugft.credit_amount Else 0 End)
      As lfy2_nult_giving
  From nu_gft_trp_gifttrans nugft
  Cross Join rpt_pbh634.v_current_calendar cal
  Inner Join all_committees
    On all_committees.id_number = nugft.id_number
  Where tx_gypm_ind != 'Y' -- No pledge payments
    And fiscal_year Between cal.curr_fy - 2 And cal.curr_fy
  Group By nugft.id_number
)

, all_committees_giving As (
  Select
    all_committees.*
    , nvl(fy_nu_giving.cfy_nult_giving, 0) As cfy_nult_giving
    , nvl(fy_nu_giving.lfy_nult_giving, 0) As lfy_nult_giving
    , nvl(fy_nu_giving.lfy2_nult_giving, 0) As lfy2_nult_giving
    , nvl(KGS.ngc_lifetime_full_rec, 0) As ksm_lt_giving
    , nvl(v_ksm_giving_campaign.campaign_giving,0) As ksm_campaign_giving
    , nvl(KGS.af_cfy, 0) As af_cfy_sftcredit
    , nvl(KGS.af_pfy1, 0) As af_lyfy_sftcredit
    , nvl(KGS.af_pfy2, 0) As af_lyfy2_sftcredit
    , nvl(KGS.ngc_cfy, 0) As ksm_cfy_sftcredit
    , nvl(KGS.ngc_pfy1, 0) As ksm_lyfy_sftcredit
    , nvl(KGS.ngc_pfy2, 0) As ksm_lyfy2_sftcredit
    , nvl(v_ksm_giving_campaign.campaign_cfy, 0) As campaign_cfy
    , nvl(v_ksm_giving_campaign.campaign_pfy1, 0) As campaign_pfy1
    , nvl(v_ksm_giving_campaign.campaign_pfy2, 0) As campaign_pfy2
    , nvl(v_ksm_giving_campaign.campaign_pfy3, 0) As campaign_pfy3
    , nvl(KGS."CASH_PFY1",0)+nvl(KGS."CASH_PFY2",0)+nvl(KGS."CASH_PFY3",0)+nvl(KGS."CASH_PFY4",0)+nvl(KGS."CASH_PFY5",0) AS ksm_giving_5yrs
    , CASE WHEN KGS."AF_PFY1" >0 THEN 1 ELSE 0 END AS AF_PFY1
    , CASE WHEN KGS."AF_PFY2" >0 THEN 1 ELSE 0 END AS AF_PFY2
    , CASE WHEN KGS."AF_PFY3" >0 THEN 1 ELSE 0 END AS AF_PFY3
    , KGS.LAST_GIFT_DATE
    ,KGS.LAST_GIFT_RECOGNITION_CREDIT
    ,KGS.LAST_GIFT_ALLOC
  From all_committees
  Left Join rpt_pbh634.v_ksm_giving_summary KGS
    On KGS.id_number = all_committees.id_number
  Left Join fy_nu_giving
    On all_committees.id_number = fy_nu_giving.id_number
  Left Join rpt_pbh634.v_ksm_giving_campaign
    On all_committees.id_number = v_ksm_giving_campaign.id_number
)

,UNIVERSITY_GIFT AS (
 SELECT
   NTG.ID_NUMBER
   ,MIN(NTG.DATE_OF_RECORD) KEEP(DENSE_RANK FIRST ORDER BY NTG.DATE_OF_RECORD DESC) AS "Last University Gift Date"
   ,MIN(NTG.ALLOC_SHORT_NAME) KEEP(DENSE_RANK FIRST ORDER BY NTG.DATE_OF_RECORD DESC) AS "Last Gift Allocation"
 FROM nu_gft_trp_gifttrans NTG
 INNER JOIN all_committees ac
 ON NTG.ID_NUMBER = ac.ID_NUMBER
 WHERE NTG.TX_GYPM_IND NOT IN ('P', 'M')
   AND NTG.ALLOC_SCHOOL <> 'KM'
 GROUP BY NTG.ID_NUMBER
)

,FIRST_GIFT AS(
  SELECT
   GT.ID_NUMBER
   ,MIN(GT.DATE_OF_RECORD) AS FIRST_GIFT_DATE
  FROM RPT_PBH634.V_KSM_GIVING_TRANS GT
  INNER JOIN all_committees ac
  ON GT.ID_NUMBER = ac.ID_NUMBER
  WHERE GT.TX_GYPM_IND NOT IN ('P', 'M')
  GROUP BY GT.ID_NUMBER
)

,DEAN_VISITS AS (
  SELECT
   CRF.ID_NUMBER
   ,max(CRF.contact_date) keep(dense_rank First Order By CRF.contact_date Desc) AS "Contact Date with Dean"
   ,max(CRF.contact_type) keep(dense_rank FIRST ORDER BY CRF.CONTACT_DATE DESC) AS "Contact Type with Dean"
   ,max(CRF.description) keep(dense_rank First Order By CRF.contact_date Desc) AS "Dean Visit Description"
 FROM RPT_PBH634.V_CONTACT_REPORTS_FAST CRF
 INNER JOIN all_committees ac
 ON crf.id_number = ac.id_number
    WHERE CRF.credited = '0000804796'
  GROUP BY CRF.ID_NUMBER
)

-- KSM proposal data
, activeproposals As (
  Select
    phf.proposal_id
    , phf.prospect_id
    , Case
        When phf.total_original_ask_amt >= 100000
          Or phf.total_ask_amt >= 100000
          Or phf.total_anticipated_amt >= 100000
          Then 'Y'
        Else 'N'
        End
      As majorgift
  From rpt_pbh634.v_proposal_history_fast phf
  Where phf.ksm_proposal_ind = 'Y'
    And phf.proposal_active_calc = 'Active'
)

, proposalcount As (
  Select
    prospect_id
    , count(proposal_id) As proposalcount
  From activeproposals
  Where majorgift = 'Y'
  Group By prospect_id
)

, gab_meetings AS (
  SELECT 
    id_number
    ,COUNT(EVENT_ID) AS gab_meeting_count_3yrs   
  FROM rpt_pbh634.v_nu_event_participants_fast E
  CROSS JOIN RPT_PBH634.V_CURRENT_CALENDAR CAL
  WHERE ((EVENT_NAME LIKE '%Global Advisory Board%' AND EVENT_TYPE = 'Meeting')
    OR (EVENT_NAME LIKE '%Global Advisory Board%')
    OR (EVENT_NAME LIKE '%GAB%')
    OR (EVENT_NAME LIKE '%GAB%' AND EVENT_TYPE = 'Meeting'))
    AND E.START_FY_CALC BETWEEN CAL."CURR_FY"-3 AND CAL."CURR_FY"-1
  GROUP BY ID_NUMBER
)
-- Main query
Select DISTINCT
  prs.id_number
  , prs.pref_mail_name
  , e.first_name
  , e.last_name
  , v_entity_ksm_degrees.degrees_concat
  , CASE WHEN T.ID_NUMBER IS NOT NULL THEN 'Y' ELSE 'N' END AS TRUSTEE
  , CASE WHEN E.ETHNIC_CODE IN ('1', '2', '4', '9', '12') THEN 'Y' ELSE 'N' END AS URM 
  , CASE WHEN E.citizen_cntry_code1 = ' ' AND E.citizen_cntry_code2 = ' ' THEN 'N' 
       WHEN E.citizen_cntry_code1 = 'US' AND E.citizen_cntry_code2 = 'US' THEN 'N'
       WHEN E.citizen_cntry_code1 <> 'US' THEN 'Y'
       WHEN E.citizen_cntry_code1 = ' ' AND E.citizen_cntry_code2 <> 'US' THEN 'Y'
       WHEN E.citizen_cntry_code1 = 'US' AND E.citizen_cntry_code2 = ' ' THEN 'N'   
       WHEN E.citizen_cntry_code1 = 'US' AND E.citizen_cntry_code2 <> 'US' THEN 'Y' END AS CITIZENSHIP_OUTSIDE_US
  , CASE WHEN E.GENDER_CODE = 'F' THEN 'Y' ELSE 'N' END AS FEMALE
  , SH.SPECIAL_HANDLING_CONCAT
  , DV."Contact Date with Dean"
  , DV."Contact Type with Dean"
  , DV."Dean Visit Description"
  , HA.STREET1 AS HOME_STREET1
  , HA.STREET2 AS HOME_STREET2
  , HA.STREET3 AS HOME_STREET3
  , HA.CITY AS HOME_CITY
  , HA.STATE_CODE AS HOME_STATE
  , HA.ZIPCODE AS HOME_ZIPCODE
  , HTC.short_desc AS HOME_COUNTRY
  , prs.employer_name1
  , prs.business_title
  , BA.STREET1 AS BUSINESS_STREET1
  , BA.STREET2 AS BUSINESS_STREET2
  , BA.STREET3 AS BUSINESS_STREET3
  , BA.CITY AS BUSINESS_CITY
  , BA.STATE_CODE AS BUSINESS_STATE
  , BA.ZIPCODE AS BUSINESS_ZIPCODE
  , BTC.short_desc AS BUSINESS_COUNTRY
 /* , prs.pref_city
  , prs.pref_state
  , prs.pref_zip
  , prs.preferred_country*/
  , asum.lgos
  , prs.prospect_id
  , prs.prospect_manager
  , prs.prospect_stage
  , prs.evaluation_rating
  , prs.evaluation_date
  , prs.officer_rating
  , mg.pr_segment
  , mg.pr_score
  , acg.committee_code
  , ch.short_desc As committee_name
  , acg.committee_title
  , gm.gab_meeting_count_3yrs  
  , acg.start_dt
  , acg.stop_dt
  , acg.status
  , acg.role
  , nvl(prs.giving_total, 0) As nu_lt_giving
  , acg.cfy_nult_giving
  , acg.lfy_nult_giving
  , acg.lfy2_nult_giving
  , UG."Last University Gift Date"
  , UG."Last Gift Allocation"
  , acg.ksm_lt_giving
  , acg.ksm_campaign_giving
  , FG.FIRST_GIFT_DATE
  , acg.LAST_GIFT_DATE
  , acg.LAST_GIFT_RECOGNITION_CREDIT
  , acg.LAST_GIFT_ALLOC
  , nvl(proposalcount.proposalcount, 0) As proposal_count
  , acg.af_cfy_sftcredit
  , acg.af_lyfy_sftcredit
  , acg.af_lyfy2_sftcredit
  , acg.ksm_cfy_sftcredit
  , acg.ksm_lyfy_sftcredit
  , acg.ksm_lyfy2_sftcredit
  , acg.ksm_giving_5yrs
  , (acg.AF_PFY1+acg.AF_PFY2+acg.AF_PFY3)/3 AS AF_GIVING_PARTICIPATION_3yrs
  , acg.campaign_cfy
  , acg.campaign_pfy1
  , acg.campaign_pfy2
  , acg.campaign_pfy3
From all_committees_giving acg
Inner Join nu_prs_trp_prospect prs
  On prs.id_number = acg.id_number
LEFT JOIN RPT_PBH634.V_ASSIGNMENT_SUMMARY ASUM
ON ASUM.id_number = ACG.ID_NUMBER
LEFT JOIN RPT_PBH634.V_ENTITY_SPECIAL_HANDLING SH
ON acg.ID_NUMBER = SH.ID_NUMBER
LEFT JOIN ADDRESS HA
ON acg.ID_NUMBER  = HA.ID_NUMBER
  AND HA.ADDR_STATUS_CODE = 'A'
  AND HA.ADDR_TYPE_CODE = 'H'
LEFT JOIN TMS_COUNTRY HTC
ON HA.COUNTRY_CODE = HTC.country_code
LEFT JOIN ADDRESS BA
ON acg.ID_NUMBER  = BA.ID_NUMBER
  AND BA.ADDR_STATUS_CODE = 'A'
   AND BA.ADDR_TYPE_CODE = 'B'
LEFT JOIN TMS_COUNTRY BTC
ON HA.COUNTRY_CODE = BTC.country_code
LEFT JOIN DEAN_VISITS DV
ON acg.ID_NUMBER = DV.ID_NUMBER
LEFT JOIN UNIVERSITY_GIFT UG
ON acg.ID_NUMBER = UG.ID_NUMBER
LEFT JOIN FIRST_GIFT FG
ON acg.ID_NUMBER = FG.ID_NUMBER
Left Join committee_header ch
  On ch.committee_code = acg.committee_code
LEFT JOIN TABLE(RPT_PBH634.KSM_PKG_TMP.tbl_committee_trustee) T
ON T.ID_NUMBER = acg.id_number
LEFT JOIN ENTITY e
ON e.id_number = acg.id_number
LEFT JOIN gab_meetings gm
ON gm.id_number = acg.id_number
Left Join rpt_pbh634.v_entity_ksm_degrees
  On v_entity_ksm_degrees.id_number = acg.id_number
LEFT JOIN RPT_PBH634.V_KSM_MODEL_MG MG
ON mg.id_number = prs.id_number
Left Join proposalcount
  On proposalcount.prospect_id = prs.prospect_id
;
