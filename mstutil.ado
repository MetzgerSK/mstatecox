// mstutil: Data utility to set which variable contains to and from.  Also sets transition variable + number of transitions.
	** presupposes that user has already stset AND that they've already stcox'd.
// ** part of mstatecox package
// ** see "help mst" for details

*! 21JUN21
	
cap program drop mstutil
program define mstutil, eclass
qui{
	syntax , [FRom(varname) TO(varname) SDUR DRAW(varname)]
	// SDUR: for when the user only has a single transition.
	
	// take everything that's currently in ereturn, and just append it with this stuff (h/t to estsimp for the idea)
	* why?  ensures this stuff doesn't stay in memory forever as global macros.  prevents user from doing something stupid. 
	
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
	
	// if the to variable and the transition variable are the same, clone the from variable to generate a new transition variable.  (mstsample gets fussy later if you don't)
	if("`to'"=="`e(strata)'" & "`to'"!=""){
		cap drop trans__ms
		clonevar trans__ms = `to'
		label variable trans__ms "transition ID variable for mstatecox"
		ereturn local strata trans__ms
	}
	
	// return the transition variable
	* start by taking the transition variable from stcox's strata.  (You've already checked that stcox has strata specified above.)
	ereturn local trans `e(strata)'
	local internal `e(strata)'
	
	
	* if there's no stratification, alert the user, but come up with a temp var in the meantime
	if("`e(strata)'"==""){
		if("`draw'"!=""){
			ereturn local trans `draw'
			local internal `draw'
		}
		else{
			noi di as gr "No {bf:strata} variable specified in {bf:stcox}.  Generated fake transition variable named " as ye "trans__ms" as gr "."
			
			cap drop trans__ms
			gen trans__ms = 1
			ereturn local trans trans__ms
			local internal trans__ms
		}
		
	}
	
	// if single duration only...
	if("`sdur'"!=""){
		cap drop trans__ms
		ereturn scalar sdur = 1
		
		// ...generate a new trans variable with only 1 transition, if user hasn't done already
		if("`e(strata)'"=="" & "`draw'"==""){
			gen trans__ms = 1
			label variable trans__ms "transition ID variable for mstatecox"
			ereturn local trans trans__ms
			local internal trans__ms
		}
		else{
			if("`e(strata)'"!="")	local desc = "estimated stcox with a strata variable"
			if("`draw'"=="")	local desc = "estimated stcox with a strata variable"
			di as gr "You specified {bf:sdur} for a single transition, but you .  Transition variable set to " as ye "`e(strata)'" as gr "."
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
		ereturn scalar sdur = 0
	}
	
	// also see if stage 0 is a thing.  If so, Stata will get angry.  Make the user fix it.
	qui sum `from'
	if(`r(min)'<=0){
		noi di as err "Your smallest stage is `r(min)'.  Please give your stages sequential integer values starting at 1."
		exit 125
	}
	
	// make sure from and to (AND trans) are all integers
	local noun = "stages"
	foreach v of varlist `from' `to' `trans'{
		if("`v'"=="trans")	local noun = "transitions"
		tempvar temp
		gen `temp' = mod(`v', 1)
		
		qui sum `temp'
		if(`r(max)'>0){
			noi di as err "`v' contains non-integer elements.  Please give your `noun' sequential integer values starting at 1."
			exit 125
		}
	}
	
	// return highest stage number
	qui sum `from'
		local max = r(max)
	qui sum `to'
		local max = max(`max',r(max))
	ereturn scalar maxStgNo = `max'
	
	// return number of transitions
	qui tab `internal'
	ereturn scalar nTrans = `r(r)'
	
	// return from stage
	ereturn local from `from'	
	
	// return to stage
	ereturn local to `to'		

} // for bracket collapse in editor	
end
