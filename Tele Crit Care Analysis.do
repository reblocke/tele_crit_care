* Data Analysis for Tele-crit care projects. 

//Brian Locke
//Last updated May 5, 2024

clear

/* 
Reminder: for active treaetments per day, chronic conditions initial group, and cumulatives scores per day - must remove the "blocks" by hospital in the spreadsheet and fill in the ICU-s

????


*/ 

cd "/Users/blocke/Box Sync/Residency Personal Files/Scholarly Work/Locke Research Projects/Tele Crit Care/Data" //Mac version
//cd "C:\Users\reblo\Box\Residency Personal Files\Scholarly Work\Locke Research Projects\Tele Crit Care\Data" //PC version

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






/*
???
TUAKALAU,LELEA K - 2 admissions, both are counted as a death, but the 1st one has a discharge to an unknown location - then the second admission occurs 2 days after. 

[ ] ADJUST THIS: DO NOT REMOVE READMITS? For the merged dataset, I only kept the first admission and dropped the rest (we'd make the stats more complicated if we try to allow for multiple admissions per person; and it seems like most of the apache in-hosp mort data is missing from the readmits), but some of the outcome logic isn't perfect because it probably shouldn't count as in-hospital mortality if they are discharged, then later readmitted and die. 

*/



