#############################################################################
#
# (C) 2021 Cadence Design Systems, Inc. All rights reserved worldwide.
#
# This sample script is not supported by Cadence Design Systems, Inc.
# It is provided freely for demonstration purposes only.
# SEE THE WARRANTY DISCLAIMER AT THE BOTTOM OF THIS FILE.
#
#############################################################################

#############################################################################
##
## SemiCircle.glf
##
## CREATE STRUCTURED TOPOLOGY FROM TWO SELECTED CONNECTORS
## 
## This script automates the creation of six structured domains from two 
## user-specified connectors. In addition to creating the new topology when 
## possible (edge dimensions must both be odd), the elliptic solver is run
## for 10 iterations, allowing the newly generated domains to relax to an
## optimal configuration. Note that an initial dimension can be even and used,
## but the dimension will be changed when input(AutoDim) is set to 1 before
## proceeding.
## 
## For maximum productivity, a GUI is included, but can easily be disabled. 
## Set input(GUI) to 1 on line 39 to enable control over internal dimension.
## Otherwise, simply select three connectors and run the script. The internal
## dimension will be automatically set to an optimal value.
## 
#############################################################################

package require PWI_Glyph 2.3

## Set global parameters
## Default solve resulting grids or not
set input(Solve) 1
## Automatically increment even-dimensioned connectors
set input(AutoDim) 1
## Enable (1)/Disable (0) GUI
set input(GUI) 0

## Switch that interpolates gridline angles on outer edges, should remain 
## set to 1 for most applications.
set interpAngles 1

## Check that connectors form singly-connected loop
proc isLoop { conList } {
  set e [pw::Edge createFromConnectors -single $conList]
  if { [llength $e] != 1 } {
    foreach edge $e {
      $edge delete
    }
    return 0
  }
  
  set chkVal [$e isClosed]
  $e delete

  return $chkVal
}

## Return connectors adjacent to specified node that are also in the list $cons
proc getAdjCons { node cons } {
    set list1 [$node getConnectors]
    set list2 $cons
    
    set relCons [list]
    foreach ll $list1 {
        if {[lsearch -exact $list2 $ll]!=-1} {
            lappend relCons [list $ll]
        }
    }
    
    return $relCons
}

## Create two point connector given two points with dimension $dim
proc createTwoPt { pt1 pt2 dim } {
    set creator [pw::Application begin Create]
        set con [pw::Connector create]
        set seg [pw::SegmentSpline create]
        $seg addPoint $pt1
        $seg addPoint $pt2
        $con addSegment $seg
    $creator end
    $con setDimension $dim
    return $con
}

## Calculate split locations for three connectors to create TriQuad domain
proc splitTri { conList } {
    set c1 [lindex $conList 0]
    set c2 [lindex $conList 1]
    set c3 [lindex $conList 2]
    
    set L1 [expr [$c1 getDimension] - 1 ]
    set L2 [expr [$c2 getDimension] - 1 ]
    set L3 [expr [$c3 getDimension] - 1 ]
    
    if { $L1 < [expr $L2 + $L3] } {
        set cond1 1
    } else { set cond1 0 }
    if { $L2 < [expr $L1 + $L3] } {
        set cond2 1
    } else { set cond2 0 }
    if { $L3 < [expr $L1 + $L2] } {
        set cond3 1
    } else { set cond3 0 }
    
    
    if { $cond1 && $cond2 && $cond3 } {
        set a [expr {($L1+$L3-$L2)/2. + 1}]
        set b [expr {($L1+$L2-$L3)/2. + 1}]
        set c [expr {($L2+$L3-$L1)/2. + 1}]
    
        if { $a == [expr int($a)] } {
            set cc1 1
            set a [expr int($a)]
        } else { set cc1 0 }
        if { $b == [expr int($b)] } {
            set cc2 1
            set b [expr int($b)]
        } else { set cc2 0 }
        if { $c == [expr int($c)] } {
            set cc3 1
            set c [expr int($c)]
        } else { set cc3 0 }
        
        if { $cc1 && $cc2 && $cc3 } {
            set pt1 [$c1 getXYZ -grid $b]
            set pt2 [$c2 getXYZ -grid $c]
            set pt3 [$c3 getXYZ -grid $a]
            
            lappend splCon [$c1 split -I $b]
            lappend splCon [$c2 split -I $c]
            lappend splCon [$c3 split -I $a]
            
            return [list [list $a $b $c] [list $pt1 $pt2 $pt3] $splCon]
        } else { 
            ## dimensions not even
            return -1
        }
    } else {
        ## One dimension is too large
        return -2
    }
}

## Create domains
proc createTopo { pts dims outerCons } {
    global input

    set pt0 [lindex $pts 0]
    set pt1 [lindex $pts 1]
    set pt2 [lindex $pts 2]
    
    set temp1 [pwu::Vector3 add $pt0 $pt1]
    set temp2 [pwu::Vector3 add $temp1 $pt2]
    set cntr [pwu::Vector3 divide $temp2 3.0]
    
    set nc1 [createTwoPt $pt0 $cntr [lindex $dims 2]]
    set nc2 [createTwoPt $pt1 $cntr [lindex $dims 0]]
    set nc3 [createTwoPt $pt2 $cntr [lindex $dims 1]]
    
    set conList [list $nc1 $nc2 $nc3]
    foreach oc $outerCons {
        foreach c $oc {
            lappend conList $c
        }
    }
    
    set doms [pw::DomainStructured createFromConnectors $conList]
    
    if $input(Solve) {
        solve_Grid $cntr $doms 10
    } else {
        solve_Grid $cntr $doms 0
    }
    
    return $doms
}

## Run elliptic solver for 10 interations with floating BC on interior lines to 
## smooth grid
proc solve_Grid { cntr doms num } {
    global interpAngles
    
    set solver_mode [pw::Application begin EllipticSolver $doms]
        if {$interpAngles == 1} {
            foreach ent $doms {
                foreach bc [list 1 2 3 4] {
                    $ent setEllipticSolverAttribute -edge $bc \
                        EdgeAngleCalculation Interpolate
                }
            }
        }
        
        for {set ii 0} {$ii<3} {incr ii} {
            set tempDom [lindex $doms $ii]
            set inds [list]
            for {set jj 1 } {$jj <= 4 } {incr jj} {
                set tmpEdge [$tempDom getEdge $jj]
                set n1 [$tmpEdge getNode Begin]
                set n2 [$tmpEdge getNode End]
                set c1 [pwu::Vector3 equal -tolerance 1e-6 [$n1 getXYZ] $cntr]
                set c2 [pwu::Vector3 equal -tolerance 1e-6 [$n2 getXYZ] $cntr]
                if { $c1 || $c2 } {
                    lappend inds [list $jj]
                }
            }
            set temp_list [list]
            for {set jj 0} {$jj < [llength $inds] } {incr jj} {
                lappend temp_list [list $tempDom]
            }
            foreach ent $temp_list bc $inds {
                $ent setEllipticSolverAttribute -edge $bc \
                    EdgeConstraint Floating
                $ent setEllipticSolverAttribute -edge $bc \
                    EdgeAngleCalculation Orthogonal
            }
        }
        
        $solver_mode run $num
    $solver_mode end
    
    return
}

## Since final grid is actually two TriQuad grids, can run smoother on all 
## domains at very end.
proc solve_All { doms num } {
    set solver_mode [pw::Application begin EllipticSolver $doms]
    
        foreach ent $doms {
            foreach bc [list 1 2 3 4] {
                $ent setEllipticSolverAttribute -edge $bc \
                    EdgeConstraint Floating
            }
        }
        
        $solver_mode run $num
    $solver_mode end
    
    return
}

## Main procedure to split two connectors into half-OH topology
proc splitSemiCircle { cons } {
    global input newDoms lowerBound upperBound

    set con(1) [lindex $cons 0]
    set con(2) [lindex $cons 1]
    
    set L1 [$con(1) getLength -arc 1.0]
    set L2 [$con(2) getLength -arc 1.0]

    if {$L2 > $L1} { 
        set sE 1
        set lE 2
    } else { 
        set sE 2 
        set lE 1
    }
    
    set N1 [$con($sE) getDimension]
    set N2 [$con($lE) getDimension]
    
    ## Check parity. If both are odd, no problem, otherwise, connectors must 
    ## be split. Even-dimensioned connectors pose problems. Either re-dimension
    ## or exclude. input(AutoDim) will automatically increase their dimension.
    if {[expr $N1%2]==0 || [expr $N2%2] == 0 } {
        puts "Inconsistent Dimension."
        if { !$input(AutoDim) } { exit }
        
        set dimMode [pw::Application begin Dimension]
        if {[expr $N1%2] == 0} {
            incr N1
            $con($sE) resetGeneralDistributions
            $con($sE) setDimension $N1
            $dimMode balance -resetGeneralDistributions
            puts "Re-dimensioned [$con($sE) getName]."
        }
        
        if {[expr $N2%2] == 0} {
            incr N2
            $con($lE) resetGeneralDistributions
            $con($lE) setDimension $N2
            $dimMode balance -resetGeneralDistributions
            puts "Re-dimensioned [$con($lE) getName]."
        }
        $dimMode end
    }
    
    ## Exit if dimensions are too small to support split operations
    if { $N1 < 5 || $N2 < 5 } { 
        puts "Dimension too small."
        exit 
    }
    
    set N1_split [expr ($N1-1)/2+1]
    set N2_split [expr ($N2-1)/2+1]
  
    set lowerBound [expr abs($N2_split-$N1_split)+2]
    set upperBound [expr $N1_split+$N2_split-3]
    set w(Message) [list $lowerBound $upperBound]
    
    set N3 [expr $lowerBound+$upperBound]
    if { [expr $N3%2] != 0 } { incr N3 }
    set input(sDim) [expr $N3/2]
    
    set node1 [$con($sE) getNode Begin]
    set node2 [$con($sE) getNode End]
    
    set param1 [$con($sE) getParameter -closest [pw::Application getXYZ [$con($sE) getXYZ -arc 0.5]]]
    set tmp_cons1 [$con($sE) split $param1]
    
    set param2 [$con($lE) getParameter -closest [pw::Application getXYZ [$con($lE) getXYZ -arc 0.5]]]
    set tmp_cons2 [$con($lE) split $param2]
    
    set pt1 [[lindex $tmp_cons2 0] getXYZ -arc 1.0]
    set pt2 [[lindex $tmp_cons1 0] getXYZ -arc 1.0]
    
    ## Enable GUI if desired
    if $input(GUI) {
        makeWindow
        tkwait window .top
    }
    
    ## Retrieve calculated/specified value for the splitting connector dimension
    set midDim $input(sDim)
    
    if {[expr (($N1+1)/2+($N2+1)/2+$midDim)%2]==0} {incr midDim}
    set midCon1 [createTwoPt $pt1 $pt2 $midDim]
    
    set list1 [getAdjCons $node1 [concat $tmp_cons1 $tmp_cons2]]
    $midCon1 alignOrientation $list1
    lappend list1 [list $midCon1]
    
    ## Attempt splitting operation
    set temp [splitTri $list1]

    ## Check results of split
    if {$temp != -1 && $temp != -2} {
        set dims [lindex $temp 0]
        set pts [lindex $temp 1]
        set splCons [lindex $temp 2]
        
        set doms1 [createTopo $pts $dims $splCons]
    } elseif {$temp == -1} { 
        puts "Unable to match dimensions, check edge dimensions."
        puts "Sum of three connector dimensions must be odd."
        exit 
    } else {
        puts "Unable to match dimensions, check edge dimensions."
        puts "No edge may have a dimension longer than the sum of the other two."
    }
    
    set midCon2 [createTwoPt $pt1 $pt2 $midDim]
    
    set list2 [getAdjCons $node2  [concat $tmp_cons1 $tmp_cons2]]
    $midCon2 alignOrientation $list2
    lappend list2 [list $midCon2]
    
    ## Attempt splitting operation
    set temp2 [splitTri $list2]

    ## Check results of split
    if {$temp2 != -1 && $temp2 != -2} {
        set dims [lindex $temp2 0]
        set pts [lindex $temp2 1]
        set splCons [lindex $temp2 2]
        
        set doms2 [createTopo $pts $dims $splCons]
    } elseif {$temp2 == -1} { 
        puts "Unable to match dimensions, check edge dimensions."
        puts "Sum of three connector dimensions must be odd."
        exit 
    } else {
        puts "Unable to match dimensions, check edge dimensions."
        puts "No edge may have a dimension longer than the sum of the other two."
    }
    
    set newDoms [concat $doms1 $doms2]
    
    if $input(Solve) { 
        solve_All $newDoms 5 
    } else { 
        solve_All $newDoms 0 
    }
    
    return
}

###########################################################################
## GUI 
###########################################################################
## Load TK
if {$input(GUI)} {
    pw::Script loadTk

    # Initialize globals
    set infoMessage ""

    set color(Valid)   SystemWindow
    set color(Invalid) MistyRose

    set w(Window)           [tk::toplevel .top]
    set w(LabelTitle)           .top.title
    set w(FrameMain)          .top.main
      set w(LabelDimension)     $w(FrameMain).ldim
      set w(EntryDimension)     $w(FrameMain).edim
      set w(LabelSolve)            $w(FrameMain).lslv
      set w(EntrySolve)            $w(FrameMain).eslv
      set w(ButtoncOH)            $w(FrameMain).doit
    set w(FrameButtons)      .top.fbuttons
      set w(Logo)                   $w(FrameButtons).cadencelogo
      set w(ButtonCancel)        $w(FrameButtons).bcancel
    set w(Message)             .top.msg

    # dimension field validation
    proc validateDim { dim widget } {
      global w color input lowerBound upperBound
      
      if { [string is integer -strict $dim] && $dim >= $lowerBound && $dim <= $upperBound } {
        $w($widget) configure -background $color(Valid)
      } else {
        $w($widget) configure -background $color(Invalid)
      }
      updateButtons
      return 1
    }

    # return true if none of the entry fields are marked invalid
    proc canCreate { } {
      global w color
      return [expr \
        [string equal -nocase [$w(EntryDimension) cget -background] $color(Valid)]]
    }

    # enable/disable action buttons based on current settings
    proc updateButtons { } {
      global w infoMessage lowerBound upperBound

      if { [canCreate] } {
        $w(ButtoncOH) configure -state normal
        set infoMessage "Press Create OH"
      } else {
        $w(ButtoncOH) configure -state disabled
        set infoMessage "Enter integer between $lowerBound and $upperBound"
      }
      update
    }

    # set the font for the input widget to be bold and 1.5 times larger than
    # the default font
    proc setTitleFont { l } {
      global titleFont
      if { ! [info exists titleFont] } {
        set fontSize [font actual TkCaptionFont -size]
        set titleFont [font create -family [font actual TkCaptionFont -family] \
            -weight bold -size [expr {int(1.5 * $fontSize)}]]
      }
      $l configure -font $titleFont
    }

    ###############################################################################
    # cadenceLogo: Define Cadence Design Systems logo
    ###############################################################################
    proc cadenceLogo {} {
      set logoData {
	R0lGODlhgAAYAPQfAI6MjDEtLlFOT8jHx7e2tv39/RYSE/Pz8+Tj46qoqHl3d+vq62ZjY/n4+NT
	T0+gXJ/BhbN3d3fzk5vrJzR4aG3Fubz88PVxZWp2cnIOBgiIeH769vtjX2MLBwSMfIP///yH5BA
	EAAB8AIf8LeG1wIGRhdGF4bXD/P3hwYWNrZXQgYmVnaW49Iu+7vyIgaWQ9Ilc1TTBNcENlaGlIe
	nJlU3pOVGN6a2M5ZCI/PiA8eDp4bXBtdGEgeG1sbnM6eD0iYWRvYmU6bnM6bWV0YS8iIHg6eG1w
	dGs9IkFkb2JlIFhNUCBDb3JlIDUuMC1jMDYxIDY0LjE0MDk0OSwgMjAxMC8xMi8wNy0xMDo1Nzo
	wMSAgICAgICAgIj48cmRmOlJERiB4bWxuczpyZGY9Imh0dHA6Ly93d3cudy5vcmcvMTk5OS8wMi
	8yMi1yZGYtc3ludGF4LW5zIyI+IDxyZGY6RGVzY3JpcHRpb24gcmY6YWJvdXQ9IiIg/3htbG5zO
	nhtcE1NPSJodHRwOi8vbnMuYWRvYmUuY29tL3hhcC8xLjAvbW0vIiB4bWxuczpzdFJlZj0iaHR0
	cDovL25zLmFkb2JlLmNvbS94YXAvMS4wL3NUcGUvUmVzb3VyY2VSZWYjIiB4bWxuczp4bXA9Imh
	0dHA6Ly9ucy5hZG9iZS5jb20veGFwLzEuMC8iIHhtcE1NOk9yaWdpbmFsRG9jdW1lbnRJRD0idX
	VpZDoxMEJEMkEwOThFODExMUREQTBBQzhBN0JCMEIxNUM4NyB4bXBNTTpEb2N1bWVudElEPSJ4b
	XAuZGlkOkIxQjg3MzdFOEI4MTFFQjhEMv81ODVDQTZCRURDQzZBIiB4bXBNTTpJbnN0YW5jZUlE
	PSJ4bXAuaWQ6QjFCODczNkZFOEI4MTFFQjhEMjU4NUNBNkJFRENDNkEiIHhtcDpDcmVhdG9yVG9
	vbD0iQWRvYmUgSWxsdXN0cmF0b3IgQ0MgMjMuMSAoTWFjaW50b3NoKSI+IDx4bXBNTTpEZXJpZW
	RGcm9tIHN0UmVmOmluc3RhbmNlSUQ9InhtcC5paWQ6MGE1NjBhMzgtOTJiMi00MjdmLWE4ZmQtM
	jQ0NjMzNmNjMWI0IiBzdFJlZjpkb2N1bWVudElEPSJ4bXAuZGlkOjBhNTYwYTM4LTkyYjItNDL/
	N2YtYThkLTI0NDYzMzZjYzFiNCIvPiA8L3JkZjpEZXNjcmlwdGlvbj4gPC9yZGY6UkRGPiA8L3g
	6eG1wbWV0YT4gPD94cGFja2V0IGVuZD0iciI/PgH//v38+/r5+Pf29fTz8vHw7+7t7Ovp6Ofm5e
	Tj4uHg397d3Nva2djX1tXU09LR0M/OzczLysnIx8bFxMPCwcC/vr28u7q5uLe2tbSzsrGwr66tr
	KuqqainpqWko6KhoJ+enZybmpmYl5aVlJOSkZCPjo2Mi4qJiIeGhYSDgoGAf359fHt6eXh3dnV0
	c3JxcG9ubWxramloZ2ZlZGNiYWBfXl1cW1pZWFdWVlVUU1JRUE9OTUxLSklIR0ZFRENCQUA/Pj0
	8Ozo5ODc2NTQzMjEwLy4tLCsqKSgnJiUkIyIhIB8eHRwbGhkYFxYVFBMSERAPDg0MCwoJCAcGBQ
	QDAgEAACwAAAAAgAAYAAAF/uAnjmQpTk+qqpLpvnAsz3RdFgOQHPa5/q1a4UAs9I7IZCmCISQwx
	wlkSqUGaRsDxbBQer+zhKPSIYCVWQ33zG4PMINc+5j1rOf4ZCHRwSDyNXV3gIQ0BYcmBQ0NRjBD
	CwuMhgcIPB0Gdl0xigcNMoegoT2KkpsNB40yDQkWGhoUES57Fga1FAyajhm1Bk2Ygy4RF1seCjw
	vAwYBy8wBxjOzHq8OMA4CWwEAqS4LAVoUWwMul7wUah7HsheYrxQBHpkwWeAGagGeLg717eDE6S
	4HaPUzYMYFBi211FzYRuJAAAp2AggwIM5ElgwJElyzowAGAUwQL7iCB4wEgnoU/hRgIJnhxUlpA
	SxY8ADRQMsXDSxAdHetYIlkNDMAqJngxS47GESZ6DSiwDUNHvDd0KkhQJcIEOMlGkbhJlAK/0a8
	NLDhUDdX914A+AWAkaJEOg0U/ZCgXgCGHxbAS4lXxketJcbO/aCgZi4SC34dK9CKoouxFT8cBNz
	Q3K2+I/RVxXfAnIE/JTDUBC1k1S/SJATl+ltSxEcKAlJV2ALFBOTMp8f9ihVjLYUKTa8Z6GBCAF
	rMN8Y8zPrZYL2oIy5RHrHr1qlOsw0AePwrsj47HFysrYpcBFcF1w8Mk2ti7wUaDRgg1EISNXVwF
	lKpdsEAIj9zNAFnW3e4gecCV7Ft/qKTNP0A2Et7AUIj3ysARLDBaC7MRkF+I+x3wzA08SLiTYER
	KMJ3BoR3wzUUvLdJAFBtIWIttZEQIwMzfEXNB2PZJ0J1HIrgIQkFILjBkUgSwFuJdnj3i4pEIlg
	eY+Bc0AGSRxLg4zsblkcYODiK0KNzUEk1JAkaCkjDbSc+maE5d20i3HY0zDbdh1vQyWNuJkjXnJ
	C/HDbCQeTVwOYHKEJJwmR/wlBYi16KMMBOHTnClZpjmpAYUh0GGoyJMxya6KcBlieIj7IsqB0ji
	5iwyyu8ZboigKCd2RRVAUTQyBAugToqXDVhwKpUIxzgyoaacILMc5jQEtkIHLCjwQUMkxhnx5I/
	seMBta3cKSk7BghQAQMeqMmkY20amA+zHtDiEwl10dRiBcPoacJr0qjx7Ai+yTjQvk31aws92JZ
	Q1070mGsSQsS1uYWiJeDrCkGy+CZvnjFEUME7VaFaQAcXCCDyyBYA3NQGIY8ssgU7vqAxjB4EwA
	DEIyxggQAsjxDBzRagKtbGaBXclAMMvNNuBaiGAAA7}

      return [image create photo -format GIF -data $logoData]
    }

    # Build the user interface
    proc makeWindow { } {
      global w input cons
      
      wm withdraw .

      # Ceate the widgets
      label $w(LabelTitle) -text "Semi-Circle Parameters"
      setTitleFont $w(LabelTitle)

      frame $w(FrameMain)

      label $w(LabelDimension) -text "Cross dimension:" -anchor e
      entry $w(EntryDimension) -width 6 -bd 2 -textvariable input(sDim)
      $w(EntryDimension) configure -state disabled

      label $w(LabelSolve) -text "Run solver?" -padx 2 -anchor e
      checkbutton $w(EntrySolve) -variable input(Solve)
      $w(EntrySolve) configure -state disabled
      
      button $w(ButtoncOH) -text "Create Topo" -command { destroy .top }
      $w(ButtoncOH) configure -state disabled

      message $w(Message) -textvariable infoMessage -background beige \
                          -bd 2 -relief sunken -padx 5 -pady 5 -anchor w \
                          -justify left -width 300

      frame $w(FrameButtons) -relief sunken

      button $w(ButtonCancel) -text "Cancel" -command { destroy . }
      label $w(Logo) -image [cadenceLogo] -bd 0 -relief flat

      # set up validation after all widgets are created so that they all exist when
      # validation fires the first time; if they don't all exist, updateButtons
      # will fail
      $w(EntryDimension) configure -validate key \
        -vcmd { validateDim %P EntryDimension }

      # lay out the form
      pack $w(LabelTitle) -side top
      pack [frame .sp -bd 1 -height 2 -relief sunken] -pady 4 -side top -fill x
      pack $w(FrameMain) -side top -fill both -expand 1

      # lay out the form in a grid
      grid $w(LabelDimension) $w(EntryDimension) -sticky ew -pady 3 -padx 3
      grid $w(LabelSolve) $w(EntrySolve) -sticky ew -pady 3 -padx 3
      grid $w(ButtoncOH) -columnspan 2 -pady 3

      # give all extra space to the second (last) column
      grid columnconfigure $w(FrameMain) 1 -weight 1

      pack $w(Message) -side bottom -fill x -anchor s
      pack $w(FrameButtons) -fill x -side bottom -padx 2 -pady 4 -anchor s
      pack $w(ButtonCancel) -side right -padx 2
      pack $w(Logo) -side left -padx 5

      bind .top <Key-Escape> { $w(ButtonCancel) invoke }
      bind .top <Control-Key-Return> { $w(ButtoncOH) invoke }
      bind .top <Control-Key-f> { $w(ButtoncOH) invoke }
      bind $w(EntryDimension) <Key-Return> { $w(ButtoncOH) invoke }

      # move keyboard focus to the first entry
      focus $w(ButtoncOH)
      raise .top
      
      $w(EntryDimension) configure -state normal
      $w(EntrySolve) configure -state normal
      updateButtons
      
    }
}

## Set Info label
set text1 "Please select two connectors or one unstructured domain."
## Pull entities from current selection
set mask [pw::Display createSelectionMask -requireDomain {Unstructured} -requireConnector {}]

###############################################
## This script uses the getSelectedEntities command added in 17.2R2
## Catch statement should check for previous versions
if { [catch {pw::Display getSelectedEntities -selectionmask $mask curSelection}] } {
    set picked [pw::Display selectEntities -description $text1 \
        -selectionmask $mask curSelection]
    
    if {!$picked} {
        puts "Script aborted."
        exit
    }
} elseif { [llength $curSelection(Connectors)] != 2 && \
        [llength $curSelection(Domains)] != 1 } {
    puts $text1
    exit
}
###############################################

## First check for unstructured domain in selection. If so, replace with half-OH
if {[llength $curSelection(Domains)]==1} {
    set tempDom [lindex $curSelection(Domains) 0]
    set edgeCount [$tempDom getEdgeCount]
    if { $edgeCount != 1 } {
        puts "Domain has multiple edges."
        exit
    }
    
    set temp [$tempDom getEdge 1]
    set conCount [$temp getConnectorCount]
    if { $conCount != 2 } {
        puts "Domain edge has more than 2 connectors."
        exit
    }
    
    set cons [list [$temp getConnector 1] [$temp getConnector 2]]
    
    set domStatus [list [$tempDom getRenderAttribute LineMode]\
        [$tempDom getRenderAttribute FillMode]]
    
    set newDoms [splitSemiCircle $cons]
    
    pw::Entity delete $tempDom
    foreach dd $newDoms {
        $dd setRenderAttribute LineMode [lindex $domStatus 0]
        $dd setRenderAttribute FillMode [lindex $domStatus 1]
    }
    
    exit
    
} elseif {[llength $curSelection(Connectors)]==2} {
    set bool [isLoop $curSelection(Connectors)]
    
    if $bool {
        set cons $curSelection(Connectors)
        set newDoms [splitSemiCircle $curSelection(Connectors)]
    } else {
        puts "Connectors do not form closed loop."
    }
    
    exit
} else {
    puts "Please select either one unstructured domain or two connectors."
    exit
}

#############################################################################
#
# This file is licensed under the Cadence Public License Version 1.0 (the
# "License"), a copy of which is found in the included file named "LICENSE",
# and is distributed "AS IS." TO THE MAXIMUM EXTENT PERMITTED BY APPLICABLE
# LAW, CADENCE DISCLAIMS ALL WARRANTIES AND IN NO EVENT SHALL BE LIABLE TO
# ANY PARTY FOR ANY DAMAGES ARISING OUT OF OR RELATING TO USE OF THIS FILE.
# Please see the License for the full text of applicable terms.
#
#############################################################################
