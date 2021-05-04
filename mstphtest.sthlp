{smcl}
{* *! version 04may2021}{...}
{viewerjumpto "Syntax" "mstphtest##syntax"}{...}
{viewerjumpto "Description" "mstphtest##description"}{...}
{viewerjumpto "Examples" "mstphtest##examples"}{...}
{viewerjumpto "Stored results" "mstphtest##results"}{...}
{viewerjumpto "Citation" "mstphtest##cite"}{...}
{viewerjumpto "References" "mstphtest##references"}{...}

{vieweralsosee "mstatecox Commands: Overview" "help mst"}{...}
{vieweralsosee "mstutil" "help mstutil"}{...}
{vieweralsosee "" "--"}{...}
{vieweralsosee "[ST] stcox" "help stcox"}{...}
{vieweralsosee "[ST] stcox PH-assumption tests" "help stcox_diagnostics"}{...}
{title:Title}

{p 4 16 2}
{hi:mstphtest} {hline 2} A convenience wrapper to run proportional hazard tests after estimating a multi-state duration model
{p_end}


{marker syntax}{...}
{title:Syntax}

{p 4 16 2}
{hi:mstphtest}{cmd:,} [{it:phtest_opts}]

{synoptset 20 tabbed}{...}
{synopthdr}
{synoptline}
{synopt :{it:phtest_opts}}any of the test-related options associated with {help stcox_diagnostics##options_estat_phtest:estat phtest}: {bf:log, rank, km, time()}.{p_end}
{synoptline}

{p 4 6 2}
Must first run {help stcox} and {help mstutil} before running {bf:mstphtest}.{p_end}


{marker description}{...}
{title:Description}

{pstd}
{cmd:mstphtest} is a wrapper function to correctly run proportional hazard tests from a multi-state model.  
It tests the proportional hazard (PH) assumption for each stratum separately using Stata's {help estat phtest} and reports these results to the user.  Each stratum will correspond to a unique transition in the model unless you have collapsed any baseline hazards.{p_end}

{pstd}
Stata's {help estat phtest:PH test} relies on scaled Schoenfeld residuals.  
However, the test assumes homogenous variances.  Specifically, it assumes the scaled Schoenfeld residuals for every transition have the same variance (Therneau and Grambsch 2000, 127-133).  
This assumption is particularly suspect in the presence of stratified hazards, which are a hallmark of multi-state models.  It is only valid if all strata have the same variance.
As a consequence, we must run PH tests separately on each stratum specified by stcox's {bf:strata()} option (see also {bf: {manpage ST 114:[ST] estat phtest}}, "Methods and Formulas").{p_end}

{pstd}
In the presence of a single transition, {cmd:mstphtest, {it:phtest_opts}} is identical to running {cmd:estat phtest, detail {it:phtest_opts}}.{p_end}

{pstd}
{cmd:mstphtest} automatically reports the equivalent of {bf:estat phtest, detail}; {bf:detail} need not be specified as an option again.


{marker examples}{...}
{title:Examples}

{pstd}Competing-risks data - Semi-parametric{p_end}
{phang2}{cmd:. webuse hypoxia}{p_end}
{phang2}{cmd:. gen days = dftime * 365.25} {p_end}
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
{phang2}{cmd:. mstphtest}{p_end}
{phang2}{cmd:. mstphtest, log}{p_end}
{phang2}{cmd:. mstphtest, km}{p_end}
{phang2}{cmd:. mstphtest, rank}{p_end}

{pstd}Multi-state data - Semi-parametric{p_end}
{phang2}{cmd:. use http://www.shawnakmetzger.com/research/2%20-%20h%26a%20-%20continuous%2c%20no%20TVC.dta}{p_end}
{phang2}{cmd:. stset t, enter(t0) f(status)}{p_end}
{phang2}{cmd:. stcox milratioA milratioB milratioC milratioD milratioE milratioF milratioG milratioH milratioI chgodiI chgodiH chgodiG chgodiE chgodiF chgodiD chgodiC chgodiB chgodiA, estimate strata(trans) efron}{p_end}
{phang2}{cmd:. replace stage = stage + 1}{p_end}
{phang2}{cmd:. replace nextStage = nextStage + 1}{p_end}
{phang2}{cmd:. mstutil, from(stage) to(nextStage)}{p_end}
{phang2}{cmd:. mstphtest}{p_end}
{phang2}{cmd:. mstphtest, log}{p_end}
{phang2}{cmd:. mstphtest, km}{p_end}
{phang2}{cmd:. mstphtest, rank}{p_end}


{marker results}{...}
{title:Stored Results}

{synoptset 22 tabbed}{...}
{p2col 5 15 19 2: Matrices}{p_end}
{synopt:{cmd:phtest_{it:stratumID}}} a matrix for each stratum containing the separate {cmd: estat phtest} results each covariate.  {it:strataID} corresponds to {bf:e(strata)}'s value.{p_end}
{synopt:{cmd:global_{it:stratumID}}} a matrix for each stratum containing the degrees of freedom, chi2 value, and corresponding p-value for the global test.{p_end}


{marker cite}{...}
{title:Citation}

{pstd}See the {help mst##cite:mst} help file.{p_end}


{marker references}{...}
{title:References}

{pstd}Therneau, Terry M., and Patricia M. Grambsch.  2000.  {it:Modeling Survival Data: Extending the Cox Model}.  New York: Springer.{p_end}


{p 0 0 0}
{bf:Last Updated} - 04MAY21
{p_end}

