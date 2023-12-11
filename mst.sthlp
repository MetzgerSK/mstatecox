{smcl}
{* *! version 11dec2023}{...}
{viewerjumpto "Description" "mst##description"}{...}
{viewerjumpto "System Requirements" "mst##prereq"}{...}
{viewerjumpto "Background Reading" "mst##toread"}{...}
{viewerjumpto "List of Commands" "mst##alpha"}{...}
{viewerjumpto "Steps" "mst##howto"}{...}
{viewerjumpto "Package Updates" "mst##updates"}{...}
{viewerjumpto "Citation" "mst##cite"}{...}
{viewerjumpto "References" "mst##reference"}{...}

{vieweralsosee "mstutil" "help mstutil"}{...}
{vieweralsosee "mstcovar" "help mstcovar"}{...}
{vieweralsosee "mstphtest" "help mstphtest"}{...}
{vieweralsosee "mstsample" "help mstsample"}{...}
{vieweralsosee "" "--"}{...}
{vieweralsosee "mstdraw" "help mstdraw"}{...}
{vieweralsosee "msttvc" "help msttvc"}{...}
{vieweralsosee "" "--"}{...}
{vieweralsosee "[ST] stset" "help stset"}{...}
{vieweralsosee "[ST] stcox" "help stcox"}{...}
{vieweralsosee "[ST] stcox PH-assumption tests" "help stcox_diagnostics"}{...}
{title:Title}

{p 4 16 2}
{hi:mst} {hline 2} 'mstatecox', commands for non-parametric and semi-parametric multi-state duration modeling.
{p_end}


{marker description}{...}
{title:Description}

{pstd}
The 'mstatecox' suite provides six commands for analyzing non- and semi-parametric multi-state duration models in Stata.  
These models are described by Metzger and Jones (2016) and de Wreede, Fiocco, and Putter (2010), among others.

{pstd}  
Stata has a built-in ability to estimate semi-parametric multi-state models via {help stcox}.
However, it cannot easily generate predicted quantities from the resultant model.  In particular, Stata lacks the ability 
to estimate transition probabilities, which describe the probability of subjects being in a particular state at a particular time, given a set of starting conditions.
Transition probabilities are a quintessential quantity from a multi-state model, one whose interpretation is arguably the most intuitive of all the duration model interpretation techniques.{p_end}

{pstd}Our command suite provides the functionality to compute transition probabilities via simulation, for any stage structure.  The simulations treat coefficient values as fixed.  
Our commands also provide a number of helpful utility functions for plotting any generated transition
probabilities, checking for proportional hazards violations in a multi-state setting, and describing the model's stage structure.
{p_end}

{pstd}
For a command suite that focuses on parametric multi-state models, see Crowther and Lambert's {stata ssc describe multistate:multistate} package.{p_end}

{pstd}
Our package's name is a hattip to R's mstate package, which is our package's R equivalent.  See de Wreede, Fiocco, and Putter (2010) for details.{p_end}

 
{marker prereq}{...}
{title:System Requirements}

{pstd}
mstatecox works with Stata 13 and later.  Earlier versions of Stata lack the {help mata selectindex:selectindex} function, which {cmd:mstsample} requires.
{p_end}

{pstd}
You must also install three additional packages for {cmd:mstsample} to work.
{p_end}
 
{p 8 12 2} 1.) {bf:moremata} from SSC ({bf:ssc install moremata}).{p_end} 
{p 8 12 2} 2.) {bf:gtools} from SSC,  then updating to get the most recent stable release:{p_end}
{p 16 12 2}{cmd:ssc install gtools}{p_end}
{p 16 12 2}{cmd:gtools, upgrade}{p_end}

{p 8 12 2} 3.) {bf:ftools} from SSC ({bf:ssc install ftools}).{p_end}
 
{pstd}
Finally, if possible, we recommend you set your present working directory to one where Stata has permission to save files.  
For why, see {helpb mstsample##trigger:mstsample} (specifically, {bf:slicetrigger}'s remarks).
{p_end}


{marker toread}{...}
{title:Background Reading}

{pstd}{ul:Cox models}: Semi-parametric multi-state models are predicated on Cox models.  
For an introduction, see the {manlink ST stcox} entry, Singer and Willett (2003, Chs. 14-15), and Box-Steffensmeier and Jones (2004, Ch. 4).  
For a more detailed discussion of Cox models, see Therneau and Grambsch (2000).
{p_end}

{pstd}{ul:Proportional hazards}: One of the major assumptions underlying Cox models.  In addition to the Cox model reading, see 
Box-Steffensmeier and Zorn (2001), Licht (2011), and Jin and Boehmke (2017).

{pstd}{ul:Multi-state models}: Users needing an introduction to and discussion of multi-state models should look at Metzger and Jones (2016, 2018), 
who discuss the models in a political science setting.  Putter, Fiocco, and Geskus (2007) have a tutorial in a biostatistics setting. 
Geskus' (2015) book is also from a biostatistics angle, and discusses both competing risks and multi-state models, as competing risks are a specific example of a multi-state model.{p_end}

{pstd}{ul:Dataset structure}: For information on how to structure your dataset for the analysis, see Jones 
and Metzger (2018, Supplemental Appendix A) and de Wreede, Fiocco, and Putter (2010).{p_end}


{marker alpha}{...}
{title:Commands (Alphabetical)}

{p2colset 4 15 29 2}{...}
{p2col :{helpb mstcovar}}Sets covariate values before simulating transition probabilities{p_end}

{p2col :{helpb mstdraw}}Descriptive utility command; provides transition information and can graph transition probability results{p_end}

{p2col :{helpb mstphtest}}A convenience wrapper to run tests for proportional hazard assumption violations{p_end}

{p2col :{helpb mstsample}}Generates transition probabilities via simulation{p_end}

{p2col :{helpb msttvc}}For advanced users only; manually declares time-varying covariates in an estimated Cox model{p_end}

{p2col :{helpb mstutil}}Declares the data to be structured for multi-state duration analysis{p_end}
{p2colreset}{...}


{marker howto}{...}
{title:Steps: Overview}

{pstd}
You have a dataset in memory, from which you would like to estimate a non- or semi-parametric multi-state duration model.
To estimate and generate predicted quantities from the model, you would:{p_end}

{p 8 12 2} 1.) Ensure the dataset is in proper mstate format (see "Background Reading" section above).{p_end}

{p 8 12 2} 2.) {help stset} the data appropriately.{p_end}

{p 8 12 2} 3.) {help stcox} the data appropriately.{p_end}

{p 3}---------(our commands/help files step in here)---------{p_end}

{p 8 12 2} 4.) {helpb mstutil} the data.  This declares the data structure as multi-state duration for all other {cmd:mst} commands.{p_end}

{p 8 12 2} 5.) When covariates are present, use {helpb mstphtest} to check for proportional hazards violations and implement appropriate corrections.{p_end}

{p 9 8 2} <<repeat Steps 3-5 after implementing any PH corrections>>{p_end}

{p 6 12 2} 5.5.) Optional: For advanced users; use {helpb msttvc} to tell the other {cmd:mst} commands TVCs are present, if TVCs not declared with {cmd:stcox}.  
This must occur after {cmd:mstphtest}, or else {cmd:mstphtest} will throw an error.{p_end}

{p 8 12 2} 6.) When covariates are present, use {helpb mstcovar} to assign covariate values for the transition probability simulations.{p_end}

{p 8 12 2} 7.) Use {helpb mstsample} to generate transition probabilities.{p_end}


{pstd}
{helpb mstdraw} is a utility command.  It is not required in any way to successfully estimate the transition probabilities.  It has two abilities:{p_end}

{p 8 12 2} 1.) After you {helpb stcox} and {helpb mstutil} the data, it can tell you about the various transitions in your model.
If we inserted it above, it would be an optional Step 4.5.{p_end}

{p 8 12 2} 2.) It can provide a stacked transition probability plot after you run {helpb mstsample}, 
provided you save the results to the dataset.  Here, {helpb mstdraw} is an optional Step 7.5{p_end}


{marker updates}{...}
{title:Package Updates}

{pstd}In between official {it:Stata Journal} releases, you can find updates on GitHub:

{pmore}{browse "http://www.github.com/MetzgerSK/mstatecox"}{p_end}

{pstd}The GitHub repo's readme contains installation instructions.{p_end}


{marker cite}{...}
{title:Citation}

{pstd}Users interested in citing this package should list the following source:{p_end}

{pmore}Metzger, Shawna K., and Benjamin T. Jones.  2018.  "mstatecox: A Package for Simulating Transition Probabilities from Semiparametric Multistate Survival Models."  {it:Stata Journal} 18 (3): 533–563.{p_end}


{marker references}{...}
{title:References}

{pstd}Box-Steffensmeier, Janet M., and Bradford S. Jones.  2004.  {it:Event History Modeling: A Guide for Social Scientists}.  Cambridge: Cambridge University Press.{p_end}

{pstd}Box-Steffensmeier, Janet M., and Christopher J. W. Zorn.  2001.  "Duration Models and Proportional Hazards in Political Science."  {it:American Journal of Political Science} 45 (4): 972–988.{p_end} 
{pstd}Geskus, Ronald B.  2015.  {it:Data Analysis with Competing Risks and Intermediate States}.  Boca Raton, FL: Chapman and Hall/CRC.{p_end}

{pstd}Jin, Shuai, and Frederick J. Boehmke.  2017.  "Proper Specification of Nonproportional Hazards Corrections in Duration Models."  {it:Political Analysis} 25 (1): 138–144.{p_end}

{pstd}Jones, Benjamin T., and Shawna K. Metzger.  2018.  "Evaluating Conflict Dynamics: A Novel Empirical Approach to Stage Conceptions."  {it:Journal of Conflict Resolution} 62 (4): 819-847. {p_end}

{pstd}Licht, Amanda A.  2011.  "Change Comes with Time: Substantive Interpretation of Nonproportional Hazards in Event History Analysis."  {it:Political Analysis} 19 (2): 227–243.{p_end}
	
{pstd}Metzger, Shawna K., and Benjamin T. Jones.  2016.  "Surviving Phases: Introducing Multistate Survival Models."  
		{it:Political Analysis} 24 (4): 457-477.{p_end}
		
{pstd}Putter, Hein, Marta Fiocco, and Ronald B. Geskus.  2007.  "Tutorial in Biostatistics: Competing Risks and Multi-State Models."
{it: Statistics in Medicine} 26 (11): 2389–2430.{p_end}

{pstd}Singer, Judith D., and John B. Willett.  2003.  {it:Applied Longitudinal Data Analysis: Modeling Change and Event Occurrence}.  Oxford: Oxford University Press.{p_end}

{pstd}de Wreede, Liesbeth C., Marta Fiocco, and Hein Putter.  2010.  "The mstate Package for Estimation and Prediction in Non- and Semi-Parametric Multi-State and Competing Risks Models."  
	 {it:Computer Methods and Programs in Biomedicine} 99 (3): 261–274.{p_end}


{title:Contact}

{p 2} Any questions, feedback, or bug reports should be directed to:{p_end}

{p 4 4 2}
Shawna K. Metzger{break}
University at Buffalo{break}
shawna@shawnakmetzger.com
{p_end}

{p 4 4 2}
Benjamin T. Jones{break}
University of Mississippi{break}
btjones1@olemiss.edu
{p_end}


{p 0 0 0}
{bf:Last Updated} - 11DEC23
{p_end}
