globals
[
  ;;; constants
  patch-width
  tick-length-in-seconds
  max-perception-distance

  ;;; parameters
  ;;;; contextual
  target-point-buffer-distance
  obstacle-damage
  track-mark-probability
  track-pregeneration-period

  ;;;; hunters
  num-hunters

  hunters_height_min
  hunters_height_max
  hunters_speed_min
  hunters_speed_max
  hunters_tte_min
  hunters_tte_max
  hunters_reactiontime_min
  hunters_reactiontime_max

  ;;;; preys
  num-preys
  preys_group_max_size
  preys_safe-distance

  preys_height_min
  preys_height_max
  preys_speed_min
  preys_speed_max
  preys_tte_min
  preys_tte_max
  preys_reactiontime_min
  preys_reactiontime_max

  ;;;; environment
  init-obstacle-scale
  prey-attractor-probability

  ;;; variables
  starting-point
  target-point

  prey-attraction-max
]

breed [ hunters hunter ]

breed [ preys prey ]

hunters-own
[
  height
  time-to-exhaustion
  reaction-time

  ;;; internal/private
  hunters-in-sight
  preys-in-sight
  reaction-counter
  time-running
]

preys-own
[
  height
  time-to-exhaustion
  reaction-time

  group_id

  ;;; internal/private
  hunters-in-sight
  preys-in-sight
  reaction-counter
  time-running
]

patches-own
[
  elevation
  obstacle
  prey-attraction

  track
]

to setup

  clear-all

  set-input

  setup-environment

  setup-prey-groups

  setup-hunting-party

  initialise-perceptions

  ;generate-recent-tracks

  update-display

  reset-ticks

end

to go

  ask turtles
  [
    ifelse (breed = preys)
    [
      update-prey
    ]
    [
      update-hunter
    ]
  ]

  update-display

  tick

end

to set-input

  random-seed SEED

  set patch-width 100 ;;; meters

  set tick-length-in-seconds 60 ;;; 1 tick = 1 minute

  set max-perception-distance sqrt ((world-width ^ 2) + (world-height ^ 2)) ;;; measured in patches orthogonal dimensions (default: diagonal distance)

  ;;; parameters

  ;;;; environment
  set init-obstacle-scale par_init-obstacle-scale

  set prey-attractor-probability par_prey-attractor-probability

  set obstacle-damage par_obstacle-damage ;;; damage (m obstacle) / 1 (m height) * 1 (sec)

  set track-mark-probability par_track-mark-probability ;;; prob. / 1 (m height) * 1 (sec)

  set track-pregeneration-period par_track-pregeneration-period

  ;;;; hunters
  set num-hunters par_num-hunters
  set hunters_height_min par_hunters_height_min ; meters
  set hunters_height_max par_hunters_height_max
  set hunters_speed_min convert-kmperh-to-patchpersec par_hunters_speed_min ; patch width (m) per second
  set hunters_speed_max convert-kmperh-to-patchpersec par_hunters_speed_max
  set hunters_tte_min par_hunters_tte_min ; minutes
  set hunters_tte_max par_hunters_tte_max
  set hunters_reactiontime_min par_hunters_reactiontime_min
  set hunters_reactiontime_max par_hunters_reactiontime_max

  ;;;; preys
  set num-preys par_num-preys
  set preys_group_max_size par_preys_group_max_size
  set preys_safe-distance par_preys_safe-distance / patch-width
  set preys_height_min par_preys_height_min ; meters
  set preys_height_max par_preys_height_max
  set preys_speed_min convert-kmperh-to-patchpersec par_preys_speed_min ; patch width (m) per second
  set preys_speed_max convert-kmperh-to-patchpersec par_preys_speed_max
  set preys_tte_min par_preys_tte_min ; minutes
  set preys_tte_max par_preys_tte_max
  set preys_reactiontime_min par_preys_reactiontime_min
  set preys_reactiontime_max par_preys_reactiontime_max

  ;;;; positions
  set starting-point patch (min-pxcor + floor (world-width / 2)) (min-pycor + floor (world-height / 2))

  set target-point-buffer-distance par_target-point-buffer-distance ; km

  set target-point one-of patches with [count neighbors4 < 4] ;;; choose apatch at the edges as target point

end

to setup-environment

  ask patches
  [
    set elevation random-float 100
    set obstacle (random-float 1) * (random-float 1) * init-obstacle-scale
    set prey-attraction 0
    if (random-float 100 < prey-attractor-probability) [ set prey-attraction 100 ]

    set track (list)
  ]

  repeat 2 [ diffuse elevation 0.5 ]

  repeat 5 [ diffuse prey-attraction 0.3 ]

  set prey-attraction-max max [prey-attraction] of patches

end

to setup-prey-groups

  create-preys num-preys
  [
    set height preys_height_min + random-float (preys_height_max - preys_height_min)
    set time-to-exhaustion preys_tte_min + random (preys_tte_max - preys_tte_min)
    set time-to-exhaustion time-to-exhaustion * 60 ; convert minutes to seconds
    set reaction-time preys_reactiontime_min + random (preys_reactiontime_max - preys_reactiontime_min)

    set shape "sheep"
  ]

  let unassigned preys
  let currentID 0

  let bufferDistance target-point-buffer-distance * 1000 / patch-width ;;; km -> m -> patch widths
  let validInitialPositions patches with [distance starting-point > bufferDistance]

  while [any? unassigned]
  [
    let group_size 1 + random (min (list preys_group_max_size (count unassigned)))
    ask n-of group_size unassigned
    [
      set group_id currentID

      set unassigned other unassigned
    ]

    ask one-of validInitialPositions
    [
      let me self
      ask preys with [group_id = currentID]
      [
        move-to me
      ]
    ]

    set currentID currentID + 1
  ]

end

to generate-recent-tracks

  let trackPregenerationPeriodInMinutes track-pregeneration-period * 60 ;;; hours -> minutes

  repeat trackPregenerationPeriodInMinutes
  [
    ask preys [ update-prey ]
  ]

end

to setup-hunting-party

  ask starting-point
  [
    set obstacle 0 ;;; clear starting point

    sprout-hunters num-hunters
    [
      set height hunters_height_min + random-float (hunters_height_max - hunters_height_min)
      set time-to-exhaustion hunters_tte_min + random (hunters_tte_max - hunters_tte_min)
      set time-to-exhaustion time-to-exhaustion * 60 ; convert minutes to seconds
      set reaction-time hunters_reactiontime_min + random (hunters_reactiontime_max - hunters_reactiontime_min)

      set shape "person"
    ]
  ]

end

to initialise-perceptions

  ask turtles
  [
    set hunters-in-sight (turtle-set)
    set preys-in-sight (turtle-set)

    initialise-perception-links
  ]

end

to initialise-perception-links

  create-links-to other hunters [ set color red set hidden? true ]
  create-links-to other preys [ set color yellow set hidden? true ]

end

to update-prey

  ifelse (any? hunters-in-sight)
  [
    ;; initialise reaction counter, only if not already on the run or processing a reaction
    if (time-running = 0 and reaction-counter = 0)
    [ set reaction-counter reaction-time ]

    move-away-from hunters-in-sight
  ]
  [
    set time-running 0

    prey-baseline-behaviour
  ]

  if (count [neighbors4] of patch-here < 4)
  [
    print (word "Prey " who " and group " group_id " escaped from hunting area")
    ask other preys with [group_id = [group_id] of myself] [ die ]
    die
  ]

  if (time-running = time-to-exhaustion)
  [
    ;;; exhasted
    ;;; TODO: time of recovery greater than 1 tick
    set time-running 0
  ]

  update-perception

end

to update-hunter

  ; move-towards preys-in-sight

end

to update-perception

  let me self

  ask my-out-links [ set hidden? true ]

  set hunters-in-sight other hunters with [presence-detected-by me]
  set preys-in-sight other preys with [presence-detected-by me]

  ask hunters-in-sight [ ask in-link-from me [ set hidden? false ] ]
  ask preys-in-sight [ ask in-link-from me [ set hidden? false ] ]

end

to-report presence-detected-by [ theOther ]

  ;;; skip calculations if agents are in the same patch
  if ((xcor = [xcor] of theOther) and (ycor = [ycor] of theOther)) [ report true ]

  let me self
  let response false

  ask theOther
  [
    face me
    let myLineOfSight line-of-sight
    set response member? ([patch-here] of me) myLineOfSight
  ]

  report response

end

to-report line-of-sight

  ;;; a ray casting algorithm that takes into account:
  ;;; 1. elevation (ground level),
  ;;; 2. height of turtles
  ;;; 3. height of obstacles
  let visiblePatches (patch-set)

  let vantagePointHeight elevation + height

  let lastDist 1
  let lastPatch patch-here
  let a1 0

  ;;; use a cumulative sum of obstacles to find the max distance perceived
  let maxDistancePerceived 0

  ;; iterate through all the patches
  ;; starting at the patch directly ahead
  ;; going through MAXIMUM-VISIBILITY
  while [lastDist < max-perception-distance and lastPatch != nobody]
  [
    let aPatch patch-ahead lastDist
    ;; if we are looking diagonally across
    ;; a patch it is possible we'll get the
    ;; same patch for distance x and x + 1
    ;; but we don't need to check again.
    if (aPatch != lastPatch and aPatch != nobody)
    [
      ;; find the angle between the turtle's position
      ;; and the top of the patch.
      let aPatchHighestElement [obstacle] of aPatch
      if ([any? turtles-here] of aPatch)
      [
        set aPatchHighestElement max (list aPatchHighestElement [max [height] of turtles-here] of aPatch)
      ]
      let aPatchTopHeight aPatchHighestElement + [elevation] of aPatch
      let a2 atan lastDist (vantagePointHeight - aPatchTopHeight)
      ;; if that angle is less than the angle toward the
      ;; last visible patch there is no direct line from the turtle
      ;; to the patch in question that is not obstructed by another
      ;; patch.
      ;print (word "a1=" a1 ", a2=" a2)
      ifelse a1 < a2
      [
        set visiblePatches (patch-set visiblePatches aPatch)
        ;ask aPatch [ set pcolor red ]

        set a1 a2

        set maxDistancePerceived [distance myself] of aPatch
      ]
      [
        ;print "a1 >= a2"
      ]
      set lastPatch aPatch
    ]
    set lastDist lastDist + 1
  ]

  report visiblePatches

end

to move-away-from [ someTurtles ]

  ;;; make it acceptable that someTurtle is given as a single turtle
  set someTurtles (turtle-set someTurtles)
  print (word "prey " who " sees hunter" ([who] of someTurtles))
  repeat tick-length-in-seconds
  [
    ifelse (reaction-counter > 0)
    [
      print (word "thinking... " reaction-counter " secs to reaction")
        set reaction-counter reaction-counter - 1
    ]
    [
      print "running away..."
      ;; if reaction time has passed...
      if (time-running < time-to-exhaustion)
      [
        print "... and not exhausted."
        ;; ... and the turtle is not already exhausted
        ;; Find the nearest turtle
        let closestTurtle min-one-of someTurtles [distance myself]
        print (word "distance before: " (distance closestTurtle))
        ;; Modulate spped according to distance and safe-distance
        let maxSpeed preys_speed_min
        if ([distance myself] of closestTurtle < preys_safe-distance)
        [
          set maxSpeed preys_speed_max
        ]

        ;; Set the distance the turtle moves as the maximum
        let moveDistance (get-speed-in-patch maxSpeed patch-here)

        let oppositeHeading towards closestTurtle - 180
        set heading (get-best-route-heading oppositeHeading moveDistance)

        fd MoveDistance
        print (word "distance after: " (distance closestTurtle))
        impact-vegetation

        ;;; account for exertion
        set time-running time-running + 1
      ]
    ]
  ]
  print "minute has passed."

end

to prey-baseline-behaviour

  let moving false

  let moveDistance 0

  ;; set the default distance the turtle moves as the minimum
  let speed preys_speed_min

  ;;; *Define target heading* ;;;

  ;;; First priority: staying in an attractive patch (or moving out from unattractive ones)

  ;;; get a relative measure of how attractive is the current patch
  let patch-pull 100 * ([prey-attraction] of patch-here) / prey-attraction-max

  if (random-float 100 > patch-pull)
  [
    ;;; Second priority: keeping the group together
    ;;; NOTE: checks if all group members are in sight and, if so, head towards the closest one
    let myGroupId group_id
    let groupMembers other preys with [group_id = myGroupId]
    let groupMembersNotInSight groupMembers with [not presence-detected-by myself]
    if (count groupMembers > 0 and count groupMembers = count groupMembersNotInSight)
    [
      face min-one-of groupMembersNotInSight [distance myself]
    ]

    rt (- 30 + random 60) ;;; add random direction biased by default heading

    set moving true
  ]

  ;;; *Move towards target heading* ;;;

  ifelse (moving)
  [
    ;;; keep track of the target heading
    let targetHeading heading

    repeat tick-length-in-seconds
    [
      set MoveDistance (get-speed-in-patch speed patch-here)

      set heading (get-best-route-heading targetHeading moveDistance)

      fd MoveDistance

      impact-vegetation
    ]
  ]
  [
    repeat tick-length-in-seconds [ impact-vegetation ]
  ]

end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to-report get-best-route-heading [ targetHeading moveDistance ]

  let bestAngle targetHeading

;  let bestEscapePatch existing-patch-at-heading-and-distance targetHeading moveDistance
;
;  ;;; if moving to a new patch
;  if (bestEscapePatch != patch-here)
;  [
;    ;;; that has a higher average obstacle height than the agent's height
;    if ([obstacle] of bestEscapePatch > height);[obstacle] of patch-here)
;    [
;      ;;; recalculate bestAngle as angle torwards the patch:
;      ;;; 1. in the closest direction to targetHeading
;      ;;; 2. with the lowest mean obstacle height
;      ;;; Notice that when lacking a better option, this will return the same original bestEscapePatch
;      set bestAngle targetHeading - 180 ; start with worse angle
;      let closestAngleDifference abs (targetHeading - bestAngle)
;      let sampleAngles shuffle n-values 36 [ i -> i * 10 ] ; sample directions every 10 degrees
;
;      foreach sampleAngles
;      [
;        gridAngle ->
;        let angleDifference abs (targetHeading - gridAngle)
;
;        let patchCandidate existing-patch-at-heading-and-distance gridAngle moveDistance
;
;        if ([obstacle] of patchCandidate < [obstacle] of bestEscapePatch and angleDifference < closestAngleDifference)
;        [
;          set bestAngle gridAngle
;          set bestEscapePatch patchCandidate
;        ]
;      ]
;    ]
;  ]

;  ;; modify direction if trapped at the edges
;  if (bestEscapePatch = nobody)
;  [
;    ;;; recalculate bestEscapePatch as the patch in the closest direction to targetHeading
;    let closestAngle targetHeading - 180
;    foreach shuffle n-values 36 [ i -> i * 10 ] ; sample directions every 10 degrees
;    [
;      gridAngle ->
;      let angleDifference abs (targetHeading - gridAngle)
;      let closestAngleDifference abs (targetHeading - closestAngle)
;
;      let patchCandidate patch-at-heading-and-distance gridAngle moveDistance
;
;      if (patchCandidate != nobody and angleDifference < closestAngleDifference)
;      [
;        set closestAngle gridAngle
;        set bestEscapePatch patchCandidate
;      ]
;    ]
;  ]

  report bestAngle

end

to-report get-speed-in-patch [ freeSpeed aPatch ]

  ;;; penalise only if patch obstacle is higher than turtle (ego) height
  let penalisation 0
  if ([obstacle] of aPatch > height)
  [
    set penalisation height / [obstacle] of aPatch
  ]

  report freeSpeed * (1 - penalisation)

end

to-report existing-patch-at-heading-and-distance [ aHeading aDistance ]

  let aPatch patch-at-heading-and-distance aHeading aDistance
  let modDistance aDistance

  while [aPatch = nobody]
  [
    set modDistance modDistance - 0.2 ; small enough step to detect all patches in diagonals
    set aPatch patch-at-heading-and-distance aHeading modDistance
  ]

  report aPatch

end

to impact-vegetation

  let obstacleDamage obstacle-damage * [height] of self
  let trackMarkProbability track-mark-probability * 100 * [height] of self

  ask patch-here
  [
    ;;; clear vegetation obstacles
    set obstacle max (list 0 (obstacle - obstacleDamage))

    ;;; create mark, spurr, track
    if (trackMarkProbability > random-float 100)
    [
      set track fput myself track
    ]
  ]

end

to update-display

  paint-patches

  scale-agents

end

to paint-patches

  let min-elevation min [elevation] of patches
  let max-elevation max [elevation] of patches
  let min-obstacle min [obstacle] of patches
  let max-obstacle max [obstacle] of patches
  let min-height min [elevation + obstacle] of patches
  let max-height max [elevation + obstacle] of patches
  let min-attraction min [prey-attraction] of patches
  let max-attraction max [prey-attraction] of patches

  ask patches
  [
    if (display-mode = "elevation")
    [ set pcolor scale-color brown elevation min-elevation max-elevation ]
    if (display-mode = "obstacle")
    [ set pcolor scale-color green obstacle min-obstacle max-obstacle ]
    if (display-mode = "elevation+obstacle")
    [ set pcolor scale-color grey (elevation + obstacle) min-height max-height ]
    if (display-mode = "prey-attraction")
    [ set pcolor scale-color red (prey-attraction) min-attraction max-attraction ]
  ]

  if (display-track-marks)
  [
    ask patches with [length track > 0] [ set pcolor red ]
  ]

  if (display-target-point)
  [
    ask target-point [ set pcolor orange ]
  ]

end

to scale-agents

  ask turtles
  [
    set size patch-size * agent-scale
  ]

end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; HELPERS ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to-report convert-kmperh-to-patchpersec [ kmperh ]
  ; km/h -> m/sec -> patch/sec
  let mpersec kmperh * (1000 / 3600)
  let patchpersec mpersec / patch-width
  report patchpersec
end

to-report convert_ticks_to_hours

  report floor (tick-length-in-seconds * ticks / 3600)

end

to-report convert_ticks_to_remainder_minutes

  report ticks mod 60

end
@#$#@#$#@
GRAPHICS-WINDOW
210
10
622
423
-1
-1
4.0
1
10
1
1
1
0
0
0
1
-50
50
-50
50
0
0
1
ticks
30.0

BUTTON
10
61
73
94
NIL
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
77
60
140
93
NIL
go
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

PLOT
1067
283
1376
433
height
height (m)
NIL
0.0
10.0
0.0
10.0
true
true
"set-plot-x-range 0 ceiling (1.1 * max (list (max [height] of hunters) (max [height] of preys)))" ""
PENS
"preys" 1.0 1 -4079321 true "set-plot-pen-interval 0.1\nhistogram [height] of preys" "set-plot-pen-interval 0.1\nhistogram [height] of preys"
"hunters" 1.0 1 -5298144 true "set-plot-pen-interval 0.1\nhistogram [height] of hunters" "set-plot-pen-interval 0.1\nhistogram [height] of hunters"

PLOT
1067
433
1377
583
time to exhaustion (TTE)
TTE (seconds)
NIL
0.0
10.0
0.0
10.0
true
true
"set-plot-x-range 0 ceiling (1.1 * max (list (max [time-to-exhaustion] of hunters) (max [time-to-exhaustion] of preys)))\n" ""
PENS
"preys" 1.0 1 -4079321 true "histogram [time-to-exhaustion] of preys" "histogram [time-to-exhaustion] of preys"
"hunters" 1.0 1 -5298144 true "histogram [time-to-exhaustion] of hunters" "histogram [time-to-exhaustion] of hunters"

INPUTBOX
21
98
99
158
SEED
0.0
1
0
Number

CHOOSER
35
160
190
205
display-mode
display-mode
"elevation" "obstacle" "elevation+obstacle" "prey-attraction"
1

BUTTON
41
273
172
306
NIL
update-display
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

PLOT
211
427
623
577
obstacles
patch obstacle height (m)
NIL
0.0
10.0
0.0
10.0
true
false
"set-plot-x-range 0 3\nset-histogram-num-bars 20" ""
PENS
"default" 1.0 1 -16777216 true "" "histogram [obstacle] of patches"

BUTTON
146
60
209
93
NIL
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

INPUTBOX
126
98
194
158
agent-scale
1.0
1
0
Number

MONITOR
63
10
120
55
hours
convert_ticks_to_hours
17
1
11

MONITOR
119
10
169
55
minutes
convert_ticks_to_remainder_minutes
17
1
11

SWITCH
36
205
179
238
display-track-marks
display-track-marks
0
1
-1000

SLIDER
632
72
944
105
par_prey-attractor-probability
par_prey-attractor-probability
0
100
1.0
1
1
%
HORIZONTAL

SLIDER
632
105
944
138
par_init-obstacle-scale
par_init-obstacle-scale
0
5
3.0
0.01
1
m height
HORIZONTAL

SLIDER
638
314
863
347
par_target-point-buffer-distance
par_target-point-buffer-distance
0
10
2.0
0.1
1
Km
HORIZONTAL

SLIDER
947
72
1329
105
par_obstacle-damage
par_obstacle-damage
0
1
0.01
0.01
1
m height (obstacle) / 1 m height (body) * 1 sec
HORIZONTAL

SLIDER
947
106
1329
139
par_track-mark-probability
par_track-mark-probability
0
100
1.0
1
1
% / 1 m height (body) * 1 sec
HORIZONTAL

SLIDER
632
137
944
170
par_track-pregeneration-period
par_track-pregeneration-period
0
100
12.0
1
1
hours
HORIZONTAL

TEXTBOX
634
49
784
67
Environment
14
0.0
1

MONITOR
527
445
616
490
patch-width (m)
patch-width
17
1
11

SLIDER
638
212
830
245
par_num-hunters
par_num-hunters
0
10
3.0
1
1
hunters
HORIZONTAL

TEXTBOX
641
193
791
211
Hunters
14
0.0
1

TEXTBOX
860
192
1010
210
Preys
14
0.0
1

SLIDER
641
353
832
386
par_hunters_height_min
par_hunters_height_min
1
par_hunters_height_max
1.5
0.01
1
m
HORIZONTAL

SLIDER
640
387
831
420
par_hunters_height_max
par_hunters_height_max
par_hunters_height_min
2
2.0
0.01
1
m
HORIZONTAL

SLIDER
641
430
832
463
par_hunters_speed_min
par_hunters_speed_min
1
par_hunters_speed_max
5.0
0.1
1
km/h
HORIZONTAL

SLIDER
640
467
833
500
par_hunters_speed_max
par_hunters_speed_max
par_hunters_speed_min
30
30.0
0.1
1
km/h
HORIZONTAL

SLIDER
645
509
835
542
par_hunters_tte_min
par_hunters_tte_min
1
par_hunters_tte_max
5.0
1
1
minutes
HORIZONTAL

SLIDER
645
543
836
576
par_hunters_tte_max
par_hunters_tte_max
par_hunters_tte_min
360
30.0
1
1
minutes
HORIZONTAL

SLIDER
627
584
848
617
par_hunters_reactiontime_min
par_hunters_reactiontime_min
1
par_hunters_reactiontime_max
5.0
1
1
seconds
HORIZONTAL

SLIDER
626
617
848
650
par_hunters_reactiontime_max
par_hunters_reactiontime_max
par_hunters_reactiontime_min
360
30.0
1
1
seconds
HORIZONTAL

SLIDER
854
353
1045
386
par_preys_height_min
par_preys_height_min
1
par_preys_height_max
1.5
0.01
1
m
HORIZONTAL

SLIDER
854
387
1045
420
par_preys_height_max
par_preys_height_max
par_preys_height_min
2
2.0
0.01
1
m
HORIZONTAL

SLIDER
854
432
1047
465
par_preys_speed_min
par_preys_speed_min
1
par_preys_speed_max
30.0
0.1
1
km/h
HORIZONTAL

SLIDER
854
466
1047
499
par_preys_speed_max
par_preys_speed_max
par_preys_speed_min
90
75.0
0.1
1
km/h
HORIZONTAL

SLIDER
854
509
1047
542
par_preys_tte_min
par_preys_tte_min
1
par_preys_tte_max
60.0
1
1
minutes
HORIZONTAL

SLIDER
854
544
1047
577
par_preys_tte_max
par_preys_tte_max
par_preys_tte_min
300
100.0
1
1
minutes
HORIZONTAL

SLIDER
854
584
1066
617
par_preys_reactiontime_min
par_preys_reactiontime_min
1
par_preys_reactiontime_max
60.0
1
1
seconds
HORIZONTAL

SLIDER
854
619
1066
652
par_preys_reactiontime_max
par_preys_reactiontime_max
par_preys_reactiontime_min
300
100.0
1
1
seconds
HORIZONTAL

SLIDER
850
213
1040
246
par_num-preys
par_num-preys
0
100
50.0
1
1
preys
HORIZONTAL

SLIDER
810
245
1043
278
par_preys_group_max_size
par_preys_group_max_size
0
100
10.0
1
1
preys/group
HORIZONTAL

MONITOR
637
269
725
314
NIL
target-point
17
1
11

SWITCH
36
237
181
270
display-target-point
display-target-point
1
1
-1000

SLIDER
825
280
1043
313
par_preys_safe-distance
par_preys_safe-distance
1
2000
1000.0
1
1
m
HORIZONTAL

@#$#@#$#@
## WHAT IS IT?

(a general understanding of what the model is trying to show or explain)

## HOW IT WORKS

(what rules the agents use to create the overall behavior of the model)

## HOW TO USE IT

(how to use the model, including a description of each of the items in the Interface tab)

## THINGS TO NOTICE

(suggested things for the user to notice while running the model)

## THINGS TO TRY

(suggested things for the user to try to do (move sliders, switches, etc.) with the model)

## EXTENDING THE MODEL

(suggested things to add or change in the Code tab to make the model more complicated, detailed, accurate, etc.)

## NETLOGO FEATURES

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES

(a reference to the model's URL on the web if it has one, as well as any other necessary credits, citations, and links)
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.2.2
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@
