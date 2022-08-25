{smcl}
{* *! version 24aug2022}{...}
{viewerjumpto "Syntax" "mstutil##syntax"}{...}
{viewerjumpto "Description" "mstutil##description"}{...}
{viewerjumpto "Remarks" "mstutil##remarks"}{...}
{viewerjumpto "Examples" "mstutil##examples"}{...}
{viewerjumpto "Stored results" "mstutil##results"}{...}
{viewerjumpto "Citation" "mstutil##cite"}{...}
{viewerjumpto "References" "mstutil##references"}{...}

{vieweralsosee "mstatecox Commands: Overview" "help mst"}{...}
{vieweralsosee "mstsample" "help mstsample"}{...}
{vieweralsosee "mstdraw" "help mstdraw"}{...}
{vieweralsosee "" "--"}{...}
{vieweralsosee "[ST] stcox" "help stcox"}{...}
{title:Title}

{p 4 16 2}
{hi:mstutil} {hline 2} Sets the data for a multi-state duration analysis.
{p_end}


{marker syntax}{...}
{title:Syntax}

{p 4 16 2}
{hi:mstutil}{cmd:,} [{opt fr:om(varname)} {opt to:(varname)} {opt sdur:} {opt draw(varname)}]

{synoptset 20 tabbed}{...}
{synopthdr}
{synoptline}
{synopt :{opt fr:om(varname)}}required unless {bf:sdur} specified; variable name for the subject's current stage{p_end}
{synopt :{opt to(varname)}}required unless {bf:sdur} specified; variable name for the subject's next possible stage(s){p_end}
{synopt :{opt sdur}}convenience option for single-duration data (i.e., one failure event only); automatically creates transition ID variable, plus "from" and "to" stage variables.{p_end}
{synopt :{opt draw(varname)}}special exception case; enables {bf:mstdraw} to graph saved {bf:mstsample} results, where {it:varname} = transition ID variable.  Should only be used for this purpose.{p_end}
{synoptline}

{p 4 6 2}
Must first estimate {help stcox} before running {bf:mstutil}.  {bf:stcox}'s {bf:strata()} option must also be specified, unless {bf:mstutil}'s {bf:sdur} specified. {p_end}

{p 4 6 2}
Transition and stage identifiers must have integer values.  Additionally, the lowest stage identifier's value must be equal to 1, and all other stage identifiers must be sequential integers in increments of one.  If any of these conditions are not met, Stata will return an error message.{p_end}


{marker description}{...}
{title:Description}

{pstd}
{cmd:mstutil} is the first command you must run to generate transition probabilities from a Cox model.  It tells Stata which variables contain (1) the subject's current stage and 
(2) the next stage(s) to which a subject could potentially transition.  The command presupposes the dataset is already formatted appropriately for a multi-state analysis (see Jones 
and Metzger 2018, Supplemental Appendix A; de Wreede, Fiocco, and Putter 2010).


{marker remarks}{...}
{title:Remarks}

{p 4 6 2}
The transition, from, and to variables that {opt sdur} creates are named {bf:trans__ms}, {bf:to__ms}, and {bf:from__ms}, respectively.{p_end}


{marker examples}{...}
{title:Examples}

{pstd}Single duration data, variant 1 - Non-parametric{p_end}
{phang2}{cmd:. webuse catheter}{p_end}
{phang2}{cmd:. stset time, fail(infect)}{p_end}
{phang2}{cmd:. stcox, estimate efron}{p_end}
{phang2}{cmd:. mstutil, sdur}{p_end}

{pstd}Single duration data, variant 2 - Non-parametric{p_end}
{phang2}{cmd:. webuse catheter}{p_end}
{phang2}{cmd:. stset time, fail(infect)}{p_end}
{phang2}{cmd:. gen current = 1}{p_end}
{phang2}{cmd:. gen next = 2}{p_end}
{phang2}{cmd:. gen trans = 1}{p_end}
{phang2}{cmd:. stcox, estimate strata(trans) efron}{p_end}
{phang2}{cmd:. mstutil, from(current) to(next)}{p_end}

{pstd}Single duration data, variant 1 - Semi-parametric{p_end}
{phang2}{cmd:. webuse catheter}{p_end}
{phang2}{cmd:. stset time, fail(infect)}{p_end}
{phang2}{cmd:. stcox age female, efron}{p_end}
{phang2}{cmd:. mstutil, sdur}{p_end}

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
{phang2}{cmd:. foreach x of varlist ifp tumsize pelnode{c -(} }  {p_end}
{phang3}{cmd: forvalues tr = 1/2{c -(} }  {p_end}
{p 15 19 2}{cmd: gen `x'_tr`tr' = cond(trans==`tr', `x', cond(`x'==., ., 0))} {p_end}
{phang3}{cmd: {c )-}} {p_end}
{p 10 14 2}{cmd: {c )-}} {p_end}
{phang2}{cmd:. stcox  *_tr1 *_tr2, strata(trans) efron}{p_end}
{phang2}{cmd:. mstutil, from(curStg) to(nextStage)}{p_end}

{pstd}Multi-state data - Non-parametric{p_end}
{phang2}{cmd:. use http://www.shawnakmetzger.com/research/2%20-%20h%26a%20-%20continuous%2c%20no%20TVC.dta}{p_end}
{phang2}{cmd:. stset t, enter(t0) f(status)}{p_end}
{phang2}{cmd:. stcox, estimate strata(trans) efron}{p_end}
{phang2}{cmd:. replace stage = stage + 1}{p_end}
{phang2}{cmd:. replace nextStage = nextStage + 1}{p_end}
{phang2}{cmd:. mstutil, from(stage) to(nextStage)}{p_end}

{pstd}See {help mstdraw##examplesMID:help mstdraw} for example using {bf:mstutil, draw()}.{p_end}


{marker results}{...}
{title:Stored Results}

{pstd}
{cmd:mstutil} appends the following to {help stcox}'s {cmd:e()} (or, when {bf:draw()}'s specified, appends to whatever's currently in {cmd:e()}):

{synoptset 22 tabbed}{...}
{p2col 5 15 19 2: Scalars}{p_end}
{synopt:{cmd:e(maxStgNo)}}highest stage number{p_end}
{synopt:{cmd:e(nTrans)}}number of transition IDs{p_end}
{synopt:{cmd:e(sdur)}}1 if single duration specified, 0 otherwise{p_end}

{synoptset 22 tabbed}{...}
{p2col 5 15 19 2: Macros}{p_end}
{synopt:{cmd:e(trans)}}name of transition variable, from {bf: stcox}'s {bf:strata()} (or from {opt draw(varname)}, if {bf:draw()} specified){p_end}
{synopt:{cmd:e(from)}}name of variable with subject's current stage{p_end}
{synopt:{cmd:e(to)}}name of variable with subject's next possible stage(s){p_end}


{marker cite}{...}
{title:Citation}

{pstd}See the {help mst##cite:mst} help file.{p_end}


{marker references}{...}
{title:References}

{pstd}Jones, Benjamin T., and Shawna K. Metzger.  2018.  "Evaluating Conflict Dynamics: A Novel Empirical Approach to Stage Conceptions."  {it:Journal of Conflict Resolution} 62 (4): 819-847. {p_end}

{pstd}de Wreede, Liesbeth C., Marta Fiocco, and Hein Putter.  2010.  "The mstate Package for Estimation and Prediction in Non- and Semi-Parametric Multi-State and Competing Risks Models."  
	 {it:Computer Methods and Programs in Biomedicine} 99 (3): 261–274.{p_end}


{p 0 0 0}
{bf:Last Updated} - 24AUG22
{p_end}

