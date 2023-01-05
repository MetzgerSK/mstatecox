// mstsample: simulate transition probabilities
// ** part of mstatecox package
// ** see "help mst" for general package details

*! Last edited: 01JUN22 [v3.331]
*! Last change: fixes NP estm (v3.331); TVC demeaning to further stabilize H0 estms (v3.3); incorporated frailty's value into msfit calculations, proper inclusion of offset() in demeaned models (v3.22); fixed clustered SE error when reestimating the demeaned models (v3.21); fixed the TVC computation (v3.2)
*! Contact: Shawna K. Metzger, shawna@shawnakmetzger.com

/* mstsample: The huge mega-wrapper.  
	// Input (required): 	starting stage, starting time, matrix containing covariate values + mstutil, stcox, stset.
	// Input (optional): 	ending time (otherwise, set to highest observed in dataset), number of subjects to run through the mix, 
							number of times to repeat, stubname for variables containing sim results, CI level,	whether t is measured 
							in gap time (aka clock reset), whether to forceably recode the outward transition hazards to 1 if there 
							are any values greater than 1 (i.e., the Batman1esque situation), generate variables for each individual 
							subject for every simulation draw (option requires stubname for path vars), whether the single-core output
							should be as verbose as the multi-core output, whether multi-core output should be as verbose as the single-core,
							whether the msfit matrix should be put into memory and kept, whether _simMstate() should post the stage results (vs. path),
							the slice trigger value (for processing); whether we're brute forcing fixed horizons; whether mstsample should override
							the datasig check when generating the Cox quants

	// Output: (potentially) variables containing
				(1) the t's for the simulation run
				(2) for every stage, the stage-occupation probabilities at t, averaged across all the simulations
				(3) for every stage, the lower and upper percentiles of all the simulation's stage-occ probs at t
				
				
	// NOTE: future extensions to command present (e.g., FIXEDHorz BForce DZone) - remove for SJ submission from valid option list.		
*/	

cap program drop mstsample
program define mstsample, eclass sortpreserve
    version 14.2
local noiYN = `c(noisily)'	// Did user specify qui?  (Must do here b/c if you query within the qui block, you'll get 0, every time.)

qui{
	syntax , SStage(integer) STime(integer)  [N(integer 10) SIMS(integer 1) TMax(integer 0) ///
											  GEN(string) CI(cilevel) GAP HAZOVerride ///
											  PATH(string) TERse VERbose MSFIT SLICEtrigger(integer 250000000) ///
											  SPEED DIR(string) SEYes ///
                                              DEM_debug]
                                              
        // Note: seyes = the coefficient SEs are relevant.  This is looking ahead to some 
        //               future potential functionality.  Specifying it now will do nothing,
        //               because the SEs aren't involved in the default trPr uncertainty calc.                                      
	
        // dem_debug: for the unit tests involving the demeaned Cox model
    
	** Check to make sure data have been mstutil'd
	if("`e(from)'"==""){
		noi di as err "You must run {bf:mstutil} before running {bf:mstsample}."
		exit 198
	}
	
	** Cannot specify both speed and path options.
	if("`path'"!="" & "`speed'"!=""){
		noi di as err "Cannot specify both {bf:path} and {bf:speed} as options."
		exit 198
	}
	
    ** If hazover not specified as option but scalar exists in eclass mem, wipe it out
    if("`hazoverride'"=="" & "`e(hazover)'"!=""){
        mata: st_numscalar("e(hazover)", J(0,0,.))
    }
    	// (return mem altered next - preserve any results in return list)
        tempname retPres
        _return hold `retPres'
        global temp_mstsampleNm `retPres'
        
	** If tmax not set, use maximum observed in dataset (increments of 1). **maybe change this to list, similar to tvec, in future  (condition applic for forward or fixedh)
	if("`tmax'"=="" | `tmax'==0){
		qui sum _t if(_d==1)
		local tmax = ceil(`r(max)')     // go up to next highest integer
	}
    
	tempname skm_b
	matrix `skm_b' = e(b)
    local namesB_orig: colfullnames `skm_b'
    if(colsof(`skm_b')!=0){
        // Toss any entries w/"o." -> are variables that got dropped from spec
        // (e.g., collinearity).  Can write the regex in this way because periods
        // aren't legal chars for Stata varnames, so no chance of accidentally
        // removing a 'real' variable.
        tempname nms
        mata: `nms' = tokens("`namesB_orig'")
        
        * throw colnames w/o dropped vars back to Stata
        mata: st_local("newNames", invtokens(`nms'[,selectindex(!regexm(`nms', "^o\."))]))  
        
        * subset stored covar matrix to non-dropped vars only
        mata: st_matrix("`skm_b'", st_matrix("`skm_b'")[,selectindex(!regexm(`nms', "^o\."))])    
        matrix colnames `skm_b' = `newNames'
        matrix rownames `skm_b' = "y1"
        mata: mata drop `nms'   // tidy
	}
    
    ** Make sure user didn't specify a non-parametric model
	** If fixed horizon specified, make sure the user understands what that means
	if("`fixedhorz'"!=""){
		noi di _n as ye 	" NOTE: " as gr "You have specified the {bf:fixedhorz} option.  Your simulations will start"
		noi di _c as gr		" at t = " as ye `tmax' as gr " with all subjects in Stage " as ye `sstage' 
		noi di	  as gr		" and then count {it:backward} to s = " as ye `stime' as gr "."
	}
	
	** Check to make sure that user didn't input a negative time.	
    ** (condition applic for forward or fixedh)
	if(`stime'<0){
		noi di as err "Starting time cannot be negative."
		tidy
        exit 451
	}
        
	** Check to make sure that user didn't input a starting time that's greater 
    ** than or equal to the max time in the dataset.  
    ** (condition applic for forward or fixedh)
	qui sum _t
	if(`stime'>=`r(max)'){		
		noi di as error "Starting time of `stime' is greater than or equal to largest time at which a failure occurs in dataset.  Pick a smaller starting time."
		tidy
        exit 125
	}
											
	** Check to make sure starting stage is actually in the dataset (i.e., is valid) 
    ** (condition applic for forward or fixedh, but do need to be smart about to/from)
	local origin `e(from)'
	local destin `e(to)'
	
	local openingSent = "S"
	local inOut = "exiting"
	
	if("`fixedhorz'"!=""){
		local origin `e(to)'
		local destin `e(from)'
	
		local openingSent = "With the {bf:fixedhorz} option, s"
		local inOut = "entering"
	}
	
	qui count if(`origin'==`sstage')
	if(`r(N)'==0){
		// if it's an absorbing state, helpfully point that out to the dear user
		qui count if(`destin'==`sstage')
		if(`r(N)'!=0){
			noi di as err "Stage `sstage' is an absorbing stage in your dataset.  `openingSent'tarting stage must have at least one `inOut' transition.  Try again."
			tidy
            exit 121
		}
		
		if("`fixedhorz'"!="")	local extra " for {bf:fixedhorz}"
		
		// otherwise, just tell them straight up.
		noi di as err "No observations exist in which `origin' = `sstage'`extra'.  Try again."
		tidy
        exit 121
	}
	
	** Ensure that tmax isn't less than starting time, or else this will also be 
    ** a boring simulation.	(condition applic for forward or fixedh)
	*** NOTE: if you hit this error message, given that you've already checked 
    *** that sTime<max(_t), it means that the user punched in something stupid.
	if(`stime'>=`tmax'){
		noi di as error "Starting time of `stime' is greater than or equal to time range for the simulations (=`tmax').  Either pick a smaller starting time ({bf:stime()}) or choose a larger endpoint for the simulated time range ({bf:tmax()})."
		tidy
        exit 125
	}
	
	** Check if there's actually a failure in this interval.  
    ** (condition applic for forward or fixedh)  
	qui count if(_d==1 & _t>`stime' & _t<=`tmax')
	if(r(N)==0){
		noi di as err "There are no observed transitions in the interval (`stime',`tmax'].  At least one is required to compute (sensical) Cox transition probabilities."
		tidy
        exit 2000
	}
	
	** check for PH violation correction - indicated by presence of TVC covars 
    ** in matrix.  If no PH corrections, TVC will evaluate to missing.
	local tvc = colnumb(`skm_b', "tvc:") 
	
	
	** check to make sure everything in the e(b) matrix has a value in the 
    ** mstcovarVal matrix		
    ** (condition applic for forward or fixedh)
    ** 
	** The only time you don't need a covariate matrix is if the model's non-parametric.  Check this.
	{
		// use skm_b to see how many estimates, and if estimates exist, check for the mstcovarVal matrix
		cap confirm matrix mstcovarVals
			local mstcovar = _rc
		
		local origName = "`xvals'"
			
		if(colsof(`skm_b')!=0 & `mstcovar'!=0){
			noi di as err "{bf:stcox} has covariates, but no covariate values in memory.  Use {bf:mstcovar} to set your covariate values and try again."
			tidy
            exit 198
		}	
		
		** Then, make sure that there's a value for every covariate
		local namesB: colnames `skm_b'
			local namesB: list uniq namesB	// in case there are TVCs.  Gets rid of extra.
			local colsofB: list sizeof namesB
		
		foreach x of local namesB{
			// Pull the column number where that covariate lives.
			// If no column number, kick error.
			if(colnumb(mstcovarVals,"`x'")==.){												
				noi di as err "Need values for every model covariate.  No value for " as ye "`x' " as re "in {bf:mstcovar}'s matrix."
				tidy
                exit 503
			}
		}
		
		** Finally finally, make sure all the values are actually *values* and not set to missing.
		mata: st_local("matMiss", strofreal(missing(st_matrix("mstcovarVals"))))
		
		if("`matMiss'"!="0"){
			noi di as err "xvalue matrix has a missing value.  Matrix must have numerical values in all cells.  Set the values using {bf:mstcovar} and try again."
			tidy
            exit 198
		}
		
		// if all that's done, then just make xvals point to mstcovars
		local xvals mstcovarVals

	} // convenience collapse bracket end

	** number of subjects has to be 1, at minimum  
    ** (condition applic for forward or fixedh)
	if(`n'<=0){
		noi di as err "Must simulate at least one subject moving through process; {bf:n()} must be greater than 0.  Try again."
		tidy
        exit 125
	}
	
	** number of simulations has to be 1, at minimum 
    ** (condition applic for forward or fixedh)
	if(`sims'<=0){
		noi di as err `"Must "run" the process at least once; {bf:sims()} must be greater than 0.  Try again."'
		tidy
        exit 125
	}
	
	** If sliceTrigger==TRUE *and* the user's specified gen(), make sure you have 
    ** a place to save the stage output from each sim draw (11JUL17)   
	// Also for figuring out how you're going to be processing things.														(condition applic for forward or fixedh)
	local p = `n' * (`tmax'-`stime'+1)
	local overall = `p' * `sims'
	
	if(`overall'>`slicetrigger' & "`gen'"!="" & "`speed'"==""){
		// Create directory name for JIC export.
        jicFileNm
        local folderName = subinstr("`r(fileNm)'", "path_", "", .)
		
		// See if pwd is writable
		cap mkdir "`folderName'"
		if(_rc!=0){	// if Stata can't make the directory, figure out why.

			// ensure the directory's not already around
			local temp = "`c(pwd)'"
			cap cd "`folderName'"
			
			local escape = 0
			
			if(_rc==0){				// -- The directory already exists in PWD with the same name, which is why the initial _rc!=0.  Proceed as if init _rc==0.
				cd "`temp'"
				local stageSliceDir = "`c(pwd)'`c(dirsep)'`folderName'"
			}
			else{
				if("`dir'"==""){	// -- Directory doesn't exist in PWD, and user didn't enter anything for directory.
				
					noi di as err 	" You have specified the {bf:gen} option, but your potential stage dataset will have more than `slicetrigger' observations."
					noi di as err 	" Adding this many observations may cause an error, because Stata cannot tell how much memory your computer has free." 
					noi di as err	" Stata cannot save the stage output to a different folder, because it does not have write permissions for: "
					noi di as ye	"    `c(pwd)'" 
					noi di as err 	" Please change your working directory to one where Stata has write permission, using either {bf:cd} or {bf:mstsample}'s {bf:dir()} option, then try again."
					
                    tidy
					exit 608
				}
				else{				// -- Directory doesn't exist in PWD, *but* the user's given you an alternative directory path.  See if you can make the folder there.
					cap mkdir "`dir'`folderName'"
					
					if(_rc!=0){		// -- Can't make the folder in the alternative directory
						// ensure new folder doesn't exist first
						local temp = "`c(pwd)'"
						cap cd "`folderName'"
						
						if(_rc==0){			// -- The directory already exists in dir with the same name, which is why the initial _rc!=0.  Proceed as if init _rc==0.
							cd "`temp'"
							local stageSliceDir = "`dir'`folderName'"
						}
						else{				// -- Directory doesn't exist in dir, either.  Tell user Stata can't find any place to create the folder.
							noi di as err 	" You have specified the {bf:gen} option, but your potential stage dataset will have more than `slicetrigger' observations."
							noi di as err 	" Adding this many observations may cause an error, because Stata cannot tell how much memory your computer has free." 
							noi di as err	" Stata cannot save the stage output to a different folder, because it does not have write permissions for: "
							noi di as ye	"    `c(pwd)'" 
							noi di as ye	"	 `dir'"
							noi di as err 	" Please change your working directory to one where Stata has write permission, using either {bf:cd} or {bf:mstsample}'s {bf:dir()} option, then try again."
						
                            tidy
							exit 608
						}
					}
					else	local stageSliceDir = "`dir'`c(dirsep)'`folderName'"
				}	
			}
		}
		else	local stageSliceDir = "`c(pwd)'`c(dirsep)'`folderName'"
				
		// Let the user know what's going on
		noi di _n as ye 	" NOTE: " as gr "You have specified the {bf:gen} option, but your potential stage dataset will have more than `slicetrigger' observations."
		noi di as gr 		" Adding this many observations may cause an error, because Stata cannot tell how much memory your computer has free." 
		noi di as gr		" Instead, each simulation draw's stage output will be saved as a separate dataset (= `sims' datasets, total) in the following directory:"
		noi di as ye		"    `stageSliceDir'"
	}
	
	** Clock is forward, unless user specifies "gap"   
    ** (condition applic for forward or fixedh)
	if("`gap'"==""){
		local clock = "forward"
	}
	else{
		local clock = "gap"
	}

	** If both path and gen specified, the stubs have to be different   
    ** (condition applic for forward or fixedh)
	if("`path'"=="`gen'" & "`gen'"!=""){
		noi di as err "{bf:gen()} specified to save simulation output as variables and {bf:path()} specified to save each individual subject's path."
		noi di as err "The two options cannot have the same stubname for variable generation.  Please pick a different stubname for each option and try again."
		tidy
        exit 110
	}
	
	// The user can't specify both terse and verbose.  If they do, go with 
    // default, given number of cores.   
    ** (condition applic for forward or fixedh)
	if("`terse'"!="" & "`verbose'"!=""){
		local plural = "s"
		if(`c(processors)'==1){
			local answer = "verbose"
			local plural = ""
		}
		else	local answer = "tense"
		
		noi di as gr "Both {bf:verbose} and {bf:tense} specified.  Setting sim progress output to " as ye "`answer'" as gr ", the default for " as ye `c(processors)' as gr " processor`plural'."
	
		local verbose = ""
		local terse = ""
	}
	
	** If e(sample) not in memory, then it's likely the user's loaded an 
    ** already-estimated stcox model.  Set e(sample) manually.   
    ** (condition applic for forward or fixedh)
	// !! Needs tweaking (not yet consistently functional)
	estimates esample
	
	if("`r(who)'"=="zero'd"){
		noi di as gr "No e(sample) detected in memory, which occurs when you load model results using either {help estimates_store:estimates restore} or {help estimates_save:estimates use}."
		noi di as gr "Setting e(sample) based on observations with " as ye "_st==1 " as gr " and non-missing values of " as ye "`namesB'" " `e(trans)'" as gr "."
		noi di as gr "If you believe e(sample) should exist, kill {bf:mstsample} and check your data."
		
		estimates esample: `namesB' `e(trans)' if(_st==1)
		
		// But then, check to make sure the number of e(sample) observations gels with the model N.
		count if(e(sample)==1)
		if(`r(N)'!=`e(N)'){
			noi di _n as red "New e(sample)'s N (=" as ye `r(N)' as re ") does not match {bf:stcox}'s N (=" as ye `e(N)' as red ")."
			noi di as red "{bf:mstsample} requires the exact same set of observations as {bf:stcox}, or else {bf:mstsample}'s hazard calculations will be wrong."
			noi di as red "Check your dataset and try again."
			noi di ""
			tidy
            exit 459
		}
	}
	

	
	** If user's specified both gen and speed, remind them that only the results 
    ** will be saving (not also the indv sim pulls)
	if("`speed'"!=""){
		if("`gen'"!=""){
			local bit1 = "Both {bf:gen} and "
			local bit2 = "Only results variables will be generated.  "
		}
		else{
			local bit1 = ""
			local bit2 = ""
		}
		noi di as gr "`bit1'{bf:speed} specified.  `bit2'Also ignoring {bf:slicetrigger}."
		local slicetrigger = .
	}
	else{
		** If user's specified pathspeed but not speed, tell them you'll be ignoring the option.
		if("`pathspeed'"!="")	noi di as gr "{bf:pathspeed} option only relevant when {bf:speed} is specified.  Ignoring."
		local pathspeed = ""
	}
	*************************************************
	* // The huge block of macro pulls
	local from `e(from)'
	local to `e(to)'
	local trans `e(trans)'
		glevelsof `trans' if(e(sample)==1), local(transNos)
	local nTrans `e(nTrans)'
	local maxStage `e(maxStgNo)'
	local nSubjs `n'
	local tvcHack = "`e(msttvc)'"
	local datSig = "`e(datasignature)'" // !! DANGER. This is the equivalent to taking off the safety.
	*************************************************
	
	*---------------------------------------------------------------------------
	// Let the games begin.  
    // All of this is identical for forward vs. fixedh until *right* before the sim section starts.
	tempvar sorter
	gen `sorter' = _n
	sort _t `from' `to' `sorter'
	
**** // Zeroth, fill to the end. // ****
	local tMax_inputted = `tmax'
		local tmax = `tmax' + 1	// jic of boundary problems.
	
	
**** // First, compute all the hazards. // ****
	* (moved message to after PH-TVC if/else)
	{
	
	// To start: get number of unique from-to pairs
	tempvar thePairings
	gegen `thePairings' = group(`from' `to')
	qui glevelsof `thePairings', local(fromToPairsList)
		local fromToPairs: list sizeof fromToPairsList
		
	* BASELINE HAZ, HAZ RAT
	tempvar H0 hr

	// In case reestimating's needed.  Just do this once, to reduce redundancy. 
	if("`e(method)'"=="breslow")		local tieType = "breslow"
	else if("`e(method)'"=="efron")		local tieType = "efron"
	else if("`e(method)'"=="partial")	local tieType = "exactp"
	else if("`e(method)'"=="marginal")	local tieType = "exactm"
	
    // Get frailty value
    if("`e(shared)'"!=""){
        local frVal = "$mstcovar_lFr"
        local frNote = ""
        if("`frVal'"==""){
            local frVal = 0	        // if no log-frailty given, set to 0
            local frNote "> No log-frailty value set using {bf:mstcovar}.  Value held at 0 by {bf:mstsample} (implies frailty = 1)."	// populate the end-of-estm FYI message
        }
    }
    // If no frailty, frVal=0
    else    local frVal = 0   
    
    // Get offset value
    if("`e(offset)'"!=""){
        local offVal = "$mstcovar_offset"
        local offNote = ""
        if("`offVal'"==""){
            local offVal = 0	// if no offset given, set to 0
            local offNote "> No offset value set using {bf:mstcovar}.  Value held at 0 by {bf:mstsample}."	// populate the end-of-estm FYI message
        }
    }    
    // If no offset value set, offVal=0
    else    local offVal = 0
    
    // Files to save the results
    tempfile basechaz   // UoA = _t-trans pairings
    tempfile hazrat     // UoA = _t-from-to triples (b/c of possibility of trSp effects)
        
	// NON-PARAMETRIC 
	if(colsof(`skm_b')==0){
        // Shift to straight N-A from stcox (will have issues incorporating 
        // frail +/or offset, otherwise)
        predict double `H0', basechaz
        
            // [ST] v17, p. 152: predict..., basechaz after stcox will produce 
            // Nelson-Aalen estimate of H(t) "when [the model is] estimated 
            // with no covariates".  (*And* the tie correction's Breslow -> KEY.)

        // Save baseline haz
        preserve
            drop if `H0'==. 
            tempvar flagFirst anyFail
            bysort `trans' _t: egen `anyFail' = max(_d)
            bysort `trans' _t (`sorter'): gen `flagFirst' = _n
            keep if _d==1 | (`anyFail'==0 & `flagFirst'==1)
            gduplicates drop _t `trans', force
            keep _t `trans' `H0' `anyFail'
            save `basechaz', replace
        restore
	}
	// SEMI-PARAMETRIC
	else{
        // manual sample flag (JIC)
		tempvar flag19
		gen `flag19' = e(sample)
        
        // If there are collapsed transitions, detect any gaps in t coverage.
        // (Won't matter for NP b/c you already manually add h(t) within strata
        // to get H(t).)
        // OBJECTIVE: find whether any gaps exist.  If so, split on fails within strata.
        local chk_tGaps = ""    // "": no gaps to worry about (or no collapsed trs, making the edge case irrelevant); != "" list of macros, storing gaps-in-t value for from-to pair

        if(`nTrans'!=`fromToPairs'){
            mstdraw, tr post
            
            tempname stacked freqs
            mata: `stacked' = vec(st_matrix("r(trMat)"))
            mata: `stacked' = sort(`stacked'[selectindex(`stacked':!=.)],1) // to save time later
            mata: `freqs' = mm_freq(`stacked')
            mata: st_local("temp_noCollTrs", strofreal(allof(`freqs',1)))
            
            // We have collapsed trs--therefore, there's more to be done
            if(`temp_noCollTrs'!=1){
                mata: st_local("chk_collTrs", invtokens(strofreal(uniqrows(`stacked')[selectindex(`freqs':!=1)])))
                
                // Keep running list of troublesome Ts for later fixing
                tempname troubleTs
                local firstTimeThrough=1
                
                // For the collapsed trs
                foreach trVal of local chk_collTrs{
                    tempname allTs allTs_uniq trVal_Ts trVal_Ts_uniq
                    putmata `allTs' = _t if(`trans'==`trVal'), replace
                    mata: st_local("`allTs_uniq'", strofreal(mm_nunique(`allTs')))
                    
                    // Get list of pairings in this transition, see if the # of uniq
                    // ts for the pairing matches the transition's # of uniq ts.  
                    // (Throw to Mata, to avoid running into tab's limit.)  If no
                    // match, gap exists.
                    tempname trVal_pairLst
                    glevelsof `thePairings' if(`trans'==`trVal'), local(`trVal_pairLst')
                    foreach tP of local `trVal_pairLst'{
                        putmata `trVal_Ts' = _t if(`thePairings'==`tP'), replace
                        mata: st_local("`trVal_Ts_uniq'", strofreal(mm_nunique(`trVal_Ts')))

                        * see if the locals match
                        if(``allTs_uniq''!=``trVal_Ts_uniq''){
                            local chk_tGaps = "`chk_tGaps' `trVal'"   // Add to list as a coll tr w/time gap issues
                            local chk_tGaps: list uniq chk_tGaps
                            
                            // Store the gaps (check later to see whether splitting's
                            // fixed the issue, and if not, add those obsvs)
                            tempname tr`trVal'_tP`tP'
                            mata: `tr`trVal'_tP`tP'' = ms_setdiff(uniqrows(`allTs'), uniqrows(`trVal_Ts'))
                            mata: st_local("numGps", strofreal(rows(`tr`trVal'_tP`tP'')))
                            
                            if(`firstTimeThrough'==1){
                               mata: `troubleTs' =  `tr`trVal'_tP`tP''
                               local firstTimeThrough = 0
                            }
                            else{
                                mata: `troubleTs' =  `troubleTs' \ `tr`trVal'_tP`tP''
                            }
                            
                            // Start filling.  The key: do EVERYTHING you possibly
                            // can to preserve precision for _t, which why the code's
                            // so roundabout.  (This still needs to be here, even
                            // with the less kludge-y msfit tweak.)
                            tempvar tr`trVal'_tP`tP'Var
                            getmata `tr`trVal'_tP`tP'Var' = `tr`trVal'_tP`tP'', double force
                            
                                * clone observations
                                ** find an obsv corresp to this `tP' first
                                tempvar newExpdFlag sumNewExpdFlag
                                sum `sorter' if(`thePairings'==`tP')
                                expand `=`numGps'+1' if(`sorter'==`r(min)'), gen(`newExpdFlag') // +1 for original obsv.
                                
                                ** flag all these as not being included in esamp
                                replace `flag19' = 0 if(`newExpdFlag'==1)
                                
                                ** start filling t vals
                                gen `sumNewExpdFlag' = sum(`newExpdFlag') if(`newExpdFlag'==1)
                                tempname tGapVal
                                forvalues nG = 1/`numGps'{
                                    scalar `tGapVal' = `tr`trVal'_tP`tP'Var' in `nG'
                                    replace _t = `tGapVal' if(`sumNewExpdFlag'==`nG')
                                }
                        }
                    }
                }
            }
        }
		
        // Pull info on noadj, since no other way to recover
        tokenize "`e(cmdline)'", parse(",")
        local noadj  = cond(regexm("`3'", "noadj[a-z]*"), "noadjust", "")
        
		// Pull any info on frailty term
		if("`e(shared)'"!=""){
            // * Do it the fast way via offset
            if("`seyes'"==""){
                tempvar reestOffset
                predict double `reestOffset', effects                 
                    // In case there's already an offset variable
                    if("`e(offset)'"!="")      replace `reestOffset' = `reestOffset' + `e(offset)'
                
                * frailty/offset opts
                local reest_fr = ""
                local reest_off = "`reestOffset'"
                * populate shortcut macro
                local reest_shtct = "matfrom(`skm_b') iter(0) norefine"
            }
            // * Do it the long way and reestimate
            else{
            	* frailty/offset opts
                local reest_fr = "shared(`e(shared)') forceshared"	// in case this is start/stop
                local reest_off = "`e(offset)'"
                * populate the shortcut macro with nothing
                local reest_shtct = ""
            }
			local reest_tr = ""	// no strata currently possible if frailty term present.

            // If we're doing it the long way, give user an apology message
            if("`seyes'"!=""){
                noi di _n as ye "> NOTE: " as gr ///
                  "Your model has a frailty term and you have specified the {bf:seyes} option.  {bf:mstsample} reestimates your model using "
                noi di as gr _col(9) /// 
                  "demeaned covariates to obtain more stable estimates of the baseline cumulative hazard.  It cannot use its usual "
                noi di as gr _col(9)  ///   
                  "quick shortcut to do this when a frailty term and {bf:seyes} are both present--it has to reestimate your entire model."
                noi di as gr _col(9)  ///
                  "As a result, the prep stage before computing the hazard may take noticeably longer than it would otherwise."
            }
		}
		else{
			local reest_fr = ""
			local reest_tr = "strata(`trans')"
			local frVal = 0	// nothing to add, if this isn't a frailty model
			local reest_shtct = "matfrom(`skm_b') iter(0) norefine"
		}
		
		// Get list of TICs for demeaning (needed regardless of whether TVCs present)
		if(`tvc'==.)	matrix coleq `skm_b' = "main"		// if there are no TVCs, main eq won't have a name.  Fix that.
		tempname skm_tic
		matrix `skm_tic' = `skm_b'[1,"main:"]
		local namesTIC: colnames `skm_tic'
			
		// Demean TICs					
		local ticDemean = ""
		foreach x of local namesTIC{
			tempvar `x'Dem
			covarDemean mstcovarVals_means `x' ``x'Dem' `thePairings' "`namesB'" "dem"
			local ticDemean = "`ticDemean' ``x'Dem'"
		}
			
		// REESTMATE
        tempname origCox
        _estimates hold `origCox', restore copy
        
		if(`tvc'==. & "`chk_tGaps'"==""){
			** REESTIMATE WITH DEMEANED		- 20FEB19
			stcox `ticDemean'  if(`flag19'==1), ///
						`tieType' `reest_tr' `reest_fr' ///
						offset(`reest_off') ///
						vce(`e(vce)' `e(clustvar)') `noadj' ///
						`reest_shtct'		// to speed things along
			
            * (save to Stata memory, if running unit tests)
            if("`dem_debug'"!="")   est store mst_demCox
                
			* BASELINE HAZARD 
			qui predict double `H0', basechaz		// !! - 20FEB19 modification.  Computing via the cumulative hazard now.

                * Save (eventually, merge this on _t-TRANSITION)
                preserve
                    drop if `H0'==.
                    tempvar flagFirst anyFail
                    bysort `trans' _t: egen `anyFail' = max(_d)
                    bysort `trans' _t (`sorter'): gen `flagFirst' = _n
                    keep if _d==1 | (`anyFail'==0 & `flagFirst'==1)
                    gduplicates drop _t `trans', force
                    keep _t `trans' `H0' `anyFail'
                    save `basechaz', replace
                restore	
                
            * HAZARD RATIO
            cap drop `xbTIV'
            tempvar xbTIV
                // Fill TICs w/mstcovar-set values
                foreach x of local namesTIC{
                    covarFill `xvals' mstcovarVals_means `x' `thePairings' "`namesB'"
                }
            matrix sco double `xbTIV' = `skm_b', eq("main") 

            * combine w/frailty and/or offset (if present) into the HR.
            gen double `hr' = exp(`xbTIV'+`frVal'+`offVal')
            
                * Save (eventually, merge this on _t-FROM-TO)
                preserve
                    tempvar flagFirst2 anyFail2 
                    bysort `from' `to' _t: egen `anyFail2' = max(_d)    
                    bysort `from' `to' _t (`sorter'): gen `flagFirst2' = _n
                    keep if _d==1 | (`anyFail2'==0 & `flagFirst2'==1) `=cond("`chk_tGaps'"=="", "", "| `newExpdFlag'==1")'
                    gduplicates drop _t `from' `to', force
                    keep _t _d `trans' `from' `to' `hr' `thePairings' `sorter' `anyFail2'
                    save `hazrat', replace
                restore	
		}
		else{		// we do have TVCs, and need to quick respecify the model to estimate the baseline quants.
                    // (Will also now enter this segment if `chk_tGaps' isn't missing.  Have added stmts to
                    // make `tvc'==. & "`chk_tGaps'"!="" behave like `tvc'==. & "`chk_tGaps'"=="")
			if(`tvc'!=.) noi di _n as gr "TVCs detected. Adjusting calculations."

			preserve 
				** NOTICE: you haven't stsplit.  If there isn't an ID set, generate a fake one.
				local stID_ch: char _dta[st_id]  
                
                tempvar timeTemp time0Temp
                clonevar `timeTemp' = _t
                clonevar `time0Temp' = _t0
                
				if("`stID_ch'"==""){
					tempvar stID
					gen `stID' = _n

					local st_d:     char _dta[st_bd]

                    local st_dNums:	char _dta[st_ev]
                    if("`st_dNums'"!="")	local st_dNums = "==`st_dNums'"

					streset, id(`stID') failure(`st_d'`st_dNums')  
                    
                    // Re-fill with correct _t, _t0 values (if you have to add vars
                    // because of gaps, there's a chance the streset won't produce
                    // the correct vals)
                    replace _t = `timeTemp'   `=cond("`chk_tGaps'"=="", "", "if(`newExpdFlag'==1)")' 
                    replace _t0 = `time0Temp' `=cond("`chk_tGaps'"=="", "", "if(`newExpdFlag'==1)")' 
                }

				stsplit, at(failures) strata(`trans')  // `thePairings' won't work the way you intend, so has to be `trans'
               
                // If this is a chk_tGaps situation, split again on the affected
                // failure times.
                if("`chk_tGaps'"!=""){    
                    mata: st_local("allTs_ov_uniq", ///
                                   invtokens(strofreal(mm_unique(`troubleTs')'))) 

                    tempvar splitTemp
                    stsplit `splitTemp', at(`allTs_ov_uniq')
                    drop `splitTemp'
                }
  
                if(`tvc'!=.){
                    // generate tempvars for all the TVC vars.
                    tempname skm_tvc
                    matrix `skm_tvc' = `skm_b'[1,"tvc:"]
                    local namesTVC: colnames `skm_tvc'
                    
                    local tvcStrDemean = ""
                    foreach v of local namesTVC{
                        ** demean the TVCs (MAY21)
                        if(regexm("`namesTIC' ", "`v' ")==0){ // Ensure this TVC isn't in the TIC list (is already demeaned, if so).
                            tempvar `v'Dem
                            covarDemean mstcovarVals_means `v' ``v'Dem' `thePairings' "`namesB'" "dem"	
                        }

                        ** generate the temp names for interacts using demeaned
                        tempvar `v'TVC
                        
                        gen double ``v'TVC' = ``v'Dem' * `e(texp)'
                        local tvcStrDemean = "`tvcStrDemean' ``v'TVC'"
                    }
                    
                    // Reestimate  
                    local texp = "`e(texp)'"  // needed for next segment's xb calcs
				}

				stcox `ticDemean' `tvcStrDemean' if(`flag19'==1), ///
						`tieType' `reest_tr' `reest_fr' ///
						offset(`reest_off') ///
						vce(`e(vce)' `e(clustvar)') `noadj' ///
						`reest_shtct' // *should* be fine, since TICs and TVCs will be in same order as the skm_b matrix
				
                * (save to Stata memory, if running unit tests)
                if("`dem_debug'"!="")   est store mst_demCox
                
                // You're here b/c of the odd edge case -> calc's straightforward 
                if(`tvc'==.){
                    * BASELINE HAZARD 
                    qui predict double `H0', basechaz		// !! - 20FEB19 modification.  Computing via the cumulative hazard now.

                    // Override _t for the eventual remerge
                    replace _t = `timeTemp'  `=cond("`chk_tGaps'"=="", "", "if(`newExpdFlag'==1)")' 
                    
                    // Also need to do the HR here, for the same reason as the
                    // pure TVC case.
                    foreach x of local namesTIC{
                        covarFill `xvals' mstcovarVals_means `x' `thePairings' "`namesB'"
                    }
                    
                    // Gen linear combo
                    * TIC 
                    cap drop `xbTIV'
                    tempvar xbTIV
                    matrix sco double `xbTIV' = `skm_b', eq("main") 
                    
                    * combine w/frailty and/or offset (if present) into the HR.
                    gen double `hr' = exp(`xbTIV'+`frVal'+`offVal')
                    
                }
                // You're here b/c of TVCs.
                else{
                    // Tidy
                    matrix drop `skm_tvc' 
                
                    * BASELINE CHAZ, via hazard components	
                    tempvar basehc
                    predict double `basehc', basehc

            *********************************************************************************************************************
                  // Need to do linear combo for mstcovar values  
                  // (and doing it here to make life easier, in the longer run.)
                    
                    // Override _t for the eventual remerge
                    replace _t = `timeTemp' `=cond("`chk_tGaps'"=="", "", "if(`newExpdFlag'==1)")' 
                    
                    // Fill TIC first (and since demeaned model is in memory, means 
                    // you have to fill in the demeaned vars for the prediction.)
                    foreach x of local namesTIC{
                        covarFill `xvals' mstcovarVals_means `x' `thePairings' "`namesB'"
                    }
                    
                    // Fill any TVCs not in TIC list next  
                    foreach v of local namesTVC{
                        // Ensure this TVC isn't in the TIC list.
                        if(regexm("`namesTIC' ", "`v' ")==0){
                            covarFill `xvals' mstcovarVals_means `v' `thePairings' "`namesB'" 
                        }
                    }
                        
                    // Gen linear combo
                    * TIC 
                    cap drop `xbTIV'
                    tempvar xbTIV
                    matrix sco double `xbTIV' = `skm_b', eq("main") 

                    * TVC gen here.
                    cap drop `xbTVC'
                    tempvar xbTVC
                    matrix sco double `xbTVC' = `skm_b', eq("tvc") 
                        // then, add in the t bit, which is equiv to multiplying the 
                        // TVC's pseudo-linear combo times time's functional form
                        replace `xbTVC' = `xbTVC' * `texp'
                    
                    gcollapse (mean) `basehc' `xbTIV' `xbTVC' `trans' `thePairings' (max) _d, by(_t `from' `to')
                    
                    // Get the final prediction for H0.
                    tempvar pieces H

                    gen double `pieces' = 1-(1-`basehc')^exp(`xbTIV'+`xbTVC'+`frVal'+`offVal') 
                    bysort `from' `to' (_t): gen double `H' = sum(`pieces')                               
                }
                // tempfile stuff
                if("`chk_tGaps'"==""){                   
                    keep _t `from' `to' `trans' `H' `thePairings' _d
                    drop if `H'==.
                    tempvar flagFirst anyFail 
                    gen `sorter' = _n
                    bysort `from' `to' _t: egen `anyFail' = max(_d)
                    bysort `from' `to' _t (`sorter'): gen `flagFirst' = _n
                    keep if _d==1 | (`anyFail'==0 & `flagFirst'==1)
                    gduplicates drop _t `from' `to', force       
                    save `hazrat', replace	
                }
                else{

                    char _dta[st_id] "`stID_ch'"    // setting ID to prev
                    
                    if(`tvc'==.)    local varlist `H0' `hr' `sorter'
                    else            local varlist `H'
                    
                    keep _t _d `from' `to' `trans' `thePairings' `varlist'
                    
                    // Will need to do a few extra steps, so save a temp file
                    tempfile stuff
                    save `stuff'
                }

			restore		

            // If it's the odd edge case, need to take extra step to get H0 in 
            // expected shape
            if("`chk_tGaps'"!=""){
                preserve
                    // H0
                    use `stuff', clear
                    local var = cond(`tvc'==., "`H0'", "`H'")
                    drop if `var'==.
                    if(`tvc'!=.)    gen `sorter' = _n
                    tempvar flagFirst anyFail
                    bysort `trans' _t: egen `anyFail' = max(_d)
                    bysort `trans' _t (`sorter'): gen `flagFirst' = _n
                    keep if _d==1 | (`anyFail'==0 & `flagFirst'==1)
                    gduplicates drop _t `trans', force
                    drop `=cond(`tvc'==.,"`hr'", "")' `from' `to'
                    save `basechaz', replace
                    
                    // HR
                    use `stuff', clear
                    gduplicates drop _t `from' `to', force
                    cap drop `H0'
                    save `hazrat', replace
                restore
            }

			// Reset the stset to the original thing (i.e., without the id() from 
            // stsplit, if there was no ID to start with)
            reset_stset, id(`stID_ch')

		}
        _estimates unhold `origCox'
        cap drop `flag19'
	}
	
	noi di _n as gr "Please wait.  Computing hazards" _c		// display message
	
    // Bring back in the merged datasets to get our unique list
    preserve
        // HAZARD RATIO (UoA: _t-from-to)
        * SEMI-PARAMETRIC
        if(colsof(`skm_b')!=0)  use `hazrat', clear
        * NON-PARAMETRIC
        else{
            gduplicates drop _t `from' `to', force
            gen double `hr' = exp(`frVal' + `offVal') // if you ever allow different offset values for different transitions, will need to revisit this decision (here and elsewhere)
        }
        
        // BASELINE HAZARD
        if(`tvc'==. | colsof(`skm_b')==0){  // (tvc==. for SP w/o TVCs AND for NP; leaving the redundant conditional to make clear for future self)
            * (Nothing to merge for TVC case b/c already generated H earlier.)
            describe * using `basechaz'
            local mrgSize = `r(N)'

            tempvar merge
            if(`mrgSize' < 100000)	merge _t `trans' using `basechaz', sort uniqusing nokeep _merge(`merge') keep(`H0' `anyFail')
			else					join * , from(`basechaz') by(_t `trans') keep(1 3) generate(`merge') keep(`H0' `anyFail')		// on the off chance this helps save time       

            // Fill
            fillForward, t(_t) f(`anyFail') qoi(`H0') tr(`trans') id(`sorter')
            
            drop `anyFail'
        }
        
        // FINAL H
        tempvar Haz
        if(`tvc'==. | colsof(`skm_b')==0){
            gen double `Haz' = `H0' * `hr'
        }
        else{		
            gen double `Haz' = `H'		
            drop `H'		
        }

        // Toss anything with a larger failure time than tmax (to help with memory)
		drop if(_t>`tmax')

		// OK, at this point: rename and you're done.
        tempvar refT refTrans refFrom refTo refFrTo refHaz
		rename _t 				`refT'
		rename `trans' 			`refTrans'
		rename `from'			`refFrom'
		rename `to'				`refTo'
		rename `thePairings'	`refFrTo'
		rename `Haz'			`refHaz'
		
		keep `refT' `refTrans' `refFrom' `refTo' `refFrTo' `refHaz'

		drop if `refT'==.
        
		// For every unique from-to pairing in the dataset, make sure there's a 
        // stime observation where surv = 1
		tempvar flagT34 firstInP
		bysort `refFrom' `refTo' (`refT'): gen `firstInP' = _n==1	// notice: is giving you a t=0 observation for all transitions. (Important for differencing purposes.)
		expand 2 if(`firstInP'==1), gen(`flagT34')
		replace `refHaz' = 0 if(`flagT34'==1)
		replace `refT' = 0 if(`flagT34'==1)	// this needs to be zero, because it's still calculating the full msfit matrix for **all** unique failures, not just the range we've inputted.

		drop `firstInP'
		drop `flagT34'
		
		sort `refTrans' `refFrom' `refTo' `refT'
		
        tempfile msfit2
        stset, clear
		save `msfit2', replace
		local mrgSize = `c(N)'
    restore

	noi di as gr "." _c			// display message

	// Second, generate the holder variables.  **NOTE: if gen's on at the end, keep them.
	* These will have one row for every simulation-time pairing.
	local keepHolders = 1
	if("`gen'"=="")		local keepHolders = 0
	
	local tPoints = (floor(`tmax') - floor(`stime') + 1)		// if you eventually relax the unit increment part, this will need modifying  * ceil/floor added on 24NOV17

	
	if(`keepHolders'==1){			// if the user wants to save things, then... 
		foreach stub in _t Nm _stage	{
			local errMsg = "`gen'`stub'"

			cap confirm v `gen'`stub'
			if(_rc==0 & `keepHolders'==1)	continue, break
				
			
			if("`stub'"=="_t"){		// for the aggregate, "final" results
				local errMsg = "`gen'_Rslt`stub'"
				cap confirm v `gen'_Rslt`stub'
				if(_rc==0)	continue, break
			}
			else if("`stub'"=="Nm"){
				cap confirm v `gen'`stub'
				if(_rc==0)	continue, break
			}
			else{
				forvalues s = 1/`maxStage'{
					local errMsg = "`gen'`stub'`s'"
					local esc = 0
					
					// create the var for each individual sim result
					cap confirm v `gen'`stub'`s'
					if(_rc==0)	{
						local esc = 1
						continue, break
					}
					
					// but then also create the vars for the "final" results--mean, upper, lower
					foreach sstb in _m _ub _lb{
						local errMsg = "`gen'_Rslt`stub'`sstb'"
						cap confirm v `gen'_Rslt`stub'`s'`sstb'
						
						if(_rc==0)	{
							local esc = 1
							continue, break
						}
					}
					if(`esc'==1)	continue, break
					
				}
				if(`esc'==1)	continue, break
			}
		}
	}
	
	// Or maybe just leave this loop in here for all the naming of things, to 
    // ensure there's no name conflict before the simulations.
	if(_rc==0 & `keepHolders'==1){	// kick error if the holder variables need to be saved, but var w/the name already exists
		noi di _n as err "{bf:gen()} specified to save simulation output as variables.  However, variable named `errMsg' already exists.  Please drop variable and try again."
		tidy `sorter'
        exit 110
	}
	
	
	// If path specified, check those names, too
	if("`path'"!=""){			
		foreach stub in _id _t _simNm _stage{
			local errMsg = "`path'`stub'"
			cap confirm v `path'`stub' 
			if(_rc==0)	continue, break
		}
		if(_rc==0){	// kick error if the holder variables need to be saved, but var w/the name already exists
			noi di _n as err "{bf:path()} specified to save path output as variables.  However, variable named `errMsg' already exists.  Please drop variable and try again."
			tidy `sorter'
            exit 110
		}
	}
	
	noi di "." _c		// display message
	
	
	// Last preparation step.  Need h(t) and H(t) for every t, regardless of obsv. fail time.
	* So, generate one more set of variables containing haz and Surv
	tempvar refhaz refSurv

	// Bring the msfit vars back in.
	if(`mrgSize' < 100000)	merge 1:1 _n using `msfit2', nogen
	else					fmerge 1:1 _n using `msfit2', nogen
	
		
	// In preparation for the sims, sum all the outward transitions together for every from-t pairing
	noi di as gr "." _c			// display message
	tempvar outhaz outHaz 

		// Start the actual calculations.
		* ensure S(t) is at 1 for starting time, if missing
		recode `refHaz' (.=0) if(`refT'==`stime')
		
		* go H_q(t) -> S_q(t) 	(jic)
		tempvar refSurv
		gen double `refSurv' = exp(-`refHaz')
		
		* go H_q(t) -> h_q(t)
		tempvar mergeID
		gen `mergeID' = _n
		
		foreach tr of local fromToPairsList{	// Switched to unique from-to pairs, just to eliminate any possible complication.
			tempname Haz_mta w
            putmata `mergeID' `Haz_mta'=`refHaz' if(`refFrTo'==`tr'), replace   // is sorted correctly earlier - Ctrl+F for "sort `refTrans'"
            
			mata: `w' = diff(1 :- `Haz_mta') 		// took out colsum for this one.  will need in stgSample and hazSamp, clearly. 
					
			getmata `refhaz' = `w', update id(`mergeID') double
			
			mata: mata drop `Haz_mta' `mergeID' `w'	// cleanup
		}
		
		replace `refhaz' = `refhaz' * -1	    // because the diff function is coded for Surv, originally, so it assumes decreasing values as t increases.
		
	// go h_q(t) -> outward hazard for all 'from' stages	
	bysort `refFrom' `refT': gegen double `outhaz' = total(`refhaz') if(`refT'!=.)		// ! changed on 18JAN17, to reflect the S(t) change
		replace `refhaz' = 0 if(`refT'==0 & `refhaz'<0)
		replace `outhaz' = 0 if(`refT'==0 & `outhaz'<0)  	// ensuring the starting observation is coded as stime for haz and outsum (though I don't think this should matter)
															// 29JUL17: this now needs to shift to 0 instead of stime, given how you've recoded things for unique failure times.
    qui sum `outhaz' if(`refT'>`stime' & `refT'<=`tMax_inputted')
		local m_min = `r(min)'
		local m_max = `r(max)'
	cap matrix drop tShoot_mstate
	
	// centralize the matrix code, in case of msfit option.
	if( ("`hazoverride'"=="" & (`m_max'>1 | `m_min'<0)) | "`msfit'"!="" ){
		local where = "Stata"
		sort `refTrans' `refFrom' `refTo' `refT' 
		
		count if(`refT'!=.)
		if(`r(N)'>`c(matsize)' & `r(N)'<=`c(max_matsize)')	set matsize `r(N)'
		if(`r(N)'<=`c(max_matsize)'){
			mkmat `refT' `refTrans' `refFrom' `refTo' `refSurv' `refhaz' `refHaz' `outhaz', matrix(tShoot_mstate) nomiss
				matname tShoot_mstate time,		col(1) e
				matname tShoot_mstate trans,	col(2) e
				matname tShoot_mstate from,		col(3) e
				matname tShoot_mstate to,		col(4) e
				matname tShoot_mstate surv,		col(5) e
				matname tShoot_mstate haz,		col(6) e
				matname tShoot_mstate cumlHaz,  col(7) e
				matname tShoot_mstate outhaz,	col(8) e
		}
		else{	// too big for Stata matrix.  Load into Mata
			local where = "Mata"
			putmata tShoot_mstate = (`refT' `refTrans' `refFrom' `refTo' `refSurv' `refhaz' `refHaz' `outhaz'), omit replace
		}
	}
	
    // holder for any FYI messages, so they print after "done!"
    local hazovMsg = ""
    
    // do checks
	if(`m_max'>1){
		if("`hazoverride'"==""){
			noi di _n as err "The outward transition hazards for one or more stages are summing to greater than 1 when they typically should not."
			noi di as err "This can be a sign of model specification issues, particularly when there are a number of binary independent variables and/or few observed transitions between two stages."
			noi di as err "Adjust your model's specification and try again."
			
			noi di _n as err "Time, trans, from, to, survivor, trans-specific haz, trans-specific cumulative haz, and stages' outward hazs saved to {res:{bf:tShoot_mstate}} matrix in `where'."
			if("`where'"=="Stata")	noi di as err "To view, type {inp:{bf:matrix list tShoot_mstate}}."
			else					noi di as err "To view, type {inp:{bf:mata: tShoot_mstate}}."
			
			noi di _n as err "{it:If} you wish to persist with this model specification, specify {bf:hazoverride} as an option for mstsample."
			noi di as err "It will force all stages' outward transition hazards to sum to 1 by manually rescaling the hazards, keeping their proportions to each other intact.  **" as ye "DO SO AT YOUR OWN RISK" as err "**."
			
			tidy `sorter'
			exit 125
		}
		else{
            local hazovMsg = "{bf:hazoverride} invoked.  At least one of your hazards was larger than 1."
			qui recode `refhaz' (.=0) if(`outhaz'==0)
			qui replace `outhaz' = 1 if(`outhaz'>1 & `outhaz'<.)
			ereturn scalar hazover = 1	//21DEC18 addition (to know when hazoverride's actually invoked, if specified)
		}
	}
	if(`m_min'<0){
		if("`hazoverride'"==""){
			noi di _n as err "The outward transition hazards for one or more stages are summing to less than 0 when they typically should not."
			noi di as err "This can be a sign of model specification issues, particularly when there are a number of binary independent variables and/or few observed transitions between two stages."
			noi di as err "Adjust your model's specification and try again."
			
			noi di _n as err "Time, trans, from, to, survivor, trans-specific haz, trans-specific cumulative haz, and stages' outward hazs saved to {res:{bf:tShoot_mstate}} matrix in `where'."
			if("`where'"=="Stata")	noi di as err "To view, type {inp:{bf:matrix list tShoot_mstate}}."
			else					noi di as err "To view, type {inp:{bf:mata: tShoot_mstate}}."
			
			noi di _n as err "{it:If} you wish to persist with this model specification, specify {bf:hazoverride} as an option for mstsample."
			noi di as err "It will force all stages' outward transition hazards to sum to 1 by manually rescaling the hazards, keeping their proportions to each other intact.  **" as ye "DO SO AT YOUR OWN RISK" as err "**."
			
			tidy `sorter'
			exit 125
		}
		else{
            local hazovMsg = "{bf:hazoverride} invoked.  At least one of your hazards was less than 0."
			qui replace `refhaz' = 0 if(`outhaz'<0)
			qui replace `outhaz' = 0 if(`outhaz'<0)
			qui recode `refhaz' (.=0) if(`outhaz'==0)
			ereturn scalar hazover = 1	//21DEC18 addition (to know when hazoverride's actually invoked, if specified)
		}
	}
	
	// to round out the return
	if(`m_min'>=0 & `m_max'<=1 & "`hazoverride'"!=""){
		ereturn scalar hazover = 0
	}
    
	tempvar refOverallSurv outhaz1
		gen double `outhaz1' = 1-`outhaz'	// 1 - hazsum  (to load into Mata)
		gen double `refOverallSurv' = .
		
		// You need to loop over all the from stages.
		// It's not the most efficient way of doing this, but just loop over all 
        // the unique pairs (to eliminate possible sources of complication).
		foreach tr of local fromToPairsList{
			putmata `mergeID' haz1=`outhaz1' if(`refFrTo'==`tr'), replace
		
			mata: w = cumprod(haz1)
		
			getmata `refOverallSurv' = w, update id(`mergeID') double
			mata: mata drop w haz1 `mergeID'	// cleanup
		}
		drop `outhaz1' `mergeID'
			
		// If msfit specified, append overall survivor to end of matrix
		if("`msfit'"!=""){
			count if(`refT'!=.)
			if(`r(N)'>`c(matsize)' & `r(N)'<=`c(max_matsize)')	set matsize `r(N)'
			if(`r(N)'<=`c(max_matsize)'){
			mkmat `refT' `refTrans' `refFrom' `refTo' `refSurv' `refhaz' `refHaz' `outhaz' `refOverallSurv', matrix(tShoot_mstate) nomiss
				matname tShoot_mstate time,			col(1) e
				matname tShoot_mstate trans,		col(2) e
				matname tShoot_mstate from,			col(3) e
				matname tShoot_mstate to,			col(4) e
				matname tShoot_mstate surv,			col(5) e
				matname tShoot_mstate haz,			col(6) e
				matname tShoot_mstate cumlHaz,  	col(7) e
				matname tShoot_mstate outhaz,		col(8) e
				matname tShoot_mstate overallSurv,	col(9) e  	
			}
			else{	// too big for Stata matrix.  Load into Mata
				local where = "Mata"
				putmata tShoot_mstate = (`refT' `refTrans' `refFrom' `refTo' `refSurv' `refhaz' `refHaz' `outhaz' `refOverallSurv'), omit replace
			}
		}
	// * FIXEDH ADJUSTMENT HERE.
	//	 You need to flip around the coding, similar to how a rechargeable battery works.
	if("`fixedhorz'"!=""){
		replace `refT' = abs(`tMax_inputted' - `refT')
		tempname moose
		local frName = "`refFrom'"
		local toName = "`refTo'"
		rename	`refFrom' 	`moose'
		rename	`refTo' 	`frName'
		rename	`moose' 	`toName'
	}	
	
	tempname ref
	putmata `ref' =(`refT' `refFrom' `refTo' `refOverallSurv' `refhaz'), omit replace
	keep if `sorter'!=. 
	sort `sorter'

	noi di as gr "done."		// display message
    if("`hazovMsg'"!="")    noi di as gr " > `hazovMsg'"
    	
	// If msfit's specified, but the matrix had to go into Mata, not Stata, memory:
	if("`msfit'"!="" & "`where'"=="Mata"){
		noi di as gr "{bf:msfit} specified, but {inp:tShoot_mstate} matrix too large for Stata memory.  Saved in Mata."
		noi di as gr "To view, type {inp:{bf:mata: tShoot_mstate}}."
	}
    
	}	// end of convenience collapse bracket for section 1
	

**** // Second, begin the sims. // ****
	tempname obsvFrom
	putmata `obsvFrom'=`from', omit replace		
	mata: `obsvFrom' = uniqrows(`obsvFrom')
	
	// Prepare file to which results will be posted (to try to help with speed)
	tempname postName
	tempfile postFile
	
		* tempvar names, because otherwise you may have a merge nightmare on your hands
		tempname simNo_outpt subj_outpt t_outpt stg_outpt flag_outpt
		local postVarNames = "`simNo_outpt' `subj_outpt' `t_outpt' `stg_outpt' `flag_outpt'"
		
	// The ALWAYS post file
	cap postclose `postName'
	postfile `postName' `simNo_outpt' `subj_outpt' `t_outpt' `stg_outpt' `flag_outpt' using `postFile', replace

		
	// The post file that'll reset after every draw, for the big datasets	
	tempname postName_draw
	tempfile postFile_draw
	
	tempfile countAll		// (initializing outside of conditional so that the arguments won't passthrough with an error for _simMstate)
	tempfile stageAll
	tempfile countTemp
	tempfile stageTemp
	
	local fullPost_draw = ""
	if(`overall'>`slicetrigger' & "`speed'"==""){
		
		tempfile postFile_draw
		
		cap postclose `postName_draw'
		local fullPost_draw = "postfile `postName_draw' `simNo_outpt' `subj_outpt' `t_outpt' `stg_outpt' `flag_outpt' using `postFile_draw', replace"
		`fullPost_draw'
		
		
		// (If 'gen' is specified, will also need a running stage file to append 
        // everything into.  That'll be tempfile stageAll.  Any adjustments you 
        // need to make have to be on the backend.)
	}
	
	noi di _n as gr "Simulations underway."
		timer clear 76
		timer on 76
        // ^ needs to exist in order to give user the heads up about processing
        //   times at the start of the processing stage
	
	mata: resFinal = .
	mata: resFinalPath = .

	
	mata: _simMstate(`sims', `nSubjs', `obsvFrom', `sstage', `stime', `tmax', "`clock'", ///
					`ref', "`verbose'", "`terse'", "`postName'", `slicetrigger', ///
					"`postName_draw'", "`postFile_draw'", "`countAll'", "`countTemp'", ///
					"`stageAll'", "`stageTemp'", "`fullPost_draw'", "`postVarNames'", ///
					"`folderName'", "`fixedhorz'", "`bforce'", `noiYN', "`speed'", `ci', ///
					resFinal, resFinalPath, "`pathspeed'")
																			// notice: no longer tMax_inputted, but tmax, where tmax = inputted + 1 (while tshooting the boundary thing)
		timer off 76
		
	cap mata: mata drop mstate_intRslts
	mata: mata rename resFinalPath mstate_intRslts
	postclose `postName'
	if(`overall'>`slicetrigger' & "`speed'"=="")	postclose `postName_draw'
	
	// housekeep
	mata: mata drop `ref' `obsvFrom'
	if("`fixedhorz'"!=""){
		replace `refT' = abs(`tmax' - `refT')	// flip t back around
		tempname moose
		rename	`refFrom' 	`moose'
		rename	`refTo' 	`toName'
		rename	`moose' 	`frName'
	}
	
**** // Third, process the results. // ****
	qui timer list
	local spc ""
	if(`r(t76)'>180 | "`speed'"!="")	local spc = "_c"
	noi di _n `spc' as gr "Processing results."
	if(`r(t76)'>180 & "`speed'"=="")	noi di as gr "  (This may take a suspiciously long while because of the number of simulations you ran.  Please hold.)"
	else if("`speed'"!="")				noi di as gr "  ({bf:speed} option specified.)"
	{
	* get the percentiles
	local low = (100-`ci')/2
	local high = 100-`low'
		
		local mataSv = 0					// sticking this here, for now.
		local pathTrigger = `slicetrigger'	// how many path observations (which will be imperfect, because cannot tell how many path obsvs without opening the dataset.)
												// To get at this, going with "overall / 5" for a rough, rough estimate (when this condition's checked by ifs)
		
		// Insert the slice and dice here, for instances where we'll have a 
        // super huge dataset with results.
		* (also tell people that, if they want to save these results, we've had 
        * to write them to an outside dataset, just in case Stata goes bonko)
		** Notice: this does presuppose that we can read in the path dataset 
        ** without an issue.  If not, the previous "in case of emergency" 
        ** save will be v. important

		
		// The eventual dataset size that'll trigger the slicing.
		if(`overall'>`slicetrigger' & "`speed'"==""){
			// Create file name for JIC export.
            jicFileNm
			local jicFile = "`r(fileNm)'"
	
			// Make sure you can save things here
			cap copy "`postFile'" "`jicFile'.dta"
			
			if(_rc==0){
				local locStr = "in your present working directory."
			}
			else{
				cap copy "`postFile'" "`c(sysdir_personal)'/`jicFile'.dta"
				local locStr = "in `c(sysdir_personal)'. (Stata could not save to your present working directory.)"
			}
			
			if(_rc==0){
				noi di _n as ye "  CAUTION: " as gr "the expanded dataset will have over `slicetrigger' observations."
				noi di as gr 	"  In case the processing segment goes awry, saving raw simulation output (in path form) to:" 
				noi di as ye	"     `jicFile'.dta" 
				noi di as gr 	"  `locStr'"
				if("`path'"=="" | ("`path'"!="" & `overall'/5<`slicetrigger'))	noi di _n as gr	"  This dataset will automatically delete itself {it:iff} the processing segment executes with no errors."
				if("`path'"!="" & `overall'/5 >=`slicetrigger')					noi di _n as gr "  Because you have specified {bf:path} as an option, and because of the potentially large number of observations, this file will remain saved" as ye " in lieu of " as gr "the path variables being imported into the active dataset."		
			}
		}
		
		***************************************
		// Start doing the processing
		if("`speed'"==""){
			// * If it's the old scenario, then go to work
			if(`overall'<`slicetrigger'){
				
				* path -> stage
				tempfile stageFile
				path2stage, paths("`postFile'") stages("`stageFile'") sim(10000) names("`postVarNames'") fhorz("`fixedhorz'") tmax(`tmax')
				
				* stage -> counts
				tempfile countFile
				stage2counts, stages("`stageFile'") tmax(`tmax') sim(10000) counts("`countFile'") fhorz("`fixedhorz'")
				
				// At this point, you now have everything you'll need:
					* path output:	in `postFile'	(relevant if "path" option specified)
					* stage output: in `stageFile'	(relevant if "gen" option specified)
					* count output:	in `countFile'	REQUIRED ALWAYS, regardless of options.
					
				preserve
					use `countFile', clear
			}
			// * NEW SCENARIO: INSERT IF NEEDED
			else{
				preserve
					use `countAll', clear
			}
		
			// existing code now works, with some mapping
			tempvar `gen'Nm `gen'_t
			qui rename `simNo_outpt' ``gen'Nm' //= `out'1	// map simNo back to holder var
			qui rename `t_outpt' 	 ``gen'_t' //= `out'3	// map the time back to holder var
			
			forvalues s = 1/`maxStage'{			
				* divide all the stages by the total number of subjects, to get percents.
				tempvar `gen'_stage`s'
				
				// see if there were any transitions into this stage at all
				cap confirm v counts`s'
				if(_rc==0)		qui gen double ``gen'_stage`s'' = counts`s'
				else			qui gen double ``gen'_stage`s'' = 0
				qui replace ``gen'_stage`s'' = ``gen'_stage`s''/`nSubjs'
				
			
				tempvar `gen'_Rslt_t `gen'_Rslt_stage`s'_m `gen'_Rslt_stage`s'_lb `gen'_Rslt_stage`s'_ub
				qui gen double ``gen'_Rslt_stage`s'_m' = .
				qui gen double ``gen'_Rslt_stage`s'_lb' = .
				qui gen double ``gen'_Rslt_stage`s'_ub' = .
				
				if(`tPoints'>`c(N)')	set obs `tPoints'
					local tMaxInt = floor(`tmax')	// jic of non-integer times  (might be better to floor, not ceil => PONDER)
				qui gegen ``gen'_Rslt_t' = seq() in 1/`tPoints', from(`stime') to(`tMaxInt') block(1)
				
				* fill in the mean/percentiles
				forvalues times = `stime'/`tMax_inputted'{
					qui sum ``gen'_stage`s'' if(``gen'_t'==`times')
					qui replace ``gen'_Rslt_stage`s'_m' = r(mean) if(``gen'_Rslt_t'==`times')
					gquantiles ``gen'_stage`s'' if(``gen'_t'==`times'), _pctile p(`low' `high')		// matches what comes out of mm_quantile as is, w/o needing to add altdef
					qui replace ``gen'_Rslt_stage`s'_lb' = r(r1) if(``gen'_Rslt_t'==`times')
					qui replace ``gen'_Rslt_stage`s'_ub' = r(r2) if(``gen'_Rslt_t'==`times')
				}
			}
		} // end conventional if (in conventional vs. speed if/else)
		else{		// speed option specified

			// build list of variable names for the getmata
			tempvar `gen'_Rslt_t 
			
			local mataVarNames = `"``gen'_Rslt_t' "'
			forvalues s = 1/`maxStage'{
				tempvar `gen'_Rslt_stage`s'_m `gen'_Rslt_stage`s'_lb `gen'_Rslt_stage`s'_ub
				local mataVarNames = `"`mataVarNames' ``gen'_Rslt_stage`s'_m' ``gen'_Rslt_stage`s'_lb' ``gen'_Rslt_stage`s'_ub' "'
			}
			getmata (`mataVarNames') = resFinal, double force
		}
		
		// all the code is the same from this point out, regardless of speed or conventional
		forvalues s = 1/`maxStage'{
			local spacing = 10 + floor(log10(`maxStage'))
			
			// Display the list for the user.
			* define chars first, so that the names aren't ridic
			char define ``gen'_Rslt_t'[varname] Time
			char define ``gen'_Rslt_stage`s'_m'[varname] Pr(Stg. `s') [Mean]
			char define ``gen'_Rslt_stage`s'_lb'[varname] Lower `ci'% CI
			char define ``gen'_Rslt_stage`s'_ub'[varname] Upper `ci'% CI
			
			
			// >>> Print the results
			local stObsv = 1
			if("`fixedhorz'"!=""){
				replace ``gen'_Rslt_t' = abs(``gen'_Rslt_t'-`tMax_inputted')
				
				// for speed
				qui gdistinct ``gen'_Rslt_t'
					local tPoints = `r(J)'
			}
			if("`bforce'"!="")		local stObsv = `tPoints' - 1
			noi list ``gen'_Rslt_t' ``gen'_Rslt_stage`s'_m' ``gen'_Rslt_stage`s'_lb' ``gen'_Rslt_stage`s'_ub' in `stObsv'/`tPoints' if(``gen'_Rslt_t'<=`tMax_inputted'), noobs sep(`tPoints') subvar ab(`spacing') table
            
			// If the user wants the vars in memory, create them.
			if(`keepHolders'==1){
				if(`s'==1){
					** Raw
					if("`speed'"==""){
						clonevar `gen'_t = ``gen'_t'
						clonevar `gen'_simNm = ``gen'Nm'
					
						** Final				
						replace `gen'_simNm = . if(`gen'_t>`tMax_inputted')
						replace `gen'_t = . if(`gen'_t>`tMax_inputted')
						local rawOutput "`gen'_t `gen'_simNm"
					}
					clonevar `gen'_Rslt_t = ``gen'_Rslt_t'
					replace `gen'_Rslt_t = . if(`gen'_Rslt_t>`tMax_inputted')
					
					
					local rsltOutput "`gen'_Rslt_t"
					
				}
		
				if("`speed'"==""){
					clonevar `gen'_stage`s' = ``gen'_stage`s''
					local rawOutput "`rawOutput' `gen'_stage`s'"
				}
				
				clonevar `gen'_Rslt_stage`s'_m = ``gen'_Rslt_stage`s'_m'
				clonevar `gen'_Rslt_stage`s'_lb = ``gen'_Rslt_stage`s'_lb'
				clonevar `gen'_Rslt_stage`s'_ub = ``gen'_Rslt_stage`s'_ub'
					local rsltOutput "`rsltOutput' `gen'_Rslt_stage`s'_m `gen'_Rslt_stage`s'_lb `gen'_Rslt_stage`s'_ub"
				
				// for the boundary kludge.
				if("`speed'"=="")	replace `gen'_stage`s' = . if(`gen'_t>`tMax_inputted')
				replace `gen'_Rslt_stage`s'_m = . if(`gen'_Rslt_t>`tMax_inputted')
				replace `gen'_Rslt_stage`s'_lb = . if(`gen'_Rslt_t>`tMax_inputted')
				replace `gen'_Rslt_stage`s'_ub = . if(`gen'_Rslt_t>`tMax_inputted')
				
				// Put everything into Mata
				if("`speed'"==""){
					putmata `rawOutput', replace
					putmata `rsltOutput', replace
				
					qui count if(``gen'_stage`s''!=.)
					local rawCount = `r(N)'
				}
				
			} // if for keeping vars

		} // stage forvalues loop
				
        // If frailty present, but no value specified, make note about frailty
        // being set to 0
        if("`frNote'"!=""){
            noi di _n as gr "`frNote'"
            noi di ""
        }
        // Ditto if offset present, but no value specified.
        if("`offNote'"!=""){
            noi di _n as gr "`offNote'"
            noi di ""
        }
            
	if("`speed'"=="")	restore
			
	sort `sorter'
	
	// Display the non-integer fail message
	tempvar intCheck
	gen double `intCheck' = mod(_t,1) if(_d==1)
	
	qui sum `intCheck'
	if(`r(max)'>0){
		// message
		noi di _n as ye "> NOTE: " as gr "You have possible transitions at non-integer failure times.  This does not affect how the simulations are executed."
		noi di 	  as gr "The final results are also still correct, *but* they are reported in a more coarse way.  They can only be displayed with integer times."

		if("`speed'"==""){
			if("`path'"=="")	noi di as gr "Specify {bf:path()} in your {bf:mstsample} statement to see the exact non-integer times at which your transitions occur."
			else				noi di as gr "Examine your {bf:path()} variables to see the exact failure times."
		}
	}
	drop `intCheck'
	
	
	// If the user wanted results saved, then do so.
	if(`keepHolders'==1){
		noi di _n _c as gr "Saving requested output to dataset..."
		
		local trouble = 0
		if(`overall'<`slicetrigger' & "`speed'"==""){	// break into this only if overall's less than the trigger.  Otherwise, we've been dealing with the stage output all along.
			cap getmata `rawOutput', double force	// Pull raw output first
			
			local obsvCap = ""
			if(_rc!=0 | `rawCount'>`c(max_N_theory)'){
				if(`rawCount'>`c(max_N_theory)')	local obsvCap = "Number of observations exceeds Stata's maximum of `c(max_N_theory)'.  "
				local rawMatrixd = subinstr(strtrim("`rawOutput'"), " ", ", ",.)
				
				noi di _n as err "  Trouble converting output (in stage format) to variables.  `obsvCap'Saved to Mata memory as " as ye "ms_stgOutput" as red " instead."  as gr "  (To see, type: {bf: mata: ms_stgOutput})"
				mata: ms_stgOutput = `rawMatrixd'
			}
		}
		else{	// Otherwise, we've been dealing with stage output all along
			if("`path'"==""){
				noi di as gr "done."
				noi di ""
			}
			
			if("`speed'"==""){
				// the stage datasets are always getting saved, regardless of 
                // what the user does if slicetrigger's met
				noi di _n as gr "  Relevant variable key for stage files in: " 
				noi di as ye ///
					_col(6) 	"`stageSliceDir'"	
				noi di _n as gr	"   First variable:  simNo"	_col(30) "(simulation number)"
				noi di as gr	"   Second variable: subj"	_col(30) "(subject ID)"
				noi di as gr	"   Third variable:  time"	_col(30) "(t where transition occurs)"
				noi di as gr	"   Fourth variable: stage"	_col(30) "(subject's occupied stage at t's end)"
				noi di ""
			}
		}
		
		if("`speed'"==""){
			getmata `rsltOutput', double force		// Then, pull final output.  There really should never be a problem here.  The only real way is if the number of time points is obscene.
				
				// (just sticking in the caps to deal with the possibility that, 
                // even though you've requested stage output, it's not going to 
                // be there if overall > sliceTrigger)
				// Label everything
				** Raw
				cap label variable `gen'_t 		"SIMS: t"
				cap label variable `gen'_simNm 	"SIMS: Sim draw #"
		}	// (yes, the odd tabs are correct.)  
		
				** Results
				cap label variable `gen'_Rslt_t "RESULTS: t"
				
				forvalues s = 1/`maxStage'{
					// Label everything
					** Raw
					cap label variable `gen'_stage`s' "SIMS: % of subjects in `s' at t"		// will throw error for speed, but that's why cap'd.
					
					** Results
					cap label variable `gen'_Rslt_stage`s'_m  "RESULTS: Mean of `gen'_stage`s' at t across all `sims' simulated draws."
					cap label variable `gen'_Rslt_stage`s'_lb "RESULTS: Lower `ci'% CI, via percentiles of `gen'_stage`s'."
					cap label variable `gen'_Rslt_stage`s'_ub "RESULTS: Upper `ci'% CI, via percentiles of `gen'_stage`s'."
			}
		
		if("`path'"=="" & `overall'<`slicetrigger' & "`speed'"==""){
			noi di as gr "done."
			noi di ""
		}
        
        // Compress here, to prevent datasig issues
        compress `gen'_*
	}
	
	// Cleanup
	if("`pathspeed'"=="")	local sPathRm = "mstate_intRslts"
	else					local sPathRm = ""
	foreach vec in `rawOutput' `rsltOutput' resFinal `sPathRm'{
		mata: rmexternal(st_local("vec"))
	}	
	
	// Speed cleanup
	if("`speed'"!=""){
		forvalues s = 1/`maxStage'{
			mata: rmexternal(sprintf("spd_lb%f", `s'))
			mata: rmexternal(sprintf("spd_ub%f", `s'))
		}
	}
	
	if("`path'"!=""){		// if the user wants the path variables, export those
		if(`keepHolders'==0)	noi di _n _c as gr "Saving requested output to dataset..."
		
		if(`overall'/5<`pathTrigger'){	
			merge 1:1 _n using `postFile', nogen
			
			qui rename `simNo_outpt'	`path'_simNm
			qui rename `subj_outpt'		`path'_id
			qui rename `t_outpt'		`path'_t
			qui rename `stg_outpt'		`path'_stage
			
			label variable `path'_simNm	"PATH: Sim Number"
			label variable `path'_id	"PATH: Subject ID"
			label variable `path'_t		"PATH: t where transition occurs"
			label variable `path'_stage	"PATH: Subject's stage at end of PATH's t"
		}
		else{
			noi di _n as gr "  Relevant variable key for " as ye "`jicFile'.dta"	
			noi di as gr	"   First variable:  simNo"		_col(35) "(simulation number)"
			noi di as gr	"   Second variable: subj"		_col(35) "(subject ID)"
			noi di as gr	"   Third variable:  time"  	_col(35) "(t where transition occurs)"
			noi di as gr	"   Fourth variable: newStage"	_col(35) "(subject's new stage at end of PATH's t)"
			local pathTrigger = 1
		}
		
		noi di as gr "done."
		noi di ""
        compress `path'_*
	}
	} // end of convenience collapse for result 
	
	* end of convenience collapse for result chunk
	mat drop `skm_b'
	if(`overall'>`slicetrigger' & `mataSv'==0 & `pathTrigger'!=1)	cap qui erase "`jicFile'.dta"
	if(`overall'>`slicetrigger' & `mataSv'!=0)	cap mata: mata drop ms_pathOutput
	
	if("`dzone'"!="")	ereturn local datasignature "" // !! DANGER.  Resetting the data signature to what it was before you started mstsamp.
    
    // Restore previous return list results (don't use tidy function--will toss
    // any extra rows you needed to append to store the final processed results)
    _return restore $temp_mstsampleNm
    macro drop temp_mstsampleNm
    
} // for bracket collapse in editor	
end
********************************************************************************************************************************	
// The entire simulate portion of the code, written in Mata
***************************************
mata:
void _simMstate(			real scalar nSims,			// for number of total sims
							real scalar nSubjs,			// for number of subjects
							real vector obsvFrom, 		// observed from variables (from actual dataset)
							real scalar sstage, 		// starting stage
							real scalar stime,			// starting time
							real scalar tMax_inputted, 	// max inputted time + 1 (**kludged)
							string clockType,			// clock or gap
							real matrix ref, 			// matrix with refT, refFrom, refTo, refOverallSurv, and refhaz (and in that order)
							string verbose,				// string telling you whether user's specified "verbose" option
							string terse,				// string telling you whether user's specified "terse" option
							string postNm,				// string with postName in it
							real scalar sliceTrig,		// sliceTrigger value
							string postNm_draw,			// string with postName_draw in it 															(relevant only when sliceTrigger==TRUE)
							string postNm_file,			// string with filename for postNm_file														(relevant only when sliceTrigger==TRUE)
							string countAll,			// string with countAll in it--name of tempfile dataset for accumulation of counts 			(relevant only when sliceTrigger==TRUE)
							string countTemp,			// string with countTemp--name of tempfile for each sim draw								(relevant only when sliceTrigger==TRUE)
							string stageAll,			// string with stageAll--name of tempfile for stage output 									(relevant only when sliceTrigger==TRUE)
							string stageTemp,			// string with stageTemp--name of tempfile for each sim draw								(relevant only when sliceTrigger==TRUE)
							string fullPostNm_init,		// string with, literally, the entire Stata command that will initialize the postNm_draw	(relevant only when sliceTrigger==TRUE)
							string postVarNames,		// string with all the tempnames of the variables in the post files		
							string folderName,			// string containing name of folder for stage datasets (if gen specified)					(relevant only when sliceTrigger==TRUE)
							string fixedHorz,			// string containing whether these predictions are fixed horizon (="fixedh") or regular (="")		
							string bforce,				// string saying whether we're brute forcing the fixed horizon stuff (implying we only need to keep last time point)
							real scalar noiYN,			// scalar saying whether the user's running the command noisily or not (since this is getting passed weird to Mata)
							string speed,				// string containing whether user's opted for the speed option
							real scalar CI,				// scalar containing the CI level (default=95)												(relevant only when speed==TRUE)
							real matrix resFinal,		// HACK: to get Mata to kick back the speed results from a void function					(relevant only when speed==TRUE; will stay = . if speed not specified)
							real matrix resFinalPath,	// HACK: to get Mata to save the exact transition times (since path is disabled w/speed)	(relevant only when speed==TRUE)
							string pathSpeed			// string saying whether Mata should kick back the results with exact transition times		(relevant only when speed==TRUE)
					  ){
	// Declaring variables, in case someone has matastrict on
	real scalar	 overall
	real scalar  shoutOnce100 
	real scalar  announce 
	real scalar  simNo 
	real scalar  subjPerc 
	real scalar  subject 
	real scalar  percComplete 
	real scalar  stgCurrent 
	real scalar  tCurrent 
	real scalar  tPrev 
	real scalar  absorb 
	real scalar  t0 
	real scalar  tStar 
	real scalar  tHolder 
	real scalar  pull 
	real scalar  stgPrev 
	real scalar  start 
	real scalar  tv

	// If we've specified speed, declare additional objects
	if(speed!=""){
		real matrix res_mega		// MEANS: overall, across all sims
		real matrix res				// MEANS: within each sim (will get overwritten a bunch, but stuck here so it's declared only once)
		real matrix res1			// MEANS: for each sim-subject (will get overwritten a bunch, but stuck here so it's declared only once)
		real scalar nStgs
		real scalar nTpts
		real colvector stgSet
		real colvector tptsSet
		pointer ptrLB, ptrUB
		real scalar firstRun, bktSz, stg_i
		real matrix speedPath, tempRes
		
		// grab set of stages (relevant later for figuring out which column to write things to)
		stgSet = uniqrows(ref[,2] \ ref[,3])	// also sorts from low to high
		
		// grab number of stages
		nStgs = rows(stgSet)

		// grab number of tPoints (since we'll be calling it more than once within the for())
		// ** NOTE: you added in all integer values between stime and tMax_inputted, for output-related reas
		tptsSet =  range(stime, ceil(tMax_inputted), 1)	// ** NOTE: integer values between stime and tMax_inputted only for output-related reasons w/speed + gap + non-integer trans times
		nTpts = rows(tptsSet)	
		
		// create big matrix for ALL means (running total)
		res_mega = J(nTpts,nStgs,0)		// (# of time points) x (# of stages)
		
		// how big will the CI bucket vectors be?
		bktSz = ceil(( (nSims) - (nSims*(CI/100)) )/2)
		
		// create (do only the LB and mean for now -> clone LB for UB later on, once we get to the magic sim number and have at least that many objects in the bucket)
		for(stg_i=1;stg_i<=nStgs; stg_i++){		
			// toss the LB object if name already in memory
			rmexternal(sprintf("spd_lb%f", stg_i))
			ptrLB = crexternal(sprintf("spd_lb%f", stg_i))	 	// creates object named (in Stata code) spd_lb`i'
			*ptrLB = J(bktSz,nTpts,0) 							// (size of bucket) x (# of time points)
			  // ^ REMEMBER: This line's **ACTIVE**--it isn't commented out.  Since it always makes you look twice.
		}
	}
	
	// Redo # of overall obsvs for stage output for sliceTrigger output
	overall = nSubjs * nSims * (tMax_inputted-stime)		// don't need to add 1, because tMax passed to _simMstate is inputted tMax + 1.

    
	// moved from old place right before "sim section" started, to reduce # of params passed
	shoutOnce100 = 0
	announce = nSims*nSubjs>10 ? floor(nSims*nSubjs/10) : nSims*nSubjs
	
	for(simNo=1; simNo<=nSims; simNo++){
		// *** DISPLAY INFO HERE ***
		if(noiYN==1){	// making sure qui's not specified by user
			if(simNo==1){
				//((* Sim underway message now executes before entering the function))
				if(c("processors")>1 & verbose==""){	// the Stata MP vs. not messages
					displayas("error")	// the bad style hack, to force the output to display
					printf("{res:     0%%...}")
					displayflush()
				}
				else{
					if(c("processors")==1){
						displayas("error")		// the bad style hack, to force the output to display
						printf("{txt:> NOTE: {help set processors:single processor} in use.}")
						displayflush()
					}
					
					subjPerc = ceil(nSubjs/10)	// divisions for ~10% (will output a multiple, not a percentages: e.g., 30 subjects = 10%)
					
					if(terse=="" | verbose!=""){			// print for both processors AND verbose option
						displayas("error")	
						printf("{txt:  Setting simulation progress output to be more verbose.}\n") 
						displayflush()
					}
					if(terse!="" & c("processors")==1){		// print for single processor only
						displayas("error")	
						printf("{txt:  {bf:terse} option specified.  Using multicore output (less verbose).\n}") 
						displayflush()
					}		
				} //end of else within simNo==1 if
			} // end of simNo==1 if

			if(noiYN==1 & ((c("processors")==1 & terse=="") | verbose!="")){		// if it's a single core, print the sim number first, then prepare to print the within-sim percentages using subject
				displayas("error")	
				printf("{col 5}{res:#%f }", simNo)
				printf("{col 11}{inp:0%%...}")
				displayflush()
			}
		} // end of qui check
		
		// if speed specified, create the mean holder matrix for this sim pull
		if(speed!="")		res = J(nTpts,nStgs,0)		// (# of time points) x (# of stages)
		
		for(subject=1; subject<=nSubjs; subject++){
			// *** MORE DISPLAY INFO HERE ***			
			if((c("processors")>1 & verbose=="") | terse!=""){					// if Stata MP
				percComplete = ( ((simNo-1)*nSubjs)+subject)/(nSims*nSubjs)*100
				
				if(noiYN==1 & percComplete>0 & ///
                   mod((((simNo-1)*nSubjs)+subject),announce)==0  & percComplete<100){
					displayas("error")	
					if(percComplete>=10)	printf("{res:%2.0f%%...}", percComplete)
					else					printf("{res:%1.0f%%...}", percComplete)
					displayflush()
				}
				
			}
			else{																// single-core output
				if(mod(subject,subjPerc)==0){
					percComplete = (subject/nSubjs) * 100

					if(noiYN==1){
						displayas("error")	
						if(percComplete>=10)	printf("{inp:%2.0f%%...}", percComplete)
						else					printf("{inp:%1.0f%%...}", percComplete)
						displayflush()
					}
				}
			}			
			
			// if speed specified, create the mean holder matrix for this subject
			if(speed!="")		res1 = J(nTpts,nStgs,0)		// (# of time points) x (# of stages)
		
			// set the starting parameters
			stgCurrent = sstage
			tCurrent = stime
			tPrev = stime
			tMax_inputted = tMax_inputted
			firstRun = 1
		
			absorb = 0

			if(speed==""){		// post as normal, if we aren't gunning for speed
				_postMe(simNo, subject, tCurrent, stgCurrent, postNm, 1)
				if(overall>=sliceTrig)	_postMe(simNo, subject, tCurrent, stgCurrent, postNm_draw, 1)
			}
			
			// while the subject's not in an absorbing stage...
			while(absorb==0){
				
				// Clock/gap: Create new variable t0 to feed into Hazsample.
				if(clockType=="forward"){	// clock forward
					t0 = tCurrent
				}
				else{	// gap time
					// if this is the first pull for the subject, t0 needs to be equal to start time
					if(tCurrent==stime)		t0 = stime
					// if it's not the first pull, then t0 needs to be 0.
					else					t0 = 0
				}
			
				// ***** Hazsample, to get the next transition time			
				tStar = _Hazsample(ref, t0, stgCurrent, fixedHorz)
							
				if(tStar!=.){	// (which is likely to be true--tStar will usually be a number, unless the subject stays put to the end --or-- if tMax is somewhat low, given the data's properties.)
				
					// [[check now to see if you're at the end of the time period; if not, pull a new stage]]
					
					//* clock/gap acknowledgment
					tHolder = tStar
					if(clockType=="gap")	tHolder = tCurrent + tStar
					
					
					if(tHolder<=tMax_inputted){	// less than or equal to, or else you're precluding the possibility of a transition in the last period.
					
						// ***** stgSample, to get the next stage @ t*
						pull = _stgSample(ref, tStar, stgCurrent)
									

						// if the subject hasn't moved (if pull==.), record current stage again as pull.
						if(pull==.)		pull = stgCurrent

						// Set the subject's new stage and the new time.
						stgPrev = stgCurrent
						stgCurrent = pull
						tPrev = tCurrent
						tCurrent = tStar
						if(clockType=="gap")	tCurrent =  tPrev + tStar	// because tPrev will equal the current time, before we went updating tCurrent a few lines ago
					}
					else{	// we've reached the end of the time period of interest. fill the current observation through to the end of the simulated time period.
							//** behavior for clock and gap should be same.  Fill everything forward of the current time.		
						absorb = 1
					}
		

					// if the subject's in an absorb (or if it's the end of the 
                    // time period, which the above else takes care of), finish 
                    // out the record.
					//** same behavior for both clock and gap
					if(rows(obsvFrom[selectindex(obsvFrom[,1]:==stgCurrent),1])==0){	// It's a true absorbing stage 
						absorb = 1
					}	
				} 
				
				// if tStar==. 
				else{	// complements of the HoR troubleshoot.
					tStar = tMax_inputted					
					absorb = 1
					break
				}			
				
				// Subject still at risk; post.
				if(tCurrent!=stime | stgCurrent!=sstage){	// to get rid of the possibility of odd duplicate rows
				// path output
					if(speed==""){	// if we're not gunning it.
						_postMe(simNo, subject, tCurrent, stgCurrent, postNm, 1)
						if(overall>=sliceTrig) _postMe(simNo, subject, tCurrent, stgCurrent, postNm_draw, 1)
					}
					else{	// and if we are...	
						res1[, stgPrev] = (tCurrent==. | pull==.) 	? 	res1[, stgPrev] + (tptsSet:>=tPrev :& tptsSet:<=tMax_inputted) :
																		res1[, stgPrev] + (tptsSet:>=tPrev :& tptsSet:<tCurrent) 	
						
						// quick kludge to fix any rows with >1 values 
						res1[,stgPrev] = mm_cond(res1[,stgPrev]:>1, 1, res1[,stgPrev])
					}																	
				}
			} // end of while

			// Subject now finished; post.
			if(speed==""){	// if we're not gunning it
				_postMe(simNo, subject, tMax_inputted, stgCurrent, postNm, 1)
				if(overall>=sliceTrig)	_postMe(simNo, subject, tMax_inputted, stgCurrent, postNm_draw, 1)	// for the big eventual datasets.
			}
			else{	// if we are, then write the results to res1 and be done with it			
				res1[,stgCurrent] = res1[,stgCurrent] + (tptsSet:>=tCurrent :& tptsSet:<=max(tptsSet))
				
                    // quick kludge to fix any rows with >1 values 
                    res1[,stgCurrent] = mm_cond(res1[,stgCurrent]:>1, 1, res1[,stgCurrent])
						
				// then, post this subject to sim matrix
				res = res + res1
			}
		} // end of subject loop
		

		if(speed==""){
			// If overall's greater than the trigger, then compute all the things.
			if(overall>sliceTrig){
				_stata("postclose " + postNm_draw)
				
				// path -> stage
				if(st_local("gen")!="" )	_stata("path2stage, paths(" + postNm_file + ") stages(" + stageTemp + ") names(" + postVarNames + ") sim(" + strofreal(simNo) + ") fhorz(" + fixedHorz + ") tmax(" + strofreal(tMax_inputted) + ") folder(" + folderName + ") bforce(" + bforce + ")")
				else						_stata("path2stage, paths(" + postNm_file + ") stages(" + stageTemp + ") names(" + postVarNames + ") sim(" + strofreal(simNo) + ") fhorz(" + fixedHorz + ") tmax(" + strofreal(tMax_inputted) + ") bforce(" + bforce + ")")

				_stata("stage2counts, stages(" + stageTemp + ") counts(" + countTemp + ") tmax(" + strofreal(tMax_inputted) + ") append(" + countAll + ") sim(" + strofreal(simNo) + ") fhorz(" + fixedHorz + ")")
				
				// also, stop and restart the postName_draw
				_stata(fullPostNm_init)
			}
		}
		else{ // Post this simulation's set of results to the mega-sim matrix
			// Means
			res = res :/ nSubjs
			res_mega = res_mega + res

			// CIs (i.e., now deal with the buckets.)
			if(simNo<bktSz){		// if the bucket isn't full yet, fill it
				for(stg_i=1; stg_i<=nStgs; stg_i++){	// loop over all the stage matrices
					ptrLB = findexternal(sprintf("spd_lb%f", stg_i))
					(*ptrLB)[simNo,] = res[.,stg_i]'

				}
			}
			else if(simNo==bktSz){	// if this is the last item in the bucket, clone it once full to generate the UB bucket		// (trying to help with code's efficiency by breaking this into a separate conditional (instead of nesting it within a <=, where it'd be evaluated every time)				
				for(stg_i=1; stg_i<=nStgs; stg_i++){	// loop over all the stage matrices
					
					ptrLB = findexternal(sprintf("spd_lb%f", stg_i))
					(*ptrLB)[simNo,] = res[.,stg_i]'
				
					// sort each column from low to high (will only need to do once, thankfully)
					*ptrLB = _colIndpSort(*ptrLB)
					
					// generate the UB bucket
					rmexternal(sprintf("spd_ub%f", stg_i))
					ptrUB = crexternal(sprintf("spd_ub%f", stg_i))			// creates object named (in Stata code) spd_lb`i'
					*ptrUB = *ptrLB		
				}
			}
			else{					// if buckets are full, check the swap rules; swap as needed		
				for(stg_i=1; stg_i<=nStgs; stg_i++){	// loop over all the stage matrices
				   // For LB: if this sim's draw < max(LB bucket), replace one element containing max(LB bucket) with this sim's draw
					// max: will be in last row, given sort
					ptrLB = findexternal(sprintf("spd_lb%f", stg_i))
					
					// I'd love to do this without sorting again.  But for now.			
					// Would also love to do this in a way that's more readable.  
                    // Trying to go for speed, though, and thus, not creating extra objects.
					// So read your comments CAREFULLY
					(*ptrLB)[bktSz, selectindex(res[.,stg_i]' :< (*ptrLB)[bktSz,])				// in the bucket matrix's last row...										
							] = 																	// for the columns in which this sim's draw is less than the bucket's max
							 res[.,stg_i]'[,selectindex(res[.,stg_i]' :< (*ptrLB)[bktSz,])]			// replace those columns with the draws.  Specifically:
																										// Pull the sim draw, put it into a row		(nofed[j..j+8-1,i+2]')
					*ptrLB = _colIndpSort(*ptrLB)  // re-sort											// Of that now-row, select the columns in which this sim's draw is less than bucket's max ([,selectindex(nofed[j..j+8-1,i+2]' :< (*ptrLB)[bktSz,])])
		
					
				   // For UB: if this sim's draw > min(UB bucket), replace one element containing min(UB bucket) with this sim's draw
					// min: will be in first row, given sort
					ptrUB = findexternal(sprintf("spd_ub%f", stg_i))
					(*ptrUB)[1, selectindex(res[.,stg_i]' :> (*ptrUB)[1,])							// in the bucket matrix's first row...
							] =																			// for the columns in which this sim's draw is more than the bucket's min
							res[.,stg_i]'[,selectindex(res[.,stg_i]' :> (*ptrUB)[1,])]					// replace those columns with the draws.  Specifically:
																											// Pull the sim draw, put it into a row		
					*ptrUB = _colIndpSort(*ptrUB)  // re-sort												// Of that now-row, select the columns in which this sim's draw is more than bucket's min ([,selectindex(nofed[j..j+8-1,i+2]' :> (*ptrUB)[1,])])

				} // end stg matrix loop		
			} // end bucket fill if/elses
		} // end large conventional post vs. speed if/else
		
		// *** DISPLAY MESSAGES ***
		if(noiYN==1){ // making sure qui's not specified
			// display done at end of sim bracket 
			if(( (c("processors")>1 & verbose=="") | terse!="") & percComplete==100 & shoutOnce100==0){					// multicore: display 'done' once, at the end of everything.
				_stata(`"noi di as ye "done!""')
				shoutOnce100 = 1
			}
			
			// *** DISPLAY MESSAGES ***
			if( ( (c("processors")==1 & terse=="") | ((c("processors")>1 & verbose!="")) ) ){		// single core: display 'done' at end of each sim, via a period.
				_stata(`"noi di as wh "done!""')
			}
		}

	} // sim loop
		
	// Simulations now done: process.
	if(speed!=""){
		// MEAN
		res_mega = res_mega :/ nSims

		// CIs
		for(stg_i=1; stg_i<=nStgs; stg_i++){	// loop over all the stage matrices, one last time
			ptrLB = findexternal(sprintf("spd_lb%f", stg_i))
			if(stg_i!=1)	resFinal = resFinal, res_mega[,stg_i], (*ptrLB)[bktSz,]'
			else			resFinal = res_mega[,stg_i], (*ptrLB)[bktSz,]'
			
			ptrUB = findexternal(sprintf("spd_ub%f", stg_i))
			resFinal = resFinal, (*ptrUB)[1,]'		
		}

		resFinal = tptsSet, resFinal

		// Keep the integers only
		resFinal = resFinal[selectindex(mod(resFinal[,1],1):==0),] 
		
	} // end speed result process
	
} // function end

end
********************************************************************************************************************************	
// Function to take path output and convert it into stage output
cap program drop path2stage
program path2stage
{
	syntax, Paths(string) Stages(string) Names(string) SIM(integer) TMax(real) [Append(string) FOLDer(string) FHORZ(string) BForce(string)]
		// don't need to add anything fancy with conditions for append, because everywhere this function's called that 
		// requires conditionality, the function itself's already called inside an if to enforce that conditionality
	
	local tmax = floor(`tmax')	// coerce into integer, if not already.
	
	preserve
		use "`paths'", clear
		
		// toss any duplicates in the path output.
		gduplicates drop *, force 
		save "`paths'", replace
		
		
		** KEY: exploit Stata's panel stuff.  (this, too, we can probably also write in Mata, eventually)

		//	For reference, output matrix columns:
			*	simNo		subj		t		stg
			*	simNo_outpt	subj_outpt	t_outpt	stg_outpt  <- tempnames
		
		tempname simNo_outpt	subj_outpt	t_outpt	stg_outpt flag_outpt
		
		// The names are being dumb, because they're defined in the larger program locally, so they don't scope to here.  So, just manually rename to what you need.
		local counter = 1
		local origNames = ""
		foreach v of varlist *{
			// create a list of the current varnames, because you'll have to reverse everything when you get to the bigger program.
			local origNames = "`origNames' `v'"
			
			if(`counter'==1){
				rename `v' `simNo_outpt'
				label variable `simNo_outpt'	"Sim number ID"
			}
			else if(`counter'==2) {
				rename `v' `subj_outpt'
				label variable `subj_outpt'		"Subject ID"
			}
			else if(`counter'==3){
				rename `v' `t_outpt'
				label variable `t_outpt'		"Time"
			}
			else if(`counter'==4){
				rename `v' `stg_outpt'
				label variable `stg_outpt'		"Subject's occupied stage @ t's end"
			}
			else if(`counter'==5){
				rename `v' `flag_outpt'
				label variable `flag_outpt'		"INTERNAL: flag"
			}
			
			local `counter++'
		}
		
		// see if there are non-integer failure times.
		tempvar intCheck
		gen double `intCheck' = mod(`t_outpt',1)
		
		qui sum `intCheck'
		if(`r(max)'>0){
			// If so, ceil() them, and keep the last transition that occurs in a 
            // particular unit interval (in case there are multiples)/.
			// 		*Has* to be ceil, because if there's a transition in the 
            //      start-stop interval (e.g.) (0.9,1], you want to know where 
            //      the subject is *at the end of 1* (i.e., the integer ending 
            //      the interval (0,1]).  If you floor() it, that start-stop 
            //      interval won't be grouped with the transitions occurring 
            //      between 0-1, as it should be, but instead, it'll be (incorrectly) 
            //      grouped with the transitions on the interval (1,2].
			//
			// Also be sure to save a message for the user.
			
			// ceil it.
			tempvar ceiled
			gen `ceiled' = ceil(`t_outpt')  
			
				// If multiple transitions occur within a unit interval, keep 
                // the LAST observed transition only.
				bysort `simNo_outpt' `subj_outpt' `ceiled' (`t_outpt'): keep if(_n==_N)
			
			// message
			local nonIntFailTimes 	= "You have transitions at non-integer failure times.  This does not affect how the simulations are executed, and the final results are still correct, but these results are less fine-grained.  They can only be displayed with integer times."
			local nonIntFailTimes2 	= "Specify {bf:path()} in your {bf:mstsample} statement to see the exact non-integer times at which your transitions occur." 
			
			// put in the integer'd times into the time var
			replace `t_outpt' = `ceiled'
			
			drop `ceiled'
		}
		drop `intCheck'
		

		// panel exploit
		tempvar tempID
		gegen `tempID' = group(`simNo_outpt' `subj_outpt')
		
		// just brute force the duplicates to leave. 
		qui gduplicates drop `tempID' `t_outpt', force
		
		// get all obsv
		xtset `tempID' `t_outpt'
		
		// if bforce, implement fix from comment below
		if("`bforce'"!="")	bysort `tempID'  (`t_outpt'): keep if(_n==_N | _n==_N-1)
			
		// sort as appropriate, depending on whether forward or fhorz	
		if("`fixedh'"=="")	sort   `tempID'  `t_outpt'
		else				gsort +`tempID' -`t_outpt'
		
		tsfill, full
			
		// fill the missing stuff
		tempvar orig tempPanels
		gen `orig' = `simNo_outpt'!=.
		gen `tempPanels' = sum(`orig')

		foreach x in simNo subj stg {
			tempvar max
			qui bysort `tempPanels' (`t_outpt'): gegen `max' = max(``x'_outpt')
			qui replace ``x'_outpt' = `max' if(``x'_outpt'==.)
			qui drop `max'
		}
		
		cap drop `tempID'
		cap drop `orig'
		cap drop `tempPanels'
		
		// If brute force is specified, toss everything that's not the end.	
		if("`bforce'"!="")	keep if(`t_outpt' >= `tmax' - 1)
		
		// Re-rename everything
		tokenize "`origNames'"
		local counter = 1
		foreach v of varlist *{
			if(`counter'==1)		rename `v' `1'
			else if(`counter'==2)	rename `v' `2'
			else if(`counter'==3)	rename `v' `3'
			else if(`counter'==4)	rename `v' `4'
			else if(`counter'==5)	rename `v' `5'
			
			local `counter++'
		}
        //compress        // would like to be able to compress here, but would be too much hassle, long story short.
        save "`stages'", replace
        
		if("`append'"!=""){
			if(`sim'>1)		append using `append'
			save `append', replace
		}
		
		if("`folder'"!=""){
			cap confirm new file "`folder'`c(dirsep)'sim`sim'.dta"
			if(_rc==0) {
				save "`folder'`c(dirsep)'sim`sim'.dta"
			}
			else{
				local nonUnique = 1
				
				while(`nonUnique'==1){
					local rand = runiformint(0,10000)		// eh--not perfect, but there's no helping it, at this exact moment (rngstate will be same, for every run through, if the user's set seed right before mstsample's called)
					
					cap confirm new file "`folder'`c(dirsep)'sim`sim'_`rand'.dta"
					if(_rc==0) {
						save "`folder'`c(dirsep)'sim`sim'_`rand'.dta"
						local nonUnique = 0
					}
				}
			}
		}
		
	restore
}
end
********************************************************************************************************************************	
// Function to take stage output and convert it into counts (didn't do proportions/percents because of the messiness with the possible path/gen opts)
cap program drop stage2counts
program stage2counts
{
	syntax, Stages(string) Counts(string) TMAX(real) SIM(integer) [Append(string) FHORZ(string)]
		// don't need to add anything fancy with conditions for append, because 
        // everywhere this function's called that requires conditionality, the 
        // function itself's already called inside an if to enforce that conditionality
		
	local tmax = floor(`tmax')	// coerce into integer, if not already.	
	
	preserve
		use "`stages'", clear
		
		tempname simNo_outpt	subj_outpt	t_outpt	stg_outpt flag_outpt
		
		// The names are being dumb, because they're defined in the larger 
        // program locally, so they don't scope to here.  So, just manually 
        // rename to what you need.
		local counter = 1
		local origNames = ""
		foreach v of varlist *{
			// create a list of the current varnames, because you'll have to 
            // reverse everything when you get to the bigger program.
			local origNames = "`origNames' `v'"

			if(`counter'==1){
				rename `v' `simNo_outpt'
				label variable `simNo_outpt'	"Sim number ID"
			}
			else if(`counter'==2) {
				rename `v' `subj_outpt'
				label variable `subj_outpt'		"Subject ID"
			}
			else if(`counter'==3){
				rename `v' `t_outpt'
				label variable `t_outpt'		"Time"
			}
			else if(`counter'==4){
				rename `v' `stg_outpt'
				label variable `stg_outpt'		"Subject's occupied stage @ t's end"
			}
			else if(`counter'==5){
				rename `v' `flag_outpt'
				label variable `flag_outpt'		"INTERNAL: flag"
			}
			
			local `counter++'
		}
		
		//tempvar counts
		qui gcontract `simNo_outpt' `t_outpt' `stg_outpt', freq(counts) zero

			
		* put into wide
		qui greshape wide counts, i(`simNo_outpt' `t_outpt') j(`stg_outpt')
		drop if `t_outpt' >= `tmax'		// weak inequality, since you're working with tMax_inputted, which = tmax + 1
		
		* jic sort, to keep things tidy for the merge.
		if("`fhorz'"=="")		sort  `simNo_outpt'  `t_outpt'
		else				   gsort +`simNo_outpt' -`t_outpt'
	
		// Re-rename everything
		tokenize "`origNames'"
		local counter = 1
		foreach v of varlist *{
			if(`counter'==1)		rename `v' `1'
			else if(`counter'==2)	rename `v' `3'
			
			local `counter++'
		}
		
		save "`counts'", replace
		
		if("`append'"!=""){
			if(`sim'>1)	append using `append'	// adds count results to countAll	(which you'll always need to do, really.  Kept syntax like this just to keep the same formatting as path2stage)
			save `append', replace
		}
		
	restore
}
end
********************************************************************************************************************************	
// The difference function (same as diff in R)
cap mata: mata drop diff()
mata:	
real colvector diff(real colvector x)
{
	real colvector ub
	real scalar i
	real scalar xRow
	
	ub = J(rows(x),1,0)	// create empty vector that's as long as what you passed in.
	
	x = 0 \ x			// append a zero at the front to make the first obsv. behave
	
	xRow = rows(x) // for speed gains, given how Mata compiler works
	for (i=2;i<=xRow;i++){  
		ub[i-1] = x[i] - x[i-1]
	}
	
	return(ub)
}
end	
********************************************************************************************************************************	
// The cumulative product function (same as cumprod in R)
cap mata: mata drop cumprod()
mata:	
	real colvector cumprod(real colvector x)
	{
		real colvector ub
        real scalar i
		real scalar xRow
		
		ub = J(rows(x),1,0)		// create empty vector that's as long as what you passed in.
		
		ub = 1 \ ub				// append a one at the front to make the first obsv. behave
		
		xRow = rows(x) // for speed gains, given how Mata compiler works
		for (i=1;i<=xRow;i++){  
			ub[i+1] = x[i] * ub[i]
		}
			
		ub = ub[2..length(ub)]
		return(ub)
	}
end
********************************************************************************************************************************	
// ms_setdiff: The difference-in-sets function (similar to setdiff in R)
//   There's almost certainly a better way to implement this, speed-wise.  Given 
//   the situations where it'll be invoked, though, (shrug).
//
// NOTE: this coding is specialized to the situation.  Specifically, it exploits
//       the fact that var2 is always going to be a subset of var1 when it's called
//       from within the main program.

cap mata mata drop ms_setdiff()
mata:
	transmorphic colvector ms_setdiff(transmorphic colvector var1, ///
                                      transmorphic colvector var2)
    // var1: variable containing values (either numeric or string)
    // var2: variable containing values (either numeric or string)
{    
    // Initialize holders
    transmorphic colvector stack, uniqs
    real colvector frqs 
    
    // Stack the two 
    stack = uniqrows(var1) \ uniqrows(var2)

    // Get freq table
    frqs = mm_freq(stack)

    // Get uniq list for later
    uniqs = uniqrows(stack)
    
    // Vals appearing only once are those missing from var2, given the applic here.
    return(uniqs[selectindex(frqs:!=2)])
}
end
********************************************************************************************************************************	
// The column independent sort function
// Given a multicolumn matrix, sorts each of matrix's columns individually from 
// low to high, as if they were mere colvectors
cap mata mata drop _colIndpSort()
mata:
	real matrix _colIndpSort(real matrix x)
	{
		real scalar nCols
		real matrix holder
		real scalar i 
		
		nCols = cols(x)
		for(i=1;i<=nCols;i++){
			if(i!=1)	holder = holder, sort(x[,i],1)
			else		holder = sort(x[,i],1)
		}
		
		return(holder)
	}
end
********************************************************************************************************************************	
// The Hazsample Mata function
cap mata: mata drop _Hazsample()
mata:
real scalar _Hazsample(	real matrix info, 	 // has t, from, to, overallSurv
						real matrix curT,	 // current time
						real matrix current, // current stage
						string fixedh	 	 // whether this is fixedh or not 
					   ){
	
	real matrix info2
	real colvector to
	real colvector tm
	real colvector surv
	real colvector w
	real scalar winner

	// The matrix's rows are uniquely IDed by t-from-to triple. 
	// For this sampling bit, we only need unique t-from pairs.
	// Toss the duplicates from the t-from pairs by picking an arbitrary (but 
    // valid) to, given current stg and time.
	
	// get correct time points and survivors for THIS transition --AND-- only 
    // keep rows for time greater than current
	info2 = info[selectindex(info[,2]:==current), ] 	// current stage


	// if the matrix is empty, then there are no rows meeting the above criteria.
	// That will happen if you are at tMax, and no transitions occur at that time.
	// If this occurs, then simply return . and skip the rest of the function.
	if(rows(info2)==0){
		return(.)
	}
	else{
		// pick arbitrary to stage, from the current stage, to get unique rows for sampling.
		to = uniqrows(info2[,3]) // get the unique list, and just arbitrarily use the first value in the vector to toss duplicates 
			info2 = info2[selectindex(info2[.,3]:==to[1,1]), ]	// subsetting big matrix for arbitrary to

		//*** REQ INPUT QUANTS ***
		// TIME
		tm = info2[,1] \ .	// with missing on end for no transition/stays put

		// OVERALL SURV
		surv = info2[,4]
		
		// Get the difference, *then* subset those greater than current time.  *Then* sample.
		if(fixedh!="") {
			w = (info2[,5] \ (1-colsum(info2[,5])))
		}
		else {
			w = diff(1 :- surv) \ (1-colsum(diff(1 :- surv)))	
		}				// ^ notice: b/c of surv's inclusion as last weight, there should never be an instance where all the weights are now zero.
		
		// Temp rejoin for the subset for convenience
		info2 = (tm, w)
			info2 = info2[selectindex(info2[,1]:>curT),] 	// current time (bigger than)	
				
		// Sample it.
		winner = mm_upswr(1, info2[,2] , 1)		// 2nd arg = weights matrix, with the survival probability appended at the end for the no transition/stays put instance.

		// Return winner (t*)
		return(info2[selectindex(winner),1])
	}
}
end	

********************************************************************************************************************************
// The stgSample Mata function
cap mata: mata drop _stgSample()
mata:
real scalar _stgSample( real matrix info, 	 // has t, from, to, haz
						real scalar curT,	 // current time
						real scalar current  // current stage
					  ){
	
	real matrix info2
	real colvector to
	real colvector haz
	real scalar winner
	
	// We don't need to toss duplicates based on "to," here, because
	// our interest is in randomly pulling one of these "to"s
	
	// get correct to stages and haz for this time point
	info2 = info[selectindex(info[.,2]:==current), ] 			// current stage		
		info2 = info2[selectindex(info2[.,1]:==curT), ] 		// current time			
	
	//*** REQ INPUT QUANTS ***	
	// TO STAGE
	to = info2[,3]
	// HAZARD
	haz = info2[,5]
	
	// Sample it
	winner = mm_upswr(1, haz, 1)
	
	// Return winner (next stage)
	return(to[selectindex(winner)])	
}
end	
********************************************************************************************************************************
// _postMe: Mata function to be called for posting results
cap mata: mata drop _postMe()
mata:
void _postMe(	real scalar sim,	// simNo
				real scalar subj,	// subj
				real scalar time,	// time
				real scalar stage,	// stage
				string postName,	// postname for post
				real scalar flag	// flag = 1 if observation for path, 0 othw
			)
{
	real matrix outRow
	outRow = (sim,subj,time,stage,flag)
	
	st_matrix("msOutputTemp",outRow)

	_stata("postMe, name(msOutputTemp) pname(" + postName + ")")

}
end
********************************************************************************************************************************
// postMe: Stata command, to be called within Mata function _postMe(), for posting things.
program postMe
{
	syntax, Name(string) PName(string)
	
	local sim	= `name'[1,1]
	local sbj	= `name'[1,2]
	local t		= `name'[1,3]
	local stg	= `name'[1,4]
	local flag	= `name'[1,5]
	
	post `pname' (`sim') (`sbj') (`t') (`stg') (`flag')
	
	cap matrix drop msOutputTemp
}
end
********************************************************************************************************************************
// tidy: Program to be called for housekeeping.  Tosses any extra observations 
//       created by command, in the early going.
* (Written in case I eventually realize there are other things that need tidied.)
program tidy
{
	args var1 
    
	cap drop if(`var1'==.)
    
	// sortpreserve on mstsample will return the data to original order
	
	// getting a list of Mata objects is apparently more of chore than I expected.
    
    // restore r-class memory
    _return restore $temp_mstsampleNm
    macro drop temp_mstsampleNm
}
end
********************************************************************************************************************************
// covarFill: To be called within mstsample, specifically while setting 
//            covariate values for the haz gen.
program covarFill, sortpreserve
{			
	args matrix matMeans x pairings covarNames 
		// matrix:     matrix with covariate values 
		// matMeans:   matrix with the covar means
		// x:		   current variable name
		// pairings:   the name of the variable w/unique IDs for from-to pairs
		// covarNames: string with ALL unique varnames in model, across both main + tvc
		
	
		// pull the covar value
		tempname vM vS 
		matrix `vM' = `matrix'[1,colnumb(`matrix',"`x'")]
		local `vS' =  `vM'[1,1]
		
		// pull covar mean
		tempname vM_mn vS_mn
		matrix `vM_mn' = `matMeans'[1,colnumb(`matMeans',"`x'")]
		local `vS_mn' =  `vM_mn'[1,1]
		
		// go through every from-to combo and fill
		qui glevelsof `pairings', local(trNos)	// (will be filled with from-to pairs, which will = trNos if nothing's collapsed)
		foreach tr of local trNos{
			qui _rmcoll(`covarNames') if(`pairings'==`tr'), forcedrop
			local covars_tr`tr' `r(varlist)'
		
			if(regexm("`covars_tr`tr'' ", "`x' ")){
				replace `x' = ``vS'' - ``vS_mn'' if(`pairings'==`tr')
			}
			// no: leave equal to 0
			else{
				replace `x' = 0 if(`pairings'==`tr')
			}
		}
		
} // for bracket collapse in editor
end
********************************************************************************************************************************
// covarDemean: To be called within mstsample, specifically while demeaning the covariates for the stcox reest, to get best poss estimates of H0
program covarDemean, sortpreserve
{			
	args matMeans x newX pairings covarNames dirOpt 
		// matMeans:   matrix with the covar means
		// x:		   current variable name
		// newX:	   name for new variable containing the demeaned values
		// pairings:   the name of the variable w/unique IDs for from-to pairs
		// covarNames: string with ALL unique varnames in model, across both main + tvc
		// dirOpt:	   "dem" = demeaning the vars; "rem" = re-meaning (= readding mean)
		
		// Demeaning or remeaning?
		if("`dirOpt'"=="dem")		local dir = -1
		else if("`dirOpt'"=="rem")	local dir = 1
		else{
			noi di _n as err `"Helper function error.  Invalid {bf:covarDemean} 'dirOpt' argument.  Can only be "dem" or "rem"."'
			tidy
            exit
		}
		
		// pull covar mean
		tempname vM_mn vS_mn
		matrix `vM_mn' = `matMeans'[1,colnumb(`matMeans',"`x'")]
		local `vS_mn' =  `vM_mn'[1,1]
		
		// go through every transition and fill		
		qui glevelsof `pairings', local(trNos)			
		foreach tr of local trNos{					
			qui _rmcoll(`covarNames') if(`pairings'==`tr'), forcedrop
			local covars_tr`tr' `r(varlist)'
		
			if(regexm("`covars_tr`tr'' ", "`x' ")){
				cap gen double `newX' = `x' + `dir'*``vS_mn'' if(`pairings'==`tr')		// if dir is -1, will subtract mean.  If dir is +1, will add mean.
				if(_rc!=0)	replace `newX' = `x' + `dir'*``vS_mn'' if(`pairings'==`tr')
				recode `newX' (.=0)		// for the other transitions
			}
		}
	
	compress `newX'
	
} // for bracket collapse in editor
end
********************************************************************************************************************************
// Create JIC file name
cap prog drop jicFileNm
prog define jicFileNm, rclass
{
    // Today's date, in ddMMMyy form
        //day
        local day = word("`c(current_date)'", 1)
        local length = length("`day'")
        if(`length'==1){							// add a 0 if the date is one digit
            local day = "0`day'"
        }	
        
        //month
        local month = word("`c(current_date)'", 2)	// get corresp Aaa abbreviation
        local month = upper("`month'")				// capitalize so it's AAA

        //year (2-digit)
        local year = word("`c(current_date)'", 3)
        local year = substr("`year'",-2,.) 
        
    local date = "`day'`month'`year'"
    ****************************************
    // filename without the dta
    * get fName only first (easiest to do in Mata)
    tempname tkns
    mata: `tkns' = tokens("`c(filename)'","\/")
    * throw back to Stata
    mata: st_local("fName", subinstr(`tkns'[cols(`tkns')], ".dta", "", .))
    local fName = strtoname("`fName'")
    mata: mata drop `tkns'
    ****************************************
    // Current time
    local fTime = subinstr("`c(current_time)'",":","",.)

    // And just to absolutely ENSURE this is a unique name
    tempname closer
    return local fileNm "path_`fName'_`date'_`fTime'`closer'"
    return local date "`date'"
    
} // for bracket collapse in editor
end
********************************************************************************************************************************
// For H0 or S0, fill the value forward for trans-_t pairings where no fail occurs
cap program drop fillForward
program define fillForward
qui{
    syntax [, Timevar(varname) Failvar(varname) QOI(varname) TRansvar(varname) SURV ID(varname)]
    
    // Fill zeros first
    tempvar runCntT runCnt HazMax2 
    bysort `transvar' (`timevar' `id'): gen `runCntT' = sum(`failvar')     // needs to be trans, not thePairings, or else collapsed trs won't calc properly
    bysort `transvar' `timevar' (`id'): gegen `runCnt' = max(`runCntT')    // need this b/c if there are multiple obsvs for a _t (e.g., collapsed trs), there's a chance `runCntT' won't reflect the quantity you intend
    
    replace `qoi' = cond("`surv'"=="", 0, 1) if(`runCnt'==0)        // if surv option specified, is s0.  Otherwise, is H0. 
    
    // See how many missings we have
    count if `qoi'==.
    local nMiss = `r(N)'

    while(`nMiss'>0){
        // Fill
        bysort `transvar' (`timevar' `id'): replace `qoi' = `qoi'[_n-1] if(`qoi'[_n-1]!=. & `qoi'==.)
    
        // Recount
        count if `qoi'==.
        local nMiss = `r(N)'
    }
}
end
********************************************************************************************************************************
// Helper option to reset stset to original settings, before any stsplit-related manips
cap prog drop reset_stset
program define reset_stset
qui{
        syntax, [ID(string)]
        
        local stID_ch `id'
        
        * time (or else will show up as _t when you stset, which isn't helpful)
        local st_t:			char _dta[st_bt]
        
        * failure
        local st_d:			char _dta[st_bd]
        local st_dNums:		char _dta[st_ev]
            if("`st_dNums'"!="")	local st_dNums = "==`st_dNums'"
            
        * if/weight
        local st_ifexp: 	char _dta[st_ifexp] 
            if("`st_ifexp'"!="")	local st_ifexp = "if(`st_ifexp')"
        local st_weight:	char _dta[st_w]
        
        * multiple_options (since most extensive): 13 possibilities
        local st_scale:		char _dta[st_bs] 
        local st_enter: 	char _dta[st_enter]
        local st_exit : 	char _dta[st_exit] 
        local st_origin: 	char _dta[st_orig] 
        local st_ifopt: 	char _dta[st_if] 
        local st_ever: 		char _dta[st_ever] 
        local st_never: 	char _dta[st_never] 
        local st_after: 	char _dta[st_after] 
        local st_before: 	char _dta[st_befor] 
        local st_bt0: 		char _dta[st_bt0] 
        local st_show:		char _dta[st_show]
        
        stset, clear    // to ensure id() clears
        
        // re-stset
        stset `st_t' `st_ifexp' `st_weight' , 				///
                    failure(`st_d'`st_dNums') id(`stID_ch') ///
                    scale(`st_scale')	enter(`st_enter') 	///
                    exit(`st_exit')		origin(`st_origin') ///
                    ever(`st_ever')		never(`st_never') 	///
                    after(`st_after')	before(`st_before') ///
                    time0(`st_bt0') 	if(`st_ifopt') 		///
                    `st_show' 	
}
end
