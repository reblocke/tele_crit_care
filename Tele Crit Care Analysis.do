* Data Analysis for Tele-crit care projects. 

//Brian Locke
//Last updated May 5, 2024

clear

/* 
Reminder: for active treaetments per day, chronic conditions initial group, and cumulatives scores per day - must remove the "blocks" by hospital in the spreadsheet and fill in the ICU-s

????


[ ] add demographics spreadsheet to existing 
[ ] create reviewer comparisons - calculate kappa for each (reconcile these all into reviewer 1 and reviewer 2)
[ ] add apache scores (or is this in there already?)



Such a boss for turning this around so quickly. Thanks man!
 
Not seeing anything too interesting here, which isn't a surprise. I'm waiting on one of the residents to finish his portion of the chart review then we'll have all the intubated patients sorted out. I think it may be more interesting to do a similar thing with code status on just the intubated patients who transfer and compare to intubated referral center patients. Then we can see if there's any difference in the sickest patients with an easier analysis. Let me know your thoughts.

[ ] code status on transferred patients compared to... matched? 


Other things I still to do:
 last code status logic (e.g. for prior to transfer or prior to death)
Haven't incorporated APACHE etc. – treating it like a time-varying confounder will be tricky, but baseline is super easy if you want it now.
Sankey diagram.



 
As far as other priorities but not urgent:
[ ] APACHE/APS/ICU mortality on day of transfer for those that transition to DNR and those that stay full-code
[ ] Same scores for transfer patients who survive vs die

Sankey diagram: What do you think about this? Looking at this initial stuff I'm not sure it's going to tell us that much that isn't obvious between the groups. I'm starting to think a comparison using our intubated cohort may have more meat if we find differences between the groups-- or if the above shows something. e.g. If ICU mortality above x% consider early palliative consult upon arrival or something like that.
 


Chart Review:
There are five files for each reviewer (me and four residents). 

[ ] I attached another file with how the patients are distributed. All patients are reviewed twice. I think the most important part of the review is really the transfer reason and SOC. We'll want to ***only include those that have transfer_reason = intubation *** . If there is disagreement between reviewers we'll need to run back in and reconcile. 

Other things that I feel confident in are SOC (standard of care), which I spent time defining with the residents but essentially is SOC for COVID patients in the ICU prior to transfer. If blank or disagreement I'll need to go review that patient. Dex, Remd, Toci/bari/tofa is reliable. ABX is less reliable since it was taken from notes and we were looking for acknowledgement of a treatment plan for 3-5 days rather than just 24 hours, etc. HCQ/iver can be ignored. There's only a handful of refusals, so probably not worth including. TR_support, Proc & proc_timing is reliable. This is what support they were transferred on, which procedures were completed prior to transfer and how many days prior to transfer were procedures completed (most are zero or occur on day of transfer). Proc_comp, central line, intubation and cardiac_arrest are reliable. Tr_comp, arr_interventions are reliable. I wouldn't worry about the REC_ columns. This was really had to reliably find during review. Sheet two has all the column definitions. Overall the patients just need to be matched up between reviewers for a kappa for SOC/TR_reason primarily and then we'll have to reconcile any differences there. The rest we can match secondarily, but don't think we really need to reconcile differences. Let me know if you have other thoughts.
 
 
 
 
Analysis:
I attached my last PGR with a breakdown of what we were thinking to help jog your memory since it's been a few months. Just jump to slide 25. I think most of the stuff I looked at is self-explanatory in the slides. I did this all from pivot tables in excel, so if you don't mind crunching everything with stata I'm sure it'll be more reliable. The one thing I couldn't work in pivot tables was the transfer time. The off the floor time is buried in Hospital discharge date/time and arrival time is ICU admission date/time. Think it would be interesting to look at prolonged transfer time and arrival SOI scores. The only interesting trend I found were the APACHE/APS scores. The intubated & transferred patients had a higher APACHE/APS with a declining trend for the 72 hours following transfer while the intubated/no transfer had an increasing APACHE/APS trend, which is supportive of what we were thinking regarding transfer as a potential harmful intervention immediately after transfer. There's some COVID data that seems to support this, as well. I also attached the missing demographic data that needs to be added to the main dataset.
 



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


//baseline comorbidities etc. 



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






//APACHE/APS/ICU mortality on day of transfer for those that transition to DNR and those that stay full-code



//Also needs 'last' logic


//TODO: last code status
//TODO: group admissions involving a transfer

//Probably due a censoring of code status type setup - e.g. did the duration end because of a change to the code status, or because 

/*
TODO: Timing of code status change prior to transfer and after transfer, for example, DNR/DNI and then switch to full code before transfer, or full code on arrival but switch to DNR/DNI within 24-48-72 hours after transfer.
*/ 


/* 
It may be interesting to look at SOI with APACHE/predicted mortality, especially with the group that transfers. I wonder if there's a point where most switch to DNR/DNI after transfer?
*/ 

/*
Similarly, we could look at total ICU LOS, limited to the referral group and transfer group. Is there a cutoff where most will ultimately switch to DNR/DNI?

We initially talked about a Sankey diagram, which seems like a great idea.
j....Sankey diagram: What do you think about this? Looking at this initial stuff I'm not sure it's going to tell us that much that isn't obvious between the groups. I'm starting to think a comparison using our intubated cohort may have more meat if we find differences between the groups-- or if the above shows something. e.g. If ICU mortality above x% consider early palliative consult upon arrival or something like that.
 
*/ 



//Same scores for transfer patients who survive vs die









/*
???
*** - 2 admissions, both are counted as a death, but the 1st one has a discharge to an unknown location - then the second admission occurs 2 days after. 

[ ] ADJUST THIS: DO NOT REMOVE READMITS? For the merged dataset, I only kept the first admission and dropped the rest (we'd make the stats more complicated if we try to allow for multiple admissions per person; and it seems like most of the apache in-hosp mort data is missing from the readmits), but some of the outcome logic isn't perfect because it probably shouldn't count as in-hospital mortality if they are discharged, then later readmitted and die. 

*/



