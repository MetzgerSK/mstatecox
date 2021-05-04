/*	mstphtest

	A wrapper function to run PH tests from a multi-state model, which requires
	that each stratum be run separately.
	
	Requires that stcox is run first, then mstutil.
	
	* v2.1: removed code for VCE override
	* v2: rewrite to deal with possibility that collapsed covariate effects might exist.
*/

*! Last edited: 04MAY21 (no changes for MAR19 update)
*! Last change: removed code for VCE override.
*! Contact: Shawna K. Metzger, shawna@shawnakmetzger.com

cap program drop mstphtest
program define mstphtest, rclass
qui{
	syntax , [*]	// specify any estat phtest options after the comma
	
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

	// Housekeep - get sample flag, covariate list, store trans name
	tempvar flag19
	gen `flag19' = e(sample)
	
	tempname skm_b skm_V
	matrix `skm_b' = e(b)
	matrix `skm_V' = e(V)
	if("`e(vce)'"!="oim"){
		tempname skm_V_mb
		matrix `skm_V_mb' = e(V_modelbased)
	}
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
	
	// Get the varlist for each strata
	qui levelsof `transVar', local(transIDs)
	
	_estimates hold origCox, restore copy
	
	// Pull the ties and VCE information, in case something odd happens (again) with passing the e()
	local ties 	 = "`e(ties)'"
	local vce 	 = "`e(vce)'"
	local vceVar = "`e(clustvar)'"	// if there's a clustering variable.
	
	foreach tr of local transIDs{
		/* Notice: 	Stata will just drop the irrelevant variables for every transition,
					which doesn't affect the PH testing									*/
		noi di _n as gr "Transition " as ye `tr'
		qui _rmcoll(`namesB') if(`transVar'==`tr' & `flag19'==1), forcedrop
			local eqCovars `r(varlist)'
			
		
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
			
			// The 12SEP17 fix.
			qui stcox `eqCovars' if(`transVar'==`tr' & `flag19'==1), 	`ties' vce(`vce' `vceVar') nohr estimate ///
																		matfrom(`skm_bSubset') iter(0) norefine		//<- the key part.  Reestimate using the overall model as your bHats, and don't maximize, at all. 			
			cap qui estat phtest, `options' d
			
			// If no error, say loudly
			if(_rc==0)				noi estat phtest, `options' d
			// If error, say insuff obsvs.
			if(_rc==2001)			noi di as err "Insufficient observations to compute PH test: N = `e(N)'.  Moving to next stratum..."
			// If any other error, just be generic.
			if(_rc!=0 & _rc!=2001)	noi di as err "Error in computing PH test (error code "_rc").  Compute manually to see the specific message."
		}
		else{
			noi di _col(7) in gr "No covariates detected for transition " as ye `tr' as gr "."
		}
	
	}
	
	cap drop `flag19'
	foreach mat in `skm_b' `skm_V' `skm_tvc' `skm_bSubset' `skm_vSubset' `skm_V_mb' `skm_vSubset_mb'{
		cap matrix drop `mat'
	}
	
	_estimates unhold origCox
	return clear
}
end
