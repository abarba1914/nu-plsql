---------------------------
-- ksm_pkg_allocation tests
---------------------------

Select *
From table(ksm_pkg_allocation.tbl_alloc_annual_fund_ksm)
;

Select *
From table(ksm_pkg_allocation.tbl_alloc_curr_use_ksm)
;

Select *
From table(ksm_pkg_allocation.tbl_threshold_allocs)
;

Select *
From table(ksm_pkg_allocation.tbl_cash_alloc_groups)
;

---------------------------
-- ksm_pkg tests
---------------------------

Select *
From table(ksm_pkg_tst.tbl_alloc_annual_fund_ksm)
;

Select *
From table(ksm_pkg_tst.tbl_alloc_curr_use_ksm)
;
