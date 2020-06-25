Create Or Replace View v_addr_continents As 

-- View linking countries to their continent
Select tms_country.country_code, tms_country.short_desc As country,
  Case
    When short_desc In (
      'Algeria'
      , 'Angola'
      , 'Benin'
      , 'Botswana'
      , 'British Indian Ocean Territory'
      , 'Burkina Faso'
      , 'Burundi'
      , 'Cameroon'
      , 'Cape Verde'
      , 'Central African Republic'
      , 'Chad'
      , 'Comoros'
      , 'Congo'
      , 'Congo, Democratic Republic of'
      , 'Djibouti'
      , 'Egypt'
      , 'Equatorial Guinea'
      , 'Eritrea'
      , 'Ethiopia'
      , 'French Southern Territories'
      , 'Gabon'
      , 'Gambia'
      , 'Ghana'
      , 'Guinea'
      , 'Guinea-Bissau'
      , 'Ivory Coast'
      , 'Kenya'
      , 'Lesotho'
      , 'Liberia'
      , 'Libya'
      , 'Madagascar'
      , 'Malawi'
      , 'Mali'
      , 'Mauritania'
      , 'Mauritius'
      , 'Mayotte'
      , 'Morocco'
      , 'Mozambique'
      , 'Namibia'
      , 'Niger'
      , 'Nigeria'
      , 'Reunion'
      , 'Rwanda'
      , 'Sao Tome & Principe'
      , 'Senegal'
      , 'Seychelles'
      , 'Sierra Leone'
      , 'Somalia'
      , 'South Africa'
      , 'South Sudan'
      , 'St. Helena'
      , 'Sudan'
      , 'Swaziland'
      , 'Tanzania'
      , 'Togo'
      , 'Tunisia'
      , 'Uganda'
      , 'Western Sahara'
      , 'Zaire'
      , 'Zambia'
      , 'Zimbabwe'
    ) Then 'Africa'
    When short_desc In (
      'Antarctica'
      , 'Antartica' -- sic
      , 'Bouvet Island'
    ) Then 'Antarctica'
    When short_desc In (
      'Afghanistan'
      , 'Bahrain'
      , 'Bangladesh'
      , 'Bhutan'
      , 'Brunei Darussalam'
      , 'Burma'
      , 'Cambodia'
      , 'Cambodia (Kampuchea)'
      , 'China'
      , 'Christmas Island'
      , 'Cocos (Keeling) Islands'
      , 'East Timor'
      , 'Hong Kong'
      , 'India'
      , 'Indonesia'
      , 'Iran'
      , 'Iraq'
      , 'Israel'
      , 'Japan'
      , 'Jordan'
      , 'Kazakhstan'
      , 'Korea'
      , 'Korea, North'
      , 'Korea, South'
      , 'Kuwait'
      , 'Kyrgyzstan'
      , 'Laos'
      , 'Lebanon'
      , 'Macao' -- sic
      , 'Malaysia'
      , 'Maldives'
      , 'Mongolia'
      , 'Nepal'
      , 'North Korea'
      , 'Oman'
      , 'Pakistan'
      , 'Palestine'
      , 'Philippines'
      , 'Qatar'
      , 'Saudi Arabia'
      , 'Singapore'
      , 'South Korea'
      , 'Sri Lanka'
      , 'Syria'
      , 'Taiwan'
      , 'Tajikistan'
      , 'Thailand'
      , 'Turkey'
      , 'Turkmenistan'
      , 'United Arab Emirates'
      , 'Uzbekistan'
      , 'Vietnam'
      , 'Yemen'
      , 'Yemen Peoples Republic' -- sic
    ) Then 'Asia'
    When short_desc In (
      'Albania'
      , 'Andorra'
      , 'Armenia'
      , 'Austria'
      , 'Azerbaijan'
      , 'Belarus'
      , 'Belgium'
      , 'Bosnia & Herzegovina'
      , 'Bulgaria'
      , 'Channel Islands'
      , 'Croatia'
      , 'Corsica'
      , 'Cyprus'
      , 'Czech Republic'
      , 'Denmark'
      , 'England'
      , 'Estonia'
      , 'Faroe Islands'
      , 'Finland'
      , 'France'
      , 'Georgia'
      , 'Germany'
      , 'Gibralter' -- sic
      , 'Greece'
      , 'Hungary'
      , 'Iceland'
      , 'Ireland'
      , 'Italy'
      , 'Kosovo'
      , 'Latvia'
      , 'Liechtenstein'
      , 'Lithuania'
      , 'Luxembourg'
      , 'Macedonia'
      , 'Malta'
      , 'Moldova'
      , 'Monaco'
      , 'Montenegro'
      , 'Netherlands'
      , 'Northern Ireland'
      , 'Norway'
      , 'Poland'
      , 'Portugal'
      , 'Republic of Macedonia'
      , 'Romania'
      , 'Russia'
      , 'Russian Federation'
      , 'San Marino'
      , 'Scotland'
      , 'Serbia'
      , 'Serbia and Montenegro'
      , 'Slovakia'
      , 'Slovenia'
      , 'Spain'
      , 'Svalbard & Jan Mayen'
      , 'Sweden'
      , 'Switzerland'
      , 'Ukraine'
      , 'United Kingdom'
      , 'Vatican City'
      , 'Wales'
      , 'Yugoslavia'
    ) Then 'Europe'
    When short_desc In (
      'Anguilla'
      , 'Antigua & Barbuda'
      , 'Bahamas'
      , 'Barbados'
      , 'Belize'
      , 'Bermuda'
      , 'British Virgin Islands'
      , 'Canada'
      , 'Cayman Islands'
      , 'Costa Rica'
      , 'Cuba'
      , 'Dominica'
      , 'Dominican Republic'
      , 'El Salvador'
      , 'Greenland'
      , 'Grenada'
      , 'Guadeloupe'
      , 'Guatemala'
      , 'Haiti'
      , 'Honduras'
      , 'Jamaica'
      , 'Martinique'
      , 'Mexico'
      , 'Montserrat'
      , 'Nicaragua'
      , 'Panama'
      , 'Puerto Rico'
      , 'St. Kitts & Nevis'
      , 'St. Lucia'
      , 'St Maarten' -- sic
      , 'St. Pierre & Miquelon'
      , 'Saint Vincent & the Grenadines'
      , 'St. Vincent & the Grenadines'
      , 'Trinidad & Tobago'
      , 'Turks and Caicos Islands'
      , 'United States'
      , 'U.S. Minor Outlying Islands'
      , 'U.S. Virgin Islands'
      , 'West Indies'
    ) Then 'North America'
    When short_desc In (
      'American Samoa'
      , 'Australia'
      , 'Cook Islands'
      , 'Fed. States of Micronesia'
      , 'Fiji'
      , 'French Polynesia'
      , 'Guam'
      , 'Kiribati'
      , 'Marshall Islands'
      , 'Micronesia'
      , 'Nauru'
      , 'New Caledonia'
      , 'New Guinea'
      , 'New Zealand'
      , 'Niue'
      , 'Norfolk Island'
      , 'Northern Mariana Islands'
      , 'Palau'
      , 'Papua New Guinea'
      , 'Pitcairn'
      , 'Samoa'
      , 'Solomon Islands'
      , 'Tokelau'
      , 'Tonga'
      , 'Tuvalu'
      , 'Vanuatu'
      , 'Wallis & Futuna Islands'
      , 'Western Samoa'
    ) Then 'Oceania'
    When short_desc In (
      'Argentina'
      , 'Aruba'
      , 'Bolivia'
      , 'Brazil'
      , 'Chile'
      , 'Colombia'
      , 'Ecuador'
      , 'Falkland Islands (Malvinas)'
      , 'French Guiana'
      , 'Guyana'
      , 'Netherlands Antilles'
      , 'Paraguay'
      , 'Peru'
      , 'South Georgia & South Sandwich Island'
      , 'Surinam' -- sic
      , 'Suriname'
      , 'Uruguay'
      , 'Venezuela'
    ) Then 'South America'
    Else 'CHECK'
  End As continent
--- Special Regions: Latin America, South Asia and Middle East
Case When short_desc IN ('Antigua & Barbuda',
  'Argentina',
  'Aruba',
  'Bahamas',
  'Barbados',
  'Belize',
  'Bolivia',
  'Brazil',
  'British Virgin Islands',
  'Cayman Islands',
  'Chile',
  'Colombia',
  'Costa Rica',
  'Cuba',
  'Dominican Republic',
  'Ecuador',
  'El Salvador',
  'Guadeloupe',
  'Guatemala',
  'Haiti',
  'Honduras',
  'Jamaica',
  'Mexico',
  'Netherlands Antilles',
  'Nicaragua',
  'Panama',
  'Paraguay',
  'Peru',
  'Puerto Rico',
  'Trinidad & Tobago',
  'Uruguay',
  'Venezuela',
  'West Indies')
Then 'Latin_America'
  When short_desc IN ('Bahrain',
  'Cyprus',
  'Egypt',
  'Iran',
  'Iraq',
  'Israel',
  'Jordan',
  'Kuwait',
  'Lebanon',
  'Oman',
  'Pakistan',
  'Palestine',
  'Qatar',
  'Saudi Arabia',
  'Turkey',
  'United Arab Emirates')
Then 'Middle_East'
  When short_desc IN ('Bangladesh',
  'India',
  'Sri Lanka')
  Then 'South_Asia'
  END AS KSM_Continent
From tms_country
-- Add a row for USA
Union All
-- USA is blank country code
Select ' ', 'United States', 'North America'
From DUAL
/

-- Did I miss any countries?
Select *
From v_addr_continents
Where continent = 'CHECK'
