CREATE OR REPLACE Function fytd_indicator(dt In date)
Return character Is
  output character;
  -- Declarations
  fy_start_mo constant number := 9; -- fiscal start month, 9 = September
  today_fisc_day number;
  today_fisc_mo number;
  dt_fisc_day number;
  dt_fisc_mo number;
Begin
  -- extract dt fiscal month and day
  today_fisc_day := extract(day from sysdate);
  today_fisc_mo  := math_mod(m => extract(month from sysdate) - fy_start_mo, n => 12) + 1;
  dt_fisc_day    := extract(day from dt);
  dt_fisc_mo     := math_mod(m => extract(month from dt) - fy_start_mo, n => 12) + 1;
  -- logic to construct output
  If dt_fisc_mo < today_fisc_mo Then
    -- if dt_fisc_mo is earlier than today_fisc_mo no need to continue checking
    output := 'Y';
  ElsIf dt_fisc_mo > today_fisc_mo Then
    output := 'N';
  ElsIf dt_fisc_mo = today_fisc_mo Then
    If dt_fisc_day < today_fisc_day Then
      output := 'Y';
    Else
      output := 'N';
    End If;
  Else
    -- fallback condition
    output := '#ERR';
  End If;
  Return(output);
End fytd_indicator;
/
