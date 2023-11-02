With

hhf As (
  Select *
  From v_entity_ksm_households_fast
)

, attr_cash As (
  Select
    kgc.*
    -- All past managed grouped into Unmanaged
    , Case
        When substr(managed_hierarchy, 1, 9) = 'Unmanaged'
          Then 'Unmanaged'
        Else managed_hierarchy
        End
      As managed_grp
  From rpt_pbh634.v_ksm_giving_cash kgc
)

, grouped_cash As (
  Select
    attr_cash.cash_category
    , hhf.household_id
    , attr_cash.fiscal_year
    , attr_cash.managed_grp
    , sum(attr_cash.legal_amount)
      As sum_legal_amount
    , count(household_id) Over(Partition By cash_category, household_id, fiscal_year)
      As n_managed_in_group
  From attr_cash
  Inner Join hhf
    On hhf.id_number = attr_cash.id_number
  Group By
    attr_cash.cash_category
    , hhf.household_id
    , attr_cash.fiscal_year
    , attr_cash.managed_grp
)

, pivot_cash As (
  -- Pivot cash category/household/fiscal year by managed group, for later use with board dues
  Select *
  From (
    Select
      cash_category
      , household_id
      , fiscal_year
      , managed_grp
      , sum_legal_amount
    , n_managed_in_group
  From grouped_cash
  ) Pivot (
    sum(sum_legal_amount)
    For managed_grp In ('Unmanaged', 'MGO', 'LGO', 'KSM', 'NU')
  )
)

, cash_years As (
  Select Distinct fiscal_year
  From attr_cash
)

, boards_all As (
  Select
    committee.id_number
    , committee.committee_code
    , committee.committee_title
    , committee.committee_role_code
    , committee.committee_status_code
    , committee.start_dt
    , committee.stop_dt
    -- Start date is used, if present; else fill in Sep 1 for partial dates; else use date added
    , Case
        When rpt_pbh634.ksm_pkg_utility.to_date2(committee.start_dt) Is Not Null
          Then rpt_pbh634.ksm_pkg_utility.to_date2(committee.start_dt)
        When committee.start_dt <> '00000000'
          Then rpt_pbh634.ksm_pkg_utility.date_parse(committee.start_dt, fallback_dt => to_date('20200901', 'yyyymmdd'))
        Else trunc(date_added)
        End
      As start_dt_calc
    -- Stop date is used if present; else fill in Aug 31 for partial dates; else for past participation use date modified
    -- If committee status is current use a far future date (year 9999)
    , Case
        When rpt_pbh634.ksm_pkg_utility.to_date2(committee.stop_dt) Is Not Null
          Then rpt_pbh634.ksm_pkg_utility.to_date2(committee.stop_dt)
        When committee_status_code <> 'C' And stop_dt <> '00000000'
          Then rpt_pbh634.ksm_pkg_utility.date_parse(committee.stop_dt, fallback_dt => to_date('20200831', 'yyyymmdd'))
        When committee.committee_status_code <> 'C'
          Then trunc(date_modified)
        When committee.committee_status_code = 'C'
          Then to_date('99991231', 'yyyymmdd')
        End
      As stop_dt_calc
    , trunc(committee.date_added)
      As date_added
    , trunc(committee.date_modified)
      As date_modified
  From committee
  Where committee.committee_code In (
    'U' -- gab
    , 'KEBA' -- ebfa
    , 'KAMP' -- amp
    , 'KREAC' -- real estate
    , 'HAK' -- healthcare
    , 'KPETC' -- peac
    , 'KACNA' -- kac
    , 'KWLC' -- kwlc
  )
)

, boards_data As (
  Select
    boards_all.*
    , rpt_pbh634.ksm_pkg_calendar.get_fiscal_year(boards_all.start_dt_calc)
      As fy_start
    , rpt_pbh634.ksm_pkg_calendar.get_fiscal_year(boards_all.stop_dt_calc)
      As fy_stop
  From boards_all
  -- Include only board membership within the cash counting period
  Where rpt_pbh634.ksm_pkg_calendar.get_fiscal_year(boards_all.start_dt_calc) >= (Select min(fiscal_year) From cash_years)
    Or rpt_pbh634.ksm_pkg_calendar.get_fiscal_year(boards_all.stop_dt_calc) >= (Select min(fiscal_year) From cash_years)
)

, board_ids As (
  Select Distinct id_number
  From boards_data
)

, entity_boards As (
  -- Year-by-year board membership; one year + id_number per row
  Select
    cash_years.fiscal_year
    , entity.id_number
    , entity.report_name
    , entity.institutional_suffix
    , Case When gab.id_number Is Not Null Then 'Y' End
      As gab
    , Case When ebfa.id_number Is Not Null Then 'Y' End
      As ebfa
    , Case When amp.id_number Is Not Null Then 'Y' End
      As amp
      , Case When re.id_number Is Not Null Then 'Y' End
      As re
      , Case When health.id_number Is Not Null Then 'Y' End
      As health
      , Case When peac.id_number Is Not Null Then 'Y' End
      As peac
      , Case When kac.id_number Is Not Null Then 'Y' End
      As kac
    , Case When kwlc.id_number Is Not Null Then 'Y' End
      As kwlc
  From board_ids
  Cross Join cash_years
  Inner Join entity
    On entity.id_number = board_ids.id_number
  Left Join boards_data gab
    On gab.id_number = entity.id_number
    And cash_years.fiscal_year Between gab.fy_start And gab.fy_stop
    And gab.committee_code = 'U'
  Left Join boards_data ebfa
    On ebfa.id_number = entity.id_number
    And cash_years.fiscal_year Between ebfa.fy_start And ebfa.fy_stop
    And ebfa.committee_code = 'KEBA'
  Left Join boards_data amp
    On amp.id_number = entity.id_number
    And cash_years.fiscal_year Between amp.fy_start And amp.fy_stop
    And amp.committee_code = 'KAMP'
  Left Join boards_data re
    On re.id_number = entity.id_number
    And cash_years.fiscal_year Between re.fy_start And re.fy_stop
    And re.committee_code = 'KREAC'
  Left Join boards_data health
    On health.id_number = entity.id_number
    And cash_years.fiscal_year Between health.fy_start And health.fy_stop
    And health.committee_code = 'HAK'
  Left Join boards_data peac
    On peac.id_number = entity.id_number
    And cash_years.fiscal_year Between peac.fy_start And peac.fy_stop
    And peac.committee_code = 'KPETC'
  Left Join boards_data kac
    On kac.id_number = entity.id_number
    And cash_years.fiscal_year Between kac.fy_start And kac.fy_stop
    And kac.committee_code = 'KACNA'
  Left Join boards_data kwlc
    On kwlc.id_number = entity.id_number
    And cash_years.fiscal_year Between kwlc.fy_start And kwlc.fy_stop
    And kwlc.committee_code = 'KWLC'
  Order By
    entity.report_name Asc
    , cash_years.fiscal_year Asc
)

, boards As (
  Select
    fiscal_year
    , id_number
    , gab
    , ebfa
    , amp
    , re
    , health
    , peac
    , kac
    , kwlc
    -- Sun board dues per person based on memberships that year
    , Case When gab Is Not Null Then ksm_pkg_committee.get_numeric_constant('dues_gab') Else 0 End
      + Case When ebfa Is Not Null Then ksm_pkg_committee.get_numeric_constant('dues_ebfa') Else 0 End
      + Case When amp Is Not Null Then ksm_pkg_committee.get_numeric_constant('dues_amp') Else 0 End
      + Case When re Is Not Null Then ksm_pkg_committee.get_numeric_constant('dues_realestate') Else 0 End
      + Case When health Is Not Null Then ksm_pkg_committee.get_numeric_constant('dues_healthcare') Else 0 End
      + Case When peac Is Not Null Then ksm_pkg_committee.get_numeric_constant('dues_privateequity') Else 0 End
      + Case When kac Is Not Null Then ksm_pkg_committee.get_numeric_constant('dues_kac') Else 0 End
      + Case When kwlc Is Not Null Then ksm_pkg_committee.get_numeric_constant('dues_womensleadership') Else 0 End
      As total_dues
  From entity_boards
  Where gab Is Not Null
    Or ebfa Is Not Null
    Or amp Is Not Null
    Or re Is Not Null
    Or health Is Not Null
    Or peac Is Not Null
    Or kac Is Not Null
    Or kwlc Is Not Null
)

, boards_hh As (
  Select
    hhf.household_id
    , boards.fiscal_year
    , sum(boards.total_dues)
      As total_dues_hh
    , count(boards.gab) As gab
    , count(boards.ebfa) As ebfa
    , count(boards.amp) As amp
    , count(boards.re) As re
    , count(boards.health) As health
    , count(boards.peac) As peac
    , count(boards.kac) As kac
    , count(boards.kwlc) As kwlc
  From boards
  Inner Join hhf
    On hhf.id_number = boards.id_number
  Group By
    hhf.household_id
    , boards.fiscal_year
  Order By
    hhf.household_id Asc
    , boards.fiscal_year Asc
)

, merged_data As (
  Select
    gc.cash_category
    , gc.household_id
    , gc.fiscal_year
    , gc.n_managed_in_group
    , boards_hh.gab
    , boards_hh.ebfa
    , boards_hh.amp
    , boards_hh.re
    , boards_hh.health
    , boards_hh.peac
    , boards_hh.kac
    , boards_hh.kwlc
    -- Board dues should come out of Expendable funds
    , Case
        When gc.cash_category = 'Expendable'
          Then boards_hh.total_dues_hh
        End
      As total_dues_hh
    -- Board dues: first take from unmanaged, then KSM, then NU, then MGO, then LGO
    -- For expendable, board_amt is at least sum_legal_amount up to total_dues_hh
    , Case
        When cash_category = 'Expendable'
          And total_dues_hh Is Not Null
          Then
        -- Check if Unmanaged >= total_dues_hh
        Case
          When nvl("'Unmanaged'", 0) >= boards_hh.total_dues_hh
            Then 'U'
        -- Check if Unmanaged + KSM >= total_dues_hh
          When nvl("'Unmanaged'", 0) + nvl("'KSM'", 0) >= boards_hh.total_dues_hh
            Then 'UK'
        -- Check if Unmanaged + KSM + NU >= total_dues_hh
          When nvl("'Unmanaged'", 0) + nvl("'KSM'", 0) + nvl("'NU'", 0) >= boards_hh.total_dues_hh
            Then 'UKN'
        -- Check if Unmanaged + KSM + NU + MGO >= total_dues_hh
          When nvl("'Unmanaged'", 0) + nvl("'KSM'", 0) + nvl("'NU'", 0) + nvl("'MGO'", 0) >= boards_hh.total_dues_hh
            Then 'UKNM'
        -- Fallback: take from everything
          Else 'UKNML'
          End
        End
      As boards_cash_source
    , nvl(gc."'Unmanaged'", 0)
      As U
    , nvl(gc."'MGO'", 0)
      As M
    , nvl(gc."'LGO'", 0)
      As L
    , nvl(gc."'KSM'", 0)
      As K
    , nvl(gc."'NU'", 0)
      As N
  From pivot_cash gc
  Left Join boards_hh
    On boards_hh.household_id = gc.household_id
    And boards_hh.fiscal_year = gc.fiscal_year
)

, prefinal_data As (
  Select
    merged_data.cash_category
    , merged_data.household_id
    , merged_data.fiscal_year
    , merged_data.n_managed_in_group
    , merged_data.gab
    , merged_data.ebfa
    , merged_data.amp
    , merged_data.re
    , merged_data.health
    , merged_data.peac
    , merged_data.kac
    , merged_data.kwlc
    , merged_data.total_dues_hh
    , merged_data.boards_cash_source
    , U
    , K
    , N
    , M
    , L
    -- Compute board dues based on the boards_cash_source string
    -- Use least() function to ensure amount is at most total_dues_hh
    , Case
        When boards_cash_source = 'U'
          Then nullif(least(U, total_dues_hh), 0)
        When boards_cash_source = 'UK'
          Then nullif(least(U + K, total_dues_hh), 0)
        When boards_cash_source = 'UKN'
          Then nullif(least(U + K + N, total_dues_hh), 0)            
        When boards_cash_source = 'UKNM'
          Then nullif(least(U + K + N + M, total_dues_hh), 0)
        When boards_cash_source = 'UKNML'
          Then nullif(least(U + K + N + M + L, total_dues_hh), 0)
        End
      As "Boards"
    -- Zero (null) out the corresponding column if boards_cash_source found that amount is needed for dues
    -- Use greatest() function to ensure remaining amount is at least 0
    , Case
        When boards_cash_source = 'U'
          Then nullif(greatest(U - total_dues_hh, 0), 0)
        When regexp_like(boards_cash_source, 'K|N|M|L')
          Then Null
        Else nullif(U, 0)
        End
      As "Unmanaged"
    , Case
        When boards_cash_source Like '%K'
          Then nullif(greatest(U + K - total_dues_hh, 0), 0)
        When regexp_like(boards_cash_source, 'N|M|L')
          Then Null
        Else nullif(K, 0)
        End
      As "KSM"
    , Case
        When boards_cash_source Like '%N'
          Then nullif(greatest(U + K + N - total_dues_hh, 0), 0)
        When regexp_like(boards_cash_source, 'M|L')
          Then Null
        Else nullif(N, 0)
        End
      As "NU"
    , Case
        When boards_cash_source Like '%M'
          Then nullif(greatest(U + K + N + M - total_dues_hh, 0), 0)
        When regexp_like(boards_cash_source, 'L')
          Then Null
        Else nullif(M, 0)
        End
      As "MGO"
    , Case
        When boards_cash_source Like '%L'
          Then nullif(greatest(U + K + N + M + L - total_dues_hh, 0), 0)
        Else nullif(L, 0)
        End
      As "LGO"
  From merged_data
)

-- Unpivot final results
Select
  cash_category
  , household_id
  , fiscal_year
  , gab
  , ebfa
  , amp
  , re
  , health
  , peac
  , kac
  , kwlc
  , total_dues_hh
  , boards_cash_source
From prefinal_data
Unpivot (
  legal_amount
  For managed_grp In ("Boards", "Unmanaged", "KSM", "NU", "MGO", "LGO")
)
