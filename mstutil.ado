// mstutil: Data utility to set which variable contains to and from.  Also sets transition variable + number of transitions.
	** presupposes that user has already stset AND that they've already stcox'd.
// ** part of mstatecox package
// ** see "help mst" for details

*! Last edited: 23JUN22
*! Last change: inserted version stmt, r-class mem preserve
*! Contact: Shawna K. Metzger, shawna@shawnakmetzger.com
	
cap program drop mstutil
program define mstutil, eclass
    version 14.2
qui{
	syntax , [FRom(varname) TO(varname) SDUR DRAW(varname)]
	// SDUR: for when the user only has a single transition.
	
	// take everything that's currently in ereturn, and just append it with this stuff (h/t to estsimp for the idea)
	* why?  ensures this stuff doesn't stay in memory forever as global macros.  prevents user from doing something stupid. 
  
  // Input validation checks ---------------------------------------------------	
	// First, check to make sure the user has Stata 13 or later.  mstsample requires the Mata function selectindex(), which doesn't appear until Stata 13 and after.
	if(`c(version)'<13){
		noi di as err _c "You are running (or have {bf:version} set to) Stata 12 or lower.  {bf:mstsample} will eventually require the Mata function {bf:selectindex()}, "
		noi di as error  "which does not appear until Stata 13."
		noi di as error  "Try running the command again using Stata 13 or higher."
		exit 133
	}
  
	// Check to ensure moremata, ftools, and gtools installed next
	cap which lmoremata.mlib
	local rc_mm = _rc
	
	cap which gtools
	local rc_gt = _rc
	
	cap which ftools
	local rc_ft = _rc
	if(`rc_mm'!=0 | `rc_gt'!=0 | `rc_ft'!=0){
		if((`rc_mm'!=0)+(`rc_gt'!=0)+(`rc_ft'!=0)>1)	local pl = "s"
		else											local pl = ""
		
		local first = ""
		di as error "You need to install the following package`pl' from SSC:"
		if(`rc_mm'!=0){	
			noi di _n _col(8) "{stata ssc install moremata}"
			local first = "_n"
		}
		if(`rc_gt'!=0){
			noi di `first' _col(8) "{stata ssc install gtools}"
			noi di _col(8) "{stata gtools, upgrade}"
			local first = "_n"
		}
		if(`rc_ft'!=0)	noi di `first' _col(8) "{stata ssc install ftools}"
		
		exit 198
	}	
	
	// See if draw is specified.  If so, remind the user that they're on the hook for any misuse.
	if("`draw'"!=""){
		if("`e(cmd2)'"!="stcox"){
			noi di as gr "{bf:draw()} specified.  Can now use {bf:mstdraw} use without first running {bf:stcox}."
			noi di as gr "This option should be used **only** when loading saved {bf:mstsample} results, or else the other {bf:mst} commands may behave oddly.  "  as err "Caveat lector."
		}
		else{
			noi di as gr "{bf:draw()} specified, but {bf:stcox} in memory.  Ignoring {bf:draw()} and using {bf:stcox} results instead."
			local draw = ""
		}
	}
	
	// Make sure stcox's been run
	if("`e(cmd2)'"!="stcox" & "`draw'"==""){
		local extra = ""
		if("`sdur'"==""){
			local extra ="with strata "
		}
		noi di as err "You must estimate {bf:stcox} `extra'before running {bf:mstutil}.  Try again."
		exit 198
	}
	
    // See if model has both frailties and strata.  If so, exit out, for now.  
    ** (Everything written here presumes the long-time Stata behavior of not 
    ** permitting both.  (Won't be hard to update, if this rule ever gets 
    ** relaxed, but will simply need to BE updated.))
    if("`e(strata)'"!="" & "`e(shared)'"!=""){
        noi di as red "{bf:shared()} and {bf:strata()} both present in {bf:stcox}.  Traditionally, this has been impossible in Stata.  {bf:mstatecox} will require an update to accommodate the change."
        exit 198
    }
    
	// If sdur isn't specified, then from and to need to be.  Shout at the user.
	if("`sdur'"=="" & ("`from'"=="" | "`to'"=="")){
		noi di as err "You must either (1) specify variables containing both the from and to stages or (2) declare your data to contain a single transition only.  Try again."
		exit 198
	}
    
  // Begin checks that may gen vars --------------------------------------------				
    // Preserve any results in return list
    tempname retPres
    _return hold `retPres'
    
	// if the to variable and the transition variable are the same, clone the to variable to generate a new transition variable.  (mstsample gets fussy later if you don't)
	local extraToSet = ""
    if("`to'"=="`e(strata)'" & "`to'"!=""){
		cap drop trans__ms
		clonevar trans__ms = `to'
		label variable trans__ms "transition ID variable for mstatecox"
		local extraToSet = "ereturn local strata trans__ms"
        
        noi di as gr "{bf:to()} variable and {bf:stcox}'s {bf:strata} variable are same.  {bf:mstsample} expects them to be separate."
        noi di as gr "Generated fake transition variable named " as ye "trans__ms" as gr ".  No additional action is required on your part."		
        
        local internal trans__ms
    }
	
	// if there's no stratification, alert the user, but come up with a temp var in the meantime
	if("`e(strata)'"==""){
		if("`draw'"!=""){
			local internal `draw'
		}
		else{
			noi di as gr "No {bf:strata} variable specified in {bf:stcox}.  Generated fake transition variable named " as ye "trans__ms" as gr "."
			
			cap drop trans__ms
			gen trans__ms = 1
			local internal trans__ms
		}	
	}
	
	// if single duration only...
	if("`sdur'"!=""){
		cap drop trans__ms
		local sdurVal = 1
		
		// ...generate a new trans variable with only 1 transition, if user hasn't done already
		if("`e(strata)'"=="" & "`draw'"==""){
			gen trans__ms = 1
			label variable trans__ms "transition ID variable for mstatecox"
			local internal trans__ms
		}
		else{
			noi di as gr _c "You specified {bf:sdur} for a single transition, but you "
            if("`e(strata)'"!="")	noi di as gr "estimated stcox with a strata variable.  Transition variable set to " as ye "`e(strata)'" as gr "."
                _return restore `retPres'
                exit 198
			if("`draw'"!="")	    noi di as gr "specified the {bf:draw} option.  Ignoring {bf:sdur}."
		}
		
		// also generate fake from and to stage variables for the user
		* from
		cap drop from__ms
		gen from__ms = 1
		local from from__ms		
		label variable from__ms "current stage ID variable for mstatecox"
		
		* to
		cap drop to__ms
		gen to__ms = 2
		local to to__ms
		label variable to__ms "next stage ID variable for mstatecox"
	}
	else{		// if not single duration, then set that macro appropriately
		local sdurVal = 0
        
        // Also return the transition variable
        if("`internal'"=="")    local internal `e(strata)'
	}
    
	// also see if stage 0 is a thing (or stage 2 being smallest, or...).  If so, Stata will get angry.  Make the user fix it.
	qui sum `from'
        local min = r(min)
    qui sum `to'
        local min = min(`min',r(min))
	if(`min'!=1){
		noi di as err "Your smallest stage is `min'.  Please give your stages sequential integer values starting at 1."
        _return restore `retPres'
        exit 125
	}

	// make sure from and to (AND trans) are all integers
	local noun = "stages"
	foreach v of varlist `from' `to' `internal'{
        if("`ferest()'"=="")	local noun = "transitions"
		tempvar temp
		gen `temp' = mod(`v', 1)
        
		qui sum `temp'
		if(`r(sum)'!=0){
			noi di as err "`v' contains non-integer elements.  Please give your `noun' sequential integer values starting at 1."
            _return restore `retPres'
            exit 125
		}
	}
    
  // ereturn all relv info -----------------------------------------------------	
	// return highest stage number
	qui sum `from'
		local max = r(max)
	qui sum `to'
		local max = max(`max',r(max))
	ereturn scalar maxStgNo = `max'
	
    // return sdur
    ereturn scalar sdur = `sdurVal'
    
	// return number of transitions
	qui tab `internal'
	ereturn scalar nTrans = `r(r)'
	
	// return from stage
	ereturn local from `from'	
	
	// return to stage
	ereturn local to `to'		

    // return transition 
    ereturn local trans `internal'
    
    // Set anything else that needs setting
    `extraToSet'
    
    // Restore previous return list results
    _return restore `retPres'
    
} // for bracket collapse in editor	
end
