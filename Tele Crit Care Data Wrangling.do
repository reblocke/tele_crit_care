* Data pre-processing
clear

// Brian Locke, MD MSCI
// Assistant Professor, Clinical Investigation. Intermountain Medical Center
// Last updated Dec 26 2024

/* 

Purpose: this script merges data from several Excel spreadsheets to a tabular format: 
- 1 line per patient
- dates indexed to day of transfer. 

A separate .do files contains the analytic files. 

Source Spreadsheets: 
1. "Info, apache mortality" sheet processing; 3718 patients; 4123 admits
(+several pages corresponding to specific interventions)
2.  Code Status: 4023 patients; 4023 admissions 
3.  Chronic Conditions Initial Group: 5160 patients. ; 5770 icu admits (some extra)
4.  Chronic conditions Missing Group 1-3: In total, this contains data from 1808 patients. 1930 admits
5. "Missing APACHE patients, merged.xlsx" 1322 patients; 1394 icu admissions
6. Active treatments per day.xlsx 3740 patients; 4118 admits
(Active treatments per admit and active treatments per stay number not used because they contain only redundant information)

7-12.  Reviewer assessment of eaach of the process metrics for the subset of patients who transferred. 
-- there are 5 raters. together, each patient was reviewed by 2 of the raters for several process measures relating to the care they received up until the point of transfer. 

Raw Data\Reviewer 1 - RB_completed.xlsx
Raw Data\Reviewer 2_BK_completed.xlsx
Raw Data\Reviewer 3 CL_complete.xlsx
Raw Data\Reviewer 4- KR_complete.xlsx
Raw Data\Reviewer 5, JG_completed.xlsx


Input Data specification: 

- All patients admitted to a tele-facility and transferred have a hospital discharge location of "another hospitals ICU"
- The MRN for each patient will remain consistent across admissions/encounters
- The FIN (or hospital account number) will be consistent with each encounter, i.e. same FIN for tele-facility admission and then upon arrival at referral facility will have a different FIN for that admission. MRN will remain the same.
- Not specified as discharge destination = death

There will be an initial row entry that corresponds to the initial admission with discharge to Another Hospital's ICU
There will be a post-transfer ICU admission. 
-Discharge-to and admit times must be within 24h ***

Patients who are not transferred may have 
- just 1 admission
- an admission and a readmission 

Combining method: 
Link based on MRN+Admit time to identify a unique admission
Combine all the comorbidity, intervention, apache data per intervention
Then, flag which ones involved an ICU to ICU transfer: Discharge Location: to another ICU and a discharge time within 48hours of another admit. 
Then, keep those that are involved in either a pre- or a post- transfer hospitalization
For procedures, I truncated days at hospital day 50 (mainly because stata basic limits to 2400 variable names which we were reaching)
tatus


Ultimately - the analyatic dataset contains: 
***

Versions in wide (1 row per patient, different columns for each day) and long (different row for each patient x day)

These are indexed to the day of TRANSFER. 
Day Below 100 = Pretransfer
Day 100 = last day of pre-transfer
Day 101 = first day of post-transfer


Dataset chars:

Entire dataset, 'All combined': 
Number of unique MRNs: 5742
Number of unique ICU Admits: 6514

For Transfers: 
- excluded repeat transfers
n=335, each which contains a pre- and a post- transfer hospital course. 
- all transfer courses where there is an intubation were reviewed by two raters.
-- agreement statistics for these agreements go to "rater_agreement.txt"

TODO: 

FOR LATER - From Jeff
[ ] are TIS scores coming?  "I need to get the active treatments (TISS scores) pulled in a different way, but that's not important for us to start chart review. I also need to get the code status changes for the new missing patients. I'll send those to you within the next couple of days."

//Data-oddities: 
- I'm not sure why so many of the reintubations occur before ICU admit (e.g. Day "0") - seems odd for a REintubation. 
e.g.****L - reintubation noted ICU day 2, but 

[ ] ??Not sure what this means? Preprocessing Reminder: for active treaetments per day, chronic conditions initial group, and cumulatives scores per day - must remove the "blocks" by hospital in the spreadsheet and fill in the ICU-s

*/ 

cd "/Users/blocke/Box Sync/Residency Personal Files/Scholarly Work/Locke Research Projects/Tele Crit Care/tele_crit_care" //Mac version
//cd "C:\Users\reblo\Box\Residency Personal Files\Scholarly Work\Locke Research Projects\Tele Crit Care\tele_crit_care" //PC version

capture mkdir "Results and Figures"
capture mkdir "Results and Figures/$S_DATE/" //make new folder for figure output if needed
capture mkdir "Results and Figures/$S_DATE/Logs/" //new folder for stata logs
local a1=substr(c(current_time),1,2)
local a2=substr(c(current_time),4,2)
local a3=substr(c(current_time),7,2)
local b = "Tele Crit Care Data Wrangling.do" // do file name
copy "`b'" "Results and Figures/$S_DATE/Logs/(`a1'_`a2'_`a3')`b'"

set scheme cleanplots
graph set window fontface "Helvetica"

capture log close
log using "Results and Figures/$S_DATE/Logs/temp.log", append

/*
"Info, apache mortality" sheet processing; 3718 patients; 4123 admits
*/ 
import excel using "Raw Data\V1 COVID dataset from APACHE.xlsx", sheet("Info, apache mortality") firstrow case(lower) clear
ds, has(type string) //convert each string to 64 length (for later merging)
local stringvars `r(varlist)'
foreach var of local stringvars {
    replace `var' = trim(`var')
    recast str64 `var'
}
destring(mrn hospitalaccountnumber), ignore("" "n/a" "-" "na") replace
keep if !missing(mrn)

gen icu_admit_name = string(icuadmissiondatetime) + "-" + string(mrn, "%12.0f")
label variable icu_admit_name "ICU-Identifier: Admit date - MRN"

quietly levelsof mrn, local(mrnLevels)
quietly levelsof icu_admit_name, local(icuAdmitNameLevels)
di "Number of unique MRN: " `: word count `mrnLevels''
di "Number of unique ICU Admits: " `: word count `icuAdmitNameLevels''

//reshape from long->wide format
rename apacheiiiscore apache_3_score_day_
rename acutephysiologyscoreaps aps_day_
rename apacheivhospmortality apache_4_hosp_mort_day_
rename apacheivicumortality apache_4_cum_mort_day_
reshape wide apache_3_score_day_ aps_day_ apache_4_hosp_mort_day_ apache_4_cum_mort_day_, i(icu_admit_name) j(apacheday) 
save info_apache_mort_data, replace
clear

/*
//"Reintubation with 24 hours" ; 100 patients, 110 events (10 multiple reintubations), 1 icu admissions
*/ 
import excel using "Raw Data\V1 COVID dataset from APACHE.xlsx", sheet("Reintubation with 24 hours") firstrow case(lower) clear
ds, has(type string) //convert each string to 64 length (for later merging)
local stringvars `r(varlist)'
foreach var of local stringvars {
    replace `var' = trim(`var')
    recast str64 `var'
}
destring(mrn hospitalaccountnumber), ignore("" "n/a" "-" "na") replace
keep if !missing(mrn)
//Note, they can be intubated multiple times

gen icu_admit_name = string(icuadmissiondatetime) + "-" + string(mrn, "%12.0f")
label variable icu_admit_name "ICU-Identifier: Admit date - MRN"

quietly levelsof mrn, local(mrnLevels)
quietly levelsof icu_admit_name, local(icuAdmitNameLevels)
di "Number of unique MRN: " `: word count `mrnLevels''
di "Number of unique ICU Admits: " `: word count `icuAdmitNameLevels''

drop icuprocedureactivetreatmentt

//Generate ICU day of reintubation
gen icuadmissiondate_only = date(string(icuadmissiondatetime, "%td"), "DMY")
format icuadmissiondate_only %td
gen reintub_day = trunc(datediff(icuadmissiondate_only, proceduretreatmentstartdate, "d"))+1

drop proceduretreatmentstartdate proceduretreatmentstopdate //all dates start = stop
drop hospitaladmissiondatetime hospitaldischargedatetime icuadmissiondatetime icudischargedatetime posticudestination hospitaldischargedestination apachediagnosis admittingicu //these are all present in main sheet

egen reintub_rank_ = rank(reintub_day), by(icu_admit_name) track // is this 1st or 2n reintubation?
reshape wide reintub_rank_, i(icu_admit_name) j(reintub_day)

save reintub_24h_data, replace 
clear 

//NMB: 417 patients; 425 icu admissions
import excel using "Raw Data\V1 COVID dataset from APACHE.xlsx", sheet("NMB") firstrow case(lower) clear
ds, has(type string) //convert each string to 64 length (for later merging)
local stringvars `r(varlist)'
foreach var of local stringvars {
    replace `var' = trim(`var')
    recast str64 `var'
}
destring(mrn hospitalaccountnumber), ignore("" "n/a" "-" "na") replace
keep if !missing(mrn)
gen icu_admit_name = string(icuadmissiondatetime) + "-" + string(mrn, "%12.0f")
label variable icu_admit_name "ICU-Identifier: Admit date - MRN"
quietly levelsof mrn, local(mrnLevels)
quietly levelsof icu_admit_name, local(icuAdmitNameLevels)
di "Number of unique MRN: " `: word count `mrnLevels''
di "Number of unique ICU Admits: " `: word count `icuAdmitNameLevels''

gen cont_nmb = 1 //when merging, will need to generate 0's for others. 
drop icuprocedureactivetreatmentt

gen icuadmissiondate_only = date(string(icuadmissiondatetime, "%td"), "DMY")
format icuadmissiondate_only %td
gen start_nmb_ = trunc(datediff(icuadmissiondate_only, proceduretreatmentstartdate, "d"))+1
gen stop_nmb_ = trunc(datediff(icuadmissiondate_only, proceduretreatmentstopdate, "d"))+1
gen days_cont_nmb_ = (stop_nmb - start_nmb) + 1

rename totalofcalendardays total_icu_days_nmb

drop proceduretreatmentstartdate proceduretreatmentstopdate
drop hospitaladmissiondatetime hospitaldischargedatetime icuadmissiondatetime icudischargedatetime posticudestination hospitaldischargedestination apachediagnosis admittingicu //these are all present in main sheet
egen nmb_rank = rank(start_nmb), by(icu_admit_name) track // is this 1st-4th stretch of NMB?
//TODO: might be better to just sum total number
reshape wide start_nmb_ stop_nmb_ days_cont_nmb_, i(icu_admit_name) j(nmb_rank)
save nmb_data, replace
clear 

//Proning: 2477 patients; 2639 admissions
import excel using "Raw Data\V1 COVID dataset from APACHE.xlsx", sheet("Proning") firstrow case(lower) clear
ds, has(type string) //convert each string to 64 length (for later merging)
local stringvars `r(varlist)'
foreach var of local stringvars {
    replace `var' = trim(`var')
    recast str64 `var'
}
destring(mrn hospitalaccountnumber), ignore("" "n/a" "-" "na") replace
keep if !missing(mrn)
gen icu_admit_name = string(icuadmissiondatetime) + "-" + string(mrn, "%12.0f")
label variable icu_admit_name "ICU-Identifier: Admit date - MRN"
quietly levelsof mrn, local(mrnLevels)
quietly levelsof icu_admit_name, local(icuAdmitNameLevels)
di "Number of unique MRN: " `: word count `mrnLevels''
di "Number of unique ICU Admits: " `: word count `icuAdmitNameLevels''

drop icuprocedureactivetreatmentt

gen icuadmissiondate_only = date(string(icuadmissiondatetime, "%td"), "DMY")
format icuadmissiondate_only %td
gen start_proning_ = trunc(datediff(icuadmissiondate_only, proceduretreatmentstartdate, "d"))+1
gen stop_proning_ = trunc(datediff(icuadmissiondate_only, proceduretreatmentstopdate, "d"))+1
gen days_cont_proning_ = (stop_proning_ - start_proning_) + 1

rename totalofcalendardays total_icu_days_proning

drop proceduretreatmentstartdate proceduretreatmentstopdate
drop hospitaladmissiondatetime hospitaldischargedatetime icuadmissiondatetime icudischargedatetime posticudestination hospitaldischargedestination apachediagnosis admittingicu //these are all present in main sheet
egen prone_rank = rank(start_proning_), by(icu_admit_name) track // is this 1st-3rd stretch of proning?
reshape wide start_proning_ stop_proning_ days_cont_proning_, i(icu_admit_name) j(prone_rank)
save proning_data, replace
clear 

//CRRT; 172 patients, 173 icu admissions
import excel using "Raw Data\V1 COVID dataset from APACHE.xlsx", sheet("CRRT") firstrow case(lower) clear
ds, has(type string) //convert each string to 64 length (for later merging)
local stringvars `r(varlist)'
foreach var of local stringvars {
    replace `var' = trim(`var')
    recast str64 `var'
}
destring(mrn hospitalaccountnumber), ignore("" "n/a" "-" "na") replace
keep if !missing(mrn)

gen icu_admit_name = string(icuadmissiondatetime) + "-" + string(mrn, "%12.0f")
label variable icu_admit_name "ICU-Identifier: Admit date - MRN"
quietly levelsof mrn, local(mrnLevels)
quietly levelsof icu_admit_name, local(icuAdmitNameLevels)
di "Number of unique MRN: " `: word count `mrnLevels''
di "Number of unique ICU Admits: " `: word count `icuAdmitNameLevels''

drop icuprocedureactivetreatmentt

gen icuadmissiondate_only = date(string(icuadmissiondatetime, "%td"), "DMY")
format icuadmissiondate_only %td
gen start_crrt_ = trunc(datediff(icuadmissiondate_only, proceduretreatmentstartdate, "d"))+1
gen stop_crrt_ = trunc(datediff(icuadmissiondate_only, proceduretreatmentstopdate, "d"))+1
gen days_cont_crrt_ = (stop_crrt_ - start_crrt_) + 1

rename totalofcalendardays total_icu_days_crrt

drop proceduretreatmentstartdate proceduretreatmentstopdate
drop hospitaladmissiondatetime hospitaldischargedatetime icuadmissiondatetime icudischargedatetime posticudestination hospitaldischargedestination apachediagnosis admittingicu //these are all present in main sheet
egen crrt_rank = rank(start_crrt_), by(icu_admit_name) track // is this 1st-3rd stretch of CRRT?
reshape wide start_crrt_ stop_crrt_ days_cont_crrt_, i(icu_admit_name) j(crrt_rank)
save crrt_data, replace
clear 

//Code Status: 4023 patients; 4023 admissions 
import excel using "Raw Data\V1 COVID dataset from APACHE.xlsx", sheet("Code Status") firstrow case(lower)
ds, has(type string) //convert each string to 64 length (for later merging)
local stringvars `r(varlist)'
foreach var of local stringvars {
    replace `var' = trim(`var')
    recast str64 `var'
}
rename encntr_id enc_id
rename fin_nbr hospitalaccountnumber //fin_nbr = hospitalaccountnumber ; this is the variable to merge on
quietly levelsof hospitalaccountnumber, local(mrnLevels) 
di "Number of unique Hospital Account values: " `: word count `mrnLevels''

encode billing_entity_name, generate(hospital_billing)
drop billing_entity_name
rename code_status code_string
encode resuscitation_status, gen(code_status)
drop resuscitation_status

gen start_code_status = dofc(current_start_dts)
format start_code_status %td
drop current_start_dts

gen stop_code_status = dofc(discontinue_effective_dts)
format stop_code_status %td
drop discontinue_effective_dts

//hospitaladmissiondatetime hospitaldischargedatetime == case_admit_dts case_disch_dts
gen hospitaladmissiondatetime = dofc(case_admit_dts)
format hospitaladmissiondatetime %td
drop case_admit_dts

gen hospitaldischargedatetime = dofc(case_disch_dts)
format hospitaldischargedatetime %td
drop case_disch_dts

//generate: time since admit_start, time since admit_end, duration of status. 
gen hosp_day_start_code_status = start_code_status - hospitaladmissiondatetime
gen hosp_day_stop_code_status = stop_code_status - hospitaladmissiondatetime
gen dur_code_status = hosp_day_stop_code_status - hosp_day_start_code_status

gen hosp_admit_name = string(hospitaladmissiondatetime, "%td") + "-" + string(hospitalaccountnumber, "%12.0f")
label variable hosp_admit_name "Hosp-Identifier: Admit date - FIN"
quietly levelsof hosp_admit_name, local(hospAdmitNameLevels)
di "Number of unique Hosp Admits: " `: word count `hospAdmitNameLevels''

egen code_order_rank = rank(start_code_status), by(hosp_admit_name) unique // is this 1st-8th Code Status?
egen num_code_status = max(code_order_rank), by(hosp_admit_name)
label variable num_code_status "Number of Code Statuses During Admission"


// bysort hospitalaccountnumber: tab code_order_rank // this is to ensure there are no 'ties' - unique in the command above makes it so they are broken arbitrarily if two status entered at same time. 
reshape wide code_status code_string start_code_status stop_code_status hosp_day_start_code_status hosp_day_stop_code_status dur_code_status, i(hosp_admit_name) j(code_order_rank)
save code_status_data, replace
clear

/*
//Chronic Conditions here:  - 1 file for the patients we already had. 
This includes 5160 patients. ; 5770 icu admits
*/ 
import excel using "Raw Data\Chronic conditions initial group.xlsx", sheet("Report 1") cellrange(B4) firstrow case(lower)
ds, has(type string) //convert each string to 64 length (for later merging)
local stringvars `r(varlist)'
foreach var of local stringvars {
    replace `var' = trim(`var')
    recast str64 `var'
}
destring(mrn hospitalaccountnumber), force replace
keep if !missing(mrn)
//drop singleselectcdevalue

gen icu_admit_name = string(icuadmissiondatetime) + "-" + string(mrn, "%12.0f")
label variable icu_admit_name "ICU-Identifier: Admit date - MRN"

quietly levelsof mrn, local(mrnLevels)
quietly levelsof icu_admit_name, local(icuAdmitNameLevels)
di "Number of unique MRN: " `: word count `mrnLevels''
di "Number of unique ICU Admits: " `: word count `icuAdmitNameLevels''

/* Note: collapse (below) discards all the other variables. Thus, the code below
creates a new dataset with each icu-admit. then later the chronic conditions are 
merged many to 1 to these admits 
Thus, saved as two different sheets
*/
preserve 
drop chronichealthconditions
duplicates drop icu_admit_name, force //get rid of all the duplicate entries that did correspond to each condition
save chronic_cond_old_data_icu_admits, replace
restore

replace chronichealthconditions = subinstr(chronichealthconditions, ":", "",.) //replace these for var names.
replace chronichealthconditions = subinstr(chronichealthconditions, "'", "",.)
replace chronichealthconditions = subinstr(chronichealthconditions, "-", "_",.)
replace chronichealthconditions = subinstr(chronichealthconditions, "/", "_",.)
replace chronichealthconditions = subinstr(chronichealthconditions, " ", "_",.)
replace chronichealthconditions = substr(chronichealthconditions, 1, 28) //for max var length
levelsof chronichealthconditions, local(NAMES)
foreach name of local NAMES {
	gen cnd_`name' = 1 if (chronichealthconditions == "`name'")
}

collapse (max) cnd_*, by(mrn) // collapses the multiple rows down to just 1
save chronic_cond_old_data, replace

/*
Chronic conditions: Four files for all the chronic diagnoses for each patient.
One file for the previous merged patients
In total, this contains data from 1808 patients. 1930 admits
*/ 
import excel using "Raw Data\Chronic conditions missing group 3.xlsx", sheet("Report 1") cellrange(B4) firstrow case(lower) clear
ds, has(type string) //convert each string to 64 length (for later merging)
local stringvars `r(varlist)'
foreach var of local stringvars {
    replace `var' = trim(`var')
    recast str64 `var'
}
destring(mrn hospitalaccountnumber), force replace
keep if !missing(mrn)
save chronic_cond_new3, replace
import excel using "Raw Data\Chronic conditions missing group 2.xlsx", sheet("Report 1") cellrange(B4) firstrow case(lower) clear
ds, has(type string) //convert each string to 64 length (for later merging)
local stringvars `r(varlist)'
foreach var of local stringvars {
    replace `var' = trim(`var')
    recast str64 `var'
}
destring(mrn hospitalaccountnumber), force replace
keep if !missing(mrn)
save chronic_cond_new2, replace
import excel using "Raw Data\Chronic conditions missing group 1.xlsx", sheet("Report 1") cellrange(B4) firstrow case(lower) clear
ds, has(type string) //convert each string to 64 length (for later merging)
local stringvars `r(varlist)'
foreach var of local stringvars {
    replace `var' = trim(`var')
    recast str64 `var'
}
destring(mrn hospitalaccountnumber), force replace
keep if !missing(mrn)
append using chronic_cond_new2
append using chronic_cond_new3

gen icu_admit_name = string(icuadmissiondatetime) + "-" + string(mrn, "%12.0f")
label variable icu_admit_name "ICU-Identifier: Admit date - MRN"
quietly levelsof mrn, local(mrnLevels)
quietly levelsof icu_admit_name, local(icuAdmitNameLevels)
di "Number of unique MRN: " `: word count `mrnLevels''
di "Number of unique ICU Admits: " `: word count `icuAdmitNameLevels''

/* Note: collapse (below) discards all the other variables. Thus, the code below
creates a new dataset with each icu-admit. then later the chronic conditions are 
merged many to 1 to these admits */ 
preserve 
drop chronichealthconditions
duplicates drop icu_admit_name, force //get rid of all the duplicate entries that did correspond to each condition
save chronic_cond_new_data_icu_admits, replace
restore

replace chronichealthconditions = subinstr(chronichealthconditions, ":", "",.) //replace these for var names.
replace chronichealthconditions = subinstr(chronichealthconditions, "'", "",.)
replace chronichealthconditions = subinstr(chronichealthconditions, "-", "_",.)
replace chronichealthconditions = subinstr(chronichealthconditions, "/", "_",.)
replace chronichealthconditions = subinstr(chronichealthconditions, " ", "_",.)
replace chronichealthconditions = substr(chronichealthconditions, 1, 28) //for max var length
levelsof chronichealthconditions, local(NAMES)
foreach name of local NAMES {
	gen cnd_`name' = 1 if (chronichealthconditions == "`name'")
}

collapse (max) cnd_*, by(mrn) // collapses the multiple rows down to just 1
save chronic_cond_new_data, replace

/* 
Missing APACHE patients. These are the additional patients that need to be added to the already merged data. 

This is a group we discovered through Vizient that weren't found in our initial APACHE query since their beds at time of admission were surge beds due to overflow, which apparently threw it off. I've found that some patients that had missing data in our initial merged dataset are within this dataset. I think it'll make sense to add these patients to the merged set before you try to match for transfers, etc.
This has daily APACHE scores, APS, and hospital/ICU mortality
*/ 

//1322 patients; 1394 icu admissions
import excel using "Raw Data\Missing APACHE patients, merged.xlsx", sheet("Report 1") cellrange(B4) firstrow case(lower) clear
ds, has(type string) //convert each string to 64 length (for later merging)
local stringvars `r(varlist)'
foreach var of local stringvars {
    replace `var' = trim(`var')
    recast str64 `var'
}
destring(mrn hospitalaccountnumber), force replace
keep if !missing(mrn)

gen icu_admit_name = string(icuadmissiondatetime) + "-" + string(mrn, "%12.0f")
label variable icu_admit_name "ICU-Identifier: Admit date - MRN"

quietly levelsof mrn, local(mrnLevels)
quietly levelsof icu_admit_name, local(icuAdmitNameLevels)
di "Number of unique MRN: " `: word count `mrnLevels''
di "Number of unique ICU Admits: " `: word count `icuAdmitNameLevels''

tab apacheday, plot
drop if apacheday > 50  // this is done to limit the total number of variables; if not STATA BE, could probably keep it all. 

//reshape from long->wide format
rename apacheiiiscore apache_3_score_day_
rename acutephysiologyscoreaps aps_day_
rename apacheivhospmortality apache_4_hosp_mort_day_
rename apacheivicumortality apache_4_cum_mort_day_
reshape wide apache_3_score_day_ aps_day_ apache_4_hosp_mort_day_ apache_4_cum_mort_day_, i(icu_admit_name) j(apacheday) 

save missing_apache_merged, replace
clear

//3740 patients; 4118 admits
//Active treatments per day.xlsx
import excel using "Raw Data\Active treatments per day.xlsx", sheet("Report 1") cellrange("B4:L190444") firstrow case(lower) clear

ds, has(type string) //convert each string to 64 length (for later merging)
local stringvars `r(varlist)'
foreach var of local stringvars {
    replace `var' = trim(`var')
    recast str64 `var'
}
destring(mrn hospitalaccountnumber apacheday), force replace
keep if !missing(mrn)

gen icu_admit_name = string(icuadmissiondatetime) + "-" + string(mrn, "%12.0f")
label variable icu_admit_name "ICU-Identifier: Admit date - MRN"

tab apacheday, plot
drop if apacheday > 50

quietly levelsof mrn, local(mrnLevels)
quietly levelsof icu_admit_name, local(icuAdmitNameLevels)
di "Number of unique MRN: " `: word count `mrnLevels''
di "Number of unique ICU Admits: " `: word count `icuAdmitNameLevels''

/* Rename and split variables active treatments to be suitable variable names */ 
//This works by splitting out into binary variables, setting all the rows for the same 
//admission x day to 1 if the procedure was performed, then elminiating duplicates
gen act_av_pace = 1 if icuprocedureactivetreatmentt == "A/V Pacing"
bysort icu_admit_name apacheday: egen act_av_pace_ = max(act_av_pace)
drop act_av_pace
label variable act_av_pace_ "A/V Pacing"
gen barb_anesth = 1 if icuprocedureactivetreatmentt == "Barbiturate anesthesia"
bysort icu_admit_name apacheday: egen barb_anesth_ = max(barb_anesth)
drop barb_anesth
label variable barb_anesth_ "Barbiturate anesthesia"
gen crrt = 1 if icuprocedureactivetreatmentt == "CRRT" //TODO: reconcile this with the old apache dataset
bysort icu_admit_name apacheday: egen crrt_ = max(crrt)
drop crrt
label variable crrt_ "CRRT"
gen cardiovert = 1 if icuprocedureactivetreatmentt == "Cardioversion"
bysort icu_admit_name apacheday: egen cardiovert_ = max(cardiovert)
drop cardiovert
label variable cardiovert_ "Cardioversion"
gen cont_art_drug_inf = 1 if icuprocedureactivetreatmentt == "Continuous Arterial Drug Infusion"
bysort icu_admit_name apacheday: egen cont_art_drug_inf_ = max(cont_art_drug_inf)
drop cont_art_drug_inf
label variable cont_art_drug_inf_ "Continuous Arterial Drug Infusion"
gen cont_iv_sed = 1 if icuprocedureactivetreatmentt == "Continuous IV Sedation"
bysort icu_admit_name apacheday: egen cont_iv_sed_ = max(cont_iv_sed)
drop cont_iv_sed
label variable cont_iv_sed_	"Continuous IV Sedation"
gen cont_nmb = 1 if icuprocedureactivetreatmentt == "Continuous Neuromuscular Blockade"
bysort icu_admit_name apacheday: egen cont_nmb_ = max(cont_nmb)
drop cont_nmb
label variable cont_nmb_ "Continuous Neuromuscular Blockade"
gen cont_anti_arrh = 1 if icuprocedureactivetreatmentt == "Continuous antiarrhythmic"
bysort icu_admit_name apacheday: egen cont_anti_arrh_ = max(cont_anti_arrh)
drop cont_anti_arrh
label variable cont_anti_arrh_ "Continuous antiarrhythmic"
gen ecmo = 1 if icuprocedureactivetreatmentt == "ECMO"
bysort icu_admit_name apacheday: egen ecmo_ = max(ecmo)
drop ecmo
label variable ecmo_ "ECMO"
gen emerg_op_in_icu = 1 if icuprocedureactivetreatmentt == "Emergency Op procedures inside ICU"
bysort icu_admit_name apacheday: egen emerg_op_in_icu_ = max(emerg_op_in_icu)
drop emerg_op_in_icu
label variable emerg_op_in_icu_ "Emergency Op procedures inside ICU"
gen emerg_op_out_icu = 1 if icuprocedureactivetreatmentt == "Emergency Op procedures outside ICU"
bysort icu_admit_name apacheday: egen emerg_op_out_icu_ = max(emerg_op_out_icu)
drop emerg_op_out_icu
label variable emerg_op_out_icu_ "Emergency Op procedures outside ICU"
gen endoscope = 1 if icuprocedureactivetreatmentt == "Endoscopies"
bysort icu_admit_name apacheday: egen endoscope_ = max(endoscope)
drop endoscope
label variable endoscope_ "Endoscopies"
gen hfnc = 1 if icuprocedureactivetreatmentt == "HFNC"
bysort icu_admit_name apacheday: egen hfnc_ = max(hfnc)
drop hfnc
label variable hfnc_ "HFNC"
gen ippv = 1 if icuprocedureactivetreatmentt == "IPPV"
bysort icu_admit_name apacheday: egen ippv_ = max(ippv)
drop ippv
label variable ippv_ "IPPV"
gen irrt = 1 if icuprocedureactivetreatmentt == "IRRT"
bysort icu_admit_name apacheday: egen irrt_ = max(irrt)
drop irrt
label variable irrt_ "IRRT"
gen iv_vaso = 1 if icuprocedureactivetreatmentt == "IV Vasopressin"
bysort icu_admit_name apacheday: egen iv_vaso_ = max(iv_vaso)
drop iv_vaso
label variable iv_vaso_ "IV Vasopressin"
gen iv_fluid_rep = 1 if icuprocedureactivetreatmentt == "IV replacement excessive fluid loss"
bysort icu_admit_name apacheday: egen iv_fluid_rep_ = max(iv_fluid_rep)
drop iv_fluid_rep
label variable iv_fluid_rep_ "IV replacement excessive fluid loss"
gen ttm = 1 if icuprocedureactivetreatmentt == "Induced hypothermia"
bysort icu_admit_name apacheday: egen ttm_ = max(ttm)
drop ttm
label variable ttm_ "Induced hypothermia"
gen nippv = 1 if icuprocedureactivetreatmentt == "NIPPV"
bysort icu_admit_name apacheday: egen nippv_ = max(nippv)
drop nippv
label variable nippv_ "NIPPV"
gen icu_intub = 1 if icuprocedureactivetreatmentt == "Naso/Orotracheal Intubation in ICU"
bysort icu_admit_name apacheday: egen icu_intub_ = max(icu_intub)
drop icu_intub
label variable icu_intub_ "Naso/Orotracheal Intubation in ICU"
gen pa_cath = 1 if icuprocedureactivetreatmentt == "PA line (with or w/o CO measurement)"
bysort icu_admit_name apacheday: egen pa_cath_ = max(pa_cath)
drop pa_cath
label variable pa_cath_ "PA line (with or w/o CO measurement)"
gen post_arrest = 1 if icuprocedureactivetreatmentt == "Post Arrest (48 hours)"
bysort icu_admit_name apacheday: egen post_arrest_ = max(post_arrest)
drop post_arrest
label variable post_arrest_ "Post Arrest (48 hours)"
gen prone = 1 if icuprocedureactivetreatmentt == "Prone Positioning" //todo: reconcile
bysort icu_admit_name apacheday: egen prone_ = max(prone)
drop prone
label variable prone_ "Prone Positioning"
gen mtp = 1 if icuprocedureactivetreatmentt == "Rapid Blood Transfusion"
bysort icu_admit_name apacheday: egen mtp_ = max(mtp)
drop mtp
label variable mtp_ "Rapid Blood Transfusion"
gen reintub = 1 if icuprocedureactivetreatmentt == "Reintubation within 24 hours"
bysort icu_admit_name apacheday: egen reintub_ = max(reintub)
drop reintub
label variable reintub_ "Reintubation within 24 hours"
gen one_pressor = 1 if icuprocedureactivetreatmentt == "Single Vasoactive drug infusion"
bysort icu_admit_name apacheday: egen one_pressor_ = max(one_pressor)
drop one_pressor
label variable one_pressor_ "Single Vasoactive drug infusion"
gen tx_acid_base = 1 if icuprocedureactivetreatmentt == "Tx complex metab bal, acidosis/alkalosis"
bysort icu_admit_name apacheday: egen tx_acid_base_ = max(tx_acid_base)
drop tx_acid_base
label variable tx_acid_base_ "Tx complex metab bal, acidosis/alkalosis"
gen vad = 1 if icuprocedureactivetreatmentt == "VAD"
bysort icu_admit_name apacheday: egen vad_ = max(vad)
drop vad
label variable vad_ "VAD"
gen mult_pressors = 1 if icuprocedureactivetreatmentt == "Vasoactive > one"
bysort icu_admit_name apacheday: egen mult_pressors_ = max(mult_pressors)
drop mult_pressors
label variable mult_pressors_ "Vasoactive > one"
gen ventriculost = 1 if icuprocedureactivetreatmentt == "Ventriculostomy"
bysort icu_admit_name apacheday: egen ventriculost_ = max(ventriculost)
drop ventriculost
label variable ventriculost_ "Ventriculostomy"

tab icuprocedureactivetreatmentt
drop icuprocedureactivetreatmentt

duplicates drop icu_admit_name apacheday act_av_pace_ barb_anesth_ crrt_ cardiovert_ cont_art_drug_inf_ cont_iv_sed_ cont_nmb_ cont_anti_arrh_ ecmo_ emerg_op_in_icu_ emerg_op_out_icu endoscope_ hfnc_ ippv_ irrt_ iv_vaso_ iv_fluid_rep_ ttm_ nippv_ icu_intub_ pa_cath_ post_arrest_ prone_ mtp_ reintub_ one_pressor_ tx_acid_base_ vad_ mult_pressors_ ventriculost_, force

//Have to drop some to ensure under the 2400 variables limit of STATA BE 
//[eased since going down to 50 days max]. Note, we drop more later too. 
drop act_av_pace_ barb_anesth_ iv_vaso_ vad_ ventriculost_ tx_acid_base_

reshape wide crrt_ cardiovert_ cont_art_drug_inf_ cont_iv_sed_ cont_nmb_ cont_anti_arrh_ ecmo_ emerg_op_in_icu_ emerg_op_out_icu endoscope_ hfnc_ ippv_ irrt_ iv_fluid_rep_ ttm_ nippv_ icu_intub_ pa_cath_ post_arrest_ prone_ mtp_ reintub_ one_pressor_ mult_pressors_ , i(icu_admit_name) j(apacheday) 

save active_tx_per_day, replace
clear


//Cumulative scores per day.xlsx - 5160 patients; 5821 admits
import excel using "Raw Data\Cumulative scores per day.xlsx", sheet("Report 1") cellrange("B4:U51981") firstrow case(lower) clear

ds, has(type string) //convert each string to 64 length (for later merging)
local stringvars `r(varlist)'
foreach var of local stringvars {
    replace `var' = trim(`var')
    recast str64 `var'
}
destring(mrn hospitalaccountnumber apacheday apacheiiiscore acutephysiologyscoreaps apacheivhospmortality apacheivicumortality), force replace
keep if !missing(mrn)

gen icu_admit_name = string(icuadmissiondatetime) + "-" + string(mrn, "%12.0f")
label variable icu_admit_name "ICU-Identifier: Admit date - MRN"

quietly levelsof mrn, local(mrnLevels)
quietly levelsof icu_admit_name, local(icuAdmitNameLevels)
di "Number of unique MRN: " `: word count `mrnLevels''
di "Number of unique ICU Admits: " `: word count `icuAdmitNameLevels''

tab apacheday, plot
drop if apacheday > 50

// Convert datetime to date only (day level of resolution) - because there were some slight inconsistency 
//between different entries of the same admission
gen hospitaldischargedatetime_var = mdy(month(hospitaldischargedatetime), day(hospitaldischargedatetime), year(hospitaldischargedatetime))
drop hospitaldischargedatetime
rename hospitaldischargedatetime_var hospitaldischargedatetime
format hospitaldischargedatetime %td 

//reshape from long->wide format
rename apacheiiiscore apache_3_score_day_
rename acutephysiologyscoreaps aps_day_
rename apacheivhospmortality apache_4_hosp_mort_day_
rename apacheivicumortality apache_4_cum_mort_day_
reshape wide apache_3_score_day_@ aps_day_@ apache_4_hosp_mort_day_@ apache_4_cum_mort_day_@, i(icu_admit_name) j(apacheday) 

save cum_score_per_day, replace
clear


/* ----------------

Merge datasets on ICU admission 

------------------*/ 

clear
use info_apache_mort_data //3718 patients, 4123 admits
merge 1:1 icu_admit_name using active_tx_per_day, update generate(_merge_active_tx)
merge 1:1 icu_admit_name using crrt_data, update generate(_merge_crrt)
merge 1:1 icu_admit_name using nmb_data, update generate(_merge_nmb) 
merge 1:1 icu_admit_name using proning_data, update generate(_merge_proning) 
merge 1:1 icu_admit_name using reintub_24h_data, update generate(_merge_reintub) 

//list crrt_1 crrt_2 crrt_3 crrt_4 crrt_5 start_crrt_1 stop_crrt_1 days_cont_crrt_1 in 1/500
//list icu_intub_1 icu_intub_2 icu_intub_3 icu_intub_4 icu_intub_5 reintub_rank_1 reintub_rank_2 reintub_rank_3 reintub_rank_4 reintub_rank_5 in 1/500 

merge 1:1 icu_admit_name using cum_score_per_day, update generate(_merge_cum_score) //lots of conflicts... need to figure out what? 

merge 1:1 icu_admit_name using missing_apache_merged, update generate(_merge_missing_apache) //4968 patients, 5517 admits
merge 1:1 icu_admit_name using chronic_cond_new_data_icu_admits, update generate(_merge_chron_new_enc) 
merge 1:1 icu_admit_name using chronic_cond_old_data_icu_admits, update generate(_merge_chron_old_enc) 

merge m:1 mrn using chronic_cond_old_data, update replace generate(_merge_chron_old)  
merge m:1 mrn using chronic_cond_new_data, update replace generate(_merge_chron_new)  

quietly levelsof mrn, local(mrnLevels)
quietly levelsof icu_admit_name, local(icuAdmitNameLevels)
di "Number of unique MRN: " `: word count `mrnLevels''
di "Number of unique ICU Admits: " `: word count `icuAdmitNameLevels''

//this one has to merge on hospital FIN-Date combo - hosp_admit_name
gen hosp_admit_name = string(hospitaladmissiondatetime, "%td") + "-" + string(hospitalaccountnumber, "%12.0f")
label variable hosp_admit_name "Hosp-Identifier: Admit date - FIN"
merge m:1 hosp_admit_name using code_status_data, update generate(_merge_code)  
drop if missing(mrn) //match failures

//Highlight whether a given readmission is the first in the data-set or no. 
egen time_thru_icu_rank = rank(icudischargedatetime), by(mrn) track //this creates an enc_rank if it's the first encounter for the patients

//Encode string variables.
encode posticudestination, gen(post_icu_dest)
drop posticudestination
encode locationattimeofdeath, gen(loc_at_death)	// N/A = did not die
drop locationattimeofdeath
encode hospitaldischargedestination, gen(hosp_disch_loc) //Not specified = died; other ICU = transferred
drop hospitaldischargedestination
label define binary_lab 0 "No" 1 "Yes"
encode chronicdialysis, gen(chr_dialysis) label(binary_lab)
drop chronicdialysis
encode apachediagnosis, gen(apache_dx)
drop apachediagnosis
encode admittingicu, gen(adm_icu)
drop admittingicu

gen hospital_los = hospitaldischargedatetime - hospitaladmissiondatetime
label variable hospital_los "Length of Stay (Hospitalization)"
gen icu_los = icudischargedatetime - icuadmissiondatetime
label variable icu_los "Length of Stay (Hospitalization)"
bysort hosp_disch_loc: sum icu_los, detail // median LOS prior to transfer is 2.9 days. n = 315

//Replace missing chronic condition values with 0's. 

* List all variables starting with "cnd_"
ds cnd_*, has(type numeric)

* Loop through each variable and replace missing values with 0
foreach var of varlist `r(varlist)' {
    replace `var' = 0 if missing(`var')
}

/*---------------

Generate transfer labeling

----------------*/

gen pre_transfer = 0
gen post_transfer = 0
sort mrn icudischargedatetime
forval i = 1/`=_N' {
    * Check the next row for the same patient
    if mrn[`i'] == mrn[`i' + 1] {
        * Check if 'hosp_disch_loc' is "Other ICU = 3" and the next 'icu_admission' is within 48 hours
        if post_icu_dest[`i'] == 3 & icuadmissiondatetime[`i' + 1] - icudischargedatetime[`i'] <= 48/24 {
            replace pre_transfer = 1 in `i'
        }
    }
}
//instead of hosp_disch_loc, should we be matching on post_icu_dest? or, require that hospital billing =/= pre and post
//changed from hosp_disch_loc[`i'] == 3 & icuadmissiondatetime[`i' + 1] - icudischargedatetime[`i'] <= 48/24 to avoid pre-transfer bounces

forval i = 1/`=_N' {
    * Check the previous row for the same patient
    if mrn[`i'] == mrn[`i' - 1] {
        * if the last row was the correct dispo and within 48. If so flag
        if post_icu_dest[`i' - 1] == 3 & icuadmissiondatetime[`i' ] - icudischargedatetime[`i' - 1] <= 48/24 {
            replace post_transfer = 1 in `i'
        }
    }
}
//if hosp_disch_loc[`i' - 1] == 3 & icuadmissiondatetime[`i' ] - icudischargedatetime[`i' - 1] <= 48/24

format mrn %15.0f
gen pre_or_post_transfer = 1
replace pre_or_post_transfer = 0 if pre_transfer == 0 & post_transfer == 0

by mrn: egen ever_transfer = max(pre_or_post_transfer) //Create "ever_transfer" as a maximum of "pre_post_transfer" within each "mrn" group

sort patientname mrn icuadmissiondatetime 

/* For Troubleshooting Pre- and post- labeling. */
//list patientname mrn hosp_disch_loc icuadmissiondatetime icudischargedatetime hospital_billing post_icu_dest adm_icu pre_transfer post_transfer if mrn == 404090462 //if pre_transfer == 1 & post_transfer == 1

//Tranfer variable labels 
label variable icuadmissiondate_only "Date of ICU Admission (no time)"
label variable icu_los "ICU Length of Stay"
label variable pre_transfer "Hospitalization is Pre-Transfer?"
label variable post_transfer "hospitalizatino is Post-Transfer?"
label variable pre_or_post_transfer "Hospitalization either Pre or Post Transfer?"
label variable ever_transfer "Any ICU encounters from this MRN with a transfer?"

/* 
Label by Tele-critical care status: 
List of ICUs that send transfers usually: AF_ICU, AV_ICU, CA_ICU, CC_ICU, ICU, LG_North Tower, PK_ICU, RV_ICU, 
List of ICUs that receive transfers, usually: IM_Coronary ICU, IM_Neuro ICU, IM_Shock Trauma, IM_Thoracic ICU, LD_ICU, MK_ICU, UV_F04 Intensive Care Unit, zzIM_Resp ICU
SG_ICU is about split

Labels are alphabetical, so: 
Tele / transferring: 1 2 3 4 5 11 13 14 
No Tele / accepting: 6 7 8 9 10 12 15 16 17 18
*/

recode adm_icu (6 7 8 9 10 12 15 16 17 18 = 0) (1 2 3 4 5 11 13 14 = 1), gen(tele_cc_icu) label(binary_lab)
label variable tele_cc_icu "ICU w Tele-Critical Care?"

// 1 = Referral Center, 2 = Tele, no transfer, 3 = tele transfer pre, 4 = tele transfer post
gen tele_status = 1
replace tele_status = 2 if tele_cc_icu == 1
replace tele_status = 3 if pre_transfer == 1
replace tele_status = 4 if post_transfer == 1

label variable tele_status "Tele crit care and/or transfer status"
label define tele_status_lab 1 "Referral Center" 2 "Tele-ICU, no transfer" 3  "Tele-ICU, pre-transfer" 4 "Tele-ICU, post transfer"
label values tele_status tele_status_lab

label variable dur_code_status1 "Duration (days) of First Code Status"


describe
save complete_sans_demo, replace
clear

//Add final demographics table: 
import excel using "Raw Data/TCC Demographics File.xlsx", sheet("Sheet2") firstrow case(lower) clear
describe
duplicates list hospitalaccountnumber //should be none
label variable age_in_years "Age"
rename age_in_years age
tab age, plot 
label variable bmi "BMI (kg/m2)"
tab bmi, plot

//Convert strings to categorical
encode sex_dsp, gen(sex_male)
label variable sex_male "Sex"
drop sex_dsp
tab sex_male

encode disch_disposition_dsp, gen(discharge_location)
label variable discharge_location "Discharge Location"
drop disch_disposition_dsp
tab discharge_location

encode race_dsp, gen(race)
label variable race "Race"
drop race_dsp
tab race

encode ethnic_grp_dsp, gen(ethnicity)
label variable ethnicity "Ethnicity"
drop ethnic_grp_dsp
tab ethnicity	

gen died = 1
replace died = 0 if missing(death_dts)
label variable died "Died"

rename death_dts death_date
label variable death_date "Date of Death"
tab death_date //date format; only for patients who died during followup

//there are duplicates in the complete_sans_demo, but not in the demographics. Apply the demographic record to each occurence 
merge 1:m hospitalaccountnumber using complete_sans_demo, update replace generate(_merge_new_demographics)  

/* Save full dataset (does not include raters for those who transferred. */ 
save all_data, replace
export excel using "all data.xlsx", firstrow(varlabels) keepcellfmt replace 

/* Save just transfers dataset */ 
preserve
drop if pre_or_post_transfer == 0 
//drop _merge*
//drop icu_admit_name  hosp_admit_name 
order mrn patientname pre_transfer post_transfer hospital_billing
save just_transfers, replace
export excel using "just transfers.xlsx", firstrow(varlabels) keepcellfmt replace 
restore

/* Save just non-transfers dataset */ 
preserve
drop if pre_or_post_transfer == 1 
//drop _merge*
//drop icu_admit_name hosp_admit_name
order mrn patientname pre_transfer post_transfer hospital_billing
save just_non_transfers, replace
export excel using "just non transfers.xlsx", firstrow(varlabels) keepcellfmt replace 
restore

/* -------------

Ratings 

-------------*/ 

/* REVIEWER 1 */
import excel using "Raw Data\Reviewer 1 - RB_completed.xlsx", sheet("Sheet1") firstrow case(lower) clear
describe
ds /* Label each variable by the reviewer */ 
foreach var in `r(varlist)' {
    if "`var'" != "fin" {
        rename `var' rev1_`var'
    }
}
drop if missing(fin)
duplicates report fin

replace rev1_soc = "No" if missing(rev1_soc)
replace rev1_dex = "Yes" if missing(rev1_dex)
replace rev1_remd = "Yes" if missing(rev1_remd)
replace rev1_tocibaritofa = "No" if missing(rev1_tocibaritofa)
replace rev1_abx = "No" if missing(rev1_abx)
replace rev1_hcq = "No" if missing(rev1_hcq)
drop rev1_iver
gen rev1_iver = "No"
replace rev1_transfer_reason = "Other" if missing(rev1_transfer_reason)
replace rev1_tr_nonresp = "Not Applicable" if missing(rev1_tr_nonresp)
replace rev1_tr_comorb = "None" if missing(rev1_tr_comorb)
replace rev1_refuses = "No" if missing(rev1_refuses)
replace rev1_refuses_rea = "Not Applicable" if missing(rev1_refuses_rea)
//replace rev1_refuses_tr = "Not Applicable" if missing(rev1_refuses_tr)
drop rev1_refuses_tr 
gen rev1_refuses_tr = "No"
replace rev1_tr_support = "Other" if missing(rev1_tr_support)
replace rev1_proc = "None" if missing(rev1_proc)
replace rev1_proc_time = 9999 if missing(rev1_proc_time)
replace rev1_proc_comp = "Not Applicable" if rev1_proc == "None"
replace rev1_proc_comp = "No" if missing(rev1_proc_comp)
drop rev1_central_line
gen rev1_central_line = "No"
replace rev1_intubation = "Not Applicable" if strpos(rev1_proc, "ETT") == 0
replace rev1_intubation = "No" if missing(rev1_intubation)
drop rev1_cardiac_arr
gen rev1_cardiac_arr = "No"
replace rev1_tr_comp = "No" if missing(rev1_tr_comp) 
replace rev1_arr_inter = "No" if missing(rev1_arr_inter)
drop rev1_rec_abx rev1_rec_tte rev1_rec_ct rev1_rec_bronch rev1_rec_free
gen rev1_rec_abx = "No"
gen rev1_rec_tte = "No"
gen rev1_rec_ct = "No"
gen rev1_rec_bronch = "No"
gen rev1_rec_free = "No"
replace rev1_ad = "No additional" if missing(rev1_ad)
save reviewer_1, replace

/* REVIEWER 2 */ 
import excel using "Raw Data\Reviewer 2_BK_completed.xlsx", sheet("Sheet1") firstrow case(lower) clear
rename admitdate admit
describe
ds /* Label each variable by the reviewer */ 
foreach var in `r(varlist)' {
    if "`var'" != "fin" {
        rename `var' rev2_`var'
    }
}
duplicates report fin
replace rev2_soc = "No" if missing(rev2_soc)
replace rev2_dex = "Yes" if missing(rev2_dex)
replace rev2_remd = "Yes" if missing(rev2_remd)
replace rev2_tocibaritofa = "No" if missing(rev2_tocibaritofa)
replace rev2_abx = "No" if missing(rev2_abx)
drop rev2_hcq 
gen rev2_hcq = "No" 
drop rev2_iver
gen rev2_iver = "No"
replace rev2_transfer_reason = "Other" if missing(rev2_transfer_reason)
replace rev2_tr_nonresp = "Not Applicable" if missing(rev2_tr_nonresp)
replace rev2_tr_comorb = "None" if missing(rev2_tr_comorb)
replace rev2_refuses = "No" if missing(rev2_refuses)
replace rev2_refuses_rea = "Not Applicable" if missing(rev2_refuses_rea)
//replace rev1_refuses_tr = "Not Applicable" if missing(rev1_refuses_tr)
drop rev2_refuses_tr 
gen rev2_refuses_tr = "No"
replace rev2_tr_support = "Other" if missing(rev2_tr_support)
replace rev2_proc = "None" if missing(rev2_proc)
replace rev2_proc_time = 9999 if missing(rev2_proc_time)
replace rev2_proc_comp = "Not Applicable" if rev2_proc == "None"
replace rev2_proc_comp = "No" if missing(rev2_proc_comp)
drop rev2_central_line
gen rev2_central_line = "No"
replace rev2_intubation = "Not Applicable" if strpos(rev2_proc, "ETT") == 0
replace rev2_intubation = "No" if missing(rev2_intubation)
drop rev2_cardiac_arr
gen rev2_cardiac_arr = "No"
replace rev2_tr_comp = "No" if missing(rev2_tr_comp) 
replace rev2_arr_inter = "No" if missing(rev2_arr_inter)
replace rev2_rec_abx = "No" if missing(rev2_rec_abx)
replace rev2_rec_tte = "No" if missing(rev2_rec_tte)
replace rev2_rec_ct = "No" if missing(rev2_rec_ct)
replace rev2_rec_bronch = "No" if missing(rev2_rec_bronch)
drop rev2_rec_free
gen rev2_rec_free = "No"
gen rev2_ad = "No additional"
save reviewer_2, replace

/* REVIEWER 3 */
import excel using "Raw Data\Reviewer 3 CL_complete.xlsx", sheet("Sheet1") firstrow case(lower) clear
describe
ds /* Label each variable by the reviewer */ 
foreach var in `r(varlist)' {
    if "`var'" != "fin" {
        rename `var' rev3_`var'
    }
}
duplicates report fin
duplicates examples fin
//Duplicate 1245803134 FIN in reviewer 3 same ratings 
duplicates drop fin, force
replace rev3_soc = "No" if missing(rev3_soc)
replace rev3_dex = "Yes" if missing(rev3_dex)
replace rev3_remd = "Yes" if missing(rev3_remd)
replace rev3_tocibaritofa = "No" if missing(rev3_tocibaritofa)
replace rev3_abx = "No" if missing(rev3_abx)
replace rev3_hcq = "No" if missing(rev3_hcq)
drop rev3_iver
gen rev3_iver = "No"
replace rev3_transfer_reason = "Other" if missing(rev3_transfer_reason)
replace rev3_tr_nonresp = "Not Applicable" if missing(rev3_tr_nonresp)
replace rev3_tr_comorb = "None" if missing(rev3_tr_comorb)
replace rev3_refuses = "No" if missing(rev3_refuses)
replace rev3_refuses_rea = "Not Applicable" if missing(rev3_refuses_rea)
replace rev3_refuses_tr = "Not Applicable" if missing(rev3_refuses_tr)
replace rev3_tr_support = "Other" if missing(rev3_tr_support)
replace rev3_proc = "None" if missing(rev3_proc)
replace rev3_proc_time = 9999 if missing(rev3_proc_time)
replace rev3_proc_comp = "Not Applicable" if rev3_proc == "None"
replace rev3_proc_comp = "No" if missing(rev3_proc_comp)
drop rev3_central_line
gen rev3_central_line = "No"
replace rev3_intubation = "Not Applicable" if strpos(rev3_proc, "ETT") == 0
replace rev3_intubation = "No" if missing(rev3_intubation)
replace rev3_cardiac_arr = "No" if missing(rev3_cardiac_arr)
replace rev3_tr_comp = "No" if missing(rev3_tr_comp) 
replace rev3_arr_inter = "No" if missing(rev3_arr_inter)
replace rev3_rec_abx = "No" if missing(rev3_rec_abx)
replace rev3_rec_tte = "No" if missing(rev3_rec_tte)
replace rev3_rec_ct = "No" if missing(rev3_rec_ct)
drop rev3_rec_bronch
gen rev3_rec_bronch = "No"
replace rev3_rec_free = "No" if missing(rev3_rec_free)
replace rev3_ad = "No additional" if missing(rev3_ad)
save reviewer_3, replace

/* REVIEWER 4 */ 
import excel using "Raw Data\Reviewer 4- KR_complete.xlsx", sheet("Sheet1") firstrow case(lower) clear
describe
ds /* Label each variable by the reviewer */ 
foreach var in `r(varlist)' {
    if "`var'" != "fin" {
        rename `var' rev4_`var'
    }
}
duplicates report fin // Identify duplicate rows based on the 'fin' variable
duplicates examples fin
duplicates drop fin, force
//Duplicate 1245803134 FIN in reviewer 4 with slightly different info - what do you want me to use? 
replace rev4_soc = "No" if missing(rev4_soc)
replace rev4_dex = "Yes" if missing(rev4_dex)
replace rev4_remd = "Yes" if missing(rev4_remd)
replace rev4_tocibaritofa = "No" if missing(rev4_tocibaritofa)
replace rev4_abx = "No" if missing(rev4_abx)
replace rev4_hcq = "No" if missing(rev4_hcq)
drop rev4_iver
gen rev4_iver = "No"
replace rev4_transfer_reason = "Other" if missing(rev4_transfer_reason)
replace rev4_tr_nonresp = "Not Applicable" if missing(rev4_tr_nonresp)
replace rev4_tr_comorb = "None" if missing(rev4_tr_comorb)  
drop rev4_refuses
gen rev4_refuses = "No"
drop rev4_refuses_rea
gen rev4_refuses_rea = "Not applicable"
drop rev4_refuses_tr
gen rev4_refuses_tr = "Not applicable"
replace rev4_tr_support = "Other" if missing(rev4_tr_support)
replace rev4_proc = "None" if missing(rev4_proc)
replace rev4_proc_time = 9999 if missing(rev4_proc_time)
drop rev4_proc_comp
gen rev4_proc_comp = "No"
replace rev4_proc_comp = "Not Applicable" if rev4_proc == "None"
drop rev4_central_line
gen rev4_central_line = "No"
drop rev4_intubation
gen rev4_intubation = "No" 
replace rev4_intubation = "Not Applicable" if strpos(rev4_proc, "ETT") == 0
drop rev4_cardiac_arr
gen rev4_cardiac_arr = "No"
replace rev4_tr_comp = "No" if missing(rev4_tr_comp) 
replace rev4_arr_inter = "No" if missing(rev4_arr_inter)
replace rev4_rec_abx = "No" if missing(rev4_rec_abx)
replace rev4_rec_tte = "No" if missing(rev4_rec_tte)
replace rev4_rec_ct = "No" if missing(rev4_rec_ct)
drop rev4_rec_bronch
gen rev4_rec_bronch = "No"
replace rev4_rec_free = "No" if missing(rev4_rec_free)
replace rev4_ad = "No additional" if missing(rev4_ad)
save reviewer_4, replace

/* REVIEWER 5 */
import excel using "Raw Data\Reviewer 5, JG_completed.xlsx", sheet("Sheet1") firstrow case(lower) clear
rename id fin
rename admit_date admit
rename tocibari tocibaritofa
describe
ds /* Label each variable by the reviewer */ 
foreach var in `r(varlist)' {
    if "`var'" != "fin" {
        rename `var' rev5_`var'		
    }
}
duplicates report fin
replace rev5_soc = "No" if missing(rev5_soc)
replace rev5_dex = "Yes" if missing(rev5_dex)
replace rev5_remd = "Yes" if missing(rev5_remd)
replace rev5_tocibaritofa = "No" if missing(rev5_tocibaritofa)
replace rev5_abx = "No" if missing(rev5_abx)
drop rev5_hcq
gen rev5_hcq = "No"
drop rev5_iver
gen rev5_iver = "No"
replace rev5_transfer_reason = "Other" if missing(rev5_transfer_reason)
replace rev5_tr_nonresp = "Not Applicable" if missing(rev5_tr_nonresp)
drop rev5_tr_comorb
gen rev5_tr_comorb = "None"
replace rev5_refuses = "No" if missing(rev5_refuses)
replace rev5_refuses_rea = "Not applicable" if missing(rev5_refuses_rea)
drop rev5_refuses_rea
gen rev5_refuses_rea = "Not applicable"
drop rev5_refuses_tr
gen rev5_refuses_tr = "Not applicable"
replace rev5_tr_support = "Other" if missing(rev5_tr_support)
replace rev5_proc = "None" if missing(rev5_proc)
replace rev5_proc_time = 9999 if missing(rev5_proc_time)
replace rev5_proc_comp = "No" if missing(rev5_proc_comp)
replace rev5_proc_comp = "Not Applicable" if rev5_proc == "None"
drop rev5_central_line
gen rev5_central_line = "No"
replace rev5_intubation = "No" if missing(rev5_intubation)
replace rev5_intubation = "Not Applicable" if strpos(rev5_proc, "ETT") == 0
replace rev5_cardiac_arr = "No" if missing(rev5_cardiac_arr)
replace rev5_tr_comp = "No" if missing(rev5_tr_comp) 
replace rev5_arr_inter = "No" if missing(rev5_arr_inter)
replace rev5_rec_abx = "No" if missing(rev5_rec_abx)
replace rev5_rec_tte = "No" if missing(rev5_rec_tte)
replace rev5_rec_ct = "No" if missing(rev5_rec_ct)
drop rev5_rec_bronch
gen rev5_rec_bronch = "No"
replace rev5_rec_free = "No" if missing(rev5_rec_free)
gen rev5_ad = "No additional"
save reviewer_5, replace

clear
/* NOTE, ORDER MATTERS FOR THESE MERGES AND THE _MERGE VARIABLES BELOW */ 
use reviewer_1 
merge 1:1 fin using reviewer_2, update generate(_merge_rev2)
merge 1:1 fin using reviewer_3, update generate(_merge_rev3)
merge 1:1 fin using reviewer_4, update generate(_merge_rev4)
merge 1:1 fin using reviewer_5, update generate(_merge_rev5)

ds /* Turn all byte variables into strings */ 
foreach var in `r(varlist)' {
    // Check if the variable is of type 'byte'
    if "`: type `var''" == "byte" {
        // Convert the byte variable to a string
        tostring `var', replace
    }
}

ds /* Label each variable by the reviewer */ 
foreach var in `r(varlist)' {
	if substr("`var'", 1, 7) != "_merge_" { //ignore _merge variables
		if "`var'" != "fin" { //ignore fin - we will match on this
			local varstem = substr("`var'", 6, .)
			display "`varstem'"	
			cap confirm variable first_`varstem' //check if has already been defined
			if _rc != 0 { //hasn't been defined
				local vartype: type `var'
				// Create first_dex: first nonmissing value
				if substr("`vartype'", 1, 3) == "str" {		
					egen str first_`varstem' = rowfirst(rev1_`varstem' rev2_`varstem' rev3_`varstem' rev4_`varstem' rev5_`varstem')
					egen str second_`varstem' = rowlast(rev1_`varstem' rev2_`varstem' rev3_`varstem' rev4_`varstem' rev5_`varstem')
				}
				else{ 
					egen first_`varstem' = rowfirst(rev1_`varstem' rev2_`varstem' rev3_`varstem' rev4_`varstem' rev5_`varstem')
					egen second_`varstem' = rowlast(rev1_`varstem' rev2_`varstem' rev3_`varstem' rev4_`varstem' rev5_`varstem')				
				}
			}
		}
	}
}

describe

gen reviewer_one = . 
gen reviewer_two = .

replace reviewer_one = 1 if _merge_rev2 == 1 & _merge_rev4 == 1 
replace reviewer_two = 5 if _merge_rev2 == 1 & _merge_rev4 == 1

replace reviewer_one = 2 if _merge_rev2 == 2 & _merge_rev4 == 3
replace reviewer_two = 4 if _merge_rev2 == 2 & _merge_rev4 == 3

replace reviewer_one = 1 if _merge_rev2 == 3 & _merge_rev4 == 1
replace reviewer_two = 2 if _merge_rev2 == 3 & _merge_rev4 == 1

replace reviewer_one = 3 if _merge_rev4 == 3 & missing(_merge_rev2)
replace reviewer_two = 4 if _merge_rev4 == 3 & missing(_merge_rev2)

replace reviewer_one = 3 if _merge_rev4 == 1 & missing(_merge_rev2)
replace reviewer_two = 5 if _merge_rev4 == 1 & missing(_merge_rev2)

/* Remove placeholder */ 
replace first_proc_time = . if first_proc_time == 9999
replace second_proc_time = . if second_proc_time == 9999

format first_admit %td
format second_admit %td
format fin %15.0f

/* Discard Columns we're no longer using */ 
keep fin first_admit second_admit first_soc second_soc first_dex second_dex first_remd second_remd first_tocibaritofa second_tocibaritofa first_abx second_abx first_hcq second_hcq first_transfer_reason second_transfer_reason first_tr_nonresp second_tr_nonresp first_tr_comorb second_tr_comorb first_refuses second_refuses first_refuses_rea second_refuses_rea first_tr_support second_tr_support first_proc second_proc first_proc_time second_proc_time first_proc_comp second_proc_comp first_intubation second_intubation first_tr_comp second_tr_comp first_arr_inter second_arr_inter first_iver second_iver first_refuses_tr second_refuses_tr first_central_line second_central_line first_cardiac_arr second_cardiac_arr first_rec_abx second_rec_abx first_rec_tte second_rec_tte first_rec_ct second_rec_ct first_rec_bronch second_rec_bronch first_rec_free second_rec_free reviewer_one reviewer_two

//Encode transfer reasons. 
label define bin_label 0 "No" 1 "Yes"

//Transfer reason
encode first_transfer_reason, gen(first_transfer_reason_temp)
drop first_transfer_reason
rename first_transfer_reason_temp first_transfer_reason
label variable first_transfer_reason "Transfer Reason, Rater 1"

encode second_transfer_reason, gen(second_transfer_reason_temp)
drop second_transfer_reason
rename second_transfer_reason_temp second_transfer_reason
label variable second_transfer_reason "Transfer Reason, Rater 2"

//Label if reason != intubation (by either rater)
gen both_transfer_reason_intub = 0
replace both_transfer_reason_intub = 1 if first_transfer_reason == 3 & second_transfer_reason == 3
tab both_transfer_reason_intub

//Std of Care
encode first_soc, gen(first_soc_temp)
recode first_soc_temp (1 = 0) (2 = 1) // Recode the numeric variable so that "No" becomes 0 and "Yes" becomes 1 - alphabetical
drop first_soc
rename first_soc_temp first_soc
label values first_soc bin_label
label variable first_soc "Std of Care, Rater 1"

encode second_soc, gen(second_soc_temp)
recode second_soc_temp (1 = 0) (2 = 1) // Recode the numeric variable so that "No" becomes 0 and "Yes" becomes 1 - alphabetical
drop second_soc
rename second_soc_temp second_soc
label values second_soc bin_label
label variable second_soc "Std of Care, Rater 2"

//Dexamethasone
encode first_dex, gen(first_dex_temp)
recode first_dex_temp (1 = 0) (2 = 1) // Recode the numeric variable so that "No" becomes 0 and "Yes" becomes 1 - alphabetical
drop first_dex
rename first_dex_temp first_dex
label values first_dex bin_label
label variable first_dex "Dexamethasone, Rater 1"

encode second_dex, gen(second_dex_temp)
recode second_dex_temp (1 = 0) (2 = 1) // Recode the numeric variable so that "No" becomes 0 and "Yes" becomes 1 - alphabetical
drop second_dex
rename second_dex_temp second_dex
label values second_dex bin_label
label variable second_dex "Dexamethasone, Rater 2"

//Remdesevir
encode first_remd, gen(first_remd_temp)
recode first_remd_temp (1 = 0) (2 = 1) // Recode the numeric variable so that "No" becomes 0 and "Yes" becomes 1 - alphabetical
drop first_remd
rename first_remd_temp first_remd
label values first_remd bin_label
label variable first_remd "Remdesevir, Rater 1"

encode second_remd, gen(second_remd_temp)
recode second_remd_temp (1 = 0) (2 = 1) // Recode the numeric variable so that "No" becomes 0 and "Yes" becomes 1 - alphabetical
drop second_remd
rename second_remd_temp second_remd
label values second_remd bin_label
label variable second_remd "Remdesevir, Rater 2"

// Toci, Bari, Tofa
encode first_tocibaritofa, gen(first_tocibaritofa_temp)
recode first_tocibaritofa_temp (1 = 0) (2 = 1) // Recode the numeric variable so that "No" becomes 0 and "Yes" becomes 1 - alphabetical
drop first_tocibaritofa
rename first_tocibaritofa_temp first_tocibaritofa
label values first_tocibaritofa bin_label
label variable first_tocibaritofa "Toci/Bari/Tofa, Rater 1"

encode second_tocibaritofa, gen(second_tocibaritofa_temp)
recode second_tocibaritofa_temp (1 = 0) (2 = 1) // Recode the numeric variable so that "No" becomes 0 and "Yes" becomes 1 - alphabetical
drop second_tocibaritofa
rename second_tocibaritofa_temp second_tocibaritofa
label values second_tocibaritofa bin_label
label variable second_tocibaritofa "Toci/Bari/Tofa, Rater 2"

// Antibiotics
encode first_abx, gen(first_abx_temp)
recode first_abx_temp (1 = 0) (2 = 1) // Recode the numeric variable so that "No" becomes 0 and "Yes" becomes 1 - alphabetical
drop first_abx
rename first_abx_temp first_abx
label values first_abx bin_label
label variable first_abx "Antibiotics, Rater 1"

encode second_abx, gen(second_abx_temp)
recode second_abx_temp (1 = 0) (2 = 1) // Recode the numeric variable so that "No" becomes 0 and "Yes" becomes 1 - alphabetical
drop second_abx
rename second_abx_temp second_abx
label values second_abx bin_label
label variable second_abx "Antibiotics, Rater 2"

// HCQ
encode first_hcq, gen(first_hcq_temp)
recode first_hcq_temp (1 = 0) (2 = 1) // Recode the numeric variable so that "No" becomes 0 and "Yes" becomes 1 - alphabetical
drop first_hcq
rename first_hcq_temp first_hcq
label values first_hcq bin_label
label variable first_hcq "HCQ, Rater 1"

encode second_hcq, gen(second_hcq_temp)
recode second_hcq_temp (1 = 0) (2 = 1) // Recode the numeric variable so that "No" becomes 0 and "Yes" becomes 1 - alphabetical
drop second_hcq
rename second_hcq_temp second_hcq
label values second_hcq bin_label
label variable second_hcq "HCQ, Rater 2"

// Ivermectin
encode first_iver, gen(first_iver_temp)
recode first_iver_temp (1 = 0) (2 = 1) // Recode the numeric variable so that "No" becomes 0 and "Yes" becomes 1 - alphabetical
drop first_iver
rename first_iver_temp first_iver
label values first_iver bin_label
label variable first_iver "Ivermectin, Rater 1"

encode second_iver, gen(second_iver_temp)
recode second_iver_temp (1 = 0) (2 = 1) // Recode the numeric variable so that "No" becomes 0 and "Yes" becomes 1 - alphabetical
drop second_iver
rename second_iver_temp second_iver
label values second_iver bin_label
label variable second_iver "HCQ, Rater 2"

//Non-resp reason
encode first_tr_nonresp, gen(first_tr_nonresp_temp)
drop first_tr_nonresp
rename first_tr_nonresp_temp first_tr_nonresp
label variable first_tr_nonresp "Transfer Reason - Non-resp, Rater 1"

encode second_tr_nonresp, gen(second_tr_nonresp_temp)
drop second_tr_nonresp
rename second_tr_nonresp_temp second_tr_nonresp
label variable second_tr_nonresp "Transfer Reason - Non-resp, Rater 2"

//Comorbid Transfer reson
encode first_tr_comorb, gen(first_tr_comorb_temp)
drop first_tr_comorb
rename first_tr_comorb_temp first_tr_comorb
label variable first_tr_comorb "Transfer Reason - Comorbidity, Rater 1"

encode second_tr_comorb, gen(second_tr_comorb_temp)
drop second_tr_comorb
rename second_tr_comorb_temp second_tr_comorb
label variable second_tr_comorb "Transfer Reason - Comorbidity, Rater 2"

// Refuses Transfer
encode first_refuses, gen(first_refuses_temp)
recode first_refuses_temp (1 = 0) (2 = 1) // Recode the numeric variable so that "No" becomes 0 and "Yes" becomes 1 - alphabetical
drop first_refuses
rename first_refuses_temp first_refuses
label values first_refuses bin_label
label variable first_refuses "Refuses Transfer, Rater 1"

encode second_refuses, gen(second_refuses_temp)
recode second_refuses_temp (1 = 0) (2 = 1) // Recode the numeric variable so that "No" becomes 0 and "Yes" becomes 1 - alphabetical
drop second_refuses
rename second_refuses_temp second_refuses
label values second_refuses bin_label
label variable second_refuses "Refuses Transfer, Rater 2"

// Refuses Transfer
encode first_refuses_rea, gen(first_refuses_rea_temp)
drop first_refuses_rea
rename first_refuses_rea_temp first_refuses_rea
label variable first_refuses_rea "Refuses Transfer Reason, Rater 1"

replace second_refuses_rea = subinstr(second_refuses_rea, "Not applicable", "Not Applicable", .)
encode second_refuses_rea, gen(second_refuses_rea_temp)
drop second_refuses_rea
rename second_refuses_rea_temp second_refuses_rea
label variable second_refuses_rea "Refuses Transfer, Rater 2"

//Transfer support
encode first_tr_support, gen(first_tr_support_temp)
drop first_tr_support
rename first_tr_support_temp first_tr_support
label variable first_tr_support "Transfer Support, Rater 1"

encode second_tr_support, gen(second_tr_support_temp)
drop second_tr_support
rename second_tr_support_temp second_tr_support
label variable second_tr_support "Transfer Support, Rater 2"

//Procedures
encode first_proc, gen(first_proc_temp)
drop first_proc
rename first_proc_temp first_proc
label variable first_proc "Procedure, Rater 1"

encode second_proc, gen(second_proc_temp)
drop second_proc
rename second_proc_temp second_proc
label variable second_proc "Procedure, Rater 2"

//Procedure Complications
encode first_proc_comp, gen(first_proc_comp_temp)
drop first_proc_comp
rename first_proc_comp_temp first_proc_comp
label variable first_proc_comp "Procedure Complications, Rater 1"

encode second_proc_comp, gen(second_proc_comp_temp)
drop second_proc_comp
rename second_proc_comp_temp second_proc_comp
label variable second_proc_comp "Procedure Complications, Rater 2"

//Intubation
encode first_intubation, gen(first_intubation_temp)
drop first_intubation
rename first_intubation_temp first_intubation
label variable first_intubation "Intubation, Rater 1"

encode second_intubation, gen(second_intubation_temp)
drop second_intubation
rename second_intubation_temp second_intubation
label variable second_intubation "Intubation, Rater 2"

//Transfer Complication
encode first_tr_comp, gen(first_tr_comp_temp)
drop first_tr_comp
rename first_tr_comp_temp first_tr_comp
label variable first_tr_comp "Transfer Complication, Rater 1"

encode second_tr_comp, gen(second_tr_comp_temp)
drop second_tr_comp
rename second_tr_comp_temp second_tr_comp
label variable second_tr_comp "Transfer Complication, Rater 2"

//Arr Inter
encode first_arr_inter, gen(first_arr_inter_temp)
drop first_arr_inter
rename first_arr_inter_temp first_arr_inter
label variable first_arr_inter "Arr Inter, Rater 1"

encode second_arr_inter, gen(second_arr_inter_temp)
drop second_arr_inter
rename second_arr_inter second_arr_inter
label variable second_arr_inter "Arr Inter, Rater 2"

//Refuses Transfer
encode first_refuses_tr, gen(first_refuses_tr_temp)
drop first_refuses_tr
rename first_refuses_tr_temp first_refuses_tr
label variable first_refuses_tr "Refuses Transfer, Rater 1"

encode second_refuses_tr, gen(second_refuses_tr_temp)
drop second_refuses_tr
rename second_refuses_tr_temp second_refuses_tr
label variable second_refuses_tr "Refuses Transfer, Rater 2"

//Central Line
encode first_central_line, gen(first_central_line_temp)
drop first_central_line
rename first_central_line_temp first_central_line
label variable first_central_line "Central Line, Rater 1"

encode second_central_line, gen(second_central_line_temp)
drop second_central_line
rename second_central_line_temp second_central_line
label variable second_refuses_tr "Refuses Transfer, Rater 2"

//Cardiac Arrest
encode first_cardiac_arr, gen(first_cardiac_arr_temp)
drop first_cardiac_arr
rename first_cardiac_arr_temp first_cardiac_arr
label variable first_cardiac_arr "Cardiac Arrest, Rater 1"

encode second_cardiac_arr, gen(second_cardiac_arr_temp)
drop second_cardiac_arr
rename second_cardiac_arr_temp second_cardiac_arr
label variable second_cardiac_arr "Cardiac Arrest, Rater 2"

//Tele Rec Abx
encode first_rec_abx, gen(first_rec_abx_temp)
drop first_rec_abx
rename first_rec_abx_temp first_rec_abx
label variable first_rec_abx "Tele Rec. Antibiotics, Rater 1"

encode second_rec_abx, gen(second_rec_abx_temp)
drop second_rec_abx
rename second_rec_abx_temp second_rec_abx
label variable second_rec_abx "Tele Rec. Antibitiocs, Rater 2"

//Tele Rec TTE
encode first_rec_tte, gen(first_rec_tte_temp)
drop first_rec_tte
rename first_rec_tte_temp first_rec_tte
label variable first_rec_tte "Tele Rec. TTE, Rater 1"

encode second_rec_tte, gen(second_rec_tte_temp)
drop second_rec_tte
rename second_rec_tte_temp second_rec_tte
label variable second_rec_tte "Tele Rec. TTE, Rater 2"

//Tele Rec CT
encode first_rec_ct, gen(first_rec_ct_temp)
drop first_rec_ct
rename first_rec_ct_temp first_rec_ct
label variable first_rec_ct "Tele Rec. CT, Rater 1"

encode second_rec_ct, gen(second_rec_ct_temp)
drop second_rec_ct
rename second_rec_ct_temp second_rec_ct
label variable second_rec_ct "Tele Rec. CT, Rater 2"

//Tele Rec Bronch
encode first_rec_bronch, gen(first_rec_bronch_temp)
drop first_rec_bronch
rename first_rec_bronch_temp first_rec_bronch
label variable first_rec_bronch "Tele Rec. Bronch, Rater 1"

encode second_rec_bronch, gen(second_rec_bronch_temp)
drop second_rec_bronch
rename second_rec_bronch_temp second_rec_bronch
label variable second_rec_bronch "Tele Rec. Bronch, Rater 2"

rename fin hospitalaccountnumber // to make consistent for merging with other data. 

/* Save rater dataset */ 	
save rater_data, replace
export excel using "rater data.xlsx", firstrow(varlabels) keepcellfmt replace 

/* Calculate Agreement Statistics ( [ ] move this to calculations file ) */

// Save the name of the currently active log file, if any
local previous_log = "" // Default to empty if no previous log is open
capture noisily {
    log query
    local previous_log = "`r(filename)'"
}

// Start the temporary log
capture log close
log using rater_agreement.txt, text replace
if _rc == 601 {
    log close
    log using rater_agreement.txt, text replace
}

//Reason for transfer
tab first_transfer_reason second_transfer_reason
kap first_transfer_reason second_transfer_reason

//Std of Care 
tab first_soc second_soc
kap first_soc second_soc
tab first_soc second_soc if both_transfer_reason_intub == 1
kap first_soc second_soc if both_transfer_reason_intub == 1

//Dexamethasone
tab first_dex second_dex
kap first_dex second_dex
tab first_dex second_dex if both_transfer_reason_intub == 1
kap first_dex second_dex if both_transfer_reason_intub == 1


//Remdesevir
tab first_remd second_remd
kap first_remd second_remd
tab first_remd second_remd if both_transfer_reason_intub == 1
kap first_remd second_remd if both_transfer_reason_intub == 1

//ABX
tab first_abx second_abx
kap first_abx second_abx
tab first_abx second_abx if both_transfer_reason_intub == 1
kap first_abx second_abx if both_transfer_reason_intub == 1

//Toci, Bari, Tofa
tab first_tocibaritofa second_tocibaritofa
kap first_tocibaritofa second_tocibaritofa
tab first_tocibaritofa second_tocibaritofa if both_transfer_reason_intub == 1
kap first_tocibaritofa second_tocibaritofa if both_transfer_reason_intub == 1

//HCQ
tab first_hcq second_hcq
kap first_hcq second_hcq
tab first_hcq second_hcq if both_transfer_reason_intub == 1
kap first_hcq second_hcq if both_transfer_reason_intub == 1

//Ivermectin
tab first_iver second_hcq
kap first_hcq second_hcq
tab first_iver second_hcq if both_transfer_reason_intub == 1
kap first_hcq second_hcq if both_transfer_reason_intub == 1

//Transfer Reason: nonresp
tab first_tr_nonresp second_tr_nonresp
kap first_tr_nonresp second_tr_nonresp
tab first_tr_nonresp second_tr_nonresp if both_transfer_reason_intub == 1
kap first_tr_nonresp second_tr_nonresp if both_transfer_reason_intub == 1

//Transfer Reason: Comorbidity
tab first_tr_comorb second_tr_comorb
kap first_tr_comorb second_tr_comorb
tab first_tr_comorb second_tr_comorb if both_transfer_reason_intub == 1
//kap first_tr_comorb second_tr_comorb if both_transfer_reason_intub == 1 //none

//Refuses Transfer
tab first_refuses second_refuses
kap first_refuses second_refuses
tab first_refuses second_refuses if both_transfer_reason_intub == 1
kap first_refuses second_refuses if both_transfer_reason_intub == 1

//Refuses Transfer, Reason 
tab first_refuses_rea second_refuses_rea
kap first_refuses_rea second_refuses_rea
tab first_refuses_rea second_refuses_rea if both_transfer_reason_intub == 1
kap first_refuses_rea second_refuses_rea if both_transfer_reason_intub == 1

// Transfer Support 
tab first_tr_support second_tr_support
kap first_tr_support second_tr_support
tab first_tr_support second_tr_support if both_transfer_reason_intub == 1
kap first_tr_support second_tr_support if both_transfer_reason_intub == 1

// Procedures
tab first_proc second_proc
kap first_proc second_proc
tab first_proc second_proc if both_transfer_reason_intub == 1
kap first_proc second_proc if both_transfer_reason_intub == 1

//Procedure Complication
tab first_proc_comp second_proc_comp
kap first_proc_comp second_proc_comp
tab first_proc_comp second_proc_comp if both_transfer_reason_intub == 1
kap first_proc_comp second_proc_comp if both_transfer_reason_intub == 1

//Intubation 
tab first_intubation second_intubation
kap first_intubation second_intubation
tab first_intubation second_intubation if both_transfer_reason_intub == 1
kap first_intubation second_intubation if both_transfer_reason_intub == 1

//Transfer Complications
tab first_tr_comp second_tr_comp
kap first_tr_comp second_tr_comp
tab first_tr_comp second_tr_comp if both_transfer_reason_intub == 1
kap first_tr_comp second_tr_comp if both_transfer_reason_intub == 1

//Arr Inter
tab first_arr_inter second_arr_inter
kap first_arr_inter second_arr_inter
tab first_arr_inter second_arr_inter if both_transfer_reason_intub == 1
kap first_arr_inter second_arr_inter if both_transfer_reason_intub == 1

//Refuses Transfer
tab first_refuses_tr second_refuses_tr
kap first_refuses_tr second_refuses_tr
tab first_refuses_tr second_refuses_tr if both_transfer_reason_intub == 1
kap first_refuses_tr second_refuses_tr if both_transfer_reason_intub == 1

//Central Line 
tab first_central_line second_central_line //No central line procedures? 
//kap first_central_line second_central_line
tab first_central_line second_central_line if both_transfer_reason_intub == 1 //No central line procedures? 
//kap first_central_line second_central_line

//Cardiac Arrest
tab first_cardiac_arr second_cardiac_arr
kap first_cardiac_arr second_cardiac_arr
tab first_cardiac_arr second_cardiac_arr if both_transfer_reason_intub == 1
kap first_cardiac_arr second_cardiac_arr if both_transfer_reason_intub == 1

//Tele Rec Abx
tab first_rec_abx second_rec_abx
kap first_rec_abx second_rec_abx
tab first_rec_abx second_rec_abx if both_transfer_reason_intub == 1
kap first_rec_abx second_rec_abx if both_transfer_reason_intub == 1

//Tele Rec TTE
tab first_rec_tte second_rec_tte
kap first_rec_tte second_rec_tte
tab first_rec_tte second_rec_tte if both_transfer_reason_intub == 1
kap first_rec_tte second_rec_tte if both_transfer_reason_intub == 1

//Tele Rec CT 
tab first_rec_ct second_rec_ct
kap first_rec_ct second_rec_ct
tab first_rec_ct second_rec_ct if both_transfer_reason_intub == 1
kap first_rec_ct second_rec_ct if both_transfer_reason_intub == 1

//Tele Rec Bronch
tab first_rec_bronch second_rec_bronch
kap first_rec_bronch second_rec_bronch
tab first_rec_bronch second_rec_bronch if both_transfer_reason_intub == 1
kap first_rec_bronch second_rec_bronch if both_transfer_reason_intub == 1

// Close the temporary log
log close

// Resume the previous log if it exists
if "`previous_log'" != "" {
    log using "`previous_log'", append
}


/* ----------

Combine transfer hospitalizations 

sketch
--> create last-pre, first post- 
-> shift days on the post
--> add pre and post prefixes
--> merge by mrn
--> create new vars that are maximum of pre or post 

---------------*/ 

use just_transfers, clear

//Gonzales, Nick had two transfers... only keep the first one
sort mrn pre_transfer icuadmissiondatetime 
by mrn pre_transfer: gen first_admission = (_n == 1) //Identify the first observation within each MRN-pre_transfer combination
keep if first_admission //Filter to keep only the first observation of each combination
drop first_admission  

/* 
SALAZAR,MARIA L - 547628013  -- transfer AF -> UV -> IMED all on 1 day.  *** just use first? 
BORG,KRIS S - 403384395 -- transfer AF -> UV -> IMED  *** not all in 1 day *** just use first? 
*/ 
drop if pre_transfer == 1 & post_transfer == 1  //dual transfers

duplicates report hosp_admit_name //unique 
duplicates report icu_admit_name //unique
missings report enc_id  //88 missing enc_id
duplicates report mrn //2 of each, 335 transfers. 

tab icu_los if pre_transfer == 1, plot
sum icu_los, detail
gen icu_los_int = round(icu_los) // the idea will be to shift all of these up in the post
/* Note: ICU_los_int does not get the number of calendar days, as sometimes 
people come in light and leave early, having values for both calendar days */
gen calendar_days = 0
forval day = 1/50 {
    local varname = "apache_3_score_day_`day'"
    replace calendar_days = `day' if !missing(`varname') & (`day' > calendar_days)
}

// Concatenate "mrn" and "post_transfer" variables without overwriting to reshape on
tostring mrn, generate(mrn_str)
tostring post_transfer, generate(post_transfer_str)
gen mrn_post_transfer = mrn_str + "_" + post_transfer_str
drop post_transfer_str mrn_str
reshape long apache_3_score_day_ aps_day_ apache_4_hosp_mort_day_ apache_4_cum_mort_day_ crrt_ cardiovert_ cont_art_drug_inf_ cont_iv_sed_ cont_nmb_ cont_anti_arrh_ ecmo_ emerg_op_in_icu_ emerg_op_out_icu_ endoscope_ hfnc_ icu_intub_ ippv_ irrt_ iv_fluid_rep_ mtp_ mult_pressors_ nippv_ one_pressor_ pa_cath_ post_arrest_ prone_ reintub_ ttm_, i(mrn_post_transfer) j(day)
drop mrn_post_transfer

// Variables that should be present every day (not binary; should correspond to LOS): 
// apache_3_score_day_ aps_day_ apache_4_hosp_mort_day_ apache_4_cum_mort_day_

missings table apache_3_score_day aps_day apache_4_hosp_mort_day apache_4_cum_mort_day //45 with only some missing
drop if missing(apache_3_score_day) & missing(aps_day) & missing(apache_4_hosp_mort_day) & missing(apache_4_cum_mort_day)
missings list apache_3_score_day aps_day apache_4_hosp_mort_day apache_4_cum_mort_day // just apache 4 occ. missing.

/* 
TODO: merging will occur based on intubation day - make adjustment relative to transfer.
Make Adjustment re: day of intubation? 

min of ippv variable

//TODO: Day of first intubation?  (for comparison), etc. 
*/ 
egen first_day_with_ippv = min(day) if ippv == 1, by(mrn) // minimum day w IPPV flag = day of intubation.

//Create day_indexed_transfer. 0 = last day pre, 1 = first day post 
// HOSPITAL DAY 0 = LAST PRE, DAY 1 = FIRST POST. MIN = FIRST, MAX = LAST. 
// Note: later they all need to be positive, thus add 100 below.
gen day_indexed_transfer = day 
replace day_indexed_transfer = day - calendar_days if post_transfer == 0
label variable day_indexed_transfer "Day, relative to transfer"

/* Cannot use negative ID's, thus need to add 100 to each */ 
gen adj_day_indexed_transfer = day_indexed_transfer + 100
drop day_indexed_transfer

/* Merge rating data-set with the pre-transfers
Rater data = has unique FIN for each
merge 1:many with hospitalaccountnumber */ 
merge m:1 hospitalaccountnumber using rater_data, update replace generate(_merge_rater_data)
drop _merge* //nuissance vars at this point. 

/*-----------------
Convert back to wide
-----------------*/ 

//For variables that differ between pre_ and post_ - create dual vars and later merge. 

/* 
List of variables that will differ between pre_ and post_ 

Keep with logic to keep the first one that is not missing: 
age
bmi

Worth keeping with pre_ and post_ prefixes
hospital_billing 
*/ 

//turns out, everyone has an age so can just use first pre 
bysort mrn (age): replace age = age[1] //smallest age per MRN 

//BMI: make all the same = first day where BMI is recorded, smaller of pre- and post-
egen min_day_with_bmi = min(day) if !missing(bmi), by(mrn) // Step 1: Find the minimum day where bmi is not missing
gen bmi_from_min_day = . // Step 2: Get the bmi corresponding to the minimum day
bysort mrn (day): replace bmi_from_min_day = bmi if day == min_day_with_bmi
bysort mrn (day): replace bmi_from_min_day = bmi_from_min_day[_n-1] if missing(bmi_from_min_day) // Step 3: Replace bmi with the propagated value
bysort mrn: replace bmi = bmi_from_min_day
bysort mrn (bmi): replace bmi = bmi[1] // Step 4: Replace with the smallest bmi in the group
drop min_day_with_bmi bmi_from_min_day // Step 5: Cleanup

gen pre_hospital_billing = hospital_billing if pre_transfer == 1
gen post_hospital_billing = hospital_billing if post_transfer == 1
bysort mrn (pre_hospital_billing): replace pre_hospital_billing = pre_hospital_billing[1] 
bysort mrn (post_hospital_billing): replace post_hospital_billing = post_hospital_billing[1] 
label values pre_hospital_billing hospital_billing
label values post_hospital_billing hospital_billing

/*  
Worth keeping with pre_ and post_ prefixes
[x] hospital_billing 
[ ] discharge_location  [ ] or maybe get rid of it? 
[ ] hospitalaccountnumber 
[ ] hospitaladmissiondatetime 
[ ] hospitaldischargedatetime 
[ ] icuadmissiondatetime 
[ ] icudischargedatetime
[ ] tele_status [ ] how are these diff, and is it implied? 
[ ] tele_cc_icu [ ] how are these diff, and is it implied? 
[ ] total_icu_days_crrt
[ ] total_icu_days_nmb
[ ] total_icu_days_proning
[ ] total_icu_days_crrt
[ ] total_icu_days_nmb 
[ ] cont_nmb (???) - what is the deal with this one? 
[ ] total_icu_days_proning
[ ] num_code_status 
[ ] time_thru_icu_rank 
[ ] post_icu_dest
[ ] apachereadmit
[ ] apachereadmitwithin24hours
[ ] apache_dx 
[ ] adm_icu 
[ ] hospital_los 
[ ] icu_los 
[ ] icu_los_int 

TODO (what differences? make pre_ and post_ then compare: 
loc_at_death (not sure why)
hosp_disch_loc (not sure why)
chr_dialysis (not sure why)

Discard: 

pre_transfer  (info encoded in day index)
post_transfer

icu_admit_name 
days_cont_crrt_1 days_cont_crrt_2 days_cont_crrt_3  
days_cont_nmb_1 days_cont_nmb_2 days_cont_nmb_3 days_cont_nmb_4  
days_cont_proning_1 days_cont_proning_2 
start_crrt_1 stop_crrt_1 days_cont_crrt_1 start_crrt_2 stop_crrt_2 days_cont_crrt_2 start_crrt_3 stop_crrt_3 days_cont_crrt_3

icuadmissiondate_only 
hosp_admit_name enc_id
start_nmb_1 stop_nmb_1 days_cont_nmb_1 start_nmb_2 stop_nmb_2 days_cont_nmb_2 start_nmb_3 stop_nmb_3 days_cont_nmb_3 start_nmb_4 stop_nmb_4 days_cont_nmb_4  
start_proning_1 stop_proning_1 days_cont_proning_1 start_proning_2 stop_proning_2 days_cont_proning_2 


[ ] TODO: - can we just synthesize these into number of reintubations? 
reintub_rank_1 reintub_rank_2 reintub_rank_3 reintub_rank_4 reintub_rank_5 reintub_rank_6 reintub_rank_7 reintub_rank_8 reintub_rank_9 reintub_rank_10 reintub_rank_11 reintub_rank_12 reintub_rank_13 reintub_rank_14 reintub_rank_15 reintub_rank_16 reintub_rank_17 reintub_rank_18 reintub_rank_19 reintub_rank_20 reintub_rank_21 reintub_rank_22 reintub_rank_23 reintub_rank_25 reintub_rank_26 reintub_rank_27 _merge_reintub

[ ] TODO: useful way to synthesize these? 
code_string1 code_status1 start_code_status1 stop_code_status1 hosp_day_start_code_status1 hosp_day_stop_code_status1 dur_code_status1 code_string2 code_status2 start_code_status2 stop_code_status2 hosp_day_start_code_status2 hosp_day_stop_code_status2 dur_code_status2 code_string3 code_status3 start_code_status3 stop_code_status3 hosp_day_start_code_status3 hosp_day_stop_code_status3 dur_code_status3 code_string4 code_status4 start_code_status4 stop_code_status4 hosp_day_start_code_status4 hosp_day_stop_code_status4 dur_code_status4 code_string5 code_status5 start_code_status5 stop_code_status5 hosp_day_start_code_status5 hosp_day_stop_code_status5 dur_code_status5 code_string6 code_status6 start_code_status6 stop_code_status6 hosp_day_start_code_status6 hosp_day_stop_code_status6 dur_code_status6 code_string7 code_status7 start_code_status7 stop_code_status7 hosp_day_start_code_status7 hosp_day_stop_code_status7 dur_code_status7 code_string8 code_status8 start_code_status8 stop_code_status8 hosp_day_start_code_status8 hosp_day_stop_code_status8 dur_code_status8 
*/ 



/* 
List of variables that will not differ between pre_ and post_arrest
mrn 
patientname 
death_date 
sex_male

race
ethnicity
died
ever_transfer

cnd_Acquired_Immunodeficiency_Sy cnd_COPD_Moderate cnd_COPD_No_Limitations cnd_COPD_Severe cnd_Cirrhosis cnd_Diabetes_Mellitus cnd_Hepatic_Failure cnd_Immune_Suppression cnd_Leukemia_Myeloma cnd_No_COPD cnd_No_Chronic_Health cnd_Non_Hodgkins_Lymphoma cnd_Post_COVID_Conditions cnd_Solid_Tumor_w_Metastasis cnd_Unavailable_Chronic_Health chr_dialysis

Discarded: 
singleselectcdevalue
*/ 

keep age bmi pre_or_post_transfer apache_3_score_day_ aps_day_ apache_4_hosp_mort_day_ apache_4_cum_mort_day_ crrt_ cardiovert_ cont_art_drug_inf_ cont_iv_sed_ cont_nmb_ cont_anti_arrh_ ecmo_ emerg_op_in_icu_ emerg_op_out_icu_ endoscope_ hfnc_ icu_intub_ ippv_ irrt_ iv_fluid_rep_ mtp_ mult_pressors_ nippv_ one_pressor_ pa_cath_ post_arrest_ prone_ reintub_ ttm_ mrn adj_day_indexed_transfer patientname death_date sex_male race ethnicity died ever_transfer cnd_Acquired_Immunodeficiency_Sy cnd_COPD_Moderate cnd_COPD_No_Limitations cnd_COPD_Severe cnd_Cirrhosis cnd_Diabetes_Mellitus cnd_Hepatic_Failure cnd_Immune_Suppression cnd_Leukemia_Myeloma cnd_No_COPD cnd_No_Chronic_Health cnd_Non_Hodgkins_Lymphoma cnd_Post_COVID_Conditions cnd_Solid_Tumor_w_Metastasis cnd_Unavailable_Chronic_Health

/* 
list of vars that are day specific. These are merged on day of transfer: 
apache_3_score_day_
aps_day_
apache_4_hosp_mort_day_
apache_4_cum_mort_day_
crrt_ 
cardiovert_
cont_art_drug_inf_
cont_iv_sed 
cont_nmb_
cont_anti_arrh_ 
ecmo_
emerg_op_in_icu_
emerg_op_out_icu_
endoscope_
hfnc_
icu_intub_
ippv_
irrt_
iv_fluid_rep_
mtp_
mult_pressors_
nippv_ 
one_pressor
pa_cath_
post_arrest_
prone_
reintub_
ttm_
*/ 
//can only keep ~20 variables with my STATA version. Drop least interesting
drop endoscope_ emerg_op_in_icu_ emerg_op_out_icu_ pa_cath_ iv_fluid_rep_ cont_anti_arrh_ cont_art_drug_inf_ cardiovert_
// already dropped act_av_pace_ barb_anesth_ iv_vaso_ vad_ ventriculost_ tx_acid_base_


/* Derivative Variables to create to facilitate easy analysis */ 
//TODO: make first and last vars before merge? first_pre , last_post - e.g. egen first_day_with_ippv = min(day) if ippv == 1, by(mrn) // minimum day w IPPV flag = day of intubation.
//TODO: make highest and lowest vars after merge [max] max_pre max_post - ***

drop if missing(adj_day_indexed_transfer)
reshape wide apache_3_score_day_ aps_day_ apache_4_hosp_mort_day_ apache_4_cum_mort_day_ crrt_ cont_iv_sed_ cont_nmb_ ecmo_ hfnc_ icu_intub_ ippv_ irrt_ mtp_ mult_pressors_ nippv_ one_pressor_ post_arrest_ prone_ reintub_ ttm_, i(mrn) j(adj_day_indexed_transfer)

rename pre_or_post_transfer transfer_occured //indicator that a transfer was involved.


	
	
	


use just_non_transfers, clear

duplicates report enc_id //~2300 missing
missings report enc_id //2314 missing... quite a lot?  even a few in the transfers. 
duplicates report mrn
missings report mrn //have enc_id, generally?  hospital_billing spreadsheet, have hosp_admit_name
duplicates report icu_admit_name  //this is unique and no missing *** merge etc. on this - however, issue will be why duplicates. 
missings report icu_admit_name
duplicates report patientname


//Ultimately, want to merge to NOT transfer dataset 
//Need a not transfers dataset?  - if we are going to create comparison groups, need to find an anchor to shift on. 
/// --- intubation? 
//yes, and will need to remove duplicates and bounces - including pre_bounces? 


//TOdO : Need to merge all_data_sans raters with raters data. 
// Note: that all data from the reviewers only pertains to transferred patients.  - may need to add a flag



use all_data, clear





//Other data elements: 




/*Analysis:
Comparison groups = 
Intubated, but non-transferred patients. 


I attached my last PGR with a breakdown of what we were thinking to help jog your memory since it's been a few months. Just jump to slide 25. I think most of the stuff I looked at is self-explanatory in the slides. I did this all from pivot tables in excel, so if you don't mind crunching everything with stata I'm sure it'll be more reliable. 

The one thing I couldn't work in pivot tables was the transfer time. The off the floor time is buried in Hospital discharge date/time and arrival time is ICU admission date/time. 

Think it would be interesting to look at prolonged transfer time and arrival SOI scores. The only interesting trend I found were the APACHE/APS scores. The intubated & transferred patients had a higher APACHE/APS with a declining trend for the 72 hours following transfer while the intubated/no transfer had an increasing APACHE/APS trend, which is supportive of what we were thinking regarding transfer as a potential harmful intervention immediately after transfer. There's some COVID data that seems to support this, as well. 


I also attached the missing demographic data that needs to be added to the main dataset.


//TCC Demographics File. xlsx
//[ ] TODO: to what extent is this new, or just better data? 
 */ 









//Maybe approach =  1 dataset for just transfers (and merge with raters)
// [ ] plan = just transfers -> merge with raters -> comparison groups

//then a separate document where I evaluate just the intubated comparison group. 

//Intubated but not transferred [by whether they are in a referral hospital or not]


//Outcome = 24-h, 48-h, 72-h illness severity from intubation. 





//TODO: identify intubated at mothership and intubated at peripheral center as comparator groups (Spoke) (Hub)
//Need to find way to identify patients who are intubated. - then split by transfer vs not?




//Note: time through icu, ever transfer, pre_ and post_transfer should let us restrict to what we want. 



///Suspicious ones

/*
patientname
WRAICH,SUKHJIT
RICKORDS,KAREN
JENKINS,JOSHUA C -- internal bounce
CAMPBELL,KARRI J
HOLMES,PATSY H
SMITH,DEBY L
NEWTON,JOHN
MANCINI,DENNIS
LEISHMAN,SCOTT F
BEEGLE,PATRICIA L
GWYNN,THOMAS D
HUTCHINSON,THOMAS S
BEEGLE,PATRICIA L
HALVERSON,JOEL C
DUNSTER,JESSICA
FOLTZ,SHIRLY G
MATAELE,IPU
ANTHONY,KYLE C
GRAHAM,MICHELLE P -- bounced in and out of the same icu twice
ARLT,PHILLIP M
SCOW,JAMES A -- bounced at AF before ultimately transferring to UVU
ROMERO,MARIA D
HOLMES,PATSY H
SOHN,DAVID W
*/ 



/* ?Manual exclusions
patientname


HOLMES,PATSY H - 268538485  -- first was a bounce back to the same ICU, then later a legit transfer. 
HOLMES,PATSY H - 268538485 
SCOW,JAMES A - 403321904 -- bounced at AF before ultimately transferring to UVU
RICKORDS,KAREN - 547755767 -- bounce 
BEEGLE,PATRICIA L - 403732991 - in and out of PK twice, then ultimately transfer to LD
BEEGLE,PATRICIA L - 403732991
ANTHONY,KYLE C - 540141226 - bounced within a day at logan, then later transfer to IMED
*/ 

// JENKINS,JOSHUA C - in and out of riverton twice in the same day. Need to move this back to non-transfer. 
// GRAHAM,MICHELLE P - in and out of logan twice  [these ones came up as ***]









/* --------------
These are redundant data-sets that are not currently needed; kept here fore now
---------------*/ 

//Active treatments per admit.xlsx - also 3740 patients
//No use for this data-sheet. - redundant but less granular than active treatments by day 
import excel using "Raw Data\Active treatments per admit.xlsx", sheet("Report 1") cellrange(B4) firstrow case(lower) clear
ds, has(type string) //convert each string to 64 length (for later merging)
local stringvars `r(varlist)'
foreach var of local stringvars {
    replace `var' = trim(`var')
    recast str64 `var'
}
destring(mrn hospitalaccountnumber), force replace
keep if !missing(mrn)
quietly levelsof mrn, local(mrnLevels) 
di "Number of unique MRN values: " `: word count `mrnLevels''
clear

//active treatments per stay number.xlsx  - 3740 patients, 4110 admissions
//No need for this data. 
import excel using "Raw Data\active treatments per stay number.xlsx", sheet("Report 1") cellrange(B4) firstrow case(lower) clear
ds, has(type string) //convert each string to 64 length (for later merging)
local stringvars `r(varlist)'
foreach var of local stringvars {
    replace `var' = trim(`var')
    recast str64 `var'
}
destring(mrn hospitalaccountnumber ofoccurrences), force replace
keep if !missing(mrn)

gen temp_date = date(icuadmissiondatetime, "DMY")
drop icuadmissiondatetime
rename temp_date icuadmissiondatetime
format icuadmissiondatetime %td
gen temp_date = date(hospitaladmissiondatetime, "DMY")
drop hospitaladmissiondatetime
rename temp_date hospitaladmissiondatetime
format hospitaladmissiondatetime %td 

gen icu_admit_name = string(icuadmissiondatetime) + "-" + string(mrn, "%12.0f")
label variable icu_admit_name "ICU-Identifier: Admit date - MRN"
quietly levelsof mrn, local(mrnLevels)
quietly levelsof icu_admit_name, local(icuAdmitNameLevels)
di "Number of unique MRN: " `: word count `mrnLevels''
di "Number of unique ICU Admits: " `: word count `icuAdmitNameLevels''












/* Not actually going to use the following code: 
gen apache_3_score_day_last_pre = .
forvalues i = 1/`=_N' {
	if pre_transfer[`i'] == 1 {
		local day_var = "apache_3_score_day_" + string(icu_los_int[`i']) //Retrieve the column name for the last day based on icu_los_int
        * Assign the value of the dynamically chosen column to aps_day_last_pre Use `in` to ensure the assignment is per observation
		replace apache_3_score_day_last_pre = `day_var'[`i'] in `i'
	}
}

list mrn pre_transfer icu_los_int apache_3_score_day_last_pre apache_3_score_day* in 51/60
*/ 



