{smcl}
{* *! version 27jun2022}{...}
{viewerjumpto "Syntax" "mstsample##syntax"}{...}
{viewerjumpto "Description" "mstsample##description"}{...}
{viewerjumpto "Options" "mstsample##options"}{...}
{viewerjumpto "slicetrigger Remarks" "mstsample##slicetrigDetails"}{...}
{viewerjumpto "Examples" "mstsample##examples"}{...}
{viewerjumpto "Stored results" "mstsample##results"}{...}
{viewerjumpto "Citation" "mstsample##cite"}{...}
{viewerjumpto "References" "mstsample##references"}{...}

{vieweralsosee "mstatecox Commands: Overview" "help mst"}{...}
{vieweralsosee "mstutil" "help mstutil"}{...}
{vieweralsosee "mstcovar" "help mstcovar"}{...}
{vieweralsosee "mstphtest" "help mstphtest"}{...}
{vieweralsosee "" "--"}{...}
{vieweralsosee "[ST] stcox" "help stcox"}{...}
{vieweralsosee "[R] tabstat" "help tabstat"}{...}
{title:Title}

{p 4 16 2}
{hi:mstsample} {hline 2} Generates transition probabilities via simulation for the specified stcox model on the interval ({it:s},{it:t}].
{p_end}


{marker syntax}{...}
{title:Syntax}

{p 4 16 2}
{hi:mstsample}{cmd:,} {opt ss:tage(integer)} {opt st:ime(integer)} 
					[{opt n(integer)} {opt sims:(integer)} {opt tm:ax(integer)} {opt gap:} {opt hazo:verride}
					 {opt gen(newvarstub)} {opt path(newvarstub2)} {opt ci(cilevel)} {opt ver:bose} {opt ter:se} 
					  {opt speed} {opt msfit} {opt slice:trigger(integer)} {opt dir(path)}]

{synoptset 20 tabbed}{...}
{synopthdr}
{synoptline}
{syntab:Required}
{synopt :{opt ss:tage(integer)}}starting stage{p_end}
{synopt :{opt st:ime(integer)}}starting time ({it:s} in multi-state literature){p_end}

{syntab:Simulation}
{synopt :{opt n(integer)}}number of subjects per simulation, default = 10{p_end}
{synopt :{opt sims(integer)}}number of simulations, default = 1{p_end}
{synopt :{opt tm:ax(integer)}}stopping time ({it:t} in multi-state literature), default = largest observed failure time{p_end}
{synopt :{opt gap}}duration measured in gap time, default = total time{p_end}
{synopt :{opt hazo:verride}}if outward hazards sum to greater than 1 or less than 0, force them to rescale{p_end}

{syntab:Reporting}
{synopt :{opt gen(newvarstub)}}generate results variables beginning with {it:newvarstub} for each simulation-time point pairing{p_end}
{synopt :{opt path(newvarstub2)}}generate results variables beginning with {it:newvarstub2} containing the each subject's path in every simulation{p_end}
{synopt :{opt ci(cilevel)}}confidence level to report in output, default = {bf:c(level)}{p_end}

{syntab: Simulation Progress}
{synopt : {opt ver:bose}}gives percent complete for each simulation pull, default for single-core machines{p_end}
{synopt : {opt ter:se}}gives percentage of simulations complete, overall, default for multi-core machines{p_end}

{syntab: Speed}
{synopt : {opt speed}}output only the final means and confidence intervals for each time point{p_end}

{syntab: Troubleshoot}
{synopt : {opt msfit}}saves the survivor and hazard matrix used for the simulations, default is not to save{p_end}

{syntab: Memory Management}
{synopt : {opt slice:trigger}}the number of observations triggering a different result processing routine, default = 250 million{p_end}
{synopt : {opt dir}}relevant only if slicetrigger condition is met.  Specifies where you want Stata to save output, default is within present working directory.{p_end}
{synoptline}

{p 4 6 2}
Must set {help mstutil} before running {bf:mstsample}.  If your model has covariates, you must also run {help mstcovar} before running {bf:mstsample}.{p_end}


{marker description}{...}
{title:Description}

{pstd}
{cmd:mstsample} is the third command you must run to generate transition probabilities from a Cox model, after {bf:mstutil} and (if semi-parametric) {bf:mstcovar}.  
It simulates a user-specified number of subjects moving through the process of interest, as defined by the dataset's structure, the previously estimated {help stcox} model, and the covariate profile defined by {help mstcovar}.{p_end}

{pstd}
For an intuitive overview of how the command works, see Metzger and Jones (2016, Appendix H; 2018).  The command draws heavily on de Wreede, Fiocco, and Putter's mstate package for R, which itself makes
use of Dabrowska (1995).{p_end}

{pstd}
{cmd:mstsample} is capable of simulating transition probabilities from Cox models with time interactions, 
a common way to correct for violations of the proportional hazard assumption.  To tap into this functionality,
you must specify the time interactions using {cmd:stcox}'s {bf:tvc()}/{bf:texp()} options.  Be sure your dataset
is structured properly for the time interactions using {help stsplit} (see Jin and Boehmke 2017).{p_end}

{pstd}
All covariates (transition-specific or otherwise) in your {help stcox} model must appear in one of {cmd:mstcovar}'s covariate lists.  
If a covariate does not appear in any list, {cmd:mstsample} will throw an error.  You can check if this is so by typing {cmd:mstcovar} to examine the covariate lists in memory.{p_end}

{pstd}
The command's name is a hattip to R-mstate's mssample command, as the commands perform the same task.  In terms of general syntax,
Stata's {bf:mstsample} with {bf:sims(1)} is the same as a single call of R-mstate's mssample.{p_end} 
{pstd}
{bf:mstsample} is a simulation command.  If you want to reproduce the exact same results in the future, you should {help set seed} before executing the command. {p_end}


{marker options}{...}
{title:Options}

{dlgtab:Required}

{phang}{opt ss:tage(integer)} is the stage in which all subjects begin at each simulation's start.{p_end}

{phang}{opt st:ime(integer)} is the time at which each simulation begins (denoted {it:s} in the multi-state literature).{p_end}

{dlgtab:Simulation}

{phang}{opt n(integer)} for each simulation, specifies the number of subjects to simulate moving through the process.  The default is 10 subjects.{p_end}

{pmore}It is useful (but not necessary) to set this value to the number of subjects in the dataset.  If you specify a number of subjects much smaller than the dataset's number of subjects,
it can reduce the simulation results' precision, producing wider confidence intervals.  Setting a larger number of subjects (e.g., n = [dataset's number of subjects]*1.5) 
will therefore improve the transition probabilities' precision.{p_end}

{pmore}We caution against increasing the number of subjects too far for two reasons.  First, increasing the number of subjects more than 1.5 times the observed number will 
not appreciably improve the precision of transition probability estimates further.  Second, as the number of subjects increases, the time required to run the simulations 
will also increase accordingly.{p_end}

{pmore}Our general suggestions:{p_end}

{p 12 14 2} - Do not worry at first about number of subjects.  Pick something in the 100-500 range, and pick a small number of simulations as well (200-500).  This will 
give you a sense of your transition probabilities' magnitude, the chance to finalize your model's specification, and a chance to easily spot any input errors you may have made.{p_end}

{p 12 14 2} - After finalizing your model specification, run a full set of simulations with 1000 runs.  Pick something manageable enough for the number of subjects: anything less than 1000 is sufficient.  
Again, make note of the transition probabilities' magnitude. {p_end}

{p 12 14 2} - If your CIs overlap, and you have reason to suspect they should not--perhaps the {bf:stcox} estimates hint at a potentially significant 
effect for the covariate--run another set of simulations.  The number of subjects' biggest impact is on the CIs' precision.  
Anything from 1-10 subjects will give you one decimal point of precision (1/10=.1), 11-100 subjects will give you two decimal points of precision (1/100=.01), 
101-1000 will give you three (1/1000=.001), 1001-10000 will give you four (1/10000=.0001), and so on.  Choose a number of subjects that will give you 
sufficiently precise confidence intervals, given your transition probabilities' magnitude and the dataset's true number of subjects (as discussed previously).{p_end}

{pmore}We mentioned you might suspect your covariate of interest has a statistically significant effect based on the {bf:stcox} estimates.  {it:However},
keep in mind that transition probabilities are looking at the covariate's effect across **all** transitions.  It can be the case that, although a covariate
has a statistically significant effect on the probability of experiencing one of the transitions, it may have no effect or an opposite effect on other transitions
in your process.  As a result, the covariate's net effect may very well be statistically indistinguishable from zero, once you take *all* the transitions into account.
Make sure you check the confidence intervals from the relevant transition probabilities' first differences (which you can generate using the variables from {opt gen()}, 
without {opt speed} specified) before drawing any firm conclusions.{p_end}

{phang}{opt sims(integer)} is the number of times to repeat the simulation.  The default is 1, and the usual for Monte Carlos is 1000.{p_end}

{phang}{opt tm:ax(integer)} is the time at which each simulation should stop (denoted {it:t} in the multi-state literature).  
The default is the largest observed failure time in the dataset.
We suggest you specify a value here, because your dataset may have extreme/outlier failure times.{p_end}

{phang}{opt gap} tells {bf:mstsample} that the {bf:stset}ted duration is measured in gap time.  {bf:mstsample}'s default is total time.{p_end}

{marker optionsHazo}{...}
{phang}{opt hazo:verride} is an override option, in the event that the exiting transitions' hazards for one (or more) stages sum to greater than 1 (or less than 0).  
							A value greater than 1 corresponds to the rows of the A(t) matrix summing to more than 1.
							This condition represents a statistical impossibility, in theory: each row in the A(t) matrix represents the probability of a subject moving from 
							the current stage into another stage in t (or staying in the current stage).
							The stages are defined in a mutually exclusive and exhaustive way, meaning the subject must be in one of the stages.  
							By definition, probabilities cannot sum to greater than 1.{p_end}
							{pmore}However, {bf:mstsample} uses non-parametric and semi-parametric duration models.  By definition, we have no functional form expression
							for the hazards of such models (whereas we do for parametric models).  Consequently, obtaining estimates of the transition-specific hazards is
							more involved than first glance would suggest.{p_end}
							{pmore}{cmd:mstsample} computes its transition-specific hazards 
							by first calculating the transition-specific cumulative hazards.  
							This particular way of obtaining transition-specific hazard {it:estimates} (key phrase), though, can yield {it:estimated} values greater than 1, 
							even when nothing is amiss with the model.{p_end}
							{pmore}If this option is specified, any offending outward hazards greater than 1 will be replaced with 1s.  
							For any outward hazards less than 0 (also possible for similar reasons), this option also replaces them with 0s.  {cmd:mstsample} will post
							a scalar to {bf:e(hazover)} if it replaces any hazards.{p_end}
							{pmore}{bf:NOTE:} outward hazards summing to greater than 1 or less than 0 is usually (but not always, as discussed above) a symptom of a model specification issue, 
									like when there are a number of binary covariates in the model and/or few observed transitions between two stages.
									Before you specify {bf:hazoverride}, try estimating a simpler version of your model--eliminate some covariates, collapse some transitions, etc. 
									You should also look at the outward hazards' values using the {bf:msfit} option.  {opt msfit}'s matrix is stored before overriding any of the hazards' values.{p_end}

{dlgtab:Reporting}

{phang}{opt gen(newvarstub)} will generate variables beginning with {it:newvarstub} containing the simulation results for the stage output and for each simulation-time point pairing.  The default is to calculate each time point's mean and CIs
								across all the simulations, and report these quantities in the Results window without generating any variables for 
								the stage output or the final results.{p_end}
								{pmore}If the {opt slicetrigger} condition is met, Stata will save the stage output to an external dataset.{p_end}
								
{phang}{opt path(newvarstub2)} will generate variables beginning with {it:newvarstub2} containing the specific transition sequences for every subject from every simulation ("paths").  
					The default is to report nothing and save nothing.{p_end}

{phang}{opt ci(cilevel)} specifies the confidence level for the simulation output.  The default value is {bf:c(level)}.  The option's permissible values are governed by {manhelp level R}'s conventions.{p_end}

{dlgtab:Simulation Progress}

{phang}{opt ver:bose} noisily outputs, for each simulation pull, the pull's completion percentage:{p_end}
	{pmore2}#1    0%...10%...20%...30%...40%...50%...60%...70%...80%...90%...100%...done! {break}
    #2    0%...10%...20%...30%...40%...50%...60%...70%...80%...90%...100%...done! {break}
    #3    0%...10%...20%...30%...40%...50%...60%...70%...80%...90%...100%...done! {break}
	(etc.) {p_end}
	
{pmore}This is the default output for single-core machines ({bf:c(processors)}==1; see {help set processors}).{p_end}

{phang}{opt ter:se} noisily outputs the percentage of simulations complete, overall:{p_end}

{pmore2}0%...10%...20%...30%...40%...50%...60%...70%...80%...90%...done!{p_end}

{pmore}This is the default for multi-core machines ({bf:c(processors)}>1; see {help set processors}).{p_end}

{dlgtab:Speed}

{phang}{opt speed} is faster than the default processing calculations.  Its speed gains come from how the final simulation 
output is processed, NOT how the simulations themselves are executed (which remains the same).{p_end}  
{pmore}If you specify {opt speed}, {cmd:mstsample} ignores all of your {help mstsample##trigger:memory management options}.{p_end}

{pmore}If you specify {opt gen()} with {opt speed}, {cmd:mstsample} will only save variables with the final processed simulation results ({opt gen()} variables with "RESULTS: *" labels).
It will not save variables with each simulation-subject-time point triplet ({opt gen()} variables with "SIMS: *" labels).{p_end}

{dlgtab:Troubleshoot}

{phang}{opt msfit} will save {bf:mstsample}'s internal matrix of survivor and hazard values, used for the simulations, before enforcing {opt hazoverride}.  Specifically, the matrix contains these quantities, in the following order:{p_end}

{pmore2}- Time {break}
- Transition ID (denoted 'q' in subsequent lines){break} 
- From stage {break}
- To stage {break}
- Transition-specific survivor (S_q(t)) {break}
- Transition-specific hazard (h_q(t); a_q(t) in the multi-state literature) {break}
- Transition-specific cumulative hazard (H_q(t); A_q(t) in the multi-state literature) {break}
- Outward transition hazard for a stage (sum of all the transition-specific hazards starting *from* that particular stage){p_end}

{pmore}The outward transition hazards are discussed further above, in the context of {bf:hazoverride}.

{pmore}After running {bf:mstsample}, view this matrix by typing {bf:matrix list tShoot_mstate}.  The matrix is akin to what R-mstate's msfit command outputs, hence the option's name.{p_end}

{pmore}The matrix is useful for troubleshooting purposes (say, if your transition probabilities look outrageous, given what you descriptively know about your data).  
You may also want to view these quantities for other, non-troubleshooting reasons, like graphing the transition-specific cumulative hazards or one of the other quantities.{p_end}

{pmore}By default, {bf:mstsample} purges this matrix after the command finishes, to help with memory management.{p_end}
{p 0 0 0 0}{p_end}

{dlgtab:Memory Management}

{marker trigger}{...}
{phang}{opt slice:trigger(integer)} is the number of observations that triggers a different routine for processing the simulation results.  
							The option exists because, for smaller simulation runs, {bf:slicetrigger}'s result processing routine will take longer 
							than the default processing routine.  If (number of subjects) * (number of simulation draws) *
							(tmax - stime + 1) is greater than {it:integer}, the {bf:slicetrigger} processing routine will run.  
							Otherwise, the default processing routine will run.  The default {it:integer} "trigger" value is 250 million observations.{p_end}
					{pmore}	If you specify {bf:gen()} and the slicetrigger condition is met, your stage output will also be directly saved to disk in a new directory
							created by {bf:mstsample}.  See {bf:dir()} below for details. {p_end}
					{pmore} You should modify this option {ul:only} if you are expecting issues with the amount
							of memory Stata might use, given what else you have running on your computer.  You should 
							also only modify this option if you understand the {help mstsample##slicetrigDetails:full explanation} of {bf:slicetrigger}'s behavior.{p_end} 

{phang}{opt dir(string)} provides the full directory path where {bf:mstsample} should look to save the stage output if the {bf:slicetrigger} condition is met *and*
{bf:gen()} is also specified.  (Discussed further above in the context of {bf:slicetrigger}.)  By default, Stata will try to create a new directory in your 
present working directory (of the form {it:datasetname}_{it:ddMMyy}_{it:hhmmss}_{it:a random number}).
It will then save the stage output for every simulation draw to this directory, for a total of {it:sims} datasets. {p_end}

{pmore}  If Stata cannot create this new directory in your present
working directory, it will then look to see if you specified anything in {bf:dir()}, and will try to create the new directory again in this location.  If it cannot, 
or if you specified no directory with {bf:dir()}, {cmd:mstsample} will throw an error.{p_end}
 
{pmore} Do not accidentally delete the new directory from disk while {cmd:mstsample} is running.  The command will begin behaving erratically, because once it successfully
creates the new directory, it does not re-check to ensure the directory exists before saving files into it. {p_end}


{marker slicetrigDetails}{...}
{title:Further Remarks on slicetrigger()}

{pstd} To understand what the {bf:slicetrigger} option does, you must first understand the general steps {cmd:mstsample} takes to process the simulation results.
		{bf:mstsample}'s simulation section saves the results in "path" form, where each row denotes a time point in which a subject transitioned to a new stage,
for a particular simulation draw.  For instance:{p_end}

		Sim #	Subject	Time	Stage
		------------------------------ 
		1	1	0	1 
		1	1	17	2 
		1	1	60	2 
		1	2	0	1 
		1	2	4	2 
		1	2	60	2 
		1	3	0	1 
		1	3	60	1 
	{pstd} We see the first subject begins in Stage 1 at t = 0.  It then transitions into Stage 2 at t = 17.  It is still in Stage 2 at t = 60—the end time for this hypothetical simulation.  
			The second subject starts in Stage 1, transitions into Stage 2 at t = 4, and then stays there until t = tmax = 60; 
			and both subjects 3 and 4 never transition out of Stage 1 at all. {p_end}
	{pstd}
The result processing section takes this "path" output and converts it into "stage" output, with one row for every simulation number-subject 
pairing, for every integer time point in (stime,tmax] (in multi-state parlance: (s,t]).  For the previous example, for the first two subjects, there would be 122 total observations: {p_end}

		Sim #	Subject	Time	Stage
		------------------------------ 
		1	1	0	1
		1	1	1	1
		1	1	2	1
		1	1	3	1
		:	:	:	:
		1	1	15	1
		1	1	16	1
		1	1	17	2
		1	1	18	2
		1	1	19	2
		:	:	:	:
		1	1	59	2
		1	1	60	2 
		1	2	0	1
		1	2	1	1
		1	2	2	1
		1	2	3	1
		1	2	4	2
		1	2	5	2
		1	2	6	2
		:	:	:	:
		1	2	59	2
		1	2	60	2 

{pstd}Finally, from the stage output, {bf:mstsample} computes the percentage of subjects in each stage at every t, for each simulation.  
{bf:mstsample} then reports the simulated transition probability for Stage g in time t, by averaging the percentage of subjects in Stage g at t across all the simulation draws 
(e.g., for t = 1, the percentage for t = 1 from the first simulation draw, plus the percentage for t = 1 from the second simulation draw, and so on for all the simulation draws; then the same for t = 2...).{p_end}

{pstd}The default result processing routine follows these steps almost exactly.  {bf:mstsample} first completes all of the simulation draws and compiles the path output in a separate file.
Once all the simulation draws are complete, it then converts all the path output to stage output in one swoop, and then converts all the stage output to the final percentages.{p_end}

{pstd}However, this procedure is problematic for "large" simulation runs.  The full stage output from a given simulation run will have (number of subjects) * (number of simulation draws) * 
(tmax - stime + 1) number of observations.  Very quickly, this dataset can get into the hundreds of millions for observations, giving rise to:{p_end}

{p 8 12 2} (a) slower computations for all users, but especially for single-core users {p_end}
{p 8 12 2} (b) the potential to max out both the computer's physical and virtual memory, leading Stata to throw an {search r(909), local:r(909)} error or become non-responsive entirely. {p_end}

{pstd}  If Stata throws any kind of error
during the result processing section, {it:all} your simulation results may be lost.  In some cases, {cmd:mstsample} does try to save an "emergency" version of your path output to your present working
directory before it begins processing to help stave off this precise situation, but it would be best to avoid the situation entirely. {p_end}

{pstd}{bf:slicetrigger}'s result processing routine addresses this issue head on.  Instead of collecting all of the path data to process at once, it processes the data "on the fly"--that is, at the end
of every simulation draw.  The path output's number of observations is smaller than the stage output by several orders of magnitude, giving Stata a much easier task. {p_end}

{pstd}At the end of every draw, {cmd:mstsample} will convert the path output to stage output.  If the {bf:gen()} option is specified, mstsample will save each draw's 
stage output in a dataset named {it:sim#.dta} in the new folder it creates (see {bf:dir()}, below).  {bf:slicetrigger}'s routine then takes the single simulation draw's 
stage output and converts it into the final percentages we require, and stores these percentages in memory.{p_end}

{pstd}With {bf:slicetrigger}, successive simulation draws will be slower, relative 
to the first draw.  Stata is accumulating all your final percentages into one dataset as it goes, and this dataset is getting larger after every simulation draw.
However, relative to the default result processing routine, {bf:slicetrigger}'s is faster for large datasets.{p_end}

{pstd}{bf:slicetrigger}'s {it:integer} default is a general "rule of thumb" number.  Stata does not adjust it based on your computer's current characteristics, because
it cannot easily do so.
That said, the ramifications of changing {bf:slicetrigger}'s value are clear: {p_end}

{pmore}
If the value is {ul:too low}, you are creating more work for Stata, because Stata *could* process all your
results at once, permitting it to bring its dataset-based data-manipulation capabilities to bear.  However, you are forcing Stata to 
slice up your dataset into tiny pieces, depriving you of these speed gains.
It also forces Stata to open and close various temporary datasets behind the scenes when it can otherwise finish both the simulations and the result processing very
quickly, which also takes additional time (usually in minutes, in terms of magnitude). {p_end}

{pmore}
If the value is {ul:too high}, the simulations will take longer to run because the dataset's size 
overpowers the speed advantages from Stata's data-manipulation capabilities, creating additional *hours* of run time.  
You also run the risk of Stata grinding to a halt, if the stage output has more observations than Stata can reasonably cope with, given how much of your computer's
memory is free for use.  At worst, your operating system will pull the plug by refusing to allocate Stata the memory it requests, producing an {search r(909), local:r(909)} 
error and the potential loss of all your simulation results. {p_end}


{marker examples}{...}
{title:Examples}

{pstd}Single duration data, variant 1 - Non-parametric{p_end}
{p 6 6 2}{it:38 subjects, all beginning in Healthy (stage 1) at time 0.  Determine probability of being Infected (stage 2) by time 45.  Repeat 50 times.}{p_end}
{phang2}{cmd:. webuse catheter}{p_end}
{phang2}{cmd:. stset time, fail(infect)}{p_end}
{phang2}{cmd:. stcox, estimate efron}{p_end}
{phang2}{cmd:. mstutil, sdur}{p_end}
{phang2}{cmd:. mstsample, n(38) sstage(1) stime(0) tmax(45) sims(50)}{p_end}


{pstd}Single duration data, variant 1 - Semi-parametric{p_end}
{p 6 6 2}{it:38 subjects, all beginning in Healthy (stage 1) at time 0.  Determine probability of being Infected (stage 2) by time 40 when all covariates at median values.  Repeat 30 times.}{p_end}
{phang2}{cmd:. webuse catheter}{p_end}
{phang2}{cmd:. stset time, fail(infect)}{p_end}
{phang2}{cmd:. stcox age female, efron}{p_end}
{phang2}{cmd:. mstutil, sdur}{p_end}
{phang2}{cmd:. mstcovar, clear}{p_end}
{phang2}{cmd:. mstcovar age}{p_end}
{phang2}{cmd:. mstcovar female}{p_end}
{phang2}{cmd:. mstsample, n(38) sstage(1) stime(0) tmax(40) sims(30)}{p_end}

{p 6 6 2}{it:Same scenario as above, but with speed option specified.  Results will be identical, different starting seeds aside.}{p_end}
{phang2}{cmd:. mstsample, n(38) sstage(1) stime(0) tmax(40) sims(30) speed}{p_end}


{pstd}Single duration data, variant 1 - Semi-parametric with PH correction{p_end}
{p 6 6 2}{it:Same as previous example, only with a correction for female's non-proportionality with ln(t).}{p_end}
{phang2}{cmd:. webuse catheter}{p_end}
{phang2}{cmd:. stset time, fail(infect)}{p_end}
{phang2}{cmd:. stcox age female, efron tvc(female) texp(ln(_t))}{p_end}
{phang2}{cmd:. mstutil, sdur}{p_end}
{phang2}{cmd:. mstcovar, clear}{p_end}
{phang2}{cmd:. mstcovar age, v(p50)}{p_end}
{phang2}{cmd:. mstcovar female, v(p50)}{p_end}
{phang2}{cmd:. mstsample, n(38) sstage(1) stime(0) tmax(40) sims(30)}{p_end}


{pstd}Competing-risks data - Semi-parametric{p_end}
{p 6 6 2}{it:100 subjects, all beginning in Healthy (stage 1) at time 0.  Determine probability of Distant Disease (stage 3) by time 5 when all covariates at mean values.  Repeat 15 times.  Save paths and msfit matrix when done.}{p_end}
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
{phang2}{cmd:. mstcovar ifp, n(ifp_tr1 ifp_tr2) v(mean)}{p_end}
{phang2}{cmd:. mstcovar tumsize,	n(tumsize_tr1 tumsize_tr2) v(mean)}{p_end}
{phang2}{cmd:. mstcovar pelnode,	n(pelnode_tr1 pelnode_tr2) v(mean)}{p_end}
{phang2}{cmd:. mstsample, n(100) sstage(1) stime(0) tmax(5) sims(15) path(pth) msfit}{p_end}
{phang2}{cmd:. edit pth_*}{p_end}
{phang2}{cmd:. matrix list tShoot_mstate}{p_end}


{pstd}Multi-state data - Non-parametric{p_end}
{p 6 6 2}{it:50 subjects, all beginning in Negotiations (stage 2) at time 12.  Determine probability of Resolved (stage 4) by time 48.  Repeat 10 times.  Save sim output when done.}{p_end}
{phang2}{cmd:. use http://www.shawnakmetzger.com/research/2%20-%20h%26a%20-%20continuous%2c%20no%20TVC.dta}{p_end}
{phang2}{cmd:. stset t, enter(t0) f(status)}{p_end}
{phang2}{cmd:. stcox, estimate strata(trans) efron}{p_end}
{phang2}{cmd:. replace stage = stage + 1}{p_end}
{phang2}{cmd:. replace nextStage = nextStage + 1}{p_end}
{phang2}{cmd:. mstutil, from(stage) to(nextStage)}{p_end}
{phang2}{cmd:. mstsample, n(50) sstage(2) stime(12) tmax(48) sims(10) gen(ms)}{p_end}
{phang2}{cmd:. edit ms_simNm-ms_Rslt_stage4_ub}{p_end}


{marker results}{...}
{title:Stored Results}

{pstd}
{bf:mstsample} is technically {help e-class}, to preserve the Cox estimates in memory.  If {bf:hazoverride} is specified, the command may append one scalar to {cmd:e()}.  
Additionally, {bf:mstsample} posts nothing to Stata's general memory unless {bf:msfit} is specified:{p_end}

{synoptset 22 tabbed}{...}
{p2col 5 15 19 2: Scalars}{p_end}
{synopt:{cmd:e(hazover)}}If {bf:hazoverride} specified, 1 if the override is actually invoked, 0 otherwise.{p_end}

{synoptset 22 tabbed}{...}
{p2col 5 15 19 2: Matrices}{p_end}
{synopt:{cmd:tShoot_mstate}}If {cmd:msfit} specified, matrix containing values for transition-specific survivors, hazards, and cumulative hazards, and overall outward hazards.  Values are stored before
enforcing the {opt hazoverride} option, if specified.{p_end}

{marker cite}{...}
{title:Citation}

{pstd}See the {help mst##cite:mst} help file.{p_end}


{marker references}{...}
{title:References}

{pstd}Dabrowska, Dorota.  1995.  "Estimation of Transition Probabilities and Bootstrap in a Semiparametric Markov Renewal Model."  
		{it:Journal of Nonparametric Statistics} 5 (3): 237–259.{p_end}

{pstd}Jin, Shuai, and Frederick J. Boehmke.  2017.  "Proper Specification of Nonproportional Hazards Corrections in Duration Models."  {it:Political Analysis} 25 (1): 138–144.{p_end}

{pstd}Metzger, Shawna K., and Benjamin T. Jones.  2016.  "Surviving Phases: Introducing Multistate Survival Models."  
		{it:Political Analysis} 24 (4): 457-477.{p_end}
		
{pstd}Metzger, Shawna K., and Benjamin T. Jones.  2018.  "mstatecox: A Package for Simulating Transition Probabilities from Semiparametric Multistate Survival Models."  
{it:Stata Journal} 18 (3): 533–563.{p_end}
		
{pstd}de Wreede, Liesbeth C. de, Marta Fiocco, and Hein Putter.  2010.  "The mstate Package for Estimation and Prediction in Non- and Semi-Parametric Multi-State and Competing Risks Models."  
	 {it:Computer Methods and Programs in Biomedicine} 99 (3): 261–274.{p_end}


{p 0 0 0}
{bf:Last Updated} - 28FEB19
{p_end}

