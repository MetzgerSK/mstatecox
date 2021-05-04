/*	mstphtest, v2
	12SEP17
	
	Author: Shawna K. Metzger
	shawna@shawnakmetzger.com
	
	A wrapper function to run PH tests from a multi-state model, which requires
	that each strata be run separately.
	
	Requires that stcox is run first, then mstutil.
	
	* v2: rewrite to deal with possibility that collapsed covariate effects might exist.
*/

*! Last edited: 12SEP17 (no changes for MAR19 update)
*! Last change: rewrite to deal with possibility that collapsed covariate effects might exist.
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
			
				// if there's robust/cluster, you need to override the estimated VCE matrix [15SEP17]
				* NOTE: currently won't work, because with how Stata calculates Schoenfelds, will revert back to original VCE matrix.
				cap matrix drop `skm_vSubset'
				tempname skm_vSubset
				
				matrix `skm_vSubset' 	= `skm_V'		// to not touch the original
				
				if("`vce'"!="oim"){			
					cap matrix drop `skm_vSubset_mb'
					tempname skm_vSubset_mb
					
					matrix `skm_vSubset_mb' = `skm_V_mb'	// to not touch the original
					
					local vceExtra_mb = "vmodel(`skm_vSubset_mb')"
				}
				
				
				// See if the col list for skm_bSubset is different from the overall list
				local missings: list namesB - eqCovars	// namesB = overall, eqCovars = this specific transition/stratum 
			
				// if missings has elements, remove those from the skm_vSubset matrix
				if("`missings'"!=""){
					foreach m of local missings{
						rmv_rowCol, mat(`skm_vSubset') 	  var("`m'")
						if("`vce'"!="oim")	rmv_rowCol, mat(`skm_vSubset_mb') var("`m'")
					}
				}

				force_vce_repost, v(`skm_vSubset') type("`vce'") `vceExtra_mb'
				qui stcox, nohr
			
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
	cap matrix drop `skm_b' `skm_V' `skm_tvc' `skm_bSubset' `skm_vSubset'
	cap matrix drop `skm_V_mb' `skm_vSubset_mb'
	
	_estimates unhold origCox
	return clear
}
end
**************************************************************
// To possibly deal with the SE issue
cap program drop force_vce_repost
program define force_vce_repost, eclass
{
	syntax , Vce(string) TYPE(string) [VMODel(string)]

	// stash the inputted matrix
	tempname holder
	matrix `holder' = `vce'
	
	ereturn repost V=`vce'
	matrix `vce' = `holder'
	
	if("`type'"!="oim"){	// if not OIM, also overwrite V_modelbased **WITH** the new V matrix.  (to see if it replicates R, at the moment.)
		tempname holder2
		matrix `holder2' = `vmodel'
		ereturn matrix V_modelbased = `vmodel'
		matrix `vmodel' = `holder2'
		cap matrix drop `holder2'
	}
	
	// make sure the inputted matrix still exists
	matrix `vce' = `holder'
	cap matrix drop `holder'
}	
	
end
**************************************************************
// To remove row/column of a square matrix
cap program drop rmv_rowCol
program define rmv_rowCol
{
	syntax, Mat(string) VAR(string)
		// Input: name of matrix, name of variable whose columns should be removed from matrix
		// Output: same matrix, but without the row/col for that variable
		
	// Make sure matrix's symmetric
	local nRows = rowsof(`mat')
	local nCols = colsof(`mat')
	
	if(`nRows'!=`nCols'){
		noi di as err "rmv_rowCol helper function only works on symmetric matricies.  Yours is `nRows'x`nCols'.  Try again."
		exit 503
	}
	
	// Place to temp hold the results before posting
	cap mat drop `holder'
	tempname holder
	
	mat `holder' = `mat'
	
	// Find index location for this var
	local idx = colnumb(`holder',"`var'")	// will be same for both rows and columns, because (1) symmetric and (2) it's how Stata generates the VCE, by default.
	
	// For both the rows and the columns:
		* split the matrix in half: what comes before this column, and what comes after.
		* rejoin those two halves
	
	local slice1_end = `idx'-1 //max(1,`idx'-1)				// so that if something's the first element in the list, we won't get zeros
	local slice2_beg = `idx'+1 // min(`nCols',`idx'+1)		// so that if something's the last element in the list, we won't get an out-of-range index
	//	if(`slice1_end'<1)	local slice2_beg = `idx'	// if it's the first one in the matrix, then the second slice must start
	
	
	// you tried to be all elegant in how you did this, but just brute force it, because I'm tired of dealing with 505s.
	
	** COLUMNS
	tempname slc1 slc2
	if(`idx'>1 & `idx'<`nCols'){	
		// removing column first								// if it's not the first column, then we have a first slice
		matrix `slc1' = `holder'[.,1..`slice1_end']				// if it's not the last column, then we have a second slice
		matrix `slc2' = `holder'[.,`slice2_beg'..`nCols']
		
		// rejoin (just to prevent human idiocy, with the nullmats acknowledging things may not exist)
		matrix `holder' = nullmat(`slc1'), nullmat(`slc2')
	}
	else if(`idx'==1){											// it's the first column, so no first slice				
		matrix `slc2' = `holder'[.,`slice2_beg'..`nCols']
		
		// rejoin (just to prevent human idiocy, with the nullmats acknowledging things may not exist)
		matrix `holder' = nullmat(`slc2')
	}
	else{														// it's the last column, so no second slice
		matrix `slc1' = `holder'[.,1..`slice1_end']		

		// rejoin (just to prevent human idiocy, with the nullmats acknowledging things may not exist)
		matrix `holder' = nullmat(`slc1')
	}

	

	** ROWS
	tempname slc1 slc2 
	if(`idx'>1 & `idx'<`nCols'){							// if it's not the first row, then we have a first slice
		matrix `slc1' = `holder'[1..`slice1_end',.]			// if it's not the last row, then we have a second slice
		matrix `slc2' = `holder'[`slice2_beg'..`nCols',.]
		
		// rejoin (just to prevent human idiocy, with the nullmats acknowledging things may not exist)
		matrix `holder' = nullmat(`slc1')\ nullmat(`slc2')	
	}
	else if(`idx'==1){										// it's the first row, so no first slice					
		matrix `slc2' = `holder'[`slice2_beg'..`nCols',.]
		
		// rejoin (just to prevent human idiocy, with the nullmats acknowledging things may not exist)
		matrix `holder' = nullmat(`slc2')
	}
	else{
		matrix `slc1' = `holder'[1..`slice1_end',.]			// it's the second row, so no second slice

		// rejoin (just to prevent human idiocy, with the nullmats acknowledging things may not exist)
		matrix `holder' = nullmat(`slc1')	
	}
	
	// post to the old matrix and be done
	mat `mat' = `holder'
	
	** housekeep
	cap mat drop `holder'
	cap mat drop `slc1'
	cap mat drop `slc2'
	
}
end
