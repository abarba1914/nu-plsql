Create Or Replace View v_ksm_prospect_pool As

With
/* View pulling the KSM prospect pool */

-- Kellogg alumni
ksm_deg As (
  Select *
  From rpt_pbh634.v_entity_ksm_degrees
  Where record_status_code Not In ('D', 'X') -- Exclude deceased, purgable
)

-- Kellogg prospect interest
, ksm_prs As (
  Select prospect.prospect_id, prs_e.id_number
  From program_prospect prs
  Inner Join prospect_entity prs_e On prs_e.prospect_id = prs.prospect_id
  Inner Join prospect On prs.prospect_id = prospect.prospect_id
  Inner Join entity on entity.id_number = prs_e.id_number
  Where prs.program_code = 'KM'
    -- Active only
    And prs.active_ind = 'Y'
    And prospect.active_ind = 'Y'
    -- Exclude deceased, purgable
    And entity.record_status_code Not In ('D', 'X')
    -- Exclude Disqualified, Permanent Stewardship
    And prs.stage_code Not In (7, 11)
    And prospect.stage_code Not In (7, 11)
)

-- Previously disqualified prospects; note that this will include people with multiple prospect records
, dq As (
  (
  -- Overall disqualified
  Select prospect.prospect_id, id_number, tms_stage.short_desc As dq
  From prospect
  Inner Join prospect_entity On prospect_entity.prospect_id = prospect.prospect_id
  Left Join tms_stage On tms_stage.stage_code = prospect.stage_code
  Where prospect.stage_code = 7
  ) Union (
  -- Program disqualified
  Select pp.prospect_id, id_number, tms_stage.short_desc As dq
  From program_prospect pp
  Inner Join prospect_entity On prospect_entity.prospect_id = pp.prospect_id
  Left Join tms_stage On tms_stage.stage_code = pp.stage_code
  Where pp.stage_code = 7
    And pp.program_code = 'KM'
  )
)

-- Permanent stewardship prospects
, perm_stew As (
  (
  -- Overall disqualified
  Select prospect.prospect_id, id_number, tms_stage.short_desc As ps
  From prospect
  Inner Join prospect_entity On prospect_entity.prospect_id = prospect.prospect_id
  Left Join tms_stage On tms_stage.stage_code = prospect.stage_code
  Where prospect.stage_code = 11
  ) Union (
  -- Program disqualified
  Select pp.prospect_id, id_number, tms_stage.short_desc As ps
  From program_prospect pp
  Inner Join prospect_entity On prospect_entity.prospect_id = pp.prospect_id
  Left Join tms_stage On tms_stage.stage_code = pp.stage_code
  Where pp.stage_code = 11
    And pp.program_code = 'KM'
  )
)

-- Kellogg Top 150/300
, ksm_150_300 As (
  Select
    pc.prospect_id
    , pc.prospect_category_code
    , pe.id_number
    , pe.primary_ind
  From prospect_category pc
  Inner Join prospect_entity pe On pc.prospect_id = pe.prospect_id
  Where prospect_category_code In ('KT1', 'KT3')
)

-- All prospects with an active Kellogg program code
, ksm_prs_ids As (
  (
  -- KSM top 150/300
  Select id_number
  From ksm_150_300
  ) Union (
  -- KSM prospect program, not inactive or DQ
  Select id_number
  From ksm_prs
  -- All living alumni
  ) Union (
  Select id_number
  From ksm_deg
  Where record_status_code Not In ('D', 'X')
  ) Union (
  -- All living donors
  Select Distinct gft.id_number
  From v_ksm_giving_trans gft
  Inner Join entity On entity.id_number = gft.id_number
  Where entity.record_status_code Not In ('D', 'X')
  )
)

-- No Solicit special handling
, spec_hnd As (
  Select id_number, hnd_type_code As DNS
  From handling
  Where hnd_type_code = 'DNS'
    And hnd_status_code = 'A'
)

-- UOR
, uor As (
  Select prospect_id, evaluation_date As uor_date, evaluation.rating_code, tms_rating.short_desc As uor
  From evaluation
  Left Join tms_rating On tms_rating.rating_code = evaluation.rating_code
  Where evaluation_type = 'UR' And active_ind = 'Y' -- University overall rating
)

-- Prospect assignments
, assign As (
  Select Distinct assignment.prospect_id, office_code, assignment_id_number, entity.report_name
  From assignment
  Inner Join entity On entity.id_number = assignment.assignment_id_number
  Inner Join prospect_entity On prospect_entity.prospect_id = assignment.prospect_id
  Where active_ind = 'Y' -- Active assignments only
    And assignment_type In ('PP', 'PM', 'AF') -- Program Manager (PP), Prospect Manager (PM), Annual Fund Officer (AF)
)
, assign_conc As (
  Select prospect_id,
    Listagg(report_name, ';  ') Within Group (Order By report_name) As managers,
    Listagg(assignment_id_number, ';  ') Within Group (Order By report_name) As manager_ids
  From assign
  Group By prospect_id
)

-- Main query
Select
  hh.*
  , prs.business_title
  , trim(prs.employer_name1 || ' ' || prs.employer_name2) As employer_name
  , prs.pref_city
  , prs.pref_state
  , prs.preferred_country
  , prs.business_city
  , prs.business_state
  , prs.business_country
  , prs.prospect_id
  , dq.dq
  , perm_stew.ps As permanent_stewardship
  , spec_hnd.DNS
  , prs.evaluation_rating
  , prs.evaluation_date
  , prs.officer_rating
  , uor.uor
  , uor.uor_date
  , prs.prospect_manager_id
  , prs.prospect_manager
  , prs.team
  , prs.prospect_stage
  , prs.contact_date
  , contact_auth.report_name As contact_author
  , assign_conc.manager_ids
  , assign_conc.managers
  -- Primary prospect for 150/300, or primary household member for everyone else
  , Case
      When ksm_150_300.primary_ind = 'Y' Then 'Y'
      When ksm_150_300.primary_ind = 'N' Then NULL
      When household_id = hh.id_number Then 'Y'
    End As hh_primary
  -- Rating bin
  , Case
      When rpt_pbh634.ksm_pkg.get_prospect_rating_numeric(prs.id_number) >= 10 Then 10
      When rpt_pbh634.ksm_pkg.get_prospect_rating_numeric(prs.id_number) = 0.25 Then 0.1
      When rpt_pbh634.ksm_pkg.get_prospect_rating_numeric(prs.id_number) < 0.1 Then 0
      Else rpt_pbh634.ksm_pkg.get_prospect_rating_numeric(prs.id_number)
    End As rating_bin
  -- Which group?
  , Case
      -- Top 150
      When ksm_150_300.prospect_category_code = 'KT1'
        And ksm_150_300.primary_ind = 'Y'
        Then 'A. Top 150'
      -- Top 300
      When (ksm_150_300.prospect_category_code = 'KT3'
        And ksm_150_300.primary_ind = 'Y')
        Or hh.id_number In (
        '0000262384', '0000262342', '0000262641', '0000309661', '0000383490', '0000356080', '0000087483', '0000440361', '0000281461', '0000419826', '0000555969', '0000205372', '0000323562', '0000320277', '0000246175', '0000287623', '0000190057', '0000153690', '0000291445', '0000409118', '0000408741', '0000282526', '0000283155', '0000093413', '0000297118', '0000406374', '0000202258', '0000386687', '0000482949', '0000392688', '0000546812', '0000533143', '0000287825', '0000061634', '0000325625', '0000201735', '0000352160', '0000363393', '0000407823', '0000389798', '0000132942', '0000056555', '0000316118', '0000398754', '0000484466', '0000372425', '0000540846', '0000086050', '0000350637', '0000350521', '0000355339', '0000369609', '0000324648', '0000501221', '0000402387', '0000311491', '0000285959', '0000299770', '0000390561', '0000314076', '0000289900', '0000262699', '0000384080', '0000515243', '0000378568', '0000335194', '0000020198', '0000089815', '0000329877', '0000286552', '0000150109', '0000548102', '0000309198', '0000282597', '0000346515', '0000564801', '0000354099', '0000295014', '0000092251', '0000288198', '0000382467', '0000314914', '0000433145', '0000333870', '0000306592', '0000063744', '0000281860', '0000367691', '0000316799', '0000303065', '0000304834', '0000262280', '0000354142', '0000510155', '0000376197', '0000286721', '0000625758', '0000364489', '0000386920', '0000291993', '0000403400', '0000408757', '0000517334', '0000442396', '0000384117', '0000368066', '0000369371', '0000400288', '0000317804', '0000309845', '0000371204', '0000408214', '0000354647', '0000390860', '0000340311', '0000308514', '0000402368', '0000351590', '0000066984', '0000289822', '0000428610', '0000749966', '0000281390', '0000146394', '0000201916', '0000403350', '0000262533', '0000559678', '0000292866', '0000661442', '0000395764', '0000514993', '0000113252', '0000433433', '0000347019', '0000380318', '0000402487', '0000432865', '0000478895', '0000311080', '0000176335', '0000318569', '0000287810', '0000369534', '0000329901', '0000328056', '0000432722', '0000305569', '0000323127', '0000325249', '0000298052', '0000386794', '0000294333', '0000408442', '0000447413', '0000354526', '0000292096', '0000329866', '0000407095', '0000408869', '0000321100', '0000294213', '0000407218', '0000299292', '0000314948', '0000298039', '0000334172', '0000532068', '0000351844', '0000409607', '0000292783', '0000501059', '0000350572', '0000367948', '0000404672', '0000305660', '0000296157', '0000316634', '0000557249', '0000405614', '0000439150', '0000349748', '0000288114', '0000422911', '0000287820', '0000392356', '0000398822', '0000041365', '0000335663', '0000082462', '0000293441', '0000303104', '0000411534', '0000286771', '0000053063', '0000146321', '0000404773', '0000286313', '0000348235', '0000560001', '0000379180', '0000301248', '0000285502', '0000282930', '0000404079', '0000316200', '0000114714', '0000393346', '0000361598', '0000376294', '0000484043', '0000389355', '0000394692', '0000511832', '0000324353', '0000290286', '0000295806', '0000282897', '0000365756', '0000398314', '0000287818', '0000391672', '0000301492', '0000154268', '0000368150', '0000386715', '0000364732', '0000531987', '0000387701', '0000329187', '0000336293', '0000388102', '0000308749', '0000346843', '0000182558', '0000463114', '0000418893', '0000360659', '0000386362', '0000340281', '0000420346', '0000370775', '0000475869', '0000359704', '0000660682', '0000405286', '0000375820', '0000404675', '0000338604', '0000336938', '0000441226', '0000387278', '0000433860', '0000348614', '0000329501', '0000501954', '0000284425', '0000289181', '0000407732', '0000309166', '0000295345', '0000310584', '0000517504'
      ) Then 'B. Top 300'
      -- Assigned; exclude managed by Kellogg Donor Relations
      When manager_ids Is Not Null And prospect_manager_id Not In ('0000292130')
        Then 'C. Assigned'
      -- Leads
      When manager_ids Is Null -- Unmanaged
        And (officer_rating <> ' ' Or evaluation_rating <> ' ') -- Has a rating
        And officer_rating Not In ('G  $10K - $24K') -- Not officer disqualified
        And dq.dq Is Null -- Not previously disqualified
        And perm_stew.ps Is Null -- Not permanent stewardship
        And team <> 'Unresponsive' -- Not unresponsive
        Then 'D. Leads'
      -- Previously disqualified
      When dq.dq Is Not Null Then 'Q. Previously Disqualified'
      When perm_stew.ps Is Not Null Then 'S. Permanent Stewardship'
      -- Fallback
      Else 'Z. None'
    End As pool_group
From rpt_pbh634.v_entity_ksm_households hh
Inner Join ksm_prs_ids On ksm_prs_ids.id_number = hh.id_number -- Must be a valid Kellogg entity
Left Join nu_prs_trp_prospect prs On prs.id_number = hh.id_number
Left Join ksm_150_300 On ksm_150_300.id_number = hh.id_number
Left Join entity contact_auth On contact_auth.id_number = prs.contact_author
Left Join assign_conc On assign_conc.prospect_id = prs.prospect_id
Left Join dq On dq.id_number = hh.id_number
Left Join perm_stew On perm_stew.id_number = hh.id_number
Left Join spec_hnd On spec_hnd.id_number = hh.id_number
Left Join uor On uor.prospect_id = prs.prospect_id
