// mstdraw: misc utility stuff
// ** part of mstatecox package
// ** see "help mst" for general package details

*! Last edited: 21FEB19 (part of MAR19 update)
*! Last change: tweaked order of opening messages so that errors came first, then FYIs
*! Contact: Shawna K. Metzger, shawna@shawnakmetzger.com

cap program drop mstdraw	
program define mstdraw, eclass sortpreserve
qui{	
	syntax [if], [NOLabel PRGRaph TRansinfo TYPE(string) TVAR(varname max=1) STGVAR(varlist min=2) SORT ID AREA(string) *]

	** Check to make sure data have been mstutil'd
	if("`e(from)'"==""){
		noi di as err "You must run {bf:mstutil} before running {bf:mstdraw}.  Try again."
		exit 198
	}
	
	*************************************************
	* // The huge block of macro pulls
	local from `e(from)'
	local to `e(to)'
	local trans `e(trans)'
	*************************************************

	** Give courtesy message about stage labels. (outputted at very end of all these checks)
	local labsF: val l `from'
	local labsT: val l `to'
	
	if("`graph'"=="" & "`transinfo'"=="" & "`prgraph'"==""){
		noi di as err "You need to specify {bf:trans} or {bf:prgraph}."
		exit 198
	}
	
	if("`graph'"!="" & "`transinfo'"!="") {
		noi di as err "You must specify only one of these options at a time: {bf:trans} or {bf:prgraph}."
		exit 198
	}
	
	// if prgraph, make sure all the req options are filled
	if("`prgraph'"!="" & ("`tvar'"=="" | "`stgvar'"=="")){
		noi di as err "{bf:prgraph} requires that you specify both the {bf:tvar} and {bf:stgvar} options."
		exit 198
	}
	
	// if prgraph, make sure there's only one sort option specified
	if("`prgraph'"!="" & ("`id'"!="" & "`sort'"!="")){
		noi di as err "You specified two {bf:prgraph} sort options.  You can either select highest trans prob value to lowest ({bf:sort}) or lowest stage ID to highest ({bf:id}), but not both."
		exit 198
	}
	
	// if prgraph, also make sure correct number of stage variables are passed along.
	if("`prgraph'"!=""){
		qui levelsof `from', local(all)
		qui levelsof `to', local(toTemp)
		local all: list all | toTemp
		local all: list uniq all
			
		local numStages: list sizeof all
		local numVars: word count `stgvar'
			
		noi di as gr "{bf:prgraph} is expecting the variable naming conventions from {bf:mstsample}.  Different naming conventions may cause the stacked graph to look odd."
		
		if(`numStages'!=`numVars' & `numStages'!=.){	
			noi di as err "Model has `numStages' stages, but in {bf:stgvar}, you passed along `numVars'.  There should be the same number of variables as stages."
			exit 198
		}
	}
	
	// FYI: no labels
	if("`labsF'"=="" & "`labsT'"=="" & "`nolab'"==""){
		noi di as gr "Stages have no (value) labels; using numbers in diagram.  If you would like text descriptions, define a value label and apply it to both `from' and `to'."
	}
	
	*------------------------------------------------------------
	// TRANSITION INFORMATION
	if("`transinfo'"!=""){
		if("`if'"!="")	noi di as gr "{bf:if} ignored for {bf:transinfo}."
		cap _estimates hold cox, copy
		preserve
		
		// Getting the list and matrix set
		qui sum `trans'
		local min = `r(min)'
		local max = `r(max)'
		
		local string = ""
		
		qui{
			gen skm_tr = .
			gen skm_from = .
			gen skm_to = .
			gen skm_trName = ""
		}
		local labFlag = 0
		
		if("`labsF'"=="`labsT'" & "`labsT'"!="" & "`nolabel'"==""){
			qui gen skm_fromName = ""
			qui gen skm_toName = ""
			local labFlag = 1
		}
		
		local counter = 1
		
		tempname trMat
		matrix `trMat' = J(`e(maxStgNo)',`e(maxStgNo)',.)
		
		// your 28JAN17 rewrite, upon realizing that collapsed transitions will be an issue.  Instead of going by trans number, go by from-to pairs
		forvalues fr = 1/`e(maxStgNo)'{
			forvalues toTo = 1/`e(maxStgNo)'{
				// see if there are any of this from-to pairing in the dataset
				qui count if(`e(from)'==`fr' & `e(to)'==`toTo')
				
				if(`r(N)' > 0){
					qui replace skm_from = `fr' in `counter'
					qui replace skm_to = `toTo' in `counter'
			
					qui sum `e(trans)' if(`e(from)'==`fr' & `e(to)'==`toTo')
					local tr = `r(mean)'
					qui replace skm_tr = `r(mean)' in `counter'

						
					// for the matrix
					matrix `trMat'[`fr',`toTo'] = `tr'
			
					if(`labFlag'==1){
						// Fill in the text labels for the list
						local nF: label `labsF' `fr'
						qui replace skm_fromName = "`nF'" in `counter'
						label variable skm_from `labsF'
						
						local nT: label `labsT' `toTo'
						qui replace skm_toName = "`nT'" in `counter'
						label variable skm_to `labsT'
					
						qui replace skm_trName = skm_fromName + " → " + skm_toName in `counter'
						
					}
					else{
						qui replace skm_trName = "`fr'" + " → " + "`toTo'" in `counter'
					}
						
					local `counter++'
				}
			}
			
		}
		
		local `counter--'
		
		// Display the list (and the varnames won't already exist, because you're saving only the SKM variables
			// ...after you housekeep and do some nicer variable names
			keep skm_*
			rename skm_tr trNo
			rename skm_from from
			rename skm_to to
			rename skm_trName trName
			cap rename skm_fromName fromName      
			cap rename skm_toName toName
			
			order trName, last
			
		noi di _n as ye "<<SUMMARY LIST>>"
		noi list * in 1/`counter', noobs sepby(from) //16DEC18 addition - the noi.  Wasn't printing, otherwise.  And how this wasn't a problem before now, who knows.
		
		// Display the matrix
			// ...after you fill in the column name for the matrix
			if(`labFlag'==1){
				local matNames = ""
			
				// gen
				forvalues s = 1/`e(maxStgNo)'{
					local name: label `labsF' `s'
					local name = subinstr("`name'"," ","_",.)
					local matNames = trim("`matNames'" + " `name'")
				}
				matrix rownames `trMat' = `matNames'
				matrix colnames `trMat' = `matNames'
			}
			
		noi di _n _n as ye "<<TRANSITION MATRIX>>"	
		noi di as gr _col(5) "Rows: " as ye "`e(from)'"
		noi di as gr _col(5) "Columns: " as ye "`e(to)'"
		
		noi mat list `trMat', noheader nohalf	 //16DEC18 addition - the noi.  Wasn't printing, otherwise.  And how this wasn't a problem before now, who knows.
		noi di _n
		
		restore
		cap _estimates unhold cox		
	}	
	
	
	// TRANSITION GRAPH
	if("`prgraph'"!=""){
		// put the stage variables in order based on stage number
		if("`id'"!="")		local stgvar: list sort stgvar
		
		// if specified, put the stage variables in order based on the 
		// smallest trans prob at lowest t to highest at that t
		if("`sort'"!=""){
			tempname ranking
			sort `tvar'
			
			local modified = "`stgvar'"
			local stgvar = ""
			
			local maxVars = ""
			// need all temps for stage vars (maxes)
			foreach s of local modified{
				tempvar `s'Max
				
				egen double ``s'Max' = max(`s')
				
				local maxVars = "`maxVars' ``s'Max'"
			}
			
			
			forvalues stg = 1/`numVars'{				
				cap drop `winning'
				tempvar winning
				
				** insert something in here eventually for the non-starting stages?
				** At the moment, it just goes by who has the highest trans prob
				** across all t, then who has the next highest across all t, etc.
				
				// find the highest value across each maxVar left in the list
				qui egen double `winning' = rowmax(`maxVars')
				
				// find the variable corresponding to sum's highest value
				foreach v of local modified{
					if(``v'Max'==`winning'){
						local name = "`v'"	// variable name
						drop ``v'Max'
						
						local nameMax = "``v'Max'"
						local maxVars: list maxVars - nameMax 
						
						continue, break
					}
				}
				
				// record that variable's name next
				local stgvar = "`stgvar' `name'"
				
				// delete varname from the list
				local modified: list modified - name
				local name = "" 	// in case Stata runs wild again in the future

			}
			
			* NOTE: at this point, largest is first in list and smallest is last.  Will need to be reversed.
		}
		
		// If it's sorted high to low or in input order, whichever variable is currently first in the list should be the topmost layer.  So, reverse.
		if("`id'"==""){
			mata: revVars("stgvar")	
			local stgvar = "`revVars'"
		}
		
		// Take off the last variable.
		local last: word `numVars' of `stgvar'
		local stgvar: list stgvar - last
		
		tempvar top
		gen `top' = 1
		label variable `top' "`last'"

		local newList = ""
		
		// Have to reverse everything at this point to get correct stack order, regardless of the stacking rule
		* e.g.) If you're going by stage number, you have to reverse the varlist again for summing purposes: 1, 2, 3 should be 3, 2, 1.
		mata: revVars("stgvar")	
		local stgvar = "`revVars'"
	
	
		preserve	// you're going to have to overwrite things, to make this as unpainful as possible. 
		
			drop if `tvar'==.	// to toss any empties and get the speed gains
			
			// stgvar will be ordered from highest to lowest **without** the top-most layer of the graph
			foreach v of local stgvar{
				tempvar `v'Sum
				qui egen ``v'Sum' = rowtotal(`v' `ferest()')

				qui replace `v' = ``v'Sum'
				cap drop `v'Sum
				
			}
				// stgvar will be ordered from highest to lowest
			
			
			// do up the legend text
			* if there are value labels, use those for stages (unless the user's said nolabel as an option)
			local counter = 2
			local legendText = "legend(on span colf "
			local order = "order(1 "
			foreach v of local stgvar{	// SWITCHED ON 27JUN17, after the reverse
				if(regexm("`v'","stage[0-9]+")){		// plus gives you stage1, stage10, stage100, etc.
					// if they specify labels and want them, use them
					if("`nolabel'"=="" & "`labsF'"=="`labsT'" & "`labsT'"!=""){	
						// pull the stage
						if(regexm(regexs(0),"[0-9]+")){
							local labNum = regexs(0)
							// pull the label
							local nF: label `labsF' `labNum'
						
							// insert
							local legendText = `"`legendText' label(`counter' ""'  + "`nF'" + `"" ) "'
						
						}

					}
					// otherwise, don't.
					else{
						local legendText = `"`legendText' label(`counter' ""'  + regexs(0) + `"" ) "'
					}
					local order = " `order' `counter'"
					local `counter++'
				}
			}
			
			if(regexm("`last'","stage[0-9]+")){
				local order = " `order')" 
				
				// If it's sorted by ID, you need to reverse the order in the legend. 
				* (This is the only exception.  For sort and <NONE>, we do want top to bottom in the legend, but for ID, it makes sense to go stage 1 - highest, which is the reverse of everything else.)
				if("`id'"!=""){
					local inner = subinstr("`order'","order(","",.)
					local inner = subinstr("`inner'",")","",.)
					local inner = strtrim(stritrim("`inner'"))

					mata: revVars("inner")	
					local inner = "`revVars'"
					
					local order = "order(`inner')"
				}
				
				// if they specify labels and want them, use them
				if("`nolabel'"=="" & "`labsF'"=="`labsT'" & "`labsT'"!=""){	
					// pull the stage
					if(regexm(regexs(0),"[0-9]+")){
						local labNum = regexs(0)
						// pull the label
						local nF: label `labsF' `labNum'
					
						// insert
						local legendText = `"`legendText' label(1 ""'  + "`nF'" + `"" ) `order' )"'
					}
				}
				// otherwise, don't.
				else{
					local legendText = `"`legendText' label(1 ""'  + regexs(0) + `"" ) `order' )"'
				}
			}
			else{
				local legendText = `"`legendText' )"'
			}

			// If the user's specified things for area(), then reorder any of those colors to reflect the ordering method for 
			* break up anything specified within area() into sub-pieces (e.g., color() lcolor() and so on)
				// doesn't need to be done, actually.  The colors are specified from top to bottom.
			
			
			// Plot things.
		cap{
			twoway (area `top' `stgvar' `tvar' `if', sort lw(none) `area'), ///
				xtitle("Time") ytitle("Probability")  ///
				ysc(r(0 1)) ylab(0(0.2)1) ytick(0(0.1)1) ymtick(##4) ///
				`legendText' ///
				`options' 
		}
		if(_rc!=0){
			noi di as err "Error while executing {bf:twoway area}."
			
			* to kick out the exact same error code again
			twoway (area `top' `stgvar' `tvar' `if', sort lw(none) `area'), ///
				xtitle("Time") ytitle("Probability")  ///
				ysc(r(0 1)) ylab(0(0.2)1) ytick(0(0.1)1) ymtick(##4) ///
				`legendText' ///
				`options' 
		}
		restore
		
	}	
	
} // for bracket collapse in editor
end
********************************************************************************************************************************	
// To reverse variable order in a list (needed for mstdraw).  HT to Kit Baum for saving me coding time.
cap mata: mata drop revVars()
mata:	
void revVars(string vars)	//(string vars)
{
	string v
	string v2
	
	v=tokens(st_local(vars))
	v2=invtokens(v[cols(v)..1])

	st_local("revVars",v2)
}
end
