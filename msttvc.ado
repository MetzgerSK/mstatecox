// msttvc: allows advanced users to bypass stcox's tvc() and texp() options, but still include time-interacted covariates, for large datasets.  If you have no idea what you're doing, you probably shouldn't be using this workaround.
	** presupposes that user has already stset AND that they've already stcox'd (AND stsplit, AND generated interactions, AND included the interactions + other vars in the stcox).
// ** part of mstatecox package
// ** see "help mst" for details

*! Last edited: 23JUN22
*! Last change: inserted version stmt, r-class mem preserve
*! Contact: Shawna K. Metzger, shawna@shawnakmetzger.com
	
cap program drop msttvc
program define msttvc, eclass
    version 14.2
local noiYN = `c(noisily)'	// Did user specify qui?  (Must do here b/c if you query within the qui block, you'll get 0, every time.)

qui{
	syntax , TVC(varlist) TEXP(string)
	
	// Make sure stcox's been run
	if("`e(cmd2)'"!="stcox" ){
		local extra = ""
		if("`sdur'"==""){
			local extra ="with strata "
		}
		noi di as err "You must estimate {bf:stcox} before running {bf:msttvc}.  Try again."
		exit 198
	}
	
	// Provide general warning
	if(`noiYN'==1)	noi di as red _continue "!! - CAUTION." 
	noi di as gr "  {bf:msttvc} will set stcox's e(tvc) and e(texp) equal to the contents of {bf:msttvc}'s {bf:tvc()} and {bf:texp()} options, respectively."
	noi di as gr _col(16) "It will also repost the coefficient and VCE matrices, with the naming conventions {bf:mstsample} is expecting."
	noi di ""
	noi di as gr _col(16) "You should be using this workaround only if:"
	noi di as gr _col(24) "(a) {bf:stcox} is taking a while to run with {bf:tvc()}/{bf:texp()} specified; and"
	noi di as gr _col(24) "(b) you are adept with Cox models, and understand how to {bf:stsplit} stratified" 
    noi di as gr _col(24) "    data and generate the subsequent interaction terms properly."
    
	// Preserve any results in return list
    tempname retPres
    _return hold `retPres'

	// You now need to figure out what's a TVC and what isn't, so you can repost e(b) with the proper equation names
	tempname skm_b skm_v
	matrix `skm_b' = e(b)
	matrix `skm_v' = e(V)	// Almost positive this won't matter for mstsample, but to be cautious.
	
	local namesAll: colnames `skm_b'
	local names_noInt = "`namesAll'"
	local names_int = ""
	local root = "`namesAll'"
	
	local namesTVC `tvc'
	foreach v of local namesTVC{
		tempvar `v'TVC
		
		qui gen double ``v'TVC' = `v' * `texp'
		
		local tvcStr = "`tvcStr' ``v'TVC'"
		
		// Find the variable it's collinear with--this is going to be the interaction
		local found = 0
		foreach x of local names_noInt{
			qui count if(`x'!=``v'TVC')			// DOUBLE. this does presuppose that the user wasn't messy with the generate.
				local double = `r(N)'
			qui count if(`x'!=float(``v'TVC'))	// FLOAT.  in case the user didn't specify double, and therefore only has float precision.
				local float = `r(N)'
			
			// If either of those ==0, we have a match.
			if(`double'==0 | `float'==0){
				// save the user's name for this interaction to the list
				local names_int = "`names_int' `x'"
				
				// remove the interaction from the running covariate list
				local names_noInt: list names_noInt - x
				
				local found = 1
				
				local root = subinword("`root'", "`x'", "`v'", .)
				
				// jump back to the bigger TVC foreach
				continue, break 
			}
			
		} // end running non-interaction covariate loop
		
		// If there's really nothing, kick an error and exit.  Keep variable in dataset for user to examine.
		if(`found'==0){
			cap gen double msttvc_`v'TVC = ``v'TVC'
			if(_rc!=0){
				tempname sufx
				cap gen double msttvc_`v'TVC`sufx' = `v'`TVC'
				
				if(_rc!=0)	local noGen = "Could not save {bf:msttvc}'s generated interaction term to the dataset due to a name conflict."
			}
			noi di as err "No covariate found for `v''s interaction with `texp'."
			if("`noGen'"=="") 	noi di as err "{bf:msttvc}'s generated interaction term saved as " as ye "msttvc_`v'TVC`sufx'" as re "."
			else				noi di as err "`noGen'"
			noi di as err "Please check the model's included covariates and try again."
			
            _return restore `retPres'
            exit 198
		}
	} // end tvc loop	
	
	// Now that you know who the interactions are, relabel (and reorder) the e(b) matrix
	* Because of Stata's charm, you can't do this piecemeal.  You have to give the new coleqs in one swoop, in one string, with one command.  So, go through and match.
	local colEqs = ""
	foreach x of local namesAll{
		local interact: list x in names_int
		
		* if there's a match, it has to be a TVC.  
		if(`interact'==1)	local colEqs = "`colEqs' tvc"
		* if no match, it has to be a regular var.
		else				local colEqs = "`colEqs' main"
	}
	
	// get matrix eqs right
	matrix coleq `skm_b' = `colEqs'
	matrix coleq `skm_v' = `colEqs'
	matrix roweq `skm_v' = `colEqs'
	
	// get the TVC names right, or else mstsample will go nuts.
	* frick, can't just append root to end, because all TVCs may not be at end.  (sighs)
	
	// Ensure TVC are at end of varlist.
	// Otherwise, mstsample will return slightly off estimates.
	if(regexm("`colEqs'","tvc main")){
		noi di as err "All TVCs are not grouped at end of varlist."
		noi di as err "Please reestimate stcox, with all the interactions listed last in the varlist."
		_return restore `retPres'
		exit 198
	}
	
	matrix coln `skm_b' = `root'
	matrix coln `skm_v' = `root'
	matrix rown `skm_v' = `root'
	
	// adjust the b and vce matrices
	ereturn repost b = `skm_b' V = `skm_v',  rename
	
	ereturn local msttvc "1"
	
	// success message
	noi di _n as gr "{bf:msttvc} successful."
	noi di as ye " > NOTE: " as gr "{bf:msttvc} currently breaks Stata's ability to report stcox in hazard ratios **correctly**.  {bf:mstsample} is unaffected," 
	noi di as gr "         as are the untransformed coefficients if you replay the current stcox estimates with {bf:nohr}.  If you need HRs, reestimate "
    noi di as gr "         the model entirely later."
	noi di ""
    
    // Overwrite whatever's in tvc() and texp()
	ereturn local tvc  `tvc'
	ereturn local texp `texp'
    
    // Restore previous return list results
    _return restore `retPres'
    
} // for bracket collapse in editor	
end
