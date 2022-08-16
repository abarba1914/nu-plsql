CREATE OR REPLACE VIEW V_KSM_23_REUNION AS

--- Creating a View for Reunion 2023
--- Note: 1st Milestones are 2022 and they have not been uploaded to CATs as Alumni

With manual_dates As (
Select
  2022 AS pfy
  ,2023 AS cfy
  From DUAL
),

HOUSE AS (SELECT *
FROM rpt_pbh634.v_entity_ksm_households H),

KSM_DEGREES AS (
 SELECT
   KD.ID_NUMBER
   ,KD.PROGRAM
   ,KD.PROGRAM_GROUP
   ,KD."CLASS_SECTION"
 FROM RPT_PBH634.V_ENTITY_KSM_DEGREES KD
 WHERE KD."PROGRAM" IN ('EMP', 'EMP-FL', 'EMP-IL', 'EMP-CAN', 'EMP-GER', 'EMP-HK', 'EMP-ISR', 'EMP-JAN', 'EMP-CHI', 'FT', 'FT-1Y', 'FT-2Y', 'FT-CB', 'FT-EB', 'FT-JDMBA', 'FT-MMGT', 'FT-MMM', 'TMP', 'TMP-SAT',
'TMP-SATXCEL', 'TMP-XCEL')
)

,KSM_REUNION AS (
SELECT
A.*
,GC.P_GEOCODE_Desc
,House.HOUSEHOLD_ID
FROM AFFILIATION A
CROSS JOIN manual_dates MD
Inner JOIN house ON House.ID_NUMBER = A.ID_NUMBER
LEFT JOIN RPT_DGZ654.V_GEO_CODE GC
  ON A.ID_NUMBER = GC.ID_NUMBER
    AND GC.ADDR_PREF_IND = 'Y'
     AND GC.GEO_STATUS_CODE = 'A'
WHERE TO_NUMBER(NVL(TRIM(A.CLASS_YEAR),'1')) IN (MD.CFY-1, MD.CFY-5, MD.CFY-10, MD.CFY-15, MD.CFY-20, MD.CFY-25, MD.CFY-30, MD.CFY-35, MD.CFY-40,
  MD.CFY-45, MD.CFY-50, MD.CFY-51, MD.CFY-52, MD.CFY-53, MD.CFY-54, MD.CFY-55, MD.CFY-56, MD.CFY-57, MD.CFY-58, MD.CFY-59, MD.CFY-60)
AND A.AFFIL_CODE = 'KM'
AND A.AFFIL_LEVEL_CODE = 'RG'
),

GIVING_SUMMARY AS (
Select Distinct house.household_id
    , sum(Case When tx_gypm_ind != 'P' And cal.curr_fy = fiscal_year     And cru_flag = 'Y' Then hh_credit Else 0 End) As cru_cfy
    , sum(Case When tx_gypm_ind != 'P' And cal.curr_fy = fiscal_year + 1 And cru_flag = 'Y' Then hh_credit Else 0 End) As cru_pfy1
    , sum(Case When tx_gypm_ind != 'P' And cal.curr_fy = fiscal_year + 2 And cru_flag = 'Y' Then hh_credit Else 0 End) As cru_pfy2
    , sum(Case When tx_gypm_ind != 'P' And cal.curr_fy = fiscal_year + 3 And cru_flag = 'Y' Then hh_credit Else 0 End) As cru_pfy3
    , sum(Case When tx_gypm_ind != 'P' And cal.curr_fy = fiscal_year + 4 And cru_flag = 'Y' Then hh_credit Else 0 End) As cru_pfy4
    , sum(Case When tx_gypm_ind != 'P' And cal.curr_fy = fiscal_year + 5 And cru_flag = 'Y' Then hh_credit Else 0 End) As cru_pfy5
From house
  Cross Join rpt_pbh634.v_current_calendar cal
  Inner Join rpt_pbh634.v_ksm_giving_trans_hh gfts
    On gfts.household_id = house.household_id
  Group By
house.household_id),

GIVING_TRANS AS
( SELECT HH.*
  FROM rpt_pbh634.v_ksm_giving_trans_hh HH
  INNER JOIN KSM_REUNION KR
  ON HH."ID_NUMBER" = KR.ID_NUMBER
),

KSM_GIVING_MOD as (select *
from v_ksm_reunion_giving_mod)

--- Spouse Reunion Year Only for 2023

,spouse_RY as (select house.SPOUSE_ID_NUMBER,
house.SPOUSE_PREF_MAIL_NAME,
       house.SPOUSE_SUFFIX,
       house.SPOUSE_DEGREES_CONCAT,
       house.SPOUSE_PROGRAM,
       house.SPOUSE_PROGRAM_GROUP,
       KSM_REUNION.CLASS_YEAR
from house
inner join KSM_REUNION ON KSM_REUNION.ID_number = house.SPOUSE_ID_NUMBER)

,REUNION_COMMITTEE AS (
 SELECT DISTINCT
    ID_NUMBER
 FROM COMMITTEE
 WHERE COMMITTEE_CODE = '227' AND COMMITTEE_STATUS_CODE = 'C'
)

--- Edits: 5/20/2022
--- Edit Finding Reunion 2018

,REUNION_18_COMMITTEE AS (
  SELECT DISTINCT
   ID_NUMBER
  FROM COMMITTEE
  WHERE COMMITTEE_CODE = '227' AND COMMITTEE_STATUS_CODE = 'F'
  AND START_DT = '20170901'
)

,PAST_REUNION_COMMITTEE AS (SELECT DISTINCT
   ID_NUMBER
  FROM COMMITTEE
  WHERE COMMITTEE_CODE = '227' AND COMMITTEE_STATUS_CODE = 'F')


/*,CURRENT_DONOR AS (
 SELECT
   ID_NUMBER
 FROM RPT_ABM1914.T_CYD_REUNION
)*/

,CURRENT_DONOR AS (
  SELECT DISTINCT HH.ID_NUMBER
FROM GIVING_TRANS HH
WHERE HH.FISCAL_YEAR = '2022'
 AND HH.TX_GYPM_IND NOT IN ('P', 'M')
)

,ANON_DONOR AS (
SELECT
 ID_NUMBER
 ,ANONYMOUS_DONOR
From table(rpt_pbh634.ksm_pkg_tmp.tbl_special_handling_concat)
WHERE ANONYMOUS_DONOR = 'Y'
)

,KSM_STAFF AS (
  SELECT * FROM table(rpt_pbh634.ksm_pkg_tmp.tbl_frontline_ksm_staff) staff -- Historical Kellogg gift officers
  -- Join credited visit ID to staff ID number
 )

--- Edit: 5/20/22
--- Edit: Reunion 2018 Registrations and Participants
--- Removing non relevent Reunion Years for 2023

,REUNION_2018_PARTICIPANTS AS (
Select ep_participant.id_number,
ep_event.event_id
From ep_event
Left Join EP_Participant
ON ep_participant.event_id = ep_event.event_id
where ep_event.event_id = '21792'
)


,REUNION_2018_REGISTRANTS AS (
select EP_REGISTRATION.CONTACT_ID_NUMBER,
EP_REGISTRATION.EVENT_ID,
TMS_EVENT_REGISTRATION_STATUS.short_desc,
EP_REGISTRATION.RESPONSE_DATE
from EP_REGISTRATION
left join TMS_EVENT_REGISTRATION_STATUS ON TMS_EVENT_REGISTRATION_STATUS.registration_status_code = EP_REGISTRATION.REGISTRATION_STATUS_CODE
where EP_REGISTRATION.EVENT_ID = '21792')

,KSM_ENGAGEMENT AS (--- Subquery to add into the 2021 Reunion Report. This will help user identify an alum's most recent attendance. 

Select DISTINCT event.id_number,
       max (start_dt_calc) keep (dense_rank First Order By start_dt_calc DESC) As Date_Recent_Event,
       max (event.event_id) keep (dense_rank First Order By start_dt_calc DESC) As Recent_Event_ID,
       max (event.event_name) keep(dense_rank First Order By start_dt_calc DESC) As Recent_Event_Name
from rpt_pbh634.v_nu_event_participants event
where event.ksm_event = 'Y'
and event.degrees_concat is not null
Group BY event.id_number
Order By Date_Recent_Event ASC)

,KSM_CLUB_LEADERS AS (Select DISTINCT
committee.id_number,
Listagg (committee_Header.short_desc, ';  ') Within Group (Order By committee_Header.short_desc) As Club_Titles,
Listagg (tms_committee_role.short_desc, ';  ') Within Group (Order By tms_committee_role.short_desc) As Leadership_Titles
From committee
Left Join committee_header
ON committee_header.committee_code = committee.committee_code
Inner Join tms_committee_role
ON tms_committee_role.committee_role_code = committee.committee_role_code
Where
 (committee.committee_role_code = 'CL'
    OR  committee.committee_role_code = 'P'
    OR  committee.committee_role_code = 'I'
    OR  committee.committee_role_code = 'DIR'
    OR  committee.committee_role_code = 'S'
    OR  committee.committee_role_code = 'PE'
    OR  committee.committee_role_code = 'T'
    OR  committee.committee_role_code = 'E')
   AND  (committee.committee_status_code = 'C'
   And committee.committee_code != 'KACLE'
   And committee.Committee_Code != '535'
   And committee.committee_code != 'KCGC'
   And committee.committee_code != 'KWLC'
   And committee_header.short_desc != 'KSM Global Advisory Board')
   AND (committee_header.short_desc LIKE '%KSM%'
   Or committee_header.short_desc LIKE '%Kellogg%'
   Or committee_header.short_desc LIKE '%NU-%'
   Or committee_header.short_desc = 'NU Club of Switzerland')
Group By committee.id_number)

,BUSINESS_EMAIL AS (
  SELECT
    EM.ID_NUMBER
    ,MAX(EM.EMAIL_ADDRESS) AS EMAIL_ADDRESS
  FROM EMAIL EM
  WHERE EM.EMAIL_TYPE_CODE = 'Y'
  AND EM.EMAIL_STATUS_CODE = 'A'
  GROUP BY EM.ID_NUMBER
)

,PLG AS
(SELECT
   GT.ID_NUMBER
  ,count(distinct case when GT.TX_GYPM_IND = 'P'
         AND GT.PLEDGE_STATUS <> 'R'
         THEN GT.TX_NUMBER END) KSM_PLEDGES
  ,SUM(CASE WHEN GT.TX_GYPM_IND = 'P'
         AND GT.PLEDGE_STATUS <> 'R'
         THEN GT.CREDIT_AMOUNT END) KSM_PLG_TOT
   FROM GIVING_TRANS GT
GROUP BY GT.ID_NUMBER
)

,PLEDGE_ROWS AS
 (select ID,
                 max(decode(rw,1,dt)) last_plg_dt,
                 max(decode(rw,1,stat)) status1,
                 max(decode(rw,1,plg)) plg1,
                 max(decode(rw,1,amt)) pamt1,
                 max(decode(rw,1,acct)) pacct1,
                 max(decode(rw,1,bal)) bal1,
                 max(decode(rw,1,PLG_ACTIVE)) plgActive

          FROM
             (SELECT
                 ID
                 ,ROW_NUMBER() OVER(PARTITION BY ID ORDER BY DT DESC)RW
                 ,DT
                 ,PLG
                 ,AMT
                 ,ACCT
                 ,STAT
                 ,PLG_ACTIVE
                 ,case when (bal * prop) < 0 then 0
                          else round(bal * prop,2) end bal
                FROM


       (SELECT
                      HH.ID_NUMBER ID
                      ,HH.TX_NUMBER AS PLG
                      ,HH.TRANSACTION_TYPE
                      ,HH.TX_GYPM_IND
                      ,HH.ALLOC_SHORT_NAME AS ACCT
                      ,CASE WHEN HH."PLEDGE_STATUS" = 'A' THEN 'Y' END AS PLG_ACTIVE
                      ,PS.SHORT_DESC AS STAT
                      ,HH.DATE_OF_RECORD AS DT
                      ,HH.CREDIT_AMOUNT
                      ,PP.PRIM_PLEDGE_AMOUNT AS AMT
                      ,PP.PRIM_PLEDGE_ORIGINAL_AMOUNT
                      ,PP.PRIM_PLEDGE_AMOUNT_PAID
                      ,p.pledge_associated_credit_amt
                      ,pp.prim_pledge_amount
                      ,CASE WHEN p.pledge_associated_credit_amt > pp.prim_pledge_amount THEN 1
                         ELSE p.pledge_associated_credit_amt / pp.prim_pledge_amount END PROP
                      ,PP.PRIM_PLEDGE_AMOUNT - pp.prim_pledge_amount_paid as BAL
                   FROM GIVING_TRANS HH
                   LEFT JOIN TMS_PLEDGE_STATUS PS
                   ON HH."PLEDGE_STATUS" = PS.pledge_status_code
                   INNER JOIN PLEDGE P
                   ON HH."ID_NUMBER" = P.PLEDGE_DONOR_ID
                       AND HH."TX_NUMBER" = P.PLEDGE_PLEDGE_NUMBER
                   LEFT JOIN PRIMARY_PLEDGE PP
                   ON P.PLEDGE_PLEDGE_NUMBER = PP.PRIM_PLEDGE_NUMBER
                   WHERE pp.prim_pledge_amount > 0
                   ))
             GROUP BY ID
)

,MYDATA AS (
         SELECT
           ID_NUMBER
           ,CREDIT_AMOUNT amt
           ,TX_GYPM_IND
           ,DATE_OF_RECORD dt
           ,TX_NUMBER rcpt
           ,MATCHED_TX_NUMBER m_rcpt
           ,ALLOC_SHORT_NAME acct
           ,AF_FLAG AF
           ,FISCAL_YEAR FY
          FROM GIVING_TRANS
          WHERE TX_GYPM_IND <> 'P'
)

,ROWDATA AS(
SELECT
           g.ID_NUMBER
           ,ROW_NUMBER() OVER(PARTITION BY g.ID_NUMBER ORDER BY g.dt DESC)RW
           ,g.amt
           ,m.amt match
           ,c.claim
           ,g.dt
           ,g.rcpt
           ,g.acct
           ,g.AF
           ,g.FY
           FROM (SELECT * FROM MYDATA WHERE TX_GYPM_IND <> 'M') g
           LEFT JOIN (SELECT * FROM MYDATA WHERE TX_GYPM_IND = 'M') m
                ON g.rcpt = m.m_rcpt AND g.ID_NUMBER = m.ID_NUMBER
           LEFT JOIN (SELECT
                KSMT.TX_NUMBER
                ,KSMT.ALLOCATION_CODE
                ,SUM(MC.CLAIM_AMOUNT) CLAIM
            FROM GIVING_TRANS KSMT
            INNER JOIN MATCHING_CLAIM MC
              ON KSMT."TX_NUMBER" = MC.CLAIM_GIFT_RECEIPT_NUMBER
              AND KSMT."TX_SEQUENCE" = MC.CLAIM_GIFT_SEQUENCE
              GROUP BY KSMT.TX_NUMBER, KSMT.ALLOCATION_CODE) C
              ON G.RCPT = C.TX_NUMBER
)

,GIFTINFO AS (
    SELECT
     ID_NUMBER
     ,max(decode(RW,1,rcpt))   rcpt1
     ,max(decode(RW,1,dt))       gdt1
     ,max(decode(RW,1,amt))     gamt1
     ,max(decode(RW,1,match))   match1
     ,max(decode(RW,1,claim)) claim1
     ,max(decode(RW,1,acct))   gacct1
     ,max(decode(RW,2,rcpt)) rcpt2
     ,max(decode(RW,2,dt)) gdt2
     ,max(decode(RW,2,amt))     gamt2
     ,max(decode(RW,2,match))   match2
     ,max(decode(RW,2,claim)) claim2
     ,max(decode(RW,2,acct))   gacct2
     ,max(decode(RW,3,rcpt)) rcpt3
     ,max(decode(RW,3,dt)) gdt3
     ,max(decode(RW,3,amt))     gamt3
     ,max(decode(RW,3,match))   match3
     ,max(decode(RW,3,claim)) claim3
     ,max(decode(RW,3,acct))   gacct3
     ,max(decode(RW,4,rcpt)) rcpt4
     ,max(decode(RW,4,dt)) gdt4
     ,max(decode(RW,4,amt))     gamt4
     ,max(decode(RW,4,match))   match4
     ,max(decode(RW,4,claim)) claim4
     ,max(decode(RW,4,acct))   gacct4
    FROM ROWDATA
    GROUP BY ID_NUMBER
)

,KSM_TOTAL AS (
 SELECT
  GT.ID_NUMBER
  ,SUM(GT.CREDIT_AMOUNT) AS KSM_TOTAL
 FROM GIVING_TRANS GT
 WHERE GT.TX_GYPM_IND NOT IN ('P','M')
 GROUP BY GT.ID_NUMBER
)

,KSM_AF_TOTAL AS (
  SELECT
    GT.ID_NUMBER
    ,SUM(GT.CREDIT_AMOUNT) AS KSM_AF_TOTAL
  FROM GIVING_TRANS GT
  WHERE GT.TX_GYPM_IND NOT IN ('P', 'M')
    AND (GT.AF_FLAG = 'Y' OR GT.CRU_FLAG = 'Y')
  GROUP BY GT.ID_NUMBER
)

,KSM_TOTAL23 AS (
  SELECT
  GT.ID_NUMBER
  ,SUM(GT.CREDIT_AMOUNT) AS KSM_TOTAL
 FROM GIVING_TRANS GT
 CROSS JOIN MANUAL_DATES MD
 WHERE GT.TX_GYPM_IND NOT IN ('P','M')
   AND GT.FISCAL_YEAR = MD.PFY
 GROUP BY GT.ID_NUMBER
)

,KSM_MATCH_23 AS (
   SELECT DISTINCT
     GT.ID_NUMBER
   FROM GIVING_TRANS GT
   CROSS JOIN MANUAL_DATES MD
   WHERE GT.TX_GYPM_IND = 'M'
     AND GT.MATCHED_FISCAL_YEAR = MD.PFY
 )

,PROPOSALS AS
(
SELECT
  ID_NUMBER
  ,WT0_PKG.GetProposal2(ID_NUMBER,NULL) PROPOSAL_STATUS
FROM KSM_REUNION
)

,AF_SCORES AS (
SELECT
 AF.ID_NUMBER
 ,AF.DESCRIPTION
 ,AF.SCORE
FROM RPT_PBH634.V_KSM_MODEL_AF_10K AF
INNER JOIN KSM_REUNION KR
ON AF.ID_NUMBER = KR.ID_NUMBEr
)

--- ADDING ADDTIONAL MODEL SCORES

,KSM_Model as (select DISTINCT mg.id_number,
       mg.id_score,
       mg.pr_code,
       mg.pr_segment,
       mg.pr_score
From rpt_pbh634.v_ksm_model_mg mg)

--- ADDING ACTIVITIES (SPEAKERS AND CORPORATE RECRUITERS) 

--- KSM_SPEAKERS

,KSM_SPEAKERS AS (
SELECT DISTINCT ACT.ID_NUMBER,
       TMS_ACTIVITY_TABLE.short_desc,
       ACT.ACTIVITY_CODE,
       ACT.ACTIVITY_PARTICIPATION_CODE
FROM  activity act
LEFT JOIN TMS_ACTIVITY_TABLE ON TMS_ACTIVITY_TABLE.activity_code = ACT.ACTIVITY_CODE
WHERE  act.activity_code = 'KSP'
AND ACT.ACTIVITY_PARTICIPATION_CODE = 'P')


--- KSM CORPORATE RECRUITERS 

,KSM_CORPORATE_RECRUITERS AS (
SELECT DISTINCT ACT.ID_NUMBER,
       TMS_ACTIVITY_TABLE.short_desc,
       ACT.ACTIVITY_CODE,
       ACT.ACTIVITY_PARTICIPATION_CODE
FROM  activity act
LEFT JOIN TMS_ACTIVITY_TABLE ON TMS_ACTIVITY_TABLE.activity_code = ACT.ACTIVITY_CODE
WHERE  act.activity_code = 'KCR'
AND ACT.ACTIVITY_PARTICIPATION_CODE = 'P'),

Preferred_address as (Select
         a.Id_number
      ,  a.addr_type_code
      ,  a.addr_pref_ind
      ,  a.street1
      ,  a.street2
      ,  a.street3
      ,  a.zipcode
      ,  a.city
      ,  a.state_code
      ,  a.country_code
      FROM address a
      WHERE a.addr_pref_IND = 'Y'),
      
s as (Select spec.ID_NUMBER,
       spec.EBFA,
       spec.NO_CONTACT
From rpt_pbh634.v_entity_special_handling spec),

assign as (select assign.id_number,
       assign.prospect_manager,
       assign.lgos,
       assign.managers,
       assign.curr_ksm_manager
from rpt_pbh634.v_assignment_summary assign),

--- Recent Contact Report

c as (select
id_number,
max (cr.credited) keep (dense_rank First Order By cr.contact_date DESC) as credited,
max (cr.credited_name) keep (dense_rank First Order By cr.contact_date DESC) as credited_name,
max (cr.contacted_name) keep (dense_rank First Order By cr.contact_date DESC) as contacted_name,
max (cr.contact_date) keep (dense_rank First Order By cr.contact_date DESC) as Max_Date,
max (cr.description) keep (dense_rank First Order By cr.contact_date DESC) as description_,
max (cr.summary) keep (dense_rank First Order By cr.contact_date DESC) as summary_
from rpt_pbh634.v_contact_reports_fast cr
group by cr.id_number)

--- Don't need the temp table .... Yet. Will create one when registration opens in Jan 2023. 

SELECT DISTINCT
   E.ID_NUMBER
  ,E.pref_mail_name
    ,WT0_PKG.GetMaidenLast(E.ID_NUMBER) MAIDEN_1
  ,SALUTATION_FIRST(E.ID_NUMBER,
                        DECODE(TRIM(E.PREF_MAIL_NAME),
                               NULL, ' ',
                               E.SPOUSE_ID_NUMBER)) FIRST_NAME_SAL
  ,WT0_PKG.GetDeansSal(E.ID_NUMBER, 'KM') DEANS_SALUTATION
  ,E.RECORD_STATUS_CODE
  ,E.GENDER_CODE
  ,KD."PROGRAM" AS DEGREE_PROGRAM
  ,KD."PROGRAM_GROUP"
  ,KR.CLASS_YEAR
  ,KD."CLASS_SECTION" AS COHORT
  ,HOUSE.SPOUSE_ID_NUMBER
  ,HOUSE.SPOUSE_PREF_MAIL_NAME
  ,HOUSE.SPOUSE_SUFFIX
  ,HOUSE.SPOUSE_FIRST_KSM_YEAR
  ,HOUSE.SPOUSE_PROGRAM
  ,HOUSE.SPOUSE_PROGRAM_GROUP
  ,CASE WHEN spouse_RY.SPOUSE_ID_NUMBER is not null then spouse_RY.CLASS_YEAR else '' End as Spouse_Reunion23_Classyr_IND
  ,CASE WHEN R18.CONTACT_ID_NUMBER IS NOT NULL THEN 'Y' END AS "REGISTERED_2018_REUNION"
  ,CASE WHEN RP18.ID_NUMBER IS NOT NULL THEN 'Y' END AS "ATTENDED_REUNION_2018"
  ,CASE WHEN RC18.ID_NUMBER IS NOT NULL THEN 'Y' ELSE '' END AS "REUNION_2018_COMMITTEE"
  ,CASE WHEN PRC.ID_NUMBER IS NOT NULL THEN 'Y'  ELSE ''END AS "ANY_PAST_REUNION_COMMITEE"
  ,KSM_SPEAKERS.SHORT_DESC AS ACTIVITY_KSM_SPEAKERS
  ,KSM_CORPORATE_RECRUITERS.SHORT_DESC AS KSM_CORPORATE_RECRUITERS
  ,KCL.CLUB_TITLES AS CLUB_LEADERSHIP_CLUB
  ,KCL.Leadership_Titles AS CLUB_LEADER
  ,FW.short_desc AS INDUSTRY
  ,EMPL.EMPLOYER_NAME1 AS EMPLOYER
  ,EMPL.JOB_TITLE AS BS_POSITION
  ,p.addr_pref_ind
  ,p.addr_type_code
  ,p.street1
  ,p.street2
  ,p.street3
  ,p.zipcode
  ,p.city
  ,p.state_code
  ,p.country_code
  ,KR.P_GEOCODE_DESC AS GEO_AREA 
  ,SH.NO_MAIL_SOL_IND AS NO_MAIL_SOLICIT
  ,HEM.EMAIL_ADDRESS AS HM_EMAIL
  ,BEM.EMAIL_ADDRESS AS BS_EMAIL
  ,CASE WHEN SH.SPECIAL_HANDLING_CONCAT LIKE '%No Email Solicitation%' THEN 'No Email Solicitation'
     WHEN SH.SPECIAL_HANDLING_CONCAT LIKE '%No Email%' THEN 'No Email'
     WHEN EM.EMAIL_ADDRESS IS NULL THEN ' '
     ELSE '(' || TEM.SHORT_DESC || ')' END AS EMAIL_USAGE_1
  ,SH.NO_EMAIL_IND AS NO_EMAIL
  ,SH.NO_EMAIL_SOL_IND AS NO_EMAIL_SOLICIT  
  ,WT0_PKG.GetPrefPhoneType(E.ID_NUMBER) PREF_PHONE_TYPE
  ,WT0_PKG.GetPrefPhoneInd(E.ID_NUMBER) PREF_PHONE_STATUS
  ,WT0_PKG.GetPrefPhone(E.ID_NUMBER) PREF_PHONE
  ,WT0_PKG.GetPhone(E.ID_NUMBER, 'B') BS_PHONE
  ,SH.NO_PHONE_SOL_IND AS NO_PHONE_SOLICIT
  ,SH.SPECIAL_HANDLING_CONCAT AS RESTRICTIONS
  ,S.NO_CONTACT
  ,CASE WHEN WT0_PKG.GetGAB(E.ID_NUMBER) = 'TRUE' THEN 'GAB'
       WHEN WT0_PKG.GetGAB(E.SPOUSE_ID_NUMBER) = 'TRUE' THEN 'Spouse GAB' ELSE ' ' END GAB
  ,CASE WHEN WT0_PKG.GetKAC(E.ID_NUMBER) = 'TRUE' THEN 'KAC'
     WHEN WT0_PKG.GetKAC(E.SPOUSE_ID_NUMBER) = 'TRUE' THEN 'Spouse KAC' ELSE ' ' END KAC
  ,CASE WHEN WT0_PKG.GetPeteHenderson(E.ID_NUMBER) = 'Y' THEN 'PHS'
     WHEN WT0_PKG.GetPeteHenderson(E.SPOUSE_ID_NUMBER) = 'Y' THEN 'Spouse PHS' ELSE ' ' END PHS
  ,CASE WHEN WT0_PKG.IsCurrentTrustee(E.ID_NUMBER) = 'TRUE' THEN 'Trustee'
     WHEN WT0_PKG.IsCurrentTrustee(E.SPOUSE_ID_NUMBER) = 'TRUE' THEN 'Spouse Trustee' ELSE ' ' END TRUSTEE 
  ,S.EBFA
  ,KSM_ENGAGEMENT.Date_Recent_Event
  ,KSM_ENGAGEMENT.Recent_Event_ID
  ,KSM_ENGAGEMENT.Recent_Event_Name
  ,CASE WHEN CYD.ID_NUMBER IS NOT NULL THEN 'Y' END AS "CYD"
  ,ANON.ANONYMOUS_DONOR
  ,assign.LGOS
  ,assign.Prospect_Manager
  ,GIVING_SUMMARY.CRU_CFY
  ,GIVING_SUMMARY.CRU_PFY1
  ,GIVING_SUMMARY.CRU_PFY2
  ,GIVING_SUMMARY.CRU_PFY3
  ,GIVING_SUMMARY.CRU_PFY4
  ,GIVING_SUMMARY.CRU_PFY5
  , case when GIVING_SUMMARY.CRU_PFY1 > 0
  or GIVING_SUMMARY.CRU_PFY2 > 0 
  or GIVING_SUMMARY.CRU_PFY3 > 0
  or GIVING_SUMMARY.CRU_PFY4 > 0
  or GIVING_SUMMARY.CRU_PFY5 > 0 then 'Giver_Last_5'
  Else '' END as Giver_Last_5_Years
  ,PR.last_plg_dt AS PLG_DATE
  ,PR.pacct1 AS PLG_ALLOC
  ,PR.pamt1 AS PLG_AMT
  ,PR.bal1 AS PLG_BALANCE
  ,PR.status1 AS PLG_STATUS
  ,PR.plgActive AS PLG_ACTIVE
  ,rpt_pbh634.ksm_pkg_tmp.get_fiscal_year(GI.GDT1) AS RECENT_FISAL_YEAR
  ,GI.GDT1 AS DATE1
  ,GI.GAMT1 AS AMOUNT1
  ,GI.GACCT1 AS ACC1
  ,GI.MATCH1 AS MATCH_AMOUNT1
  ,GI.CLAIM1 AS CLAIM_AMOUNT1
  ,GI.GDT2 AS DATE2
  ,GI.GAMT2 AS AMOUNT2
  ,GI.GACCT2 AS ACC2
  ,GI.MATCH2 AS MATCH_AMOUNT2
  ,GI.CLAIM2 AS CLAIM_AMOUNT2
  ,GI.GDT3 AS DATE3
  ,GI.GAMT3 AS AMOUNT3
  ,GI.GACCT3 AS ACC3
  ,GI.MATCH3 AS MATCH_AMOUNT3
  ,GI.CLAIM3 AS CLAIM_AMOUNT3
  ,GI.GDT4 AS DATE4
  ,GI.GAMT4 AS AMOUNT4
  ,GI.GACCT4 AS ACC4
  ,GI.MATCH4 AS MATCH_AMOUNT4
  ,GI.CLAIM4 AS CLAIM_AMOUNT4
  ,WT0_GIFTS2.HasAnonymousGift(E.ID_NUMBER, '1900', '2020') ANON_GIFT1
  ,WT0_GIFTS2.IsAnonymousDonor(E.ID_NUMBER) ANON_DONOR1
  ,WT0_GIFTS2.HasAnonymousGift(E.SPOUSE_ID_NUMBER, '1900', '2020') ANON_GIFT2
  ,WT0_GIFTS2.IsAnonymousDonor(E.SPOUSE_ID_NUMBER) ANON_DONOR2
  ,KSMT.KSM_TOTAL
  ,KAFT.KSM_AF_TOTAL
  ,KSM23.KSM_TOTAL AS KSM_TOTAL_2023
  ,CASE WHEN KM23.ID_NUMBER IS NOT NULL THEN 'Y' END AS MATCH_2023
  ,NP.OFFICER_RATING
  ,REPLACE(WT0_PKG.GetRecentRating(E.ID_NUMBER, 'PR'), ';;') RESEARCH_RATING
  --,WT0_PKG.Get_Prime_Geo_Area_From_Zip(PA.ZIPCODE) AS GEO_AREA
  ,WT0_PARSE(PROPOSAL_STATUS, 1,  '^') PROPOSAL_STATUS
  ,WT0_PARSE(PROPOSAL_STATUS, 2,  '^') PROPOSAL_START_DATE
  ,WT0_PARSE(PROPOSAL_STATUS, 3,  '^') PROPOSAL_ASK_AMT
  ,WT0_PARSE(PROPOSAL_STATUS, 4,  '^') ANTICIPATED_AMT
  ,WT0_PARSE(PROPOSAL_STATUS, 5,  '^') GRANTED_AMT
  ,WT0_PARSE(PROPOSAL_STATUS, 6,  '^') STOP_DATE
  ,WT0_PARSE(PROPOSAL_STATUS, 7,  '^') PROPOSAL_TITLE
  ,WT0_PARSE(PROPOSAL_STATUS, 8,  '^') PROPOSAL_DESCRIPTION
  ,WT0_PARSE(PROPOSAL_STATUS, 9,  '^') PROGRAM
  ,WT0_PARSE(PROPOSAL_STATUS, 10, '^') PROPOSAL_ID
  ,AFS.DESCRIPTION AS AF_10K_MODEL_TIER
  ,AFS.SCORE AS AF_10K_MODEL_SCORE
  ,KSM_MODEL.id_score
  ,KSM_MODEL.pr_segment
  ,KSM_MODEL.pr_score
  ,KGM.pledge_modified_cfy
  ,KGM.pledge_modified_pfy1
  ,KGM.pledge_modified_pfy2
  ,KGM.pledge_modified_pfy3
  ,KGM.pledge_modified_pfy4
  ,KGM.pledge_modified_pfy5
  ,KGM.modified_hh_credit_cfy
  ,KGM.modified_hh_gift_count_cfy
  ,KGM.modified_hh_gift_credit_pfy1
  ,KGM.modified_hh_gift_count_pfy1
  ,KGM.modified_hh_gift_credit_pfy2
  ,KGM.modified_hh_gift_count_pfy2
  ,KGM.modified_hh_gift_credit_pfy3
  ,KGM.modified_hh_gift_count_pfy3
  ,KGM.modified_hh_gift_credit_pfy4
  ,KGM.modified_hh_gift_count_pfy4
  ,KGM.modified_hh_gift_credit_pfy5
  ,KGM.modified_hh_gift_count_pfy5
  ,c.credited_name
  ,c.Contacted_name
  ,c.Max_Date
FROM ENTITY E
INNER JOIN KSM_REUNION KR
ON E.ID_NUMBER = KR.ID_NUMBER
INNER JOIN HOUSE
ON HOUSE.ID_NUMBER = E.ID_NUMBER
LEFT JOIN REUNION_COMMITTEE RC
ON E.ID_NUMBER = RC.ID_NUMBER
LEFT JOIN PAST_REUNION_COMMITTEE PRC
ON E.ID_NUMBER = PRC.ID_NUMBER
LEFT JOIN CURRENT_DONOR CYD
ON E.ID_NUMBER = CYD.ID_NUMBER
LEFT JOIN ANON_DONOR ANON
ON E.ID_NUMBER = ANON.ID_NUMBER
LEFT JOIN RPT_PBH634.V_ENTITY_KSM_DEGREES KD
ON E.ID_NUMBER = KD.ID_NUMBER
LEFT JOIN NU_PRS_TRP_PROSPECT NP
ON E.ID_NUMBER = NP.ID_NUMBER
LEFT JOIN table(rpt_pbh634.ksm_pkg_tmp.tbl_special_handling_concat) SH
ON E.ID_NUMBER = SH.ID_NUMBER
LEFT JOIN REUNION_2018_REGISTRANTS R18
ON E.ID_NUMBER = R18.Contact_ID_number
LEFT JOIN REUNION_2018_PARTICIPANTS RP18
ON E.ID_NUMBER = RP18.ID_NUMBER
LEFT JOIN KSM_CLUB_LEADERS KCL
ON E.ID_NUMBER = KCL.ID_NUMBER
LEFT JOIN EMAIL EM
ON E.ID_NUMBER = EM.ID_NUMBER
  AND EM.EMAIL_STATUS_CODE = 'A'
  AND EM.PREFERRED_IND = 'Y'
LEFT JOIN TMS_EMAIL_TYPE TEM
ON EM.EMAIL_TYPE_CODE = TEM.email_type_code
LEFT JOIN ADDRESS PA
ON E.ID_NUMBER = PA.ID_NUMBER
  AND PA.ADDR_STATUS_CODE = 'A'
  AND PA.ADDR_PREF_IND = 'Y'
LEFT JOIN TMS_COUNTRY PC
ON PA.COUNTRY_CODE = PC.COUNTRY_CODE
LEFT JOIN ADDRESS HA
ON E.ID_NUMBER = HA.ID_NUMBER
  AND HA.ADDR_STATUS_CODE = 'A'
  AND HA.ADDR_TYPE_CODE = 'H'
LEFT JOIN TMS_COUNTRY HC
ON HA.COUNTRY_CODE = HC.country_code
LEFT JOIN EMAIL HEM
ON E.ID_NUMBER = HEM.ID_NUMBER
 AND HEM.EMAIL_STATUS_CODE = 'A'
 AND HEM.EMAIL_TYPE_CODE = 'X'
 AND HEM.PREFERRED_IND = 'Y'
LEFT JOIN ADDRESS BA
ON E.ID_NUMBER = BA.ID_NUMBER
  AND BA.ADDR_STATUS_CODE = 'A'
  AND BA.ADDR_TYPE_CODE = 'B'
LEFT JOIN TMS_COUNTRY BC
ON BA.COUNTRY_CODE = BC.country_code
LEFT JOIN BUSINESS_EMAIL BEM
ON E.ID_NUMBER = BEM.ID_NUMBER
LEFT JOIN EMPLOYMENT EMPL
ON E.ID_NUMBER = EMPL.ID_NUMBER
  AND EMPL.JOB_STATUS_CODE = 'C'
  AND EMPL.PRIMARY_EMP_IND = 'Y'
LEFT JOIN TMS_FLD_OF_WORK FW
ON EMPL.FLD_OF_WORK_CODE = FW.fld_of_work_code
LEFT JOIN PLEDGE_ROWS PR
 ON E.ID_NUMBER = PR.ID
LEFT JOIN GIFTINFO GI
  ON E.ID_NUMBER = GI.ID_NUMBER
LEFT JOIN KSM_TOTAL KSMT
 ON E.ID_NUMBER = KSMT.ID_NUMBER
LEFT JOIN KSM_AF_TOTAL KAFT
  ON E.ID_NUMBER = KAFT.ID_NUMBER
LEFT JOIN KSM_TOTAL23 KSM23
  ON E.ID_NUMBER = KSM23.ID_NUMBER
LEFT JOIN KSM_MATCH_23 KM23
  ON E.ID_NUMBER = KM23.ID_NUMBER
LEFT JOIN NU_PRS_TRP_PROSPECT NP
  ON E.ID_NUMBER = NP.ID_NUMBER
LEFT JOIN PROPOSALS PROP
  ON E.ID_NUMBER = PROP.ID_NUMBER
LEFT JOIN AF_SCORES AFS
  ON E.ID_NUMBER = AFS.ID_NUMBER
LEFT JOIN KSM_MODEL
     ON KSM_MODEL.ID_NUMBER = E.ID_NUMBER
LEFT JOIN KSM_ENGAGEMENT
     ON KSM_ENGAGEMENT.ID_NUMBER = E.ID_NUMBER
LEFT JOIN KSM_SPEAKERS
     ON KSM_SPEAKERS.ID_NUMBER = E.ID_NUMBER
LEFT JOIN KSM_CORPORATE_RECRUITERS
     ON KSM_CORPORATE_RECRUITERS.ID_NUMBER = E.ID_NUMBER
LEFT JOIN GIVING_SUMMARY
     ON GIVING_SUMMARY.household_id = KR.HOUSEHOLD_ID
LEFT JOIN KSM_GIVING_MOD KGM
        ON KGM.household_id = KR.HOUSEHOLD_ID
LEFT JOIN REUNION_18_COMMITTEE RC18
 ON RC18.ID_NUMBER = E.ID_NUMBER
LEFT JOIN REUNION_2018_PARTICIPANTS RP18
 ON RP18.ID_NUMBER = E.ID_NUMBER
LEFT JOIN Preferred_address p 
 ON p.id_number = e.id_number
Left Join spouse_RY
on spouse_RY.SPOUSE_ID_NUMBER = hOUSE.SPOUSE_ID_NUMBER
LEFT JOIN S 
ON S.ID_NUMBER = E.ID_NUMBER
LEFT JOIN C 
ON C.ID_NUMBER = E.ID_NUMBER
LEFT JOIN assign
ON assign.id_number = E.ID_NUMBER
;
