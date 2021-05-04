/*	mstcovar, v1.1	
	20FEB19 (adding demeaning caps for mstsample)
	
	Part of the mstatecox package for Stata.  Permits the user to set which variables
	are associated with which set of transition-specific covariates.  Also, once
	the initial list's set (as far as which variable corresponds to which trans-spec
	covars), the command will also let you set the covariate values (similar to setx).
	
	Default value = median (as of 04AUG17).
*/

*! Last edited: 20FEB19 (part of MAR19 update)
*! Last change: adding demeaning caps for mstsample
*! Contact: Shawna K. Metzger, shawna@shawnakmetzger.com

cap program drop mstcovar
program define mstcovar

local noiYN = `c(noisily)'	// Did user specify qui?  (Must do here b/c if you query within the qui block, you'll get 0, every time.)

qui{
	syntax [varname(default=none)] [if] [in] [, Names(varlist) Value(string) REPlace CLEAR]	
		// Replace: If there's already a list in memory with diff covar names.
		//			Otherwise, Stata will assume everything's the same.
		
		// CLEAR: purges all mstcovars-stored macros.  Ignores all other option.
		
	// Get the macro lists immediately.
	local macList: all globals "mstcovar*"

	// ECHO: If there's nothing specified, take it as an echo, and print everything--all covar lists and all values.
	if("`varlist'`names'`value'`replace'`clear'"==""){
		if(`noiYN'==1)	noi di _n as gr ">> " as gr "Stored Lists" as gr " <<"
		
		* List the lists
		if(`noiYN'==1){
			if("`macList'"!="")		noi macro dir `macList'
			else					noi di as re "No lists stored by mstcovar"	
		}
		
		* List covar values
		if(`noiYN'==1){
			noi di _n _n as gr ">> " as gr "Stored Covar Values" as gr " <<"
			cap confirm matrix mstcovarVals
			if(_rc!=0)		noi di as re "No covariate values stored by mstcovar"	
			else			noi matrix list mstcovarVals, noh
			
			noi di ""
		}
		exit
	}

	// CLEAR: See if it's a clear.  If so, do what it says.
	if("`clear'"!=""){
		if(`noiYN'==1) noi di as red "Clearing mstcovar lists for all variables"
		// Print what's being deleted
		if("`macList'"==""){
			if(`noiYN'==1) noi di _col(5) as gr "Done; no covar lists in memory to delete"
		}
		else{
			if(`noiYN'==1) noi di _col(5) _c as gr "Cleared: "
			foreach m of local macList{
				if(`noiYN'==1)	noi di _c as ye "`m' "
				macro drop `m'
			}
			if(`noiYN'==1) noi di ""
		}
		
		if(`noiYN'==1) noi di _n as red "Clearing mstcovar's stored covariate values"
		cap matrix drop mstcovarVals
		cap matrix drop mstcovarVals_means
		if(_rc!=0)		noi di _col(5) in gr "Done; none found in memory to clear"	
		else			noi di _col(5) in gr "Done."
		
		if("`varlist'`names'`value'`replace'"!=""){
			noi di _n as green "All additional options ignored."
		}
		exit
	}
	
	// Make sure user's specified mstutil'd beforehand
	if("`e(from)'"==""){
		noi di as err "You must run {bf:mstutil} before running {bf:mstcovar}.  Try again."
		exit 198
	}
	
	// otherwise, there needs to be a master variable in varname.
	if("`varlist'"==""){
		noi di as re "Master variable must be specified."
		exit 100
	}
	
	cap macro list mstcovar_`varlist'
	local rcExist = _rc
	
	// if sdur's in memory, then automatically transfer the current varlist into name, if name's empty
	if(`e(sdur)'==1 & "`names'"==""){
		if(`noiYN'==1) noi di as gr "{bf:sdur} detected.  Filling {bf:names()} automatically with specified variable."
		local names `varlist'
	}
	
	// If values only, make sure the storage list exists
	if("`value'"!="" & "`names'"==""){
		if(`rcExist'!=0){
			noi di as red "No mstcovar list in memory for " as ye "`varlist'"
			noi di as red "Generate the list by adding the {bf:names()} option and try again."
			exit 198
		}
		
	}

	// If the list already exists BUT there's new list, user must type replace if there's different stuff.
	if(`rcExist'==0 & "`names'"!="" & "`replace'"==""){
		// check to see if the names are the same
		local mstcovar_`varlist' ${mstcovar_`varlist'}
		local same: list mstcovar_`varlist'===names
		
		if("`same'"=="1"){
			if(`noiYN'==1) noi di as gr "{bf:names()} matches list in memory." 
			
			// reset replace, too, if everything matches
			local replace = ""
		}
		else{
			noi di as red "{bf:names()} does not match " as ye "`varlist'" as red "'s current {bf:mstcovar} list in memory.  If you wish to overwrite the list, add {bf:replace} as an option and run again." 
			exit 198
		}
	}
	
	// Finally, make sure there's only ONE word in values.  Or else chaos.
	* begin by letting Stata simplify any math the user inputted
	cap local value = `value'
	if("`value'"!=""){
		local length: list sizeof values
		
		if(`length'>1){
			noi di as red "{bf:value()} can only contain a single number or a single {it:statname} from {help tabstat##statname:tabstat}."
			exit 123
		}
	}
	
****************************************************************************
// Error checking done.  Do the actual stuff.
	
	// Pull the sample mean		** NOTICE: you do restrict to the estimation sample here, just in case.	// 21FEB19
	tempname meanMini	
	tabstat `varlist' if(e(sample)==1), statistics(mean) save
	qui return list
	matrix `meanMini' = r(StatTotal)
		
	// Create the list if it doesn't already exist
	if(`rcExist'!=0 | "`replace'"!=""){
		global mstcovar_`varlist' `names'
	}
	
	// If there are no values, use the median
	if("`value'"==""){
		local value = "median"
		if(`noiYN'==1) noi di as gr "No covariate values specified; setting to default of " as ye "median" as gr "."
	}
	
	// Get the value
		* if it's a number, just throw that in
		* if it's a tabstat, run it using any if/ins			
		
		tempname mini
		
		// if it's a string, then it's probably a tabstat
		if(real("`value'")==.){
			cap tabstat `varlist' `if' `in', statistics(`value') save
			if(_rc!=0){
				noi di as red "Error from {bf:tabstat}; see message below.  Ensure you've entered a valid {help tabstat##statname:tabstat} {it:statname} and try again."
				tabstat `varlist' `if' `in', statistics(`value') save
			}
			qui return list
			matrix `mini' = r(StatTotal)
		}
		else{	// otherwise, it's a number
			matrix `mini' = `value'
		}
	
	
	// Insert into covariate matrix						[RECALL: value's stored in matrix named `mini']
		* If no covar value matrix exists, create one.
		* If one does exist:
			* See if these variables have values first.  Replace if so.
			* Otherwise, just stick these on the end of the matrix.
	
	
	// first: if it's a replace and the matrix exists, then nuke **everything** that's already in the matrix with this master variable's name
	cap confirm matrix mstcovarVals
	if("`replace'"!="" & _rc==0){
		local numCols = colsof(mstcovarVals)
		tempname holder superMini
		tempname holder2 superMini2
		local colEqName: coleq mstcovarVals
		local colNames: coln mstcovarVals
		
		local remaining = `numCols'
		forvalues c = 1/`numCols'{
	
			local kl: word `c' of `colEqName'		// fixes the name issue w/tokenize
			local kl2: word `c' of `colNames'	
			
			// use regex
			if(regexm("`kl'","`varlist'")){			// if this column's not related to the updated
				local `remaining--'
			}
			else{
				// for main covariate matrix
				cap matrix drop `superMini'
				matrix `superMini' = mstcovarVals[1,`c']
				matrix coleq `superMini' = `kl'
				matrix coln `superMini' = `kl2'
				matrix `holder' = (nullmat(`holder'),`superMini')
				
				// for mean matrix (because list overwrites will affect which columns need to be in that matrix, too)
				cap matrix drop `superMini2'
				matrix `superMini2' = mstcovarVals_means[1,`c']
				matrix coleq `superMini2' = `kl'
				matrix coln `superMini2' = `kl2'
				matrix `holder2' = (nullmat(`holder2'),`superMini2')
			}
		}

		if(`remaining'>0){
			matrix mstcovarVals = `holder'
			matrix mstcovarVals_means = `holder2'
		}
		else{
			mat drop mstcovarVals
			mat drop mstcovarVals_means
		}
		
	}
	
	
	// check to see if these covariates are already in the matrix; replace if so, append if not
	foreach trSp of global mstcovar_`varlist'{
		matrix coleq `mini' = `varlist'
		matrix coln `mini' = `trSp'
		
		matrix coleq `meanMini' = `varlist'
		matrix coln `meanMini' = `trSp'
		
		// replace if there
		cap matrix mstcovarVals[1,colnumb(mstcovarVals,"`trSp'")] = `mini'
		
		// append if not (will obv be case if the matrix's just been created)
		if(_rc!=0){
			matrix mstcovarVals = (nullmat(mstcovarVals), `mini')					// will create the matrix if it doesn't exist first time around
			matrix mstcovarVals_means = (nullmat(mstcovarVals_means), `meanMini')	// add this covariate's sample mean to the means matrix
		}
	}
	
	// Relabel mstcovarVals matrix row for tidiness
	matrix rown mstcovarVals = "vals"
	matrix rown mstcovarVals_means = "means"

}
end
