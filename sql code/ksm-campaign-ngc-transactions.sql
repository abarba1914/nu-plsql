/* See rpt_btaylor.nu_gft_t_ksm_dtl_curr for current counting method.
   That table is updated by rpt_btaylor.wt099031_extracttransactions.

Look into: receipt '0002275766' */

With

-- Transaction types table
tms_trans As (
  (
    Select transaction_type_code, short_desc
    From tms_transaction_type
  ) Union All (
    Select pledge_type_code, short_desc
    From tms_pledge_type
  ) Union All (
    Select ' ' As matching_gift_code, 'Matching Gift' As short_desc
    From dual
  )
)

(
-- Gift and matching gift results from nu_gft_trp_gifttrans
Select gft.id_number, gft.tx_number, gft.tx_gypm_ind, gft.transaction_type, tms_trans.short_desc,
  gft.date_of_record, gft.fiscal_year, gft.legal_amount, gft.pledge_status, gft.allocation_code,
  gft.alloc_short_name, gft.campaign_code
From nu_gft_trp_gifttrans gft
  Left Join tms_trans On tms_trans.transaction_type_code = gft.transaction_type
Where gft.alloc_school = 'KM'
  And (gft.fiscal_year >= 2008 Or gft.campaign_code = 'CCR')
  And gft.legal_amount > 0 -- Legal donors only
  And gft.tx_gypm_ind In ('G', 'M')

)/* Union All (
-- Bequest and LE results
Select plg.pledge_donor_id, plg.pledge_pledge_number, 'P' As gypm_ind, plg.pledge_pledge_type,
  tms_trans.short_desc, plg.pledge_date_of_record,
  Cast (ksm_pkg.get_fiscal_year(plg.pledge_date_of_record) As varchar(4)) As fiscal_year,
  pp.discounted_amt, pp.prim_pledge_status, plg.pledge_allocation_name, plg.pledge_program_code,
  plg.pledge_campaign
From pledge plg
  Inner Join primary_pledge pp On plg.pledge_pledge_number = pp.prim_pledge_number
  Left Join tms_trans On plg.pledge_pledge_type = tms_trans.transaction_type_code
Where plg.pledge_pledge_type In ('BE', 'LE')
  And plg.pledge_program_code = 'KM'
  And (ksm_pkg.get_fiscal_year(plg.pledge_date_of_record) >= 2008 Or plg.pledge_campaign = 'CCR')
  And plg.pledge_associated_code = 'P'
  And plg.pledge_amount > 0 -- Legal donors only
  And pp.discounted_amt > 0

) Union All (
-- Pledge results
Select plg.pledge_donor_id, plg.pledge_pledge_number, 'P' As gypm_ind, plg.pledge_pledge_type,
  tms_trans.short_desc, plg.pledge_date_of_record,
  Cast (ksm_pkg.get_fiscal_year(plg.pledge_date_of_record) As varchar(4)) As fiscal_year,
  -- Choose either amount paid or total amount
  Case
    When pp.prim_pledge_status != 'A' Then pp.prim_pledge_amount_paid
    Else pp.prim_pledge_amount
  End As pledge_amt,
  pp.prim_pledge_status, plg.pledge_allocation_name, plg.pledge_program_code, plg.pledge_campaign
From pledge plg
  Inner Join primary_pledge pp On plg.pledge_pledge_number = pp.prim_pledge_number
  Left Join tms_trans On plg.pledge_pledge_type = tms_trans.transaction_type_code
Where plg.pledge_pledge_type Not In ('BE', 'LE')
  And plg.pledge_program_code = 'KM'
  And (ksm_pkg.get_fiscal_year(plg.pledge_date_of_record) >= 2008 Or plg.pledge_campaign = 'CCR')
  And plg.pledge_associated_code = 'P'
  And plg.pledge_amount > 0 -- Legal donors only
)
*/
