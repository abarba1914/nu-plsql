Create Or Replace View vt_ksm_giving_dei As

Select *
From v_ksm_giving_trans gt
Where gt.allocation_code
In (
  '3203005797501GFT' -- KSM DEI Scholarship Fund
  ,'4104005655401END'
  ,'3203004290301GFT'
  ,'3203005797501GFT'
  ,'3203002858501GFT'
  ,'4104005824501END'
  ,'3203005848101GFT'
  ,'4104005859001END'
  ,'3203005856201GFT'
  ,'6506005776801GFT'
  ,'6509000000901GFT'
  ,'3203000970801GFT'
  ,'4104006012801END'
  ,'3203005795201GFT'
  ,'3203004707901GFT'
  ,'3203004600201GFT'
  ,'3203004993001GFT'
  ,'4104000458301END'
  ,'6506004996701GFT'
  ,'6506004769701GFT'
  ,'6506005013601GFT'
  ,'3203006030801GFT'
  ,'3203005973601GFT'
  ,'3303000891601GFT'
)
Order By date_of_record Desc
;
