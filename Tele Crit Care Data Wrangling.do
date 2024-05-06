* Data pre-processing
clear

// Brian Locke
// Last updated May 5 2024


/* 
Merge Data From each several Excel spreadsheets Down to down to 1 line per patient

"Info, apache mortality" sheet processing; 3718 patients; 4123 admits
(+several pages corresponding to specific interventions)

Code Status: 4023 patients; 4023 admissions 

Chronic Conditions Initial Group: 5160 patients. ; 5770 icu admits (some extra)

Chronic conditions Missing Group 1-3: In total, this contains data from 1808 patients. 1930 admits

"Missing APACHE patients, merged.xlsx" 1322 patients; 1394 icu admissions

Active treatments per day.xlsx 3740 patients; 4118 admits

(Active treatments per admit and active treatments per stay number not used because they contain only redundant information)



[ ] ???
Reminder: for active treaetments per day, chronic conditions initial group, and cumulatives scores per day - must remove the "blocks" by hospital in the spreadsheet and fill in the ICU-s


---- 
To get started on the chart review we just need to get the transferred patients ironed out:

All patients admitted to a tele-facility and transferred will have a hospital discharge location of "another hospitals ICU"
The MRN for each patient will remain consistent across admissions/encounters
The FIN (or hospital account number) will be consistent with each encounter, i.e. same FIN for tele-facility admission and then upon arrival at referral facility will have a different FIN for that admission. MRN will remain the same.

Sorry this example doesn't line up perfectly but for this patient you'll see hospital discharge destination "another hospital's ICU" with a discharge date of 8/23/21. The second encounter will be the hospital admission date of 8/23/21. The MRN is the same for both of these but the hospital account number is different. Not specified as discharge destination = death

I'll defer to you about how to match these up but that seems to reliably identify our transfers

Logic for determining that a transfer has occured: 

There will be an initial row entry that corresponds to the initial admission with discharge to Another Hospital's ICU
There will be a post-transfer ICU admission. 

Patients who are not transferred may have 
- just 1 admission
- an admission and a readmission 




All combined: 
Number of unique MRNs: 5742
Number of unique ICU Admits: 6514


Combining method: 
Link based on MRN+Admit time to identify a unique admission
Combine all the comorbidity, intervention, apache data per intervention
Then, flag which ones involved an ICU to ICU transfer: Discharge Location: to another ICU and a discharge time within 48hours of another admit. 

Then, keep those that are involved in either a pre- or a post- transfer hospitalization

For procedures, I truncated days at hospital day 50 (mainly because stata basic limits to 2400 variable names which we were reaching)

Versions in wide (1 row per patient, different columns for each day) and long (different row for each patient x day)

For the wide verisons, the # at the end of the variable is the ICU-day that it refers to, except in a few cases (mainly done just so that it didn't take a few hundred sparsely populated variables to represent the data): 

-- for code status, the # refers to how many times they've changed their code status


TODO: 
-- still need to assess some of the merge flags to make sure none of the data is bad, lots of conflicts on third move
-- still need to reconcile the old and new data variables for merging. - mostly done, need to address the problems with the  new procedures. 
-- still need to make a long version of the data-set 
--- need to change the code status timing to refflect days rather than time of change... --- may be more challenging. 

//TODO: do we have *LAST* days of initial hospitalization data? 

[ ] readmission flag? 


FOR LATER - From Jeff
"I need to get the active treatments (TISS scores) pulled in a different way, but that's not important for us to start chart review. I also need to get the code status changes for the new missing patients. I'll send those to you within the next couple of days."

//Data-oddities: 
- I'm not sure why so many of the reintubations occur before ICU admit (e.g. Day "0") - seems odd for a REintubation. 
e.g.****L - reintubation noted ICU day 2, but 

//TODO: why are there fewer pre-transfer than post-transfer 

*/ 

cd "/Users/blocke/Box Sync/Residency Personal Files/Scholarly Work/Locke Research Projects/Tele Crit Care/tele_crit_care" //Mac version
//cd "C:\Users\reblo\Box\Residency Personal Files\Scholarly Work\Locke Research Projects\Tele Crit Care\tele_crit_care" //PC version

// [ ] TODO: is this necessary?
program define datetime 
end

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
rename current_start_dts start_code_status
rename discontinue_effective_dts stop_code_status

//hospitaladmissiondatetime hospitaldischargedatetime == case_admit_dts case_disch_dts
gen hospitaladmissiondatetime = dofc(case_admit_dts)
format hospitaladmissiondatetime %td
drop case_admit_dts

gen hospitaldischargedatetime = dofc(case_disch_dts)
format hospitaldischargedatetime %td
drop case_disch_dts

gen hosp_admit_name = string(hospitaladmissiondatetime, "%td") + "-" + string(hospitalaccountnumber, "%12.0f")
label variable hosp_admit_name "Hosp-Identifier: Admit date - FIN"
quietly levelsof hosp_admit_name, local(hospAdmitNameLevels)
di "Number of unique Hosp Admits: " `: word count `hospAdmitNameLevels''

egen code_order_rank = rank(start_code_status), by(hosp_admit_name) unique // is this 1st-8th Code Status?
// bysort hospitalaccountnumber: tab code_order_rank // this is to ensure there are no 'ties' - unique in the command above makes it so they are broken arbitrarily if two status entered at same time. 
reshape wide code_status code_string start_code_status stop_code_status, i(hosp_admit_name) j(code_order_rank)
save code_status_data, replace
clear

/*
//Do chronic Conditions here:  - 1 file for the patients we already had. 
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

//APACHE Missing Patients: handle these separately, then marge later.  "C:\Users\reblo\Box\Residency Personal Files\Scholarly Work\Locke Research Projects\Tele Crit Care\Data\Raw Data\Missing APACHE patients, merged.xlsx"
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
//[eased since going down to 50 days max]
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


//Merge datasets on ICU admission 
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

//Highlight whether a given readmission is the first in the data-set or no. 
egen time_thru_icu_rank = rank(icudischargedatetime), by(mrn) track //this creates an enc_rank if it's the first encounter for the patients

//Encode string variables.
encode posticudestination, gen(post_icu_dest)
drop posticudestination
encode locationattimeofdeath, gen(loc_at_death)	// N/A = did not die
drop locationattimeofdeath
encode hospitaldischargedestination, gen(hosp_disch_loc) //Not specified = died; other ICU = transferred? 
drop hospitaldischargedestination
label define binary_lab 0 "No" 1 "Yes"
encode chronicdialysis, gen(chr_dialysis) label(binary_lab)
drop chronicdialysis
encode apachediagnosis, gen(apache_dx)
drop apachediagnosis
encode admittingicu, gen(adm_icu)
drop admittingicu

gen hospital_los = hospitaldischargedatetime - hospitaladmissiondatetime
gen icu_los = icudischargedatetime - icuadmissiondatetime
bysort hosp_disch_loc: sum icu_los, detail // median LOS prior to transfer is 2.9 days. n = 315

//Replace missing chronic condition values with 0's. 

* List all variables starting with "cnd_"
ds cnd_*, has(type numeric)

* Loop through each variable and replace missing values with 0
foreach var of varlist `r(varlist)' {
    replace `var' = 0 if missing(`var')
}




//TODO: make a long and a wide version.

/*---------------

Generate only the transfers 

----------------*/

gen pre_transfer = 0
gen post_transfer = 0
sort mrn icudischargedatetime
forval i = 1/`=_N' {
    * Check the next row for the same patient
    if mrn[`i'] == mrn[`i' + 1] {
        * Check if 'hosp_disch_loc' is "Other ICU = 3" and the next 'icu_admission' is within 48 hours
        if hosp_disch_loc[`i'] == 3 & icuadmissiondatetime[`i' + 1] - icudischargedatetime[`i'] <= 48/24 {
            replace pre_transfer = 1 in `i'
        }
    }
}
forval i = 1/`=_N' {
    * Check the previous row for the same patient
    if mrn[`i'] == mrn[`i' - 1] {
        * if the last row was the correct dispo and within 48. If so flag
        if hosp_disch_loc[`i' - 1] == 3 & icuadmissiondatetime[`i' ] - icudischargedatetime[`i' - 1] <= 48/24 {
            replace post_transfer = 1 in `i'
        }
    }
}

gen pre_or_post_transfer = 1
replace pre_or_post_transfer = 0 if pre_transfer == 0 & post_transfer == 0

//Tranfer variable labels 
label variable icuadmissiondate_only "Date of ICU Admission (no time)"
label variable icu_los "ICU Length of Stay"
label variable pre_transfer "Hospitalization is Pre-Transfer?"
label variable post_transfer "hospitalizatino is Post-Transfer?"
label variable pre_or_post_transfer "Hospitalization either Pre or Post Transfer?"

/* Save full dataset */ 

save all_data, replace
export excel using "all data.xlsx", firstrow(varlabels) keepcellfmt replace 


/* Save just transfers dataset */ 
drop if pre_or_post_transfer == 0 
drop icu_admit_name _merge* hosp_admit_name
order mrn patientname pre_transfer post_transfer hospital_billing
save just_transfers, replace
export excel using "just transfers.xlsx", firstrow(varlabels) keepcellfmt replace 




bysort pre_transfer: sum icu_los, detail // median transfer time - 2.0 days into ICU (stayed 10.6 after)
bysort pre_transfer: sum hospital_los, detail // median transfer time 3.7 days into hosp (stay 13.9 after)




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




