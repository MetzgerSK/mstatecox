{smcl}
{* *! version 10feb2018}{...}
{viewerjumpto "Syntax" "msttvc##syntax"}{...}
{viewerjumpto "Description" "msttvc##description"}{...}
{viewerjumpto "Examples" "msttvc##examples"}{...}
{viewerjumpto "Stored results" "msttvc##results"}{...}
{viewerjumpto "Citation" "msttvc##cite"}{...}
{viewerjumpto "References" "msttvc##references"}{...}

{vieweralsosee "mstatecox Commands: Overview" "help mst"}{...}
{vieweralsosee "mstsample" "help mstsample"}{...}
{vieweralsosee "" "--"}{...}
{vieweralsosee "[ST] stcox" "help stcox"}{...}
{vieweralsosee "[ST] stsplit" "help stsplit"}{...}
{title:Title}

{p 4 16 2}
{hi:msttvc} {hline 2} utility command for advanced users to declare time-varying covariates after estimating a Cox model.
{p_end}


{marker syntax}{...}
{title:Syntax}

{p 4 16 2}
{hi:msttvc}{cmd:,} {opt tvc(varlist)} {opt texp:(exp)}

{synoptset 20 tabbed}{...}
{synopthdr}
{synoptline}
{synopt :{opt tvc(varlist)}}required, list of time-varying covariates, identical in syntax to {bf:{help stcox:stcox, tvc()}}{p_end}
{synopt :{opt texp(exp)}}required, multiplier for time-varying covariates, identical in syntax to {bf:{help stcox:stcox, texp()}}{p_end}
{synoptline}

{p 4 6 2}
Must first estimate {help stcox} before running {bf:msttvc}.  All interactions associated with time-varying covariates must be listed together at the end of stcox's covariate list.
{p_end}


{marker description}{...}
{title:Description}

{pstd}
{cmd:msttvc} is an optional utility command for advanced users.  It is the "halfth" command you would need to run to generate transition probabilities from a Cox model.  Eventually, {cmd:mstsample} 
requires time-varying covariates to be declared using {cmd:stcox}'s {bf:tvc()} and {bf:texp()} options, or else the transition probabilities will be wrong.  
However, there are some instances where the Cox model will take significantly longer to estimate than it would if you manually generated the time-varying covariates yourself.  
This command provides a way to manually estimate the exact same model specification without using {cmd:stcox}'s {bf:tvc()} and {bf:texp()} options.{p_end}

{pstd} You should {ul:only} use this command if:{p_end}
{pmore}(a) {cmd:stcox} is taking a while to run with {bf:tvc()}/{bf:texp()} specified; and{p_end}
{p 8 12 2}(b) you are adept with Cox models, and understand how to {bf:stsplit} data and generate the subsequent interaction terms properly (see Jin and Boehmke 2017).{p_end}

{pstd}To use: {bf:{help stsplit}} the data, manually generate any interactions for time-varying covariates, and then run {cmd:stcox} and include these interactions as regressors at the list's end.
Importantly, **do not include** {bf:tvc()} and {bf:texp()} with the {bf:stcox}, since you have generated and included the time-varying covariates manually.
What you {it:would} have typed for {cmd:stcox}'s {bf:tvc()} and {bf:texp()} is what {bf:msttvc} is expecting in its identically named {bf:tvc()} and {bf:texp()} options.{p_end}

{pstd}We reiterate {bf:msttvc} should be used only when the situation warrants it {it:and} when you know what you are doing.  The command removes some of the proverbial 
safety nets.  {bf:mstsample} implements the proper stsplit and interactions on its own if you can use {bf:stcox, tvc() texp()}.  {cmd:msttvc} overwrites stored results behind the scenes, which will cause downstream problems if the command is
used improperly.{p_end}  

{marker examples}{...}
{title:Example}

{pstd}Single duration data - Semi-parametric{p_end}
{phang2}{cmd: // automated way to generate}{p_end}
{phang2}{cmd:. webuse drugtr2}{p_end}
{phang2}{cmd:. stset time, failure(cured)}{p_end}
{phang2}{cmd:. stcox age drug1 drug2, nohr tvc(drug1 drug2) texp(_t)}{p_end}

{phang2}{cmd: // generating manually}{p_end}
{phang2}{cmd:. gen id = _n}{p_end}
{phang2}{cmd:. stset time, failure(cured) id(id)}{p_end}
{phang2}{cmd:. stsplit, at(failures)}{p_end}
{phang2}{cmd:. gen double drug1_inter = drug1 * _t}{p_end}
{phang2}{cmd:. gen double drug2_inter = drug2 * _t}{p_end}
{phang2}{cmd:. stcox age drug1 drug2 drug1_inter drug2_inter, nohr}{p_end}
{phang2}{cmd: // ^ manual: notice, matches the automated}{p_end}
{phang2}{cmd:. msttvc, tvc(drug1 drug2) texp(_t)}{p_end}
{phang2}{cmd:. stcox, nohr}{p_end}
{phang2}{cmd: // ^ matches the automated output}{p_end}


{marker results}{...}
{title:Stored Results}

{pstd}
{cmd:msttvc} overwrites some of the contents of {help stcox}'s {cmd:e()} and also appends the following to {help stcox}'s {cmd:e()}:

{synoptset 22 tabbed}{...}
{p2col 5 15 19 2: Macros}{p_end}
{synopt:{cmd:e(msttvc)}} appends; "1", to tell {cmd:mstsample} the workaround has been invoked{p_end}
{synopt:{cmd:e(tvc)}} !! overwrites; contents of {bf:msttvc}'s {bf:tvc()} option{p_end}
{synopt:{cmd:e(texp)}} !! overwrites; contents of {bf:msttvc}'s {bf:texp()} option{p_end}


{marker cite}{...}
{title:Citation}

{pstd}See the {help mst##cite:mst} help file.{p_end}


{marker references}{...}
{title:References}

{pstd}Jin, Shuai, and Frederick J. Boehmke.  2017.  "Proper Specification of Nonproportional Hazards Corrections in Duration Models."  {it:Political Analysis} 25 (1): 138–144.{p_end}


{p 0 0 0}
{bf:Last Updated} - 10FEB18
{p_end}
