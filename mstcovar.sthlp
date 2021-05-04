{smcl}
{* *! version 21feb2019}{...}
{viewerjumpto "Syntax" "mstcovar##syntax"}{...}
{viewerjumpto "Description" "mstcovar##description"}{...}
{viewerjumpto "Options" "mstcovar##options"}{...}
{viewerjumpto "Examples" "mstcovar##examples"}{...}
{viewerjumpto "Stored results" "mstcovar##results"}{...}
{viewerjumpto "Citation" "mstcovar##cite"}{...}

{vieweralsosee "mstatecox Commands: Overview" "help mst"}{...}
{vieweralsosee "mstutil" "help mstutil"}{...}
{vieweralsosee "" "--"}{...}
{vieweralsosee "[ST] stcox" "help stcox"}{...}
{vieweralsosee "[R] tabstat" "help tabstat"}{...}
{title:Title}

{p 4 16 2}
{hi:mstcovar} {hline 2} Sets covariate values before simulating a multi-state duration process' transition probabilities.
{p_end}


{marker syntax}{...}
{title:Syntax}

{p 4 16 2}
{hi:mstcovar}{cmd: {varname}} {ifin}, {opt n:ames(varlist)} [{opt v:alue(stats)} {opt rep:lace} {opt clear}]

{synoptset 20 tabbed}{...}
{synopthdr}
{synoptline}
{syntab:Required}
{synopt :{opt n:ames(varlist)}}the transition-specific variable names associated with {it:varname}; required unless {bf:sdur} specified for {bf:mstutil}{p_end}

{syntab:Optional}
{synopt :{opt v:alue(stats)}}value at which the variables in question should be held, default is median.{p_end}
{synopt :{opt rep:lace}}required if defining a new transition-specific covariate list for a previously {bf:mstcovar}-set {it:varname}.{p_end}
{synopt :{opt clear}}clears all {bf:mstcovar}-related information from memory; supersedes all other options, if specified{p_end}
{synoptline}

{p 4 6 2}
Must first run {help stcox} and {help mstutil} before running {bf:mstcovar}.{p_end}


{marker description}{...}
{title:Description}

{pstd}
{cmd:mstcovar} is the second command you must run to generate transition probabilities from a Cox model.  It is only necessary if the Cox model has covariates.  It performs a similar task to Clarify's {help setx}.{p_end}

{pstd}
For each 'master' covariate, the user gives {bf:mstcovar} a list of that covariate's transition-specific variable names, and the value at which these variables should be held.
{bf:mstsample} uses this information when running the simulations for any requested transition probabilities.{p_end}

{pstd}All covariates (transition-specific or otherwise) in your {help stcox} model must appear in one of {cmd:mstcovar}'s lists.  If this is not so, {cmd:mstsample} will throw an error.{p_end}

{pstd}
{bf:mstcovar} requires {it:varname} be in the dataset.  {it:varname} is the master covariate, used to generate any transition-specific covariates.   
For instance, if we had a dataset in which GDP per capita had transition-specific effects, gdppc would be the master variable.  
It is the original, "master" variable you would use to generate the transition-specific GDPPC variables (e.g., gdppc_tr1, gdppc_tr2...).
No specific naming conventions are required for the transition-specific covariates.{p_end}

{pstd}
You can view the current covariate lists and values in memory by typing {cmd:mstcovar} (and nothing else).{p_end}

{pstd}
We {it:{opt strongly}} recommend **always** inserting {bf: mstcovar, clear} before your initial set of {bf: mstcovar} statements.  {bf:mstcovar} puts its variable lists into global macro memory, which does *{it:not}* clear by
typing {bf:clear *} in Stata.  {bf: mstcovar, clear} is the only way to ensure you are beginning with a clean slate.{p_end}


{marker options}{...}
{title:Options}

{dlgtab:Required}

{phang}{opt n:ames(varlist)} is how the user tells Stata the transition-specific variable names associated with the "master" covariate, {it:varname}.  These transition-specific covariates must already be generated and in the dataset.{p_end}
	{pmore}If the master covariate's list is already in memory and you are simply changing the covariate's value, {opt names()} is not required.{p_end}
	{pmore}If {bf:sdur} was specified in the {cmd:mstutil} statement, {opt names()} is not required, ever.  
The model has only one transition, and therefore, only one "transition-specific" covariate can be present--the master variable specified via {it:varname}.{p_end}

{dlgtab:Optional}

{phang}{opt v:alue(stats)} specifies the value at which this particular variable (and its transition-specific equivalents) should be held.  {it:stats} can be:{p_end}
	{pmore2}1.) A numerical expression or value (e.g., ln(5), -234, 0.9*7){p_end}
	{pmore2}2.) One of {help tabstat##statname:tabstat}'s statistics.  Only one statistic may be specified at a time.{p_end}
	{pmore}If you want to calculate a statistic using estimation sample observations only, be sure to specify {bf:if(e(sample)==1)}.{p_end}
	{pmore}If nothing is entered for {bf:value()}, {bf:mstcovar} will set the covariate equal to its median value.{p_end}

{phang}{opt rep:lace} is required to override any current variable list for a given master covariate.  It exists to minimize the chance of accidental user errors while {cmd:mstcovar}ing.  
You may want to override an existing list if you previously entered the list incorrectly or if the list needs updating (e.g., you collapse some transitions, constraining the covariate's effect to be equal).{p_end}
	{pmore}If you do not specify {bf:replace}, Stata will look at which transition-specific variable names are in {bf:name()} 
	for {it:varname}, compare {it:varname}'s new list to {it:varname}'s list in memory, see the two are not the same, and throw an error.{p_end}  
{pmore}As a corollary, for convenience, you could enter the same list of covariates over and over again in {bf:name()} {it:without} specifying {bf:replace}, since there are no differences between your 'new' list and the list in memory.{p_end}
	
{phang}{opt clear} will clear all of {cmd:mstcovar}'s variable lists in memory and {cmd:mstcovar}'s covariate values matrix.  If {bf:clear} is present, {cmd:mstcovar} will ignore any other option you specify.{p_end}
	{pmore}We {it:{opt strongly}} recommend **always** inserting {bf: mstcovar, clear} before your initial set of {bf:mstcovar} statements.
	  Stata's {bf:clear *} will purge {cmd:mstcovar}'s covariate matrix from memory, but not {cmd:mstcovar}'s lists, which are stored in global macros. {p_end}
{p 0 0 0 0}{p_end}


{marker examples}{...}
{title:Examples}

{pstd}Competing-risks data - Semi-parametric{p_end}
{p 6 6 2}{it:Set ifp to its 25th percentile, tumsize to its maximum, and pelnode to its mean value.}{p_end}
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
{p 9 14 2}{cmd: foreach x of varlist ifp tumsize pelnode{c -(} }  {p_end}
{phang3}{cmd: forvalues tr = 1/2{c -(} }  {p_end}
{p 15 19 2}{cmd: gen `x'_tr`tr' = cond(trans==`tr', `x', cond(`x'==., ., 0))} {p_end}
{phang3}{cmd: {c )-}} {p_end}
{p 9 14 2}{cmd: {c )-}} {p_end}
{phang2}{cmd:. stcox  *_tr1 *_tr2, strata(trans) efron}{p_end}
{phang2}{cmd:. mstutil, from(curStg) to(nextStage)}{p_end}
{phang2}{cmd:. mstcovar, clear}{p_end}
{phang2}{cmd:. mstcovar ifp, n(ifp_tr1 ifp_tr2) v(p25)}{p_end}
{phang2}{cmd:. mstcovar tumsize, n(tumsize_tr1 tumsize_tr2) v(max)}{p_end}
{phang2}{cmd:. mstcovar pelnode, n(pelnode_tr1 pelnode_tr2) v(mean)}{p_end}
{phang2}{cmd:. mstcovar}{p_end}

{p 6 6 2}{it:You decide to estimate only one effect for tumsize, and also want to set pelnode to its median value.}{p_end}
{phang2}{cmd:. mstcovar tumsize, n(tumsize) v(max)}{p_end}
{phang2}{cmd: // ^ will throw error, because new list != list in memory}{p_end}
{phang2}{cmd:. mstcovar tumsize, n(tumsize) v(max) replace}{p_end}
{phang2}{cmd:. mstcovar pelnode, n(pelnode_tr1 pelnode_tr2)}{p_end}
{phang2}{cmd: // ^ replace's presence or absence won't matter b/c new list==list in memory}{p_end}
{phang2}{cmd:. mstcovar}{p_end}

{p 6 6 2}{it:You decide to set tumsize to 1 standard deviation above its mean for the estimation sample.}{p_end}
{phang2}{cmd:. sum tumsize if(e(sample)==1)}{p_end}
{phang2}{cmd:. return list}{p_end}
{phang2}{cmd:. mstcovar tumsize, v(r(mean)+r(sd))}{p_end}
{phang2}{cmd: // ^ not necessary to enter list, b/c already in memory}{p_end}
{phang2}{cmd:. mstcovar}{p_end}


{pstd}Single duration data - Semi-parametric{p_end}
{p 6 6 2}{it:Set age to 25 and female to its median.}{p_end}
{phang2}{cmd:. webuse catheter}{p_end}
{phang2}{cmd:. stset time, fail(infect)}{p_end}
{phang2}{cmd:. stcox age female, efron}{p_end}
{phang2}{cmd:. mstutil, sdur}{p_end}
{phang2}{cmd:. mstcovar, clear}{p_end}
{phang2}{cmd:. mstcovar age, v(25)}{p_end}
{phang2}{cmd: // ^ no names() needed b/c single duration}{p_end}
{phang2}{cmd:. mstcovar female, v(p50)}{p_end}
{phang2}{cmd:. mstcovar}{p_end}


{marker results}{...}
{title:Stored Results}

{pstd}
{bf:mstcovar} is not {help stored_results:r-class or e-class}.  Instead, it automatically stores the following in Stata's general memory:{p_end}

{synoptset 22 tabbed}{...}
{p2col 5 15 19 2: {help macros:Macros}}{p_end}
{synopt:{cmd:mstcovar_{it:varname}}}list of {it:varname}'s transition-specific covariates (global){p_end}

{synoptset 22 tabbed}{...}
{p2col 5 15 19 2: {help  matrix utility:Matrices}}{p_end}
{synopt:{cmd:mstcovarVals}}covariate values for inputted covariate lists{p_end}
{synopt:{cmd:mstcovarVals_means}}mean covariate values for estimation sample for mstsample's demeaning{p_end}


{marker cite}{...}
{title:Citation}

{pstd}See the {help mst##cite:mst} help file.{p_end}


{p 0 0 0}
{bf:Last Updated} - 21FEB19
{p_end}
