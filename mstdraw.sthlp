{smcl}
{* *! version 10feb2018}{...}
{viewerjumpto "Syntax" "mstdraw##syntax"}{...}
{viewerjumpto "Description" "mstdraw##description"}{...}
{viewerjumpto "Examples" "mstdraw##examples"}{...}
{viewerjumpto "Stored results" "mstdraw##results"}{...}
{viewerjumpto "Citation" "mstdraw##cite"}{...}

{vieweralsosee "mstatecox Commands: Overview" "help mst"}{...}
{vieweralsosee "mstutil" "help mstutil"}{...}
{vieweralsosee "" "--"}{...}
{vieweralsosee "[ST] stcox" "help stcox"}{...}
{title:Title}

{p 4 16 2}
{hi:mstdraw} {hline 2} utility command capable of providing information about multi-state structured data
{p_end}


{marker syntax}{...}
{title:Syntax}

{p 4 16 2}
{hi:mstdraw}{cmd:,} {opt tr:ansinfo} [{opt nol:abel}]{p_end}

{p 5 16 2}
{it:or}
{p_end}

{p 4 16 2}
{hi:mstdraw} [{it:{help if}}]{cmd:,} {opt prgr:aph} {opt tvar(varname)} {opt stgvar(varlist)} [{opt nol:abel} {opt id} {opt sort} {opt area(area_options)} {it:twoway_options}]{p_end}

{synoptset 20 tabbed}{...}
{synopthdr}
{synoptline}
{syntab:Variant #1}
{synopt :{opt tr:ansinfo}}required, reports model's possible transitions, in table and matrix form{p_end}
{synopt :{opt nol:abel}}if stage labels are present, report stage numbers instead in the table, default is to use labels{p_end}

{syntab:Variant #2}
{synopt :{opt prgr:aph}}required, generates stacked transition probability plot using one set of saved results in dataset{p_end}
{synopt :{opt tvar(varname)}}required, name of {bf:mstsample} results variable containing time ({it:stub}_Rslt_t){p_end}
{synopt :{opt stgvar(varlist)}}required, names of {bf:mstsample} results variable containing stage means ({it:stub}_Rslt_stage#_m){p_end}
{synopt :{opt nol:abel}}if stage labels are present, use stage numbers instead in the graph's legend, default is to use labels{p_end}
{synopt :{opt id}}stack stage probabilities from highest to lowest stage ID, default is variable order in {opt stgvar()}{p_end}
{synopt :{opt sort}}stack stage probabilities from largest value to smallest, default is variable order in {opt stgvar()}{p_end}
{synopt :{opt area(area_options)}}any permissible options for {help area_options}; can be used to change area coloring.  First color = top-most probability in graph...{p_end}
{synopt :{it:twoway_options}}any permissible options for {help twoway area}{p_end}
{synoptline}

{p 4 6 2}
Must first run {helpb mstutil}, draw({it:transVarName}) from({it:varname}) to({it:varname})} before running {bf:mstdraw}.  Cannot specify {bf:transinfo} and {bf:prgraph} simultaneously.  
For {bf:prgraph}, cannot specify {bf:id} and {bf:sort} simultaneously.{p_end}

{p 4 6 2}
{it:if} is permissible for {bf:prgraph} only.  Doing so subsets the data being graphed, if desired.  It makes the most sense to craft 
conditional statements involving the {it:stub}_Rslt_* variables (see {help mstdraw##ifSubsetEx:example usage} below).{p_end}


{marker description}{...}
{title:Description}

{pstd}
{cmd:mstdraw} provides information about your dataset's multi-state stage structure.  Its syntax has two variants.{p_end}

{p 2 4 2}
{it: Variant 1}{p_end}
{pstd}
{cmd:mstdraw, transinfo} provides a table describing how many unique transition IDs are in your dataset and the from-to pairing 
associated with each transition ID.  If you have applied (value) labels to your stages, the command will print out the labels 
associated with each from-to pairing instead of stage ID numbers.  In addition to the table, {cmd:mstdraw, tr}
also outputs a transition matrix identical in form and function to R mstate's transition matrix, for those familiar with that formatting.
{p_end}

{pstd}
Variant #1 can be entered anytime after you have {cmd:mstutil}ed your dataset.{p_end}

{p 2 4 2}
{it: Variant 2}{p_end}
{pstd}
{cmd:mstdraw, prgraph} is a convenience wrapper to help graph your {cmd:mstsample} output.  Specifically, for a specific covariate 
profile, it creates a stacked probability graph for you, displaying each of your stage's transition probabilities across time.  
It expects the variable naming conventions from {cmd:mstsample}--{it:stub}_Rslt_t for the time variable and {it:stub}_Rslt_stage#_m
for the transition probability (means) for each stage.  If you have applied 
(value) labels to your stages, the command will insert the labels into the graph's legend instead of stage ID numbers.  Any options
permissible for {help twoway area} are also allowed.

{pstd}
Variant #2 can be entered anytime after you have run {cmd:mstsample}, producing the variables (and variable names) {cmd:mstdraw, prgraph}
is expecting.  {ul:Note the implication}: if you save your {cmd:mstsample} results in a dataset to load later and are dropping other variables, be sure to keep your transition ID, from, and to variables.
You will need to {bf:mstutil} again, with the addition of the {bf:draw()} option, before you can graph any results.{p_end}


{marker examples}{...}
{title:Examples}

{pstd}Competing-risks data - Semi-parametric{p_end}
{phang2}{cmd:. webuse hypoxia}{p_end}
{phang2}{cmd:. gen days = (dftime * 365.25)} {p_end}
{phang2}{cmd:// ^ to put time in days}{p_end}
{phang2}{cmd:. expand 2, gen(new)}{p_end}
{phang2}{cmd:. bysort stnum (new): gen nextStage = _n}{p_end}
{phang2}{cmd:. gen status = (nextStage==failtype)}{p_end}
{phang2}{cmd:. clonevar trans = nextStage}{p_end}
{phang2}{cmd:. gen curStg = 1}{p_end}
{phang2}{cmd:. replace nextStage = nextStage + 1}{p_end}
{phang2}{cmd:. stset days, failure(status)}{p_end}
{p 9 14 2}{cmd:  foreach x of varlist ifp tumsize pelnode{c -(} }  {p_end}
{phang3}{cmd: forvalues tr = 1/2{c -(} }  {p_end}
{p 15 19 2}{cmd: gen `x'_tr`tr' = cond(trans==`tr', `x', cond(`x'==., ., 0))} {p_end}
{phang3}{cmd: {c )-}} {p_end}
{p 9 14 2}{cmd: {c )-}} {p_end}
{phang2}{cmd:. stcox  *_tr1 *_tr2, strata(trans) efron}{p_end}
{phang2}{cmd:. mstutil, from(curStg) to(nextStage)}{p_end}
{phang2}{cmd:. mstdraw, tr}{p_end}
{phang2}{cmd:. label define stgLabs 1 "Healthy" 2 "Pelvic Disease" 3 "Distant Disease"}{p_end}
{phang2}{cmd:. label values curStg stgLabs}{p_end}
{phang2}{cmd:. label values nextStage stgLabs}{p_end}
{phang2}{cmd:. mstdraw, tr}{p_end}
{phang2}{cmd:. mstdraw, tr nolab}{p_end}

{marker examplesMID}{...}
{pstd}Multi-state data - Non-parametric{p_end}
{phang2}{cmd:. use http://www.shawnakmetzger.com/research/2%20-%20h%26a%20-%20continuous%2c%20no%20TVC.dta}{p_end}
{phang2}{cmd:. stset t, enter(t0) f(status)}{p_end}
{phang2}{cmd:. stcox, estimate strata(trans) efron}{p_end}
{phang2}{cmd:. replace stage = stage + 1}{p_end}
{phang2}{cmd:. replace nextStage = nextStage + 1}{p_end}
{phang2}{cmd:. mstutil, from(stage) to(nextStage)}{p_end}
{phang2}{cmd:. mstsample, n(50) sstage(2) stime(12) tmax(48) sims(10) gen(ms)}{p_end}
{phang2}{cmd:. mstdraw, prgraph tvar(ms_Rslt_t) stgvar(ms_Rslt_stage?_m)}{p_end}
{phang2}{cmd:. mstdraw, prgraph tvar(ms_Rslt_t) stgvar(ms_Rslt_stage?_m) sort}{p_end}
{phang2}{cmd:. label define stgs 1 "Status Quo" 2 "Negotiations" 3 "Militarization" 4 "Resolved"}{p_end}
{phang2}{cmd:. label values stage stgs}{p_end}
{phang2}{cmd:. label values nextStage stgs}{p_end}
{phang2}{cmd:. mstdraw, prgraph tvar(ms_Rslt_t) stgvar(ms_Rslt_stage?_m) id}{p_end}
{phang2}{cmd:. mstdraw, prgraph tvar(ms_Rslt_t) stgvar(ms_Rslt_stage?_m) sort}{p_end}
{phang2}{cmd:. mstdraw, prgraph tvar(ms_Rslt_t) stgvar(ms_Rslt_stage?_m) sort scheme(s2mono) aspect(1) ytitle("Transition Probabilities")}{p_end}
{phang2}{cmd:. mstdraw, prgraph tvar(ms_Rslt_t) stgvar(ms_Rslt_stage?_m) sort scheme(s2mono) aspect(1) ytitle("Transition Probabilities") plotregion(margin(r=0))}{p_end}
{phang2}{cmd:. mstdraw, prgraph tvar(ms_Rslt_t) stgvar(ms_Rslt_stage?_m) sort scheme(s2mono) aspect(1) ytitle("Transition Probabilities") plotregion(margin(r=0)) area(color(pink brown gs0))}{p_end}
{phang2}{cmd:. tempfile reloadDemo}{p_end}
{phang2}{cmd:// ^ to show how to reload results and graph}{p_end}
{phang2}{cmd:. save `reloadDemo', replace}{p_end}
{phang2}{cmd:. clear *}{p_end}
{phang2}{cmd:. use `reloadDemo'}{p_end}
{phang2}{cmd:. mstutil, from(stage) to(nextStage) draw(trans)}{p_end}
{phang2}{cmd:. mstdraw, prgraph tvar(ms_Rslt_t) stgvar(ms_Rslt_stage3_m ms_Rslt_stage1_m ms_Rslt_stage4_m ms_Rslt_stage2_m)}{p_end}
{phang2}{cmd:. mstdraw, prgraph tvar(ms_Rslt_t) stgvar(ms_Rslt_stage3_m ms_Rslt_stage1_m ms_Rslt_stage4_m ms_Rslt_stage2_m) area(color(navy gold brown dkorange))}{p_end}
{phang2}{marker ifSubsetEx}{cmd:. mstdraw if(ms_Rslt_t<=24), prgraph tvar(ms_Rslt_t) stgvar(ms_Rslt_stage3_m ms_Rslt_stage1_m ms_Rslt_stage4_m ms_Rslt_stage2_m) area(color(navy gold brown dkorange))}{p_end}


{marker results}{...}
{title:Stored Results}

{pstd}
None.
{p_end}


{marker cite}{...}
{title:Citation}

{pstd}See the {help mst##cite:mst} help file.{p_end}


{p 0 0 0}
{bf:Last Updated} - 22FEB19
{p_end}
