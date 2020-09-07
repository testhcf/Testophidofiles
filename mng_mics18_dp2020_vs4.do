﻿********************************************************************************
/*
Citation:
Oxford Poverty and Human Development Initiative (OPHI), University of Oxford. 
2020 Global Multidimensional Poverty Index - Mongolia MICS 2018 
[STATA do-file]. Available from OPHI website: http://ophi.org.uk/  

For further queries, contact: ophi@qeh.ox.ac.uk
*/
********************************************************************************

clear all 
set more off
set maxvar 10000
set mem 500m

*** Working Folder Path ***
global path_in "../rdta/Mongolia MICS 2018" 
global path_out "cdta"
global path_ado "ado"
	
	
********************************************************************************
*** MONGOLIA MICS 2018 ***
********************************************************************************


********************************************************************************
*** Step 1: Data preparation 
*** Selecting main variables from CH, WM, HH & MN recode & merging with HL recode 
********************************************************************************
	
/* Mongolia MICS 2018: Seven questionnaires were used in the survey/ 
Anthropometric information were collected with the under-5 questionnaire. 
(p. 23-24 of the survey report). Please note that the survey also sampled
men (15-49 years) but only a subsample. This will be taken into account 
in the child mortality indicator.  */


********************************************************************************
*** Step 1.1 CH - CHILD RECODE
*** (Children under 5 years) 
********************************************************************************
/*The purpose of step 1.1 is to compute anthropometric measures for children 
under 5 years.*/

use "$path_in/ch.dta", clear 

rename _all, lower	


*** Generate individual unique key variable required for data merging
*** hh1=cluster number; 
*** hh2=household number; 
*** ln=child's line number in household
gen double ind_id = hh1*1000000 + hh2*100 + ln 
format ind_id %20.0g
label var ind_id "Individual ID"

duplicates report ind_id 
	//No duplicates. 6,269 eligible children under five. Matches report (p. 3)

gen child_CH=1 
	//Generate identification variable for observations in CH recode

	
*** Check the variables to calculate the z-scores:

*** Variable: SEX ***
codebook hl4, tab (9) 
	//"1" for male ;"2" for female 
clonevar gender = hl4
tab gender


*** Variable: AGE ***
	/*In most MICS surveys, the age variables is expressed in either months or 
	days. Days are much more accurate and is the prefered age variable for 
	children under 5. However, if the missing information for the age variable 
	by days is notably much higher, then the variable in months is a prefered 
	option. */
desc cage caged
tab cage, miss
	//Age in months: information missing for 178 children
tab caged, miss
	/*Age in days: information missing for 178 children + 1 child is
	assigned with a value of '9999'. We will use age in days as it 
	result in more accurate anthropometric measures. */
count if caged < 0 	
clonevar age_days = caged
replace age_days = trunc(cage*(365/12)) if age_days>=9000 & cage<9000
sum age_days 
	//6,091 children measured. Matches the country report on page 3
gen str6 ageunit = "days"
lab var ageunit "Days"


*** Variable: BODY WEIGHT (KILOGRAMS) ***
codebook an8, tab (9999) 
 	//Unit of measurement is in kilograms
clonevar weight = an8	
replace weight = . if an8>=99 
	//All missing values or out of range are replaced as "."
tab	uf17 an8 if an8>=99 | an8==., miss   
sum weight	


*** Variable: HEIGHT (CENTIMETERS)
codebook an11, tab (9999) 
	//Unit of measurement is in centimetres
clonevar height = an11
replace height = . if an11>=999 
	//All missing values or out of range are replaced as "."
tab	uf17 an11 if an11>=999 | an11==., miss
sum height


	
*** Variable: MEASURED STANDING/LYING DOWN	
codebook an12  
gen measure = "l" if an12==1 
	//Child measured lying down
replace measure = "h" if an12==2 
	//Child measured standing up
replace measure = " " if an12==9 | an12==0 | an12==. 
	//Replace with " " if unknown
tab measure

		
	
*** Variable: OEDEMA ***
	/* If the survey did not collect information on oedema, please generate a
	variable that assumes no one has oedema. However, if your country data has 
	the oedema variable, please replace it accordingly. */ 
lookfor oedema œdème edema
gen str1 oedema = "n"  


*** Variable: SAMPLING WEIGHT ***
	/* We don't require individual weight to compute the z-scores of a child. 
	So we assume all children in the sample have the same weight */
gen sw = 1	
sum sw



*** Indicate to STATA where the igrowup_restricted.ado file is stored:
	***Source of ado file: http://www.who.int/childgrowth/software/en/
adopath + "$path_ado/igrowup_stata"

*** We will now proceed to create three nutritional variables: 
	*** weight-for-age (underweight),  
	*** weight-for-height (wasting) 
	*** height-for-age (stunting)

*** We specify the first three parameters we need in order to use the ado file:
	*** reflib, 
	*** datalib, 
	*** datalab

/* We use 'reflib' to specify the package directory where the .dta files 
containing the WHO Child Growth Standards are stored. */	
gen str100 reflib = "$path_ado/igrowup_stata"
lab var reflib "Directory of reference tables"


/* We use datalib to specify the working directory where the input STATA 
dataset containing the anthropometric measurement is stored. */
gen str100 datalib = "$path_out" 
lab var datalib "Directory for datafiles"


/* We use datalab to specify the name that will prefix the output files that 
will be produced from using this ado file (datalab_z_r_rc and datalab_prev_rc)*/
gen str30 datalab = "children_nutri_mng"
lab var datalab "Working file"

	
/*We now run the command to calculate the z-scores with the adofile */
igrowup_restricted reflib datalib datalab gender age_days ageunit weight ///
height measure oedema sw


/*We now turn to using the dta file that was created and that contains 
the calculated z-scores to create the child nutrition variables following WHO 
standards */
use "$path_out/children_nutri_mng_z_rc.dta", clear 

	
	
*** Standard MPI indicator ***
	//Takes value 1 if the child is under 2 stdev below the median & 0 otherwise
	
gen	underweight = (_zwei < -2.0) 
replace underweight = . if _zwei == . | _fwei==1
lab var underweight  "Child is undernourished (weight-for-age) 2sd - WHO"
tab underweight, miss 


gen stunting = (_zlen < -2.0)
replace stunting = . if _zlen == . | _flen==1
lab var stunting "Child is stunted (length/height-for-age) 2sd - WHO"
tab stunting, miss 


gen wasting = (_zwfl < - 2.0)
replace wasting = . if _zwfl == . | _fwfl == 1
lab var wasting  "Child is wasted (weight-for-length/height) 2sd - WHO"
tab wasting, miss 


*** Destitution indicator  ***
	//Takes value 1 if the child is under 3 stdev below the median & 0 otherwise
	
gen	underweight_u = (_zwei < -3.0) 
replace underweight_u = . if _zwei == . | _fwei==1
lab var underweight_u  "Child is undernourished (weight-for-age) 3sd - WHO"


gen stunting_u = (_zlen < -3.0)
replace stunting_u = . if _zlen == . | _flen==1
lab var stunting_u "Child is stunted (length/height-for-age) 3sd - WHO"


gen wasting_u = (_zwfl < - 3.0)
replace wasting_u = . if _zwfl == . | _fwfl == 1
lab var wasting_u  "Child is wasted (weight-for-length/height) 3sd - WHO"

 
count if _fwei==1 | _flen==1 
	/*Mongolia MICS 2018: 45 children were replaced as missing because 
	they have extreme z-scores which are biologically implausible. */
	

count  
	/*Mongolia MICS 2018: the number of eligible children is 6,269 as in 
	the country report (p.3). No mismatch. */		
	
		
	//Retain relevant variables:
keep ind_id child_CH ln underweight* stunting* wasting*  
order ind_id child_CH ln underweight* stunting* wasting*
sort ind_id
save "$path_out/MNG18_CH.dta", replace

	
	//Erase files from folder:
erase "$path_out/children_nutri_mng_z_rc.xls"
erase "$path_out/children_nutri_mng_prev_rc.xls"
erase "$path_out/children_nutri_mng_z_rc.dta"
	

********************************************************************************
*** Step 1.2  BH - BIRTH RECODE 
*** (All females 15-49 years who ever gave birth)  
********************************************************************************
/*The purpose of step 1.2 is to identify children under 18 who died in 
the last 5 years prior to the survey date.*/

use "$path_in/bh.dta", clear

rename _all, lower	

	
*** Generate individual unique key variable required for data merging using:
	*** hh1=cluster number; 
	*** hh2=household number; 
	*** wm3=women's line number. Sometimes this could be wm4. Check.
gen double ind_id = hh1*1000000 + hh2*100 + wm3 
format ind_id %20.0g
label var ind_id "Individual ID"

		
desc bh4c bh9c	
codebook bh4c bh9c, tab (9999)
gen date_death = bh4c + bh9c	
	//Date of death = date of birth (bh4c) + age at death (bh9c)	
replace date_death = . if bh4c==9999	
gen mdead_survey = wdoi-date_death	
	//Months dead from survey = Date of interview (wdoi) - date of death	
replace mdead_survey = . if (bh9c==0 | bh9c==.) & bh5==1	
	/*Replace children who are alive as '.' to distinguish them from children 
	who died at 0 months */ 
gen ydead_survey = mdead_survey/12
	//Years dead from survey
	

gen age_death = bh9c if bh5==2
label var age_death "Age at death in months"	
tab age_death, miss
	//Age is in months			
	
	
codebook bh5, tab (10)	
gen child_died = 1 if bh5==2
replace child_died = 0 if bh5==1
replace child_died = . if bh5==.
label define lab_died 0"child is alive" 1"child has died"
label values child_died lab_died
tab bh5 child_died, miss
	
	
bysort ind_id: egen tot_child_died = sum(child_died) 
	//For each woman, sum the number of children who died
		
	
	//Identify child under 18 mortality in the last 5 years
gen child18_died = child_died 
replace child18_died=0 if age_death>=216 & age_death<.
label define lab_u18died 1 "child u18 has died" 0 "child is alive/died but older"
label values child18_died lab_u18died
tab child18_died, miss	
	
bysort ind_id: egen tot_child18_died_5y=sum(child18_died) if ydead_survey<=5
	/*Total number of children under 18 who died in the past 5 years 
	prior to the interview date */	
	
replace tot_child18_died_5y=0 if tot_child18_died_5y==. & tot_child_died>=0 & tot_child_died<.
	/*All children who are alive or who died longer than 5 years from the 
	interview date are replaced as '0'*/
	
replace tot_child18_died_5y=. if child18_died==1 & ydead_survey==.
	//Replace as '.' if there is no information on when the child died  

tab tot_child_died tot_child18_died_5y, miss

bysort ind_id: egen childu18_died_per_wom_5y = max(tot_child18_died_5y)
lab var childu18_died_per_wom_5y "Total child under 18 death for each women in the last 5 years (birth recode)"
	

	//Keep one observation per women
bysort ind_id: gen id=1 if _n==1
keep if id==1
drop id
duplicates report ind_id 


gen women_BH = 1 
	//Identification variable for observations in BH recode

	
	//Retain relevant variables
keep ind_id women_BH childu18_died_per_wom_5y 
order ind_id women_BH childu18_died_per_wom_5y
sort ind_id
save "$path_out/MNG18_BH.dta", replace	


********************************************************************************
*** Step 1.3  WM - WOMEN's RECODE  
*** (Eligible females 15-49 years in the household)
********************************************************************************
/*The purpose of step 1.3 is to identify all deaths that are reported by 
eligible women.*/

use "$path_in/wm.dta", clear 
	
rename _all, lower	

	
*** Generate individual unique key variable required for data merging using:
	*** hh1=cluster number; 
	*** hh2=household number; 
	*** wm3=women's line number. In other datasets, you may have to use ln. 
gen double ind_id = hh1*1000000 + hh2*100 + wm3 
format ind_id %20.0g
label var ind_id "Individual ID"

duplicates report ind_id 
	// 11,737 women (15-49) eligible for interview (p. 3) 

gen women_WM =1 
	//Identification variable for observations in WM recode

	
tab wb4 wm17, miss
	/*Mongolia MICS 2018: 
	10,794 women 15-49 years who were successfully interviewed.*/
	
tab cm1 cm8, miss
tab mstatus if cm1==. & cm8==.,m		
	/* Mongolia MICS 2018: 5 women report never having given birth but 
	who also have information on child mortality (i.e. data anomalies). 
	The large majority of women who did not answer questions on child
	mortality are currently married or in union. */
		
	
keep wm7* cm1 cm8 cm9 cm10 ind_id women_WM 
order wm7* cm1 cm8 cm9 cm10 ind_id women_WM 
sort ind_id
save "$path_out/MNG18_WM.dta", replace


********************************************************************************
*** Step 1.4  MN - MEN'S RECODE 
***(Eligible man: 15-59 years in the household) 
********************************************************************************
/*The purpose of step 1.4 is to identify all deaths that are reported by 
eligible men.*/

use "$path_in/mn.dta", clear 

rename _all, lower


*** Generate individual unique key variable required for data merging using:
	*** hh1=cluster number; 
	*** hh2=household number; 
	*** ln=respondent's line number.  
gen double ind_id = hh1*1000000 + hh2*100 + ln 
format ind_id %20.0g
label var ind_id "Individual ID"	
	
duplicates report ind_id 
	//5,513 men eligible  for interview (p. 3) 

gen men_MN=1 	
	//Identification variable for observations in MR recode

	
tab mwb4 mwm17, miss 
	/*Mongolia MICS 2018: 4,477 men 15-49 years were successfully interviewed. 
	This matches report (p.3)*/
	
tab mcm1 mcm8, miss
tab mmstatus if mcm1==. & mcm8==.,m
	/*Mongolia MICS 2018: 8 men report never fathering a child but have a child
	who later died (i.e. data anomalies). */	

	
keep mcm1 mcm8 mcm9 mcm10 ind_id men_MN 
order mcm1 mcm8 mcm9 mcm10 ind_id men_MN 
sort ind_id
save "$path_out/MNG18_MN.dta", replace


********************************************************************************
*** Step 1.5 HH - HOUSEHOLD RECODE 
***(All households interviewed) 
********************************************************************************

use "$path_in/hh.dta", clear 
	
rename _all, lower	


*** Generate individual unique key variable required for data merging
	*** hh1=cluster number;  
	*** hh2=household number 
gen	double hh_id = hh1*1000 + hh2 
format	hh_id %20.0g
lab var hh_id "Household ID"


duplicates report hh_id 
	//14,500 households sampled (p. 3) 
	
save "$path_out/MNG18_HH.dta", replace

	
********************************************************************************
*** Step 1.6 HL - HOUSEHOLD MEMBER  
********************************************************************************

use "$path_in/hl.dta", clear 

rename _all, lower

	
*** Generate a household unique key variable at the household level using: 
	***hh1=cluster number 
	***hh2=household number
gen double hh_id = hh1*1000 + hh2 
format hh_id %20.0g
label var hh_id "Household ID"


*** Generate individual unique key variable required for data merging using:
	*** hh1=cluster number; 
	*** hh2=household number; 
	*** hl1=respondent's line number.
gen double ind_id = hh1*1000000 + hh2*100 + hl1 
format ind_id %20.0g
label var ind_id "Individual ID"

duplicates report ind_id 
	//49,839 individuals 


sort ind_id

	
********************************************************************************
*** Step 1.7 DATA MERGING 
******************************************************************************** 
 
 
*** Merging BR Recode 
*****************************************
merge 1:1 ind_id using "$path_out/MNG18_BH.dta"
drop _merge
erase "$path_out/MNG18_BH.dta" 
 
 
*** Merging WM Recode 
*****************************************
merge 1:1 ind_id using "$path_out/MNG18_WM.dta"
count if hl8>0
	/*11,737 women 15-49 years were eligible for interview. This matches the 
	country report (p.3) */
drop _merge	
erase "$path_out/MNG18_WM.dta"


*** Merging HH Recode 
*****************************************
merge m:1 hh_id using "$path_out/MNG18_HH.dta"
tab hh46 if _m==2 
	// 702 hhs with no info = 13,798 hhs interviewed (p. 3)  
drop  if _merge==2
	//Drop households that were not interviewed 
drop _merge
erase "$path_out/MNG18_HH.dta"


*** Merging MN Recode 
*****************************************
merge 1:1 ind_id using "$path_out/MNG18_MN.dta"
count if hl9>0 & hl9!=.
	/*2,153 men 15-49 years were eligible for interview. This matches
	the country report (page 3)*/
drop _merge
erase "$path_out/MNG18_MN.dta"


*** Merging CH Recode 
*****************************************
merge 1:1 ind_id using "$path_out/MNG18_CH.dta"
count if hl10>0 & hl10!=.
	/*2,189 children under 5 were eligible for measurement. This matches
	the country report (page 3)*/
drop _merge
erase "$path_out/MNG18_CH.dta"


sort ind_id


********************************************************************************
*** Step 1.8 CONTROL VARIABLES
********************************************************************************
/* Households are identified as having 'no eligible' members if there are no 
applicable population, that is, children 0-5 years, adult women or men. These 
households will not have information on relevant indicators of health. As such, 
these households are considered as non-deprived in those relevant indicators. */


*** No eligible women 15-49 years 
*** for child mortality indicator
*****************************************
count if women_WM==1
count if hl8>0 & hl8!=.
	//Eligibility based on WM datafile (women_WM) and HL datafile (hl8) matches
gen	fem_eligible = (women_WM==1)
bys	hh_id: egen hh_n_fem_eligible = sum(fem_eligible) 	
	//Number of eligible women for interview in the hh
gen	no_fem_eligible = (hh_n_fem_eligible==0) 									
	//Takes value 1 if the household had no eligible females for an interview
lab var no_fem_eligible "Household has no eligible women"
drop fem_eligible hh_n_fem_eligible 
tab no_fem_eligible, miss


*** No eligible men 15-49 years
*** for child mortality indicator (if relevant)
*****************************************
count if men_MN==1
count if hl9>0 & hl9!=.
	//Eligibility based on MN datafile (men_MN) and HL datafile (hl9) matches
gen	male_eligible = (men_MN==1)
bysort	hh_id: egen hh_n_male_eligible = sum(male_eligible)  
	//Number of eligible men for interview in the hh
gen	no_male_eligible = (hh_n_male_eligible==0) 	
	//Takes value 1 if the household had no eligible men for an interview
lab var no_male_eligible "Household has no eligible man for interview"
drop male_eligible hh_n_male_eligible
tab no_male_eligible, miss

	
*** No eligible children under 5
*** for child nutrition indicator
*****************************************
count if child_CH==1
count if hl10>0 & hl10!=.
	//Eligibility based on CH datafile (child_CH) and HL datafile (hl10) matches
gen	child_eligible = (child_CH==1) 
bysort	hh_id: egen hh_n_children_eligible = sum(child_eligible)  
	//Number of eligible children for anthropometrics
gen	no_child_eligible = (hh_n_children_eligible==0) 
	//Takes value 1 if there were no eligible children for anthropometrics
lab var no_child_eligible "Household has no children eligible for anthropometric"
drop child_eligible hh_n_children_eligible
tab no_child_eligible, miss


sort hh_id

  
********************************************************************************
*** Step 1.10 RENAMING DEMOGRAPHIC VARIABLES ***
********************************************************************************

//Sample weight
clonevar weight = hhweight 
label var weight "Sample weight"


//Area: urban or rural		
desc hh6	
codebook hh6, tab (5)	
clonevar area = hh6  
replace area=0 if area==2  
label define lab_area 1 "urban" 0 "rural"
label values area lab_area
label var area "Area: urban-rural"


//Sex of household member
codebook hl4
clonevar sex = hl4 
label var sex "Sex of household member"


//Age of household member
codebook hl6, tab (100)
clonevar age = hl6  
replace age = . if age>=98
label var age "Age of household member"


//Age group (for global MPI estimation)
recode age (0/4 = 1 "0-4")(5/9 = 2 "5-9")(10/14 = 3 "10-14") ///
		   (15/17 = 4 "15-17")(18/59 = 5 "18-59")(60/max=6 "60+"), gen(agec7)
lab var agec7 "age groups (7 groups)"	
	   
recode age (0/9 = 1 "0-9") (10/17 = 2 "10-17")(18/59 = 3 "18-59") ///
		   (60/max=4 "60+") , gen(agec4)
lab var agec4 "age groups (4 groups)"

recode age (0/17 = 1 "0-17") (18/max = 2 "18+"), gen(agec2)		 		   
lab var agec2 "age groups (2 groups)"


//Total number of de jure hh members in the household
gen member = 1
bysort hh_id: egen hhsize = sum(member)
label var hhsize "Household size"
tab hhsize, miss
compare hhsize hh48
drop member


//Subnational region
	/* The sample for the Mongolia MICS 2018 was designed to provide 
	estimates for a large number of indicators on the situation  of children 
	and women and men at the national level, for urban and rural areas, five 
	regions of the country (Eastern, Western, Central, Khangai and Ulaanbaatar) 
	and for 8 target provinces/districts of the country: provinces of 
	(1) Bayan-Ulgii, (2) Bayankhongor; (3) Govi-Altai; (4) Zavkhan; (5) Umnugovi; 
	(6) Khuvsgul; and the districts of (7) Bayanzurkh and (8) Nalaikh.. pg23 	
	*/		
codebook hh7, tab (99) 
decode hh7, gen(temp)
replace temp =  proper(temp)
encode temp, gen(region)
lab var region "Region for subnational decomposition"
codebook region, tab (99)


drop temp


********************************************************************************
***  Step 2 Data preparation  ***
***  Standardization of the 10 Global MPI indicators 
***  Identification of non-deprived & deprived individuals  
********************************************************************************

********************************************************************************
*** Step 2.1 Years of Schooling ***
********************************************************************************


/*In  Mongolia,  children  enter  primary  school  at  age  6,  lower  
secondary at age 11 and upper secondary school at age 15. There  are  5  grades  
in  primary  school  and  4  +  3  grades  in  secondary school. In primary 
school, grades are referred to as year 1 to year 5. For lower secondary school 
(LSS), grades are referred to as year 6 to year 9 and in upper secondary (USS) 
to year 10 to year 12 (p.204 of country survey report). */


codebook ed5a, tab (99) 
/* Mongolia MICS 2019: 5,030 missing values. 
0 = ECE; 1 = SECONDARY; 3 = VOCATIONAL; 
4 = UNIVERSITY; 8 = DK; 9 = NO RESPONSE  */				
tab age ed10a if ed5a==0, miss
	//The category ECE indicate early childhood education, that is, pre-primary
clonevar edulevel = ed5a 
	//Highest educational level attended
replace edulevel = . if ed5a==. | ed5a==8 | ed5a==9  
	//All missing values or out of range are replaced as "."
replace edulevel = 0 if ed4==2 
	//Those who never attended school are replaced as '0'
label var edulevel "Highest level of education attended"	
	

codebook ed5b, tab (99)
clonevar eduhighyear = ed5b 
	//Highest grade attended at that level
replace eduhighyear = .  if ed5b==. | ed5b==98 | ed5b==99 
	//All missing values or out of range are replaced as "."
replace eduhighyear = 0  if ed4==2 
	//Those who never attended school are replaced as '0'
lab var eduhighyear "Highest grade attended for each level of edu"


*** Cleaning inconsistencies
replace edulevel    = 0 if age<10 
replace eduhighyear = 0 if age<10
	/*At this point, we disregard the years of education of household members 
	younger than 10 years by replacing the relevant variables with '0 years' 
	since they are too young to have completed 6 years of schooling. */  
replace eduhighyear = 0 if edulevel<1
	//Early childhood education has no grade
	
	
*** Now we create the years of schooling
tab eduhighyear edulevel, miss

/*
        Highest grade |
    attended for each |          Highest level of education attended
         level of edu |       ECE  SECONDARY  VOCATIONA  UNIVERSIT          . |     Total
----------------------+-------------------------------------------------------+----------
                    0 |    13,666          0          0          0          0 |    13,666 
                    1 |         0        317        639        459          0 |     1,415 
                    2 |         0        417      2,602        669          0 |     3,688 
                    3 |         0        715      2,109        756          0 |     3,580 
                    4 |         0      2,139         57      5,725          0 |     7,921 
                    5 |         0      1,470          0        485          0 |     1,955 
                    6 |         0      1,416          0        228          0 |     1,644 
                    7 |         0      1,457          0          0          0 |     1,457 
                    8 |         0      5,882          0          0          0 |     5,882 
                    9 |         0      1,393          0          0          0 |     1,393 
                   10 |         0      4,551          0          0          0 |     4,551 
                   11 |         0      1,032          0          0          0 |     1,032 
                   12 |         0        900          0          0          0 |       900 
 MASTER’S FIRST GRADE |         0          0          0        119          0 |       119 
MASTER’S SECOND GRADE |         0          0          0        534          0 |       534 
               DOCTOR |         0          0          0         67          0 |        67 
                    . |         0          0          5          1         29 |        35 
----------------------+-------------------------------------------------------+----------
                Total |    13,666     21,689      5,412      9,043         29 |    49,839 

*/


gen	eduyears = eduhighyear
replace eduyears = eduhighyear + 9 if edulevel==3 
*tab ed16b ed16a if edulevel==3,m
	/*There are 5 grades in primary school; followed by 4 grades in lower 
	secondary school; This means, individuals would have completed 9 years 
	of schooling before reaching vocational training.*/	
replace eduyears = eduhighyear + 12 if edulevel==4
	/*There are 5 grades in primary school; followed by 4 grades in lower 
	secondary school; and 3 grades in Upper Secondary School (USS). This means, 
	individuals would have completed 12 years of schooling before reaching 
	university.*/	
replace eduyears = 16 if edulevel==4 & eduhighyear==21	
	/*Completed 16 years before pursuing masters first grade*/	
replace eduyears = 17 if edulevel==4 & eduhighyear==22
	/*Completed 17 years before pursuing masters first grade*/	
replace eduyears = 21 if edulevel==4 & eduhighyear==30
	/*Completed 17 years before pursuing masters first grade*/		
replace eduyears = 9 if edulevel==3 & eduhighyear==.  
	/*We assume that an individual who is in vocational but no 
	information on grade, has completed lower secondary */ 		
replace eduyears = 12 if edulevel==4 & eduhighyear==.  
	/*We assume that an individual who has university but no 
	information on grade, has completed upper secondary */ 	

	
*** Checking for further inconsistencies 
replace eduyears = eduyears - 1 if ed6==2 & eduyears>=1 & eduyears<. 
	/*Through ed6 variable, individuals confirm whether they have completed the 
	highest grade they have attended. For individuals who responded that they 
	did not complete the highest grade attended, we re-assign them to the next  
	lower grade that they would have completed. */
replace eduyears = . if age<=eduyears & age>0 
	/*There are cases in which the years of schooling are greater than the 
	age of the individual. This is clearly a mistake in the data. Please check 
	whether this is the case and correct when necessary */
replace eduyears = 0 if age< 10 
replace eduyears = 0 if (age==10 | age==11) & eduyears < 6 
	/*The variable "eduyears" was replaced with a '0' given that the criteria 
	for this indicator is household member aged 12 years or older */
tab eduyears if edulevel==. & (ed4==1 | ed4==9), miss
	/*Replaced as missing value when level of education is missing for those 
	who have attended school */
lab var eduyears "Total number of years of education accomplished"
tab eduyears, miss


	/*A control variable is created on whether there is information on 
	years of education for at least 2/3 of the eligible household members*/		
gen temp = 1 if eduyears!=. & age>=12 & age!=.
replace temp = 1 if age==10 & eduyears>=6 & eduyears<.
replace temp = 1 if age==11 & eduyears>=6 & eduyears<.
bysort	hh_id: egen no_missing_edu = sum(temp)
	//Total eligible household members with no missing years of education
gen temp2 = 1 if age>=12 & age!=.
replace temp2 = 1 if age==10 & eduyears>=6 & eduyears<.
replace temp2 = 1 if age==11 & eduyears>=6 & eduyears<.
bysort hh_id: egen hhs = sum(temp2)
	/*Total number of eligible household members who should have information 
	on years of education */
replace no_missing_edu = no_missing_edu/hhs
replace no_missing_edu = (no_missing_edu>=2/3)
	/*Identify whether there is information on years of education for at 
	least 2/3 of the eligible household members */
tab no_missing_edu, miss
	//The value for 0 (missing) is 0.04% 
label var no_missing_edu "No missing edu for at least 2/3 of the HH members aged 12 years & older"	
drop temp temp2 hhs


*** Standard MPI ***
/*The entire household is considered deprived if no household member aged 
10 years or older has completed SIX years of schooling. */
******************************************************************* 
gen	 years_edu6 = (eduyears>=6)
	/* The years of schooling indicator takes a value of "1" if at least someone 
	in the hh has reported 6 years of education or more */
replace years_edu6 = . if eduyears==.
bysort hh_id: egen hh_years_edu6_1 = max(years_edu6)
gen	hh_years_edu6 = (hh_years_edu6_1==1)
replace hh_years_edu6 = . if hh_years_edu6_1==.
replace hh_years_edu6 = . if hh_years_edu6==0 & no_missing_edu==0 
lab var hh_years_edu6 "Household has at least one member with 6 years of edu"
tab hh_years_edu6, miss


	
*** Destitution MPI ***
/*The entire household is considered deprived if no household member 
aged 10 years or older has completed at least one year of schooling. */
******************************************************************* 
gen	years_edu1 = (eduyears>=1)
replace years_edu1 = . if eduyears==.
bysort	hh_id: egen hh_years_edu_u = max(years_edu1)
replace hh_years_edu_u = . if hh_years_edu_u==0 & no_missing_edu==0
lab var hh_years_edu_u "Household has at least one member with 1 year of edu"



********************************************************************************
*** Step 2.2 Child School Attendance ***
********************************************************************************
	
codebook ed4 ed9, tab (99)

gen	attendance = .
replace attendance = 1 if ed9==1 
	//Replace attendance with '1' if currently attending school	
replace attendance = 0 if ed9==2 
	//Replace attendance with '0' if currently not attending school	
replace attendance = 0 if ed4==2 
	//Replace attendance with '0' if never ever attended school	
tab age ed9, miss	
	//Check individuals who are not of school age	
replace attendance = 0 if age<5 | age>24 
	//Replace attendance with '0' for individuals who are not of school age	
label define lab_attend 1 "currently attending" 0 "not currently attending"
label values attendance lab_attend
label var attendance "Attended school during current school year"	
tab attendance, miss


*** Standard MPI ***
/*The entire household is considered deprived if any school-aged 
child is not attending school up to class 8. */ 
******************************************************************* 

gen	child_schoolage = (schage>=6 & schage<=14)
	/*In Mongolia, the official school entrance age to primary school is 
	6 years. So, age range is 6-14 (=6+8) 
	Source: "http://data.uis.unesco.org/?ReportId=163"
	Go to Education>Education>System>Official entrance age to primary education. 
	Look at the starting age and add 8. 
	*/

	
	/*A control variable is created on whether there is no information on 
	school attendance for at least 2/3 of the school age children */
count if child_schoolage==1 & attendance==.
	//How many eligible school aged children are not attending school: 2 children 
gen temp = 1 if child_schoolage==1 & attendance!=.
	/*Generate a variable that captures the number of eligible school aged 
	children who are attending school */
bysort hh_id: egen no_missing_atten = sum(temp)	
	/*Total school age children with no missing information on school 
	attendance */
gen temp2 = 1 if child_schoolage==1	
bysort hh_id: egen hhs = sum(temp2)
	//Total number of household members who are of school age
replace no_missing_atten = no_missing_atten/hhs 
replace no_missing_atten = (no_missing_atten>=2/3)
	/*Identify whether there is missing information on school attendance for 
	more than 2/3 of the school age children */			
tab no_missing_atten, miss
	//The value for 0 (missing) is 0% 
label var no_missing_atten "No missing school attendance for at least 2/3 of the school aged children"		
drop temp temp2 hhs
	
	
bysort hh_id: egen hh_children_schoolage = sum(child_schoolage)
replace hh_children_schoolage = (hh_children_schoolage>0) 
	//It takes value 1 if the household has children in school age
lab var hh_children_schoolage "Household has children in school age"


gen	child_not_atten = (attendance==0) if child_schoolage==1
replace child_not_atten = . if attendance==. & child_schoolage==1
bysort	hh_id: egen any_child_not_atten = max(child_not_atten)
gen	hh_child_atten = (any_child_not_atten==0) 
replace hh_child_atten = . if any_child_not_atten==.
replace hh_child_atten = 1 if hh_children_schoolage==0
replace hh_child_atten = . if hh_child_atten==1 & no_missing_atten==0 
	/*If the household has been intially identified as non-deprived, but has 
	missing school attendance for at least 2/3 of the school aged children, then 
	we replace this household with a value of '.' because there is insufficient 
	information to conclusively conclude that the household is not deprived */
lab var hh_child_atten "Household has all school age children up to class 8 in school"
tab hh_child_atten, miss

/*Note: The indicator takes value 1 if ALL children in school age are attending 
school and 0 if there is at least one child not attending. Households with no 
children receive a value of 1 as non-deprived. The indicator has a missing value 
only when there are all missing values on children attendance in households that 
have children in school age. */

	
*** Destitution MPI ***
/*The entire household is considered deprived if any school-aged 
child is not attending school up to class 6. */ 
******************************************************************* 
gen	child_schoolage_6 = (schage>=6 & schage<=12) 
	/*Note: In Mongolia, the official school entrance age is 6 years.  
	  So, age range for destitution measure is 6-12 (=6+6) */

	
	/*A control variable is created on whether there is no information on 
	school attendance for at least 2/3 of the children attending school up to 
	class 6 */	
count if child_schoolage_6==1 & attendance==.	
gen temp = 1 if child_schoolage_6==1 & attendance!=.
bysort hh_id: egen no_missing_atten_u = sum(temp)	
gen temp2 = 1 if child_schoolage_6==1	
bysort hh_id: egen hhs = sum(temp2)
replace no_missing_atten_u = no_missing_atten_u/hhs 
replace no_missing_atten_u = (no_missing_atten_u>=2/3)			
tab no_missing_atten_u, miss
label var no_missing_atten_u "No missing school attendance for at least 2/3 of the school aged children"		
drop temp temp2 hhs		
		
bysort	hh_id: egen hh_children_schoolage_6 = sum(child_schoolage_6)
replace hh_children_schoolage_6 = (hh_children_schoolage_6>0) 
lab var hh_children_schoolage_6 "Household has children in school age (6 years of school)"

gen	child_atten_6 = (attendance==1) if child_schoolage_6==1
replace child_atten_6 = . if attendance==. & child_schoolage_6==1
bysort	hh_id: egen any_child_atten_6 = max(child_atten_6)
gen	hh_child_atten_u = (any_child_atten_6==1) 
replace hh_child_atten_u = . if any_child_atten_6==.
replace hh_child_atten_u = 1 if hh_children_schoolage_6==0
replace hh_child_atten_u = . if hh_child_atten_u==0 & no_missing_atten_u==0 
lab var hh_child_atten_u "Household has at least one school age children up to class 6 in school"
tab hh_child_atten_u, miss


********************************************************************************
*** Step 2.3 Nutrition ***
********************************************************************************
 
********************************************************************************
*** Step 2.3a Child Nutrition ***
********************************************************************************


*** Child Underweight Indicator ***
************************************************************************

*** Standard MPI ***
bysort hh_id: egen temp = max(underweight)
gen	hh_no_underweight = (temp==0) 
	//Takes value 1 if no child in the hh is underweight 
replace hh_no_underweight = . if temp==.
replace hh_no_underweight = 1 if no_child_eligible==1 
	//Households with no eligible children will receive a value of 1
lab var hh_no_underweight "Household has no child underweight - 2 stdev"
drop temp


*** Destitution MPI  ***
bysort hh_id: egen temp = max(underweight_u)
gen	hh_no_underweight_u = (temp==0) 
replace hh_no_underweight_u = . if temp==.
replace hh_no_underweight_u = 1 if no_child_eligible==1 
lab var hh_no_underweight_u "Destitute: Household has no child underweight"
drop temp


*** Child Stunting Indicator ***
************************************************************************

*** Standard MPI ***
bysort hh_id: egen temp = max(stunting)
gen	hh_no_stunting = (temp==0) 
	//Takes value 1 if no child in the hh is stunted
replace hh_no_stunting = . if temp==.
replace hh_no_stunting = 1 if no_child_eligible==1 
	//Households with no eligible children will receive a value of 1
lab var hh_no_stunting "Household has no child stunted - 2 stdev"
drop temp


*** Destitution MPI  ***
bysort hh_id: egen temp = max(stunting_u)
gen	hh_no_stunting_u = (temp==0) 
replace hh_no_stunting_u = . if temp==.
replace hh_no_stunting_u = 1 if no_child_eligible==1 
lab var hh_no_stunting_u "Destitute: Household has no child stunted"
drop temp


*** Child Either Underweight or Stunted Indicator ***
************************************************************************

*** Standard MPI ***
gen uw_st = 1 if stunting==1 | underweight==1
replace uw_st = 0 if stunting==0 & underweight==0
replace uw_st = . if stunting==. & underweight==.
bysort hh_id: egen temp = max(uw_st)
gen	hh_no_uw_st = (temp==0) 
replace hh_no_uw_st = . if temp==.
replace hh_no_uw_st = 1 if no_child_eligible==1
drop temp
lab var hh_no_uw_st "Household has no child underweight or stunted"


*** Destitution MPI  ***
gen uw_st_u = 1 if stunting_u==1 | underweight_u==1
replace uw_st_u = 0 if stunting_u==0 & underweight_u==0
replace uw_st_u = . if stunting_u==. & underweight_u==.
bysort hh_id: egen temp = max(uw_st_u)
gen	hh_no_uw_st_u = (temp==0) 
replace hh_no_uw_st_u = . if temp==.
replace hh_no_uw_st_u = 1 if no_child_eligible==1 
drop temp
lab var hh_no_uw_st_u "Destitute: Household has no child underweight or stunted"


********************************************************************************
*** Step 2.3b Household Nutrition Indicator ***
********************************************************************************

*** Standard MPI ***
/* The indicator takes value 1 if the household has no child under 5 who 
has either height-for-age or weight-for-age that is under 2 stdev below 
the median. It also takes value 1 for the households that have no eligible 
children. The indicator takes a value of missing only if all eligible 
children have missing information in their respective nutrition variable. */
************************************************************************

gen	hh_nutrition_uw_st = 1
replace hh_nutrition_uw_st = 0 if hh_no_uw_st==0
replace hh_nutrition_uw_st = . if hh_no_uw_st==.
replace hh_nutrition_uw_st = 1 if no_child_eligible==1   
 	/*We replace households that do not have the applicable population, that is, 
	children 0-5, as non-deprived in nutrition*/		
lab var hh_nutrition_uw_st "Household has no individuals malnourished"
tab hh_nutrition_uw_st, miss 


*** Destitution MPI ***
/* The indicator takes value 1 if the household has no child under 5 who 
has either height-for-age or weight-for-age that is under 2 stdev below 
the median. It also takes value 1 for the households that have no eligible 
children. The indicator takes a value of missing only if all eligible 
children have missing information in their respective nutrition variable. */
************************************************************************

gen	hh_nutrition_uw_st_u = 1
replace hh_nutrition_uw_st_u = 0 if hh_no_uw_st_u==0
replace hh_nutrition_uw_st_u = . if hh_no_uw_st_u==.
replace hh_nutrition_uw_st_u = 1 if no_child_eligible==1   
 	/*We replace households that do not have the applicable population, that is, 
	children 0-5, as non-deprived in nutrition*/		
lab var hh_nutrition_uw_st_u "Household has no individuals malnourished (destitution)"
tab hh_nutrition_uw_st_u, miss 


********************************************************************************
*** Step 2.4 Child Mortality ***
********************************************************************************

codebook cm9 cm10 mcm9 mcm10
	/*cm9 or mcm9: number of sons who have died 
	  cm10 or mcm10: number of daughters who have died */
	  
egen temp_f = rowtotal(cm9 cm10), missing
	//Total child mortality reported by eligible women
replace temp_f = 0 if cm1==1 & cm8==2 | cm1==2 
	/*Assign a value of "0" for:
	- all eligible women who have ever gave birth but reported no child death 
	- all eligible women who never ever gave birth */
replace temp_f = 0 if no_fem_eligible==1	
	/*Assign a value of "0" for:
	- individuals living in households that have non-eligible women */
bysort	hh_id: egen child_mortality_f = sum(temp_f), missing
lab var child_mortality_f "Occurrence of child mortality reported by women"
tab child_mortality_f, miss
drop temp_f	

egen temp_m = rowtotal(mcm9 mcm10), missing
	//Total child mortality reported by eligible men	
replace temp_m = 0 if mcm1==1 & mcm8==2 | mcm1==2 
	/*Assign a value of "0" for:
	- all eligible men who ever fathered children but reported no child death 
	- all eligible men who never fathered children */
replace temp_m = 0 if no_male_eligible==1	
	/*Assign a value of "0" for:
	- individuals living in households that have non-eligible women */
bysort	hh_id: egen child_mortality_m = sum(temp_m), missing	
lab var child_mortality_m "Occurrence of child mortality reported by men"
tab child_mortality_m, miss
drop temp_m

egen child_mortality = rowmax(child_mortality_f child_mortality_m)
lab var child_mortality "Total child mortality within household"
tab child_mortality, miss

	
*** Standard MPI *** 
/* The standard MPI indicator takes a value of "0" if women in the household 
reported mortality among children under 18 in the last 5 years from the survey 
year. The indicator takes a value of "1" if eligible women within the household 
reported (i) no child mortality or (ii) if any child died longer than 5 years 
from the survey year or (iii) if any child 18 years and older died in the last 
5 years. Households were replaced with a value of "1" if eligible 
men within the household reported no child mortality in the absence of 
information from women. The indicator takes a missing value if there was 
missing information on reported death from eligible individuals. */
************************************************************************

tab childu18_died_per_wom_5y, miss
	/* The 'childu18_died_per_wom_5y' variable was constructed in Step 1.2 using 
	information from individual women who ever gave birth in the BH file. The 
	missing values represent eligible woman who have never ever given birth and 
	so are not present in the BR file. But these 'missing women' may be living 
	in households where there are other women with child mortality information 
	from the BH file. So at this stage, it is important that we aggregate the 
	information that was obtained from the BH file at the household level. This
	ensures that women who were not present in the BH file is assigned with a 
	value, following the information provided by other women in the household.*/		
replace childu18_died_per_wom_5y = 0 if cm1==2 															   
	/*Assign a value of "0" for:
	- all eligible women who never ever gave birth */
replace childu18_died_per_wom_5y = 0 if no_fem_eligible==1	
	/*Assign a value of "0" for:
	- individuals living in households that have non-eligible women */
	
bysort hh_id: egen childu18_mortality_5y = sum(childu18_died_per_wom_5y), missing
replace childu18_mortality_5y = 0 if childu18_mortality_5y==. & child_mortality==0
	/*Replace all households as 0 death if women has missing value and men 
	reported no death in those households */
label var childu18_mortality_5y "Under 18 child mortality within household past 5 years reported by women"
tab childu18_mortality_5y, miss		
	
gen hh_mortality_u18_5y = (childu18_mortality_5y==0)
replace hh_mortality_u18_5y = . if childu18_mortality_5y==.
lab var hh_mortality_u18_5y "Household had no under 18 child mortality in the last 5 years"
tab hh_mortality_u18_5y, miss 


*** Destitution MPI *** 
*** (same as standard MPI) ***
************************************************************************
clonevar hh_mortality_u = hh_mortality_u18_5y	

				
********************************************************************************
*** Step 2.5 Electricity ***
********************************************************************************

*** Standard MPI ***
/*Members of the household are considered deprived 
if the household has no electricity */
****************************************

clonevar electricity = hc8 
codebook electricity, tab (9)
replace electricity = 1 if electricity==2
replace electricity = 0 if electricity==3
	//0=no; 1=yes 
replace electricity = . if electricity==9 
	//Replace missing values 
label define lab_elec 1 "have electricity" 0 "no electricity"
label values electricity lab_elec	
label var electricity "Household has electricity"
tab electricity, miss


*** Destitution MPI  ***
*** (same as standard MPI) ***
****************************************

gen electricity_u = electricity
label var electricity_u "Household has electricity"


********************************************************************************
*** Step 2.6 Sanitation ***
********************************************************************************

/*
Improved sanitation facilities include flush or pour flush toilets to sewer 
systems, septic tanks or pit latrines, ventilated improved pit latrines, pit 
latrines with a slab, and composting toilets. These facilities are only 
considered improved if it is private, that is, it is not shared with other 
households.
Source: https://unstats.un.org/sdgs/metadata/files/Metadata-06-02-01.pdf

Note: In cases of mismatch between the country report and the internationally 
agreed guideline, we followed the report.
*/

/*Mongolia MICS 2018: Most of the pit latrines being used by ger district 
households do not have porous lining which isolates the excreta in latrines 
from the soil and are considered to be not met with hygiene standards, thus 
excluded improved sanitation facilities. (p. 265)

Table WS.3.1 in p. 266 provides % using improved sanitation (international) and
% using improved sanitation (national = does not include pit latrine with slab)*/ 

desc ws11 ws15  
clonevar toilet = ws11  
	
clonevar shared_toilet = ws15 
codebook shared_toilet, tab(99)  
recode shared_toilet (2=0)
replace shared_toilet=. if shared_toilet==9
tab ws11 shared_toilet, miss nol
	
		
*** Standard MPI ***
/*Members of the household are considered deprived if the household's 
sanitation facility is not improved (according to the SDG guideline) 
or it is improved but shared with other households*/
********************************************************************
codebook toilet, tab(99) 
gen	toilet_mdg = ((toilet<=21 | toilet==31) & shared_toilet!=1) 
	/*Household is assigned a value of '1' if it uses improved sanitation and 
	does not share toilet with other households  */
	
	/*Mongolia MICS 2018: 22 = "pit latrine with slab". 
	Coded as unimproved, as suggested by the national guidelines 
	(p. 265 and 266 of the country survey report).*/
	
replace toilet_mdg = 0 if (toilet<=21 | toilet==31)  & shared_toilet==1 
	/*Household is assigned a value of '0' if it uses improved sanitation 
	but shares toilet with other households  */
			
replace toilet_mdg = . if toilet==.  | toilet==99	
	//Missing value

replace toilet_mdg = 0 if shared_toilet==1	
	/*It may be the case that there are individuals who did not respond on the 
	type of toilet, but they indicated that they share their toilet facilities. 
	In such case, we replace these individuals as deprived following the 
	information on shared toilet.*/	
lab var toilet_mdg "Household has improved sanitation"
tab toilet toilet_mdg, miss
tab toilet_mdg, miss	

	
*** Destitution MPI ***
/*Members of the household are considered deprived if household practises 
open defecation or uses other unidentifiable sanitation practises */
********************************************************************
gen	toilet_u = .

replace toilet_u = 0 if toilet==95 | toilet==96 
	/*Household is assigned a value of '0' if it practises open defecation or 
	others */

replace toilet_u = 1 if toilet!=95 & toilet!=96 & toilet!=99
	/*Household is assigned a value of '1' if it does not practise open 
	defecation or others  */

lab var toilet_u "Household does not practise open defecation or others"
tab toilet toilet_u, miss


*** Quality check ***
/* We compare the proportion of household members with 
improved sanitation obtained from our work and as 
reported in the country survey report. */
*********************************************************
tab toilet_mdg [aw = weight],m
	/*In the report, Table WS.3.2 (p.267) indicate that 69% of 
	household members have improved sanitation facilities that are not shared. 
	The results obtained from our work is 31.92%. The differences is because
	we have coded "pit latrine with slab" as non-improved, hence we have a
	lower % of population with improved facility than reported in Table WS.3.3. 
	Please note, our decision is based on the national guideline which is 
	stated in the country survey report (p.265).*/


********************************************************************************
*** Step 2.7 Drinking Water  ***
********************************************************************************

/*
Improved drinking water sources include the following: piped water into 
dwelling, yard or plot; public taps or standpipes; boreholes or tubewells; 
protected dug wells; protected springs; packaged water; delivered water and 
rainwater which is located on premises or is less than a 30-minute walk from 
home roundtrip. 
Source: https://unstats.un.org/sdgs/metadata/files/Metadata-06-01-01.pdf

Note: In cases of mismatch between the country report and the internationally 
agreed guideline, we followed the report.
*/

clonevar water = ws1  
clonevar timetowater = ws4  
clonevar ndwater = ws2  	


*** Standard MPI ***
/* Members of the household are considered deprived if the household 
does not have access to improved drinking water (according to the SDG 
guideline) or safe drinking water is at least a 30-minute walk from 
home, roundtrip */
********************************************************************
codebook water, tab(99)
gen	water_mdg = 1 if water==11 | water==12 | water==21 | water==31 | ///
					 water==41 | water==51 | water==61 | water==71 | ///
					 water==91 | water==72 | water==73
					 
	/*Non deprived if water is piped into dwelling, piped to yard/plot, 
	public tap/standpipe, tube well or borehole, protected well, 
	protected spring, rainwater, bottled water, packaged water.*/
		
	
	/* Note: Water kiosk connected with piped water (72) and not connected 
	with piped water (73) are considered improved following the survey report.*/
	
replace water_mdg = 0 if water==32 | water==42 | water==81 | ///
						 water==96 | water==22
	/*Deprived if it is (borehole/dug well) unprotected well, unprotected spring,
	surface water (river/lake, etc), other*/
	
replace water_mdg = . if water==99 | water==.	
	//Missing value	
lab var water_mdg "Household has safe drinking water on premises"
tab water water_mdg, miss	
tab water_mdg, miss


*** Quality check ***
/* We compare the proportion of household members with 
improved access to safe drinking water as obtained from 
our work and as reported in the country survey report. */
*********************************************************
tab water_mdg [aw = weight],miss
	/*In the report, Table WS.1.1 (p.255), xx% of household members 
	have improved or safe drinking facilities. The results obtained from our 
	work is 86.92% which matches the report. */	 

	
*** Time to water ***	
********************************************************* 
codebook timetowater, tab(999)	

replace water_mdg = 0 if water_mdg==1 & timetowater >= 30 & timetowater!=. & ///
						 timetowater!=998 & timetowater!=999
	/*Deprived if water is at more than 30 minutes' walk (roundtrip).*/
	
tab timetowater if water==99 | water==.,miss	
replace water_mdg = 0 if (water==99 | water==.) & water_mdg==. & ///
						  timetowater >= 30 & timetowater!=. & ///
						  timetowater!=998 & timetowater!=999 
	/*It may be the case that there are individuals who did not respond on their 
	source of drinking water, but they indicated the water source is 30 minutes 
	or more from home, roundtrip. In such case, we replace these individuals as
	deprived following the information on distance to water.*/			
tab water_mdg, miss	  	


*** Destitution MPI ***
/* Members of the household is identified as destitute if household 
does not have access to safe drinking water, or safe water is more 
than 45 minute walk from home, round trip.*/
********************************************************************
gen	water_u = .
replace water_u = 1 if water==11 | water==12 | water==21 | water==31 | ///
					   water==41 | water==51 | water==61 | water==71 | ///
					   water==91 | water==72 | water==73  
					   
replace water_u = 0 if water==32 | water==42 | water==81 | ///
					   water==96 | water==22
					   
replace water_u = 0 if water_u==1 & timetowater> 45 & timetowater!=. ///
					   & timetowater!=998 & timetowater!=999 	
					   
replace water_u = . if water==99 | water==.						
lab var water_u "Household has safe drinking water (considering distance)"
tab water water_u, miss


********************************************************************************
*** Step 2.8 Housing ***
********************************************************************************

/* Members of the household are considered deprived if the household 
has a dirt, sand or dung floor */
lookfor floor sol 
tab hc4 hc1e, miss
clonevar floor = hc4
codebook floor, tab(99)
clonevar floor_g = hc1e 
codebook floor_g, tab(99)
	/* Note: In Mongolia, flooring is recorded separately for households 
	living in gers/yurts/tents.*/ 
gen	floor_imp = 1
replace floor_imp = 0 if floor<=12 | floor==96 
	//Deprived if mud/earth, sand, dung, other 	
replace floor_imp = . if floor==. | floor==98 	
replace floor_imp = 0 if (floor_g<=12 | floor_g==96) & floor==.
	/* Note: In Mongolia, households living in gers are considered deprived if 
	the floor is natural floor or other floor. */
replace floor_imp = 1 if (floor_g == 21 | floor_g == 34) & floor==.
	/* Mongolia MICS 2018: households living in gers are considered 
	non-deprived if the floor is wood or cement.*/			
replace floor_imp = . if floor==. & floor_g==.
lab var floor_imp "Household has floor that is not earth/sand/dung"
tab floor floor_imp, miss
tab floor_imp, miss


/* Members of the household are considered deprived if the household has walls 
made of natural or rudimentary materials. We followed the report's definitions
of natural or rudimentary materials. */

/* Mongolia MICS 2018: concerning the walls, p. 558 of the report has a question
(hc1g) on whether the exterior wall of the ger has a single or multiple layer.*/

lookfor wall mur
tab hc6 hc1g, miss
clonevar wall = hc6
codebook wall, tab(99) 
clonevar wall_g = hc1g 
codebook wall_g, tab(99) 
/* Mongolia MICS 2018: the 21, 889 correspond to those households that have ger
housing and have answered whether the walls of their ger has a single or 
multiple layer. */

gen	wall_imp = 1 
replace wall_imp = 0 if wall<=22 | wall==96 
	/*Deprived if no wall, cane/palms/trunk, mud/dirt, 
	grass/reeds/thatch, pole/bamboo with mud, stone with mud, plywood,
	cardboard, carton/plastic, uncovered adobe, canvas/tent, 
	unburnt bricks, reused wood, other */		
replace wall_imp = . if wall==. | wall==99
replace wall_imp = 0 if wall_g==1 & wall==.
	//Mongolia MICS 2018: We consider gers with single layers as deprived.
replace wall_imp = 1 if wall_g==2 & wall==.
replace wall_imp = . if (wall_g==. | wall_g==9) & wall==.
lab var wall_imp "Household has wall that it is not of low quality materials"
tab wall wall_imp, miss	
tab wall_imp, miss	

		
/* Members of the household are considered deprived if the household has roof 
made of natural or rudimentary materials. We followed the report's definitions
of natural and rudimentary materials. */

/* Mongolia MICS 2018: concerning the roof, p. 558 of the report has a question
(hc1f) on whether the roof of the ger has a single or multiple layer. */

lookfor roof toit
tab hc5 hc1f, miss
clonevar roof = hc5
codebook roof, tab(99)
clonevar roof_g = hc1f 
codebook roof_g, tab(99) 
	/* Mongolia MICS 2018: the 21, 889 correspond to those households that have 
	ger housing and have answered whether the roof of their ger has a single or 
	multiple layer. */	
gen	roof_imp = 1 
replace roof_imp = 0 if roof<=23  | roof==96
	/*Deprived if no roof, thatch/palm leaf, mud/earth/lump of earth, 
	sod/grass, plastic/polythene sheeting, rustic mat, cardboard, 
	canvas/tent, wood planks/reused wood, unburnt bricks, other */	
replace roof_imp = . if roof==. | roof==99
replace roof_imp = 0 if roof_g==1 & roof==.
	//Mongolia MICS 2018: We consider gers with single layers as deprived.	
replace roof_imp = 1 if roof_g==2 & roof==.
replace roof_imp = . if (roof_g==. | roof_g==9) & roof==.
lab var roof_imp "Household has roof that it is not of low quality materials"
tab roof roof_imp, miss
tab roof_imp, miss 


*** Standard MPI ***
/* Members of the household is deprived in housing if the roof, 
floor OR walls are constructed from low quality materials.*/
**************************************************************
gen housing_1 = 1
replace housing_1 = 0 if floor_imp==0 | wall_imp==0 | roof_imp==0
replace housing_1 = . if floor_imp==. & wall_imp==. & roof_imp==.
lab var housing_1 "Household has roof, floor & walls that it is not low quality material"
tab housing_1, miss 


*** Destitution MPI ***
/* Members of the household is deprived in housing if two out 
of three components (roof and walls; OR floor and walls; OR 
roof and floor) the are constructed from low quality materials. */
**************************************************************
gen housing_u = 1
replace housing_u = 0 if (floor_imp==0 & wall_imp==0 & roof_imp==1) | ///
						 (floor_imp==0 & wall_imp==1 & roof_imp==0) | ///
						 (floor_imp==1 & wall_imp==0 & roof_imp==0) | ///
						 (floor_imp==0 & wall_imp==0 & roof_imp==0)
replace housing_u = . if floor_imp==. & wall_imp==. & roof_imp==.
lab var housing_u "Household has one of three aspects(either roof,floor/walls) that is not low quality material"
tab housing_u, miss 


********************************************************************************
*** Step 2.9 Cooking Fuel ***
********************************************************************************

/*
Solid fuel are solid materials burned as fuels, which includes coal as well as 
solid biomass fuels (wood, animal dung, crop wastes and charcoal). 

Source: 
https://apps.who.int/iris/bitstream/handle/10665/141496/9789241548885_eng.pdf
*/

lookfor cooking combustible energy
	/*Note: eu4 and eu1 is only present in newer MICS surveys. Previously, there 
	was only information on eu1, with slightly different categories. As such,
	we have made adjustment to the codes below, to take into account of the 
	additional information that is now available in the newer MICS. */
clonevar cookingfuel = eu4 
	//eu4 = type of fuel or energy source used for the cookstove

	
*** Standard MPI ***
/* Members of the household are considered deprived if the 
household uses solid fuels and solid biomass fuels for cooking. */
*****************************************************************
codebook eu1 cookingfuel, tab(99)
tab eu1 cookingfuel, miss

/*
    Type of cookstove |
      mainly used for |                                Type of energy source for cookstove
              cooking | COAL/ LIG       WOOD  CROP RESI  ANIMAL DU  PROCESSED    SAWDUST  IMPROVED   OTHER (sp          . |     Total
----------------------+---------------------------------------------------------------------------------------------------+----------
ELECTRIC STOVE/ COOKE |         0          0          0          0          0          0          0          0     17,063 |    17,063 
LIQUEFIED PETROLEUM G |         0          0          0          0          0          0          0          0        555 |       555 
MANUFACTURED SOLID FU |     1,497        644         25        377          6          2          0          0          0 |     2,551 
TRADITIONAL SOLID FUE |     6,351     10,929        313     11,931         19         18          1          5          0 |    29,567 
THREE STONE STOVE / O |        27         19          0         34          0          0          0          0          0 |        80 
      OTHER (specify) |        10          0          0          0          0          0          0          0          0 |        10 
NO FOOD COOKED IN HOU |         0          0          0          0          0          0          0          0         13 |        13 
----------------------+---------------------------------------------------------------------------------------------------+----------
                Total |     7,885     11,592        338     12,342         25         20          1          5     17,631 |    49,839 
*/

gen	cooking_mdg = 1
replace cooking_mdg = 0 if cookingfuel>=4 & cookingfuel<=12 
	/* Deprived if: coal/lignite, charcoal, wood, straw/shrubs/grass, 
					agricultural crop, animal dung, woodchips, sawdust 
					Note: improved fuel is not an indication of non-solid
					fuel, hence we identify this category as deprived. */	
replace cooking_mdg = 0 if eu1==96 
	/*The cross tab between eu1 and eu4 indicate that the 10 individuals who
	reported using other type of cookstove have used solid fuel (coal/lignite)
	on the cookstove. As such, we identify all individuals who reported using 
	other fuel on cookstove as deprived. */
	
replace cooking_mdg = 0 if cookingfuel==96 
	/*We have identified all 5 individuals who use traditional solid fuel stove 
	with other forms of cooking fuel as deprived. This is because, the
	nature of the stove suggest that the fuel that is used is most likely not 
	clean.*/	
replace cooking_mdg = . if cookingfuel==99 	& eu1==99
	/*Individuals who did not respond to type of cookstove and type of 
	energy source for cookstove has been identified as missing. */
lab var cooking_mdg "Household cooks with clean fuels"	
tab cookingfuel cooking_mdg, miss
tab eu1 if cookingfuel==. & cooking_mdg==1, miss 	
tab cooking_mdg, miss 


*** Destitution MPI *** 
*** (same as standard MPI) ***
****************************************	
gen	cooking_u = cooking_mdg
lab var cooking_u "Household cooks with clean fuels"


********************************************************************************
*** Step 2.10 Assets ownership ***
********************************************************************************

*** Television/LCD TV/plasma TV/color TV/black & white tv
lookfor tv television plasma lcd télé
codebook hc9a
clonevar television = hc9a 
lab var television "Household has television"
tab television, miss
	//3.27% missing value 
tab electricity television, miss
	/*This is because these households do not have electricity.*/
replace television=0 if electricity==0 & television==.	
	/*We make an assumption that there is no television in these households 
	given that there is no electricity.*/

		
***	Radio/walkman/stereo/kindle
lookfor radio walkman stereo stéréo
codebook hc7b
clonevar radio = hc7b 
lab var radio "Household has radio"	



***	Handphone/telephone/iphone/mobilephone/ipod
lookfor telephone téléphone mobilephone ipod
codebook hc7a hc12
	/*Mongolia MICS 2018: the coding of the mobile phone variable is: 
	1 = yes, smartphone; 2 = yes, analogue; 3 = yes, both smartphone and analogue; 
	4 = no; 9 = no response. Therefore, the line above has been adapted to take
	this coding into account.*/
clonevar telephone =  hc7a
replace telephone=1 if telephone!=1 & (hc12==1 | hc12==2| hc12==3)
	//hc12=mobilephone. Combine information on telephone and mobilephone.		
tab hc7a hc12 if telephone==1,miss
lab var telephone "Household has telephone (landline/mobilephone)"	

	
***	Refrigerator/icebox/fridge
lookfor refrigerator freezer réfrigérateur
codebook hc9b hc9c
clonevar refrigerator = hc9b 
lab var refrigerator "Household has refrigerator"
tab refrigerator, miss
	//3.27% missing value 
tab electricity refrigerator, miss
	//This is because these households do not have electricity.
replace refrigerator=0 if electricity==0 & refrigerator==.	
	/*We make an assumption that there is no refrigerator in these households 
	given that there is no electricity. */
replace refrigerator=1 if refrigerator!=1 & hc9c==1	
tab hc9b hc9c if refrigerator==1,miss


***	Car/van/lorry/truck
lookfor car voiture truck van
codebook hc10e hc10f hc10g 

 /* Mongolia MICS 2018: hc10f = any member of household own: Sedan car; 
 hc10g = any member of household own: Truck. These variables are used in order 
 to code the car/truck indicator. Thus, the line of code below is adapted */
 
tab hc10f hc10g, miss 
	//5,982 households without sedan car but with truck 

clonevar car = hc10f 
replace car = 1 if car!=1 & hc10g==1 
lab var car "Household has car"		

	
***	Bicycle/cycle rickshaw
lookfor bicycle bicyclette
codebook hc10b
clonevar bicycle = hc10b 
lab var bicycle "Household has bicycle"	
	
	
***	Motorbike/motorized bike/autorickshaw
lookfor motorbike moto
codebook hc10c	
clonevar motorbike = hc10c
lab var motorbike "Household has motorbike"

	
***	Computer/laptop/tablet
lookfor computer ordinateur laptop ipad tablet
codebook hc11
clonevar computer = hc11
lab var computer "Household has computer"


***	Animal cart
lookfor brouette charrette cart
codebook hc10d
gen animal_cart = hc10d
lab var animal_cart "Household has animal cart"	
 
 
foreach var in television radio telephone refrigerator car ///
			   bicycle motorbike computer animal_cart {
replace `var' = 0 if `var'==2 
label define lab_`var' 0"No" 1"Yes"
label values `var' lab_`var'			   
replace `var' = . if `var'==9 | `var'==99 | `var'==8 | `var'==98 
}
	//Labels defined and missing values replaced	
	

*** Standard MPI ***
/* Members of the household are considered deprived in assets if the household 
does not own more than one of: radio, TV, telephone, bike, motorbike, 
refrigerator, computer or animal cart and does not own a car or truck.*/
*****************************************************************************
egen n_small_assets2 = rowtotal(television radio telephone refrigerator bicycle motorbike computer animal_cart), missing
lab var n_small_assets2 "Household Number of Small Assets Owned" 
   
gen hh_assets2 = (car==1 | n_small_assets2 > 1) 
replace hh_assets2 = . if car==. & n_small_assets2==.
lab var hh_assets2 "Household Asset Ownership: HH has car or more than 1 small assets incl computer & animal cart"
tab hh_assets2, miss


*** Destitution MPI ***
/* Members of the household are considered deprived in assets if the household 
does not own any assets.*/
*****************************************************************************	
gen	hh_assets2_u = (car==1 | n_small_assets2>0)
replace hh_assets2_u = . if car==. & n_small_assets2==.
lab var hh_assets2_u "Household Asset Ownership: HH has car or at least 1 small assets incl computer & animal cart"


********************************************************************************
*** Step 2.11 Rename and keep variables for MPI calculation 
********************************************************************************
	

	//Retain data on sampling design: 
*gen psu = hh1	
clonevar strata = stratum


	//Retain year, month & date of interview:
desc hh5y hh5m hh5d 
clonevar year_interview = hh5y 	
clonevar month_interview = hh5m 
clonevar date_interview = hh5d 


	//Generate presence of subsample
gen subsample = .
 

*** Rename key global MPI indicators for estimation ***
recode hh_mortality_u18_5y  (0=1)(1=0) , gen(d_cm)
recode hh_nutrition_uw_st 	(0=1)(1=0) , gen(d_nutr)
recode hh_child_atten 		(0=1)(1=0) , gen(d_satt)
recode hh_years_edu6 		(0=1)(1=0) , gen(d_educ)
recode electricity 			(0=1)(1=0) , gen(d_elct)
recode water_mdg 			(0=1)(1=0) , gen(d_wtr)
recode toilet_mdg 			(0=1)(1=0) , gen(d_sani)
recode housing_1 			(0=1)(1=0) , gen(d_hsg)
recode cooking_mdg 			(0=1)(1=0) , gen(d_ckfl)
recode hh_assets2 			(0=1)(1=0) , gen(d_asst)
 

*** Rename key global MPI indicators for destitution estimation ***
recode hh_mortality_u       (0=1)(1=0) , gen(dst_cm)
recode hh_nutrition_uw_st_u (0=1)(1=0) , gen(dst_nutr)
recode hh_child_atten_u 	(0=1)(1=0) , gen(dst_satt)
recode hh_years_edu_u 		(0=1)(1=0) , gen(dst_educ)
recode electricity_u		(0=1)(1=0) , gen(dst_elct)
recode water_u 				(0=1)(1=0) , gen(dst_wtr)
recode toilet_u 			(0=1)(1=0) , gen(dst_sani)
recode housing_u 			(0=1)(1=0) , gen(dst_hsg)
recode cooking_u			(0=1)(1=0) , gen(dst_ckfl)
recode hh_assets2_u 		(0=1)(1=0) , gen(dst_asst) 
 

*** Total number of missing values  for each variable *** 
mdesc psu strata area age ///
d_cm d_nutr d_satt d_educ d_elct d_wtr d_sani d_hsg d_ckfl d_asst 


*** Keep main variables require for MPI calculation ***
keep hh_id ind_id psu strata subsample weight area region agec4 agec2 ///
d_cm d_nutr d_satt d_educ d_elct d_wtr d_sani d_hsg d_ckfl d_asst 

order hh_id ind_id psu strata subsample weight area region agec4 agec2 ///
d_cm d_nutr d_satt d_educ d_elct d_wtr d_sani d_hsg d_ckfl d_asst 

 
 
*** Generate coutry and survey details for estimation ***
char _dta[cty] "Mongolia"
char _dta[ccty] "MNG"
char _dta[year] "2018" 	
char _dta[survey] "MICS"
char _dta[ccnum] "496"
char _dta[type] "micro"
char _dta[class] "new_survey"

	
*** Sort, compress and save data for estimation ***
sort ind_id
compress
la da "Micro data for `_dta[ccty]' (`_dta[ccnum]') from `c(current_date)' (`c(current_time)')."
save "$path_out/mng_mics18.dta", replace
