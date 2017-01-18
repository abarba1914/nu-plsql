-- Main query
Select id_number,
  -- Concatenated degrees string
  Listagg(
    -- Trimmed degree row
    trim(
      degree_code || ' ' || degree_year || ' ' || school_code || ' ' || 
      -- Special handler for KSM and EMBA departments
      Case
        When dept_code Like '01%' Then substr(dept_code, 3)
        When dept_code = '13JDM' Then 'JD/MBA'
        When dept_code = '13LLM' Then 'LLM'
        When dept_code Like '41%' Then substr(dept_code, 3)
        Else short_desc
      End
      || ' ' || class_section
    ), '; ' -- ; is the degree delimiter
  )
  Within Group (Order By degree_year) As degrees_concat
From degrees
  Left Join tms_class_section
    On degrees.class_section = tms_class_section.section_code
Where institution_code = '31173'
  And school_code in('BUS', 'KSM')
Group By id_number;
