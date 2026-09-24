# Tele-critical-care transfers during COVID

This repository contains two Stata do-files for assembling and exploring
tele-critical-care transfer data. It is a source archive for collaborators
reviewing the workflow; no public manuscript, verified end-to-end run, clinical
acceptance or released analysis dataset is documented here. The source includes
exploratory sections and unresolved cohort/data decisions.

## Workflow and required inputs

Read the scripts in this order:

1. [`Tele Crit Care Data Wrangling.do`](Tele%20Crit%20Care%20Data%20Wrangling.do) imports workbooks, builds admission and reviewer intermediates, writes `all_data.dta` and subsets, and performs further exploratory calculations.
2. [`Tele Crit Care Analysis.do`](Tele%20Crit%20Care%20Analysis.do) loads `all_data.dta`, produces descriptive tabulations and writes two `table1_mc` workbooks.

These source-relative input workbooks are referenced by the wrangling script;
none is distributed in this repository. Excel sheet names and cell ranges are
literal script requirements, not a validated external data contract.

| Input under `Raw Data/` | Worksheet / role |
| --- | --- |
| `V1 COVID dataset from APACHE.xlsx` | `Info, apache mortality`, `Reintubation with 24 hours`, `NMB`, `Proning`, `CRRT`, `Code Status` |
| `Chronic conditions initial group.xlsx`, `Chronic conditions missing group 1.xlsx` through `3.xlsx`, `Missing APACHE patients, merged.xlsx` | `Report 1`, with `B4` start for the chronic/missing extracts |
| `Apr 14 Data/Apr_14_2025_Active Treatments per Day.xlsx`, `Active treatments per day.xlsx`, `Cumulative scores per day.xlsx` | `Report 1`; fixed cell ranges appear in the script |
| `TCC Demographics File.xlsx` | `Sheet2`; merged after the initial admission assembly |
| `Reviewer 1 - RB_completed.xlsx`, `Reviewer 2_BK_completed.xlsx`, `Reviewer 3 CL_complete.xlsx`, `Reviewer 4- KR_complete.xlsx`, `Reviewer 5, JG_completed.xlsx` | `Sheet1`; reviewer records joined by `fin`/hospital account number |

The script also names two older active-treatment workbooks in a commented
redundant-data section; they are not part of the mapped main import path.
The `.do` files contain a hard-coded local `cd`, so their relative imports,
intermediate saves and exports resolve under that configured project directory,
not automatically under a fresh clone. They are not parameterized by a CLI or
configuration file. An approved operator would first need to replace that
machine-local directory reference, supply the authorized workbook set and
confirm output isolation. This is an implementation/setup follow-up, not a
runnable first-run command offered by this README.

## Intermediate and output map

| Source stage | Output in the script's working directory | Use / caution |
| --- | --- | --- |
| Workbook normalization | Admission, APACHE/intervention, chronic-condition, treatment, score and code-status `.dta` intermediates such as `info_apache_mort_data.dta`, `active_tx_per_day_new.dta`, `code_status_data.dta` | Combined using ICU admission key, MRN and hospital-admission key according to source; `save ..., replace` can overwrite existing files. |
| Demographic merge | `complete_sans_demo.dta`, then `all_data.dta` and `all data.xlsx` | `all_data.dta` is the direct input to the analysis do-file. |
| Transfer splits | `just_transfers.dta` / `just transfers.xlsx`; `just_non_transfers.dta` / `just non transfers.xlsx` | Source-defined subsets, not independently verified cohorts. |
| Reviewer assembly | `reviewer_1.dta` through `reviewer_5.dta`, `rater_data.dta`, `rater data.xlsx`, `rater_agreement.txt` | Reviewer merges and agreement statistics; the text log is replaced. |
| Analysis do-file | `Initial Code by tele status.xlsx`, `Initial Code by ICU.xlsx` | Written by `table1_mc` from `all_data.dta`; plots are displayed in Stata, with no graph-file export command found. |
| Both do-files | `Results and Figures/<Stata date>/Logs/temp.log` and copied do-files | Logs use append; an existing date directory and script outputs may be reused or replaced. |

The wrangling script constructs `icu_admit_name` from ICU admission date and MRN,
`hosp_admit_name` from hospital admission date and account number, merges chronic
conditions at MRN level, and joins reviewers by `fin`/account number. It also
creates transfer-relative day variables for exploratory work. Comments describe
both 24-hour and 48-hour transfer matching and different row-grain intentions;
this README does not resolve those differences into a certified cohort rule.
Missing values are recoded in several source-specific steps; no maintained
variable dictionary or approved missingness contract is present in this repo.
Use the scripts and an approved data specification before interpreting a field.

## Runtime and access boundary

Neither do-file declares a Stata `version`, and no installed Stata environment
was verified for this documentation change. Both request the `cleanplots` graph
scheme and Helvetica window font; the analysis calls user-written `table1_mc`,
and wrangling calls `missings` and `egen` extensions such as `rowfirst`/`rowlast`.
Their package versions and availability are not pinned here. Confirm those
commands and the clinical workbook schema in an approved environment before a
run; do not substitute a different package or alter scientific code by guesswork.

Clinical workbooks are absent from Git. Their access owner, permitted use,
retention and output-sharing rules are not documented here. Obtain those rules
from the study/data steward before accessing, running or sharing anything.
No absence of a restriction in this README grants data access or release
permission. The repository's MIT [`LICENSE`](LICENSE) covers code; it does not
license clinical data, reviewer workbooks, third-party commands or figures.

## Recognizing completion and remaining work

For an authorized, isolated run, verify Stata's final return status and inspect
the complete dated `temp.log` for errors, then confirm the expected `.dta`,
Excel and agreement-log artifacts above. File presence alone does not prove
that the final exploratory section completed or that the analysis is valid.
No such run, output review or clinical result was performed for this README.

Before a reproducible handoff, the owner must identify the authorized input
snapshot and workbook schema; replace the hard-coded working directory with a
reviewed environment-specific setup; pin/verify Stata and user-written commands;
settle the conflicting transfer-window/row-grain notes; and define a
non-overwriting output root plus success criteria. These are follow-ups to the
existing scripts, not interfaces already implemented here.

## Citation and contact

No publication DOI is assigned to this repository. Cite its GitHub URL and the
commit or release used. For repository questions, contact Brian W. Locke
(`@reblocke`) through a GitHub issue or pull request.
