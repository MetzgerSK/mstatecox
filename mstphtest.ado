/*	mstphtest

	A wrapper function to run PH tests from a multi-state model, which requires
	that each stratum be run separately.
	
	Requires that stcox is run first, then mstutil.
	
	* v2.2: added offset, added noadj, added frailty warning msg
    * v2.1: removed code for VCE override
	* v2: rewrite to deal with possibility that collapsed covariate effects might exist.
*/

*! Last edited: 23JUN22
*! Last change: inserted version stmt
*! Contact: Shawna K. Metzger, shawna@shawnakmetzger.com

cap program drop mstphtest
program define mstphtest, rclass   
    version 14.2
qui{
	syntax , [log km rank time(varname) *]	// specify any estat phtest options after the comma
	
    // Unlike the other mst cmds, this one is r-class.  Like any of Stata's r-class
    // commands, what's previously in r-class memory should be gone after running
    // this command, even if there's an controlled early exit.  Ergo, no need to
    // bother with _return hold.
    
	** Make sure stcox's been run
	if("`e(cmd2)'"!="stcox"){
		local extra = ""
		if("`sdur'"==""){
			local extra ="with strata "
		}
		noi di as err "You must estimate {bf:stcox} `extra'before running {bf:mstphtest}.  Try again."
		exit 198
	}
	
	** Check to make sure data have been mstutil'd
	if("`e(from)'"==""){
		noi di as err "You must run {bf:mstutil} before running {bf:mstphtest}.  Try again."
		exit 198
	}
    
    ** build local w/all the non-plot opts in it
    local nonPlotOpts detail `log' `km' `time' `rank' //  <- only poss non-plot opts.
    
    ** If there's a frailty variable, that means there can't currently be a strata
    ** variable.  Flag that for the user (and our future selves), kick everything
    ** to the regular estat phtest routine.
    if("`e(shared)'"!=""){
    	noi di as gr "No {bf:strata()} variable present due to presence of {bf:shared()}.  Stata does not currently permit both in the same model."
        noi di as gr _n "Shifting to regular {bf:estat phtest} routine: "
        cap noi estat phtest, `nonPlotOpts'
            // push through estat phtest's regular r-class returns
            if(_rc==0)  return add
        exit
    }
    
	// Housekeep - get sample flag, covariate list, store trans name
	tempvar flag19
	gen `flag19' = e(sample)
    
	tempname skm_b skm_V
	matrix `skm_b' = e(b)
	matrix `skm_V' = e(V)
	local namesB: colnames `skm_b'
	
	// Check to make sure, first, that there aren't TVCs.  If so, kick preemptive error.
	tempvar skm_tvc
	cap matrix `skm_tvc' = `skm_b'[1,"tvc:"]
	if(_rc==0){
		noi di as err "{bf:estat phtest} is not allowed after estimation with tvc();"
		noi di as err "see {help tvc note} for an alternative to the tvc() option"
		exit 198
	}
	
	local transVar `e(trans)'

	// If there's a plot, print "FYI, ignoring" message.
    if(regexm("`options'", "plot")){
        noi di as gr "Ignoring {bf:plot()} options (not currently permitted for {bf:mstphtest}).  Will need to generate manually with {cmd:estat phtest} by looping over strata."
    }

    // Get qui/noi prefs for non-error messages that are printed in the error color
    local noiQui = cond(`c(noisily)'==1, "", "cap") // can't qui an error msg, but can cap it
    
	// Get the varlist for each strata
	qui levelsof `transVar', local(transIDs)
	
	_estimates hold origCox, restore copy
	
	// Pull the ties and VCE information, in case something odd happens (again) with passing the e()
	local ties 	 = "`e(ties)'"
	local vce 	 = "`e(vce)'"
	local vceVar = "`e(clustvar)'"	// if there's a clustering variable.
	* for noadjust option, since no other way to recover
    tokenize "`e(cmdline)'", parse(",")
	local noadj  = cond(regexm("`3'", "noadj[a-z]*"), "noadjust", "")
    
	foreach tr of local transIDs{
		/* Notice: 	Stata will just drop the irrelevant variables for every transition,
					which doesn't affect the PH testing									*/
		// Print header info (+ horz line, if anything other than first trans)
		local xtra = ""
		if("`tr' `ferest()'"!="`transIDs'")	noi di as gr "{hline}"
		else	local xtra = "_n" 			// add extra hard return before first transition header
					
		noi di `xtra' as gr "> Transition " as ye `tr'
		cap qui _rmcoll(`namesB') if(`transVar'==`tr' & `flag19'==1), forcedrop
			local eqCovars `r(varlist)'
            local rc_rmcoll = _rc
            
		if("`eqCovars'"!=""){	
			tempname skm_bSubset
			cap mat drop `skm_bSubset'
			
			// extract the parts of the bHat matrix that match what's in the list
			foreach n of local eqCovars{
				// form up new matrix
				mat `skm_bSubset' = nullmat(`skm_bSubset') \ `skm_b'[1,"`n'"]
			}
			
			mat `skm_bSubset' = `skm_bSubset''
			mat coln `skm_bSubset' = `eqCovars'
			mat rown `skm_bSubset' = "y1"

			if("`ties'"=="none")	local ties = ""		// to prevent "option none not allowed" error
            
			// Reestimate
			qui stcox `eqCovars' if(`transVar'==`tr' & `flag19'==1), 	///
					`ties' vce(`vce' `vceVar') nohr estimate ///
                    offset(`e(offset)') `noadj' ///
					matfrom(`skm_bSubset') iter(0) norefine		//<- the key part.  Reestimate using the overall model as your bHats, and don't maximize, at all. 			
			
                // NOTE: there's no frailty adjustment here because Stata currently
                // forbids the estimation of a frailty model with strata.  If that
                // changes in the future, this code will need to change.  There's
                // now a message that gets printed to the user about this in the 
                // housekeeping section.
                
			cap qui estat phtest, `nonPlotOpts'
			
			// If no error, say loudly
			if(_rc==0)				noi estat phtest, `nonPlotOpts'
			// If error, say insuff obsvs.
			if(_rc==2001)           `noiQui' di as err "Insufficient observations to compute PH test: N = `e(N)'.  Moving to next stratum..."
			// If any other error, just be generic.
			if(_rc!=0 & _rc!=2001)	noi di as err "Error in computing PH test (error code " _rc ").  Compute test manually to see the specific message."
		
			// Store table for r()
			local trL = strtoname("`tr'")	 // legal version of tr
			if(`tr'<0)	local trL = "_`trL'" // if it's a negative number, add an extra underscore
			tempname phtest`trL' global`trL'
			* covariates
			matrix `phtest`trL'' = r(phtest)
			* global test
			matrix `global`trL'' = (r(chi2), r(df), r(p))
			matrix colnames `global`trL'' = chi2 df p
			matrix rownames `global`trL'' = e(strata)==`tr'
		}
		else{
			if(`rc_rmcoll'==0) noi di _n _col(7) as gr "No covariates detected for transition " as ye `tr' as gr "."
            else{
                count if(`transVar'==`tr' & `flag19'==1)
                `noiQui' di as err "Insufficient observations to compute PH test: N = `r(N)'.  Moving to next stratum..."
            }
            noi di ""
		}
		// if not the last transition, insert blank line between this tr's output and horz line for next
		if("`ferest()'"!="")	noi di ""
	}
	
	cap drop `flag19'
	foreach mat in `skm_b' `skm_V' `skm_tvc' `skm_bSubset' `skm_vSubset'{
		cap matrix drop `mat'
	}
	
	_estimates unhold origCox
	return clear
	
	// Return table estimates as a series of matrices
	foreach tr of local transIDs{
	    local trL = strtoname("`tr'")	 // legal version of tr (will auto-include underscore @ front)
		if(`tr'<0)	local trL = "_`trL'" // if it's a negative number, add an extra underscore
	    foreach pref in "phtest" "global"{
			cap return matrix `pref'`trL' ``pref'`trL''
			cap matrix drop ``pref'`trL''
		}
	}
}
end
