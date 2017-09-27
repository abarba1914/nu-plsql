-- Create Or Replace View v_ksm_campaign_2008_pyramid As

With

-- Campaign goals
goals As (
  Select NULL As giving_level, NULL As dollars, NULL as donors From DUAL Where Null Is Not Null -- Column labels
  Union All Select  10, 140000000, 10 From DUAL
  Union All Select   5,  80000000, 15 From DUAL
  Union All Select   2,  60000000, 20 From DUAL
  Union All Select   1,  60000000, 50 From DUAL
  Union All Select 0.5,  40000000, 50 From DUAL
  Union All Select 0.1,  60000000, 300 From DUAL
  Union All Select   0,  60000000, NULL From DUAL
),

-- Campaign fundraising progress
giving As (
  Select household_id,
    sum(amount) As amount,
    Case -- Giving levels
      When sum(amount) >= 10000000 Then 10
      When sum(amount) >=  5000000 Then 5
      When sum(amount) >=  2000000 Then 2
      When sum(amount) >=  1000000 Then 1
      When sum(amount) >=   500000 Then 0.5
      When sum(amount) >=   100000 Then 0.1
      Else 0
    End As giving_level
  From v_ksm_campaign_2008_gifts
  Group By household_id
),
gave As (
  Select giving_level, sum(amount) As dollars, count(household_id) As donors
  From giving
  Group By giving_level
)

-- Main query
(
  Select giving_level, dollars, donors, 'Campaign Booked' As src
  From gave
) Union All (
  Select giving_level, dollars, donors, 'Goal' As src
  From goals
) Union All (
  -- Remainder
  Select gave.giving_level, gave.dollars - goals.dollars, gave.donors - goals.donors, 'Remainder' As src
  From gave
  Inner Join goals On goals.giving_level = gave.giving_level
)
