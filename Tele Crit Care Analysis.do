* Data Analysis for Tele-crit care projects. 

//Brian Locke
//Last updated May 5, 2024

clear

/* 
Reminder: for active treaetments per day, chronic conditions initial group, and cumulatives scores per day - must remove the "blocks" by hospital in the spreadsheet and fill in the ICU-s

????


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
local b = "Tele Crit Care Analysis.do" // do file name
copy "`b'" "Results and Figures/$S_DATE/Logs/(`a1'_`a2'_`a3')`b'"

set scheme cleanplots
graph set window fontface "Helvetica" //maybe change this? 

capture log close
log using "Results and Figures/$S_DATE/Logs/temp.log", append

use all_data, clear

preserve 
drop if pre_or_post_transfer == 0
bysort pre_transfer: sum icu_los, detail // median transfer time - 2.0 days into ICU (stayed 10.6 after)
bysort pre_transfer: sum hospital_los, detail // median transfer time 3.7 days into hosp (stay 13.9 after)
restore

/* Drop unneeded rows (for now) */ 
drop _merge_*
drop apache_3_*
drop apache_4_*
drop aps_*
drop cardiovert_*
drop cont_anti_arrh_*
drop cont_art_drug_inf_*
drop cont_iv_sed_*
drop cont_nmb_*
drop crrt_*
drop ecmo_*
drop emerg_op_in_icu_*
drop emerg_op_out_icu_*
drop endoscope_*
drop hfnc_*
drop icu_intub_*
drop ippv_*
drop irrt_*
drop iv_fluid_rep_*
drop mtp_*
drop mult_pressors_*
drop nippv_*
drop one_pressor_*
drop pa_cath_*
drop post_arrest_*
drop prone_*
drop reintub_*
drop ttm_*

/* Visualize Data distributions */ 

/* Facility Info */ 

tab adm_icu, plot
bysort pre_or_post_transfer pre_transfer: tab adm_icu, plot missing nolabel

// Do we infer that patients from the "usually transfer hospitals" are 

//List of ICUs that send transfers usually: AF_ICU, AV_ICU, CA_ICU, CC_ICU, ICU, LG_North Tower, PK_ICU, RV_ICU, SG_ICU East Twr
tab tele_cc_icu, plot

bysort tele_cc_icu: tab pre_or_post_transfer, plot missing
bysort tele_cc_icu: tab pre_transfer, plot missing
bysort tele_cc_icu: tab post_transfer, plot missing

tab hospital_billing, plot
bysort hospital_billing: tab adm_icu, plot //note: 2314 missing a billing hosp - but all the rest correspond perfectly... thus, I think you could safely infer the billing hosp. 



tab apachereadmit, plot //305 readmitts (of 5974)
bysort pre_or_post_transfer: tab apachereadmit //only 20 of the readmits are involved in transfers

tab apachereadmitwithin24hours, plot
bysort apachereadmit: tab apachereadmitwithin24hours, plot // w/n 24h is subset.

tab time_thru_icu_rank, plot
bysort pre_or_post_transfer pre_transfer: tab time_thru_icu_rank, plot

/* Subsequent Course */ 

summ hospital_los, detail
bysort pre_or_post_transfer pre_transfer: summ hospital_los, detail //a few transferred to floors? - then subsequently escalated? 
//Not specified == dead? 

summ icu_los, detail
bysort pre_or_post_transfer pre_transfer: summ icu_los, detail

tab post_icu_dest, plot
bysort pre_or_post_transfer pre_transfer: tab post_icu_dest, plot

tab hosp_disch_loc, plot
bysort pre_or_post_transfer pre_transfer: tab hosp_disch_loc, plot

tab loc_at_death, plot
bysort pre_or_post_transfer pre_transfer: tab loc_at_death, plot
//sanity check - no deaths associated with the pretransfer encounters, which makes sense.

//Start and Stop code status == un-indexed dates? 


// hosp_admit_name is a unique identifier for the hospitalization
// same with enc_id 
// same with icu_admit_name

/* Admission info */ 



// [ ] TODO: need to merge pre- and post- hospitalizations for apples-applies comparisons - currently represented as two different. 


// [/] TODO: get day indexes for code starts and stops
tab dur_code_status1, plot
tab hosp_day_start_code_status1, plot
tab hosp_day_stop_code_status1, plot

tab dur_code_status2, plot
tab dur_code_status3, plot
tab dur_code_status4, plot
//etc.


/* Diagnosis Info */ 
tab apache_dx, plot //some ARDS, some COVID-19, some SEPSISPULM, but most PNEUMOVIRAL

tab cnd_Acquired_Immunodeficiency_Sy, plot
tab cnd_COPD_Moderate, plot
tab cnd_COPD_No_Limitations, plot 
tab cnd_COPD_Severe, plot 
tab cnd_Cirrhosis, plot 
tab cnd_Diabetes_Mellitus, plot 
tab cnd_Hepatic_Failure, plot 
tab cnd_Immune_Suppression, plot 
tab cnd_Leukemia_Myeloma, plot 
tab cnd_No_COPD, plot
tab cnd_No_Chronic_Health, plot 
tab cnd_Non_Hodgkins_Lymphoma, plot 
tab cnd_Post_COVID_Conditions, plot 
tab cnd_Solid_Tumor_w_Metastasis, plot 
tab cnd_Unavailable_Chronic_Health, plot 
tab chr_dialysis, plot

/* Procedures - mostly ignored for now */


/* GoC */ 

tab code_status1, plot
bysort pre_transfer: tab code_status1, plot
//tab code_string1, plot - messy, mostly only useful if needed to verify a single observation. 


tab num_code_status, plot
bysort pre_or_post_transfer pre_transfer: tab num_code_status, plot

tab dur_code_status1, plot
bysort pre_or_post_transfer pre_transfer: tab dur_code_status1, plot


 
// 1) tele, no transfer 2) tele, transfer (pre-post) 3) referral-center


tab tele_status

// 1 = Referral Center, 2 = Tele, no transfer, 3 = tele transfer pre, 4 = tele transfer post

/* 
Baseline code status for 1) tele, no transfer 2) tele, transfer 3) referral
Total code status changes during ICU admission and split into the above subgroups
*/ 
table1_mc, by(tele_status) ///
vars( ///
code_status1 cat %4.0f \ ///
dur_code_status1 conts %4.0f \ ///
num_code_status conts %4.0f \ ///
hospital_los conts %4.0f \ ///
icu_los conts %4.0f \ ///
post_icu_dest cat %4.0f \ ///
hosp_disch_loc cat %4.0f \ ///
loc_at_death cat %4.0f \ ///
) ///
percent_n percsign("%") iqrmiddle(",") sdleft(" (±") sdright(")") onecol total(before) saving("Initial Code by tele status.xlsx", replace)

tab dur_code_status1 if post_transfer == 1, plot

/*
Should we also break some of this down into hospitals to look for regional variation?
*/ 
table1_mc, by(adm_icu) ///
vars( ///
code_status1 cat %4.0f \ ///
dur_code_status1 conts %4.0f \ ///
num_code_status conts %4.0f \ ///
hospital_los conts %4.0f \ ///
icu_los conts %4.0f \ ///
post_icu_dest cat %4.0f \ ///
hosp_disch_loc cat %4.0f \ ///
loc_at_death cat %4.0f \ ///
) ///
percent_n percsign("%") iqrmiddle(",") sdleft(" (±") sdright(")") onecol total(before) saving("Initial Code by ICU.xlsx", replace)



//TODO: last code status
//TODO: group admissions involving a transfer

/*
TODO: Timing of code status change prior to transfer and after transfer, for example, DNR/DNI and then switch to full code before transfer, or full code on arrival but switch to DNR/DNI within 24-48-72 hours after transfer.
*/ 


/* 
It may be interesting to look at SOI with APACHE/predicted mortality, especially with the group that transfers. I wonder if there's a point where most switch to DNR/DNI after transfer?
*/ 

/*
Similarly, we could look at total ICU LOS, limited to the referral group and transfer group. Is there a cutoff where most will ultimately switch to DNR/DNI?

We initially talked about a Sankey diagram, which seems like a great idea.
*/ 









/*
???
*** - 2 admissions, both are counted as a death, but the 1st one has a discharge to an unknown location - then the second admission occurs 2 days after. 

[ ] ADJUST THIS: DO NOT REMOVE READMITS? For the merged dataset, I only kept the first admission and dropped the rest (we'd make the stats more complicated if we try to allow for multiple admissions per person; and it seems like most of the apache in-hosp mort data is missing from the readmits), but some of the outcome logic isn't perfect because it probably shouldn't count as in-hospital mortality if they are discharged, then later readmitted and die. 

*/



