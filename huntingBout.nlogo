globals
[
  ;;; constants
  patch-width
  ;tick-length-in-seconds
  max-perception-distance
  max-shooting-distance
  track-maximum

  ;;; parameters
  ;;;; contextual
  starting-point-buffer-distance
  obstacle-damage
  track-mark-probability
  track-pregeneration-period

  ;;;; hunters
  num-hunters

  hunters_height_stealth
  hunters_height_min
  hunters_height_max
  hunters_speed_stealth
  hunters_speed_min
  hunters_speed_max
  hunters_tte_min
  hunters_tte_max
  hunters_reactiontime_min
  hunters_reactiontime_max
  hunters_cooldowntime_min
  hunters_cooldowntime_max

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
  preys_cooldowntime_min
  preys_cooldowntime_max

  ;;;; environment
  init-obstacle-scale
  prey-attractor-probability

  ;;; variables
  starting-point
  target-point

  prey-attraction-max

  hunter-prey-sightings
  prey-hunter-sightings

  hunter-who-shot
  prey-who-got-shot
]

breed [ hunters hunter ]

breed [ preys prey ]

breed [ track-makers track-maker ]

hunters-own
[
  height
  stealth-height
  time-to-exhaustion
  reaction-time
  cooldown-time

  sighting
  message
  stealth

  ;;; internal/private
  hunters-in-sight
  preys-in-sight

  follow-track-target
  unseen-target-location
  approaching-target
  pursuing-target

  reaction-counter
  relax-counter

  running-counter
  cooldown-counter
  moved-this-turn

  ;;; measurements
  distance-moved
  hunting-mode-series
]

preys-own
[
  height
  time-to-exhaustion
  reaction-time
  cooldown-time

  group_id
  group-leader

  sighting
  message

  ;;; internal/private
  hunters-in-sight
  preys-in-sight

  unseen-target-location

  reaction-counter
  relax-counter

  running-counter
  cooldown-counter
  moved-this-turn
]

track-makers-own
[
  owner
  duration
]

patches-own
[
  elevation
  obstacle
  prey-attraction

  tracks
]

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; SETUP ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to setup

  clear-all

  set-input

  setup-environment

  setup-prey-groups

  setup-hunting-party

  initialise-perceptions

  generate-recent-tracks

  initialise-output

  update-display

  reset-ticks

end

to set-input

  set-constants

  set-parameters

end

to set-constants

  set patch-width 100 ;;; meters

  ;set tick-length-in-seconds 60 ;;; 1 tick = 1 minute

  set max-perception-distance sqrt ((world-width ^ 2) + (world-height ^ 2)) ;;; measured in patches orthogonal dimensions (default: diagonal distance)

  set track-maximum 5

end

to set-parameters

  random-seed SEED

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
  set hunters_height_stealth 1 ; metre
  set hunters_speed_min convert-kmperh-to-patchpersec par_hunters_speed_min ; patch width (m) per second
  set hunters_speed_max convert-kmperh-to-patchpersec par_hunters_speed_max
  set hunters_speed_stealth hunters_speed_min * 0.5
  set hunters_tte_min par_hunters_tte_min ; minutes
  set hunters_tte_max par_hunters_tte_max
  set hunters_reactiontime_min par_hunters_reactiontime_min
  set hunters_reactiontime_max par_hunters_reactiontime_max
  set hunters_cooldowntime_min par_hunters_cooldowntime_min
  set hunters_cooldowntime_max par_hunters_cooldowntime_max

  set max-shooting-distance par_max-shooting-distance / patch-width ;;; metres

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
  set preys_cooldowntime_min par_preys_cooldowntime_min
  set preys_cooldowntime_max par_preys_cooldowntime_max

  ;;;; positions
  set starting-point patch (min-pxcor + floor (world-width / 2)) (min-pycor + floor (world-height / 2))

  set starting-point-buffer-distance par_starting-point-buffer-distance ; km

  set target-point one-of patches with [
    pxcor < min-pxcor + 0.2 * world-width or
    pycor < min-pycor + 0.2 * world-height or
    pxcor > min-pxcor + 0.8 * world-width or
    pycor > min-pycor + 0.8 * world-height ] ;;; choose apatch near the edges as target point

  ;;; TO-DO - better definition/representation of previous planning
  ;;; (e.g., interesting points, attractors?, must be "economic", knowledge of area, movement patterns, wind direction of the day)

end

to initialise-output

  set hunter-prey-sightings 0
  set prey-hunter-sightings 0

  set hunter-who-shot nobody
  set prey-who-got-shot nobody

end

to setup-environment

  ask patches
  [
    set elevation random-float 10
    set obstacle (random-float 1) * (random-float 1) * init-obstacle-scale
    set prey-attraction 0
    if (random-float 100 < prey-attractor-probability) [ set prey-attraction 100 ]

    set tracks []
  ]

  repeat 10 [ diffuse elevation 0.5 ]

  ;repeat 10 [ diffuse obstacle 0.3 ]

  repeat 10 [ diffuse prey-attraction 0.3 ]

  set prey-attraction-max max [prey-attraction] of patches

;  ask patches with [pxcor = -10 and (pycor < -10 or pycor > 10)]
;  [
;    set obstacle 5
;  ]

end

to setup-prey-groups

  create-preys num-preys
  [
    set height preys_height_min + random-float (preys_height_max - preys_height_min)
    set time-to-exhaustion preys_tte_min + random (preys_tte_max - preys_tte_min)
    set time-to-exhaustion time-to-exhaustion * 60 ; convert minutes to seconds
    set reaction-time preys_reactiontime_min + random (preys_reactiontime_max - preys_reactiontime_min)
    set cooldown-time preys_cooldowntime_min + random (preys_cooldowntime_max - preys_cooldowntime_min)

    set group-leader false

    set unseen-target-location nobody

    set moved-this-turn false

    set shape "sheep"
  ]

  let unassigned preys
  let currentID 0

  let bufferDistance starting-point-buffer-distance * 1000 / patch-width ;;; km -> m -> patch widths
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
        move-to one-of neighbors ;;; shuffle initial position around group center
      ]
    ]

    ask one-of preys with [group_id = currentID]
    [
      set group-leader true
    ]

    set currentID currentID + 1
  ]

end

to generate-recent-tracks

  let trackPregenerationPeriodInSeconds track-pregeneration-period * 60 * 60 ;;; hours -> seconds

  ask preys
  [
    hatch-track-makers 1
    [
      let me self
      set owner [group_id] of myself
      set duration 1 + random trackPregenerationPeriodInSeconds
      set heading (mean [heading] of preys with [group_id = [owner] of me]) - 180
    ]
  ]

  ask track-makers
  [
    let me self
    let previousTrackMarkProbability track-mark-probability * 100 * (mean [height] of preys with [group_id = [owner] of me]) * (count preys with [group_id = [owner] of me])
    let obstacleDamage obstacle-damage * (mean [height] of preys with [group_id = [owner] of me]) * (count preys with [group_id = [owner] of me])
    let remainingDuration duration

    ;;; shuffle within neighbors to emulate group distribution
    ;move-to one-of neighbors

    repeat duration
    [
      set obstacle max (list 0 (obstacle - obstacleDamage))

      if (previousTrackMarkProbability > random-float 100)
      [
        let preyLeavingTrack one-of preys with [group_id = [owner] of me]
        add-track-from preyLeavingTrack (heading) (0 - remainingDuration)
      ]

      if (count neighbors < 8) [ die ] ;;; delete once it reaches the edges of the area

      rt (- 30 + random 60) ;;; add random direction biased by default heading

      fd 1

      set remainingDuration remainingDuration - 1
    ]

    die
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
      set cooldown-time hunters_cooldowntime_min + random (hunters_cooldowntime_max - hunters_cooldowntime_min)

      set follow-track-target nobody
      set unseen-target-location nobody
      set approaching-target nobody
      set pursuing-target nobody

      set stealth false

      set moved-this-turn false

      set shape "person"

      set distance-moved 0
      set hunting-mode-series []
    ]
  ]

end

to initialise-perceptions

  ask (turtle-set preys hunters)
  [
    set sighting false
    set message false
    set hunters-in-sight (turtle-set)
    set preys-in-sight (turtle-set)

    initialise-perception-links
  ]

end

to initialise-perception-links

  ifelse (breed = preys)
  [
    create-links-to other hunters [ set color red set hidden? true ]
    create-links-to other preys [ set color violet  set hidden? true ]
  ]
  [
    create-links-to other hunters [ set color cyan set hidden? true ]
    create-links-to other preys [ set color yellow set hidden? true ]
  ]

end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; GO ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to go

  ask (turtle-set preys hunters with [cooldown-counter = 0])
  [
    ifelse (sighting)
    [
      ifelse (breed = preys)
      [
        prey-sighting-move
      ]
      [
        hunter-sighting-move
      ]

      set moved-this-turn true
    ]
    [
      ;;; if there are no sighting, reaction counter is reset
      set reaction-counter 0
    ]
  ]

  ask (turtle-set preys hunters) with [not moved-this-turn and cooldown-counter = 0]
  [
    ifelse (message)
    [
      ifelse (breed = preys)
      [
        prey-message-move
      ]
      [
        hunter-message-move
      ]
    ]
    [
      ifelse (breed = preys)
      [
        let unseen-threat (unseen-target-location != nobody and distance unseen-target-location < preys_safe-distance)
        ifelse (unseen-threat)
        [
          prey-memory-move
        ]
        [
          prey-default-move
        ]

      ]
      [
        let unseen-prey (unseen-target-location != nobody and unseen-target-location != patch-here)
        ifelse (unseen-prey)
        [
          hunter-memory-move
        ]
        [
          hunter-default-move
        ]
      ]
    ]
  ]

  ask preys
  [
    check-escape-condition
  ]

  ask (turtle-set preys hunters)
  [
    check-cooldown-condition

    update-perception

    impact-vegetation
  ]

  ask (turtle-set preys hunters)
  [
    update-alertness

    set moved-this-turn false
  ]

  clear-older-tracks

  update-display

  if (print-messages) [ print "second has passed." ]

  tick

end

to prey-sighting-move

  if (print-messages) [ print (word "prey " who " sees hunter" ([who] of hunters-in-sight)) ]

  ifelse (reaction-counter > 0)
  [
    if (print-messages) [ print (word "thinking... " reaction-counter " secs to reaction") ]

    ;;; mark one of the patches of sightings as target (used once the reaction time has past and preys are no more in sight)
    set unseen-target-location [patch-here] of one-of hunters-in-sight

    ;;; PROCESS REACTION
    set reaction-counter reaction-counter - 1
  ]
  [
    ;;; FLEE
    move-away-from hunters-in-sight
  ]

end

to prey-message-move

  let fleeing-preys preys-in-sight with [ sighting and running-counter > 0 ]

  if (any? fleeing-preys)
  [
    ;;; FOLLOW FLEEING PREYS
    move-along-with fleeing-preys
  ]
  ;;; else, STAY ALERT
  ;;; message received, but the emmiting part is still not reacting.

end

to hunter-sighting-move

  if (print-messages) [ print (word "hunter " who " sees prey" ([who] of preys-in-sight)) ]

  ifelse (reaction-counter > 0)
  [
    if (print-messages) [ print (word "thinking... " reaction-counter " secs to reaction") ]

    ;;; mark one of the patches of sightings as target (used once the reaction time has past and preys are no more in sight)
    set unseen-target-location [patch-here] of one-of preys-in-sight

    ;;; PROCESS REACTION
    set reaction-counter reaction-counter - 1
  ]
  [
    ifelse (any? preys-in-sight with [sighting])
    [
      ;;; One sighted prey is already alert
      let alerted-preys preys-in-sight with [sighting]

      ;;; stand, if stealth
      set stealth false

      ifelse (min [distance myself] of alerted-preys < max-shooting-distance)
      [
        ;;; SHOOT
        hunter-shoot (min-one-of alerted-preys [distance myself])
      ]
      [
        ;;; TO-DO: STANDING-LIKE-A-BUSH

        ;;; PURSUE
        hunter-pursue (min-one-of alerted-preys [distance myself])
      ]

      ;;; prey becomes aware of this hunter, if not already before
      ask min-one-of alerted-preys [distance myself]
      [
       set hunters-in-sight (turtle-set myself hunters-in-sight)
      ]
    ]
    [
      ;;; STEALTH APPROACH
      hunter-approach (min-one-of preys-in-sight [distance myself])
    ]
  ]

end

to hunter-shoot [ aPrey ]

  if (print-messages) [ print (word "hunter " who " shoots prey " ([who] of aPrey)) ]

  let me self

  ;;; reset pursuing-target
  set pursuing-target nobody

  ifelse (random-float 100 < (1 - ( (distance aPrey) / max-shooting-distance )) * 100)
  [
    ;;; SUCCESS
    if (print-messages) [ print "success!" ]

    ;;; keep successful hunt information
    set prey-who-got-shot aPrey
    set hunter-who-shot self

    ;;; mark the spot
    ask [patch-here] of aPrey
    [
      sprout-track-makers 1
      [
        ;;; prey is shot
        set shape "x"
        set size 5
        set color red
      ]
    ]

    ;;; delete the prey agent
    ask aPrey
    [
      die
    ]
  ]
  [
    ;;; FAIL
    if (print-messages) [ print "fail!" ]
  ]

end

to hunter-pursue [ aPrey ]

  if (print-messages) [ print (word "hunter " who " pursues prey " ([who] of aPrey)) ]

  ;;; reset approaching-target
  set approaching-target nobody

  set pursuing-target aPrey

  let MoveDistance (get-speed-in-patch hunters_speed_max patch-here)

  face aPrey

  fd MoveDistance

end

to hunter-approach [ aPrey ]

  if (print-messages) [ print (word "hunter " who " approaches prey " ([who] of aPrey)) ]

  set approaching-target aPrey

  set stealth true

  let MoveDistance (get-speed-in-patch hunters_speed_stealth patch-here)

  face aPrey

  ;;; TO-DO: correct direction to account for obstacle (find protection) and smell (test wind)

  fd MoveDistance

end

to hunter-message-move

  let alerted-hunters hunters-in-sight with [sighting]

  ;;; IMMITATE OTHER APPROACH

end

to hunter-memory-move

  ;;; continue towards the point of last sighting
  face unseen-target-location

  ;;; move
  advance-with-heading-and-speed-here heading hunters_speed_min

end

to prey-memory-move

  ;;; continue moving away from the point of last sighting
  face unseen-target-location
  set heading heading - 180

  ;;; move
  advance-with-heading-and-speed-here heading preys_speed_min

end

to prey-default-move

  ;;; relaxing (alertness is decreased)
  if (relax-counter > 0)
  [ set relax-counter relax-counter - 1 ]

  ;;; reset running-counter (default assumed to be "effortless")
  set running-counter 0

  ;;; forget last sighting point
  set unseen-target-location nobody

  let moving false

  ;; set the default distance the turtle moves as the minimum
  let speed preys_speed_min

  ;;; *Define target heading* ;;;

  ;;; First priority: staying in an attractive patch (or moving out from unattractive ones)

  ;;; get a relative measure of how attractive is the current patch
  let patch-pull 0
  if (prey-attraction-max > 0)
  [ set patch-pull 100 * ([prey-attraction] of patch-here) / prey-attraction-max ]

  if (random-float 100 > patch-pull)
  [
    ;;; Second priority: keeping the group together
    ;;; NOTE: checks if all group members are in sight and, if so, head towards the closest one
    let myGroupId group_id
    let groupMembers other preys with [group_id = myGroupId]
    let groupMembersNotInSight groupMembers with [not presence-detected-by myself]

    if (not group-leader and count groupMembers > 0 and count groupMembers = count groupMembersNotInSight)
    [
      face min-one-of groupMembersNotInSight [distance myself]
    ]

    rt (- 15 + random 30) ;;; add random direction biased by default heading

    set moving true
  ]

  ;;; *Move towards target heading* ;;;

  if (moving)
  [
    advance-with-heading-and-speed-here heading speed
  ]

end

to hunter-default-move

  ;;; relaxing (alertness is decreased)
  if (relax-counter > 0)
  [ set relax-counter relax-counter - 1 ]

  ;;; reset running-counter (default assumed to be "effortless")
  set running-counter 0

  ;;; stand, if stealth
  set stealth false

  ;;; forget last sighting point
  set unseen-target-location nobody

  let other-tracks-index get-all-tracks-but-mine tracks

  ;;; search for tracks
  ifelse (length other-tracks-index > 0)
  [
    ;;; TRACKING
    ;;; get the most recent track
    set follow-track-target (item 0 (item 0 other-tracks-index))
    ;;; and face it
    set heading (item 1 (item 0 other-tracks-index))
  ]
  [
    ;;; SEARCHING
    set follow-track-target nobody ;;; erase reference to last track followed? (no consequence if the most recent track is always followed)
    ;;; or continue path towards target-point
    face target-point
  ]

  ;;; move
  advance-with-heading-and-speed-here heading hunters_speed_min

end

to-report get-all-tracks-but-mine [ tracksList ]

  let filteredList []

  foreach tracksList
  [
    aTrack ->
   if (first aTrack != self)
    [
      set filteredList lput aTrack filteredList
    ]
  ]

  report filteredList

end

to check-escape-condition ;;; preys

  if (count [neighbors4] of patch-here < 4)
  [
    if (print-messages) [ print (word "Prey " who " and group " group_id " escaped from hunting area") ]
    ask other preys with [group_id = [group_id] of myself] [ die ]
    die
  ]

end

to check-cooldown-condition

  ifelse (running-counter = time-to-exhaustion)
  [
    if (print-messages) [ print (word self " is exhausted!") ]
    ;;; exhasted, starts cooling down
    set cooldown-counter cooldown-time

    set running-counter 0
  ]
  [
    if (cooldown-counter > 0)
    [
      if (print-messages) [ print (word self " is cooling down") ]
      set cooldown-counter cooldown-counter - 1
    ]
  ]


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
      add-track-from myself ([heading] of myself) ticks
    ]
  ]

end

to add-track-from [ aTurtle direction date ]

  let newTrack (list (aTurtle) (direction) (date))
  set tracks fput newTrack tracks

end

to update-perception

  let me self

  set hunters-in-sight other hunters with [presence-detected-by me]
  set preys-in-sight other preys with [presence-detected-by me]

  ask my-out-links [ set hidden? true ]

  ask hunters-in-sight [ ask in-link-from me [ set hidden? false ] ]
  ask preys-in-sight [ ask in-link-from me [ set hidden? false ] ]

end

to update-alertness

  let oldSighting sighting
  let oldMessage message

  ifelse (breed = preys)
  [
    set sighting (any? hunters-in-sight)
    set message (any? preys-in-sight with [any? hunters-in-sight])

    ;;; account for new prey-hunter-sightings
    if (sighting and not oldSighting)
    [
      set reaction-counter reaction-time - relax-counter
      set relax-counter reaction-time

      set prey-hunter-sightings prey-hunter-sightings + count hunters-in-sight
    ]
  ]
  [
    set sighting (any? preys-in-sight)
    set message (any? hunters-in-sight with [any? preys-in-sight])

    ;;; account for new hunter-prey-sightings
    if (sighting and not oldSighting)
    [
      set reaction-counter reaction-time - relax-counter
      set relax-counter reaction-time

      set hunter-prey-sightings hunter-prey-sightings + count preys-in-sight
    ]
  ]

end

to clear-older-tracks

  ask patches with [length tracks > track-maximum]
  [
    set tracks sublist tracks 0 (track-maximum - 1)
;    repeat (length tracks - track-maximum)
;    [
;      set tracks remove-item ((length tracks) - 1) tracks
;    ]
  ]

end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; AUXILIARY PROCEDURES ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to-report presence-detected-by [ theOther ]

  ;;; skip calculations if agents are in the same patch
  ;if (patch-here = [patch-here] of theOther) [ report true ]
  ;if ((xcor = [xcor] of theOther) and (ycor = [ycor] of theOther)) [ report true ]

  let me self
  let response false

  ask theOther
  [
    let currentHeading heading
    ;;; NOTE: line-of-sight modifies theOther's heading, so we keep its current value and recover it later

    let lineOfSightFromTheOtherToMe line-of-sight-with me
    set response member? ([patch-here] of me) lineOfSightFromTheOtherToMe

    set heading currentHeading
  ]

  report response

end

to-report line-of-sight-with [ anotherTurtle ]

  ;;; a ray casting algorithm that takes into account:
  ;;; 1. elevation (ground level),
  ;;; 2. height of turtles
  ;;; 3. height of obstacles

  let visiblePatches (patch-set)

  let vantagePointHeight elevation + get-height

  face anotherTurtle

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
      if ([any? turtles-here with [breed = "preys" or breed = "hunters"]] of aPatch)
      [
        set aPatchHighestElement max (list aPatchHighestElement [max [get-height] of turtles-here with [breed = "preys" or breed = "hunters"]] of aPatch)
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

to-report get-height

  let value height

  if (breed = hunters and stealth)
  [ set value stealth-height ]

  report value

end

to move-away-from [ someTurtles ]

  ;;; make it acceptable that someTurtle is given as a single turtle
  set someTurtles (turtle-set someTurtles)

  if (print-messages) [ print "running away..." ]

  ;; Find the nearest turtle
  let closestTurtle min-one-of someTurtles [distance myself]

  if (print-messages) [ print (word "distance before: " (distance closestTurtle)) ]

  ;; Modulate speed according to distance and safe-distance
  let maxSpeed preys_speed_min
  if ([distance myself] of closestTurtle < preys_safe-distance)
  [
    set maxSpeed preys_speed_max
  ]

  let oppositeHeading towards closestTurtle - 180

  advance-with-heading-and-speed-here oppositeHeading maxSpeed

  if (print-messages) [ print (word "distance after: " (distance closestTurtle)) ]

  ;;; account for exertion
  set running-counter running-counter + 1

end

to move-along-with [ someTurtles ]

  ;;; make it acceptable that someTurtle is given as a single turtle
  set someTurtles (turtle-set someTurtles)

  if (print-messages)
  [
    print (word "prey " who " sees prey" ([who] of someTurtles) " fleeing.")
    print "running along..."
  ]

  ;; Find the nearest turtle
  let closestTurtle min-one-of someTurtles [distance myself]
  if (print-messages) [ print (word "distance before: " (distance closestTurtle)) ]

  ;; Modulate speed according to distance and safe-distance
  let maxSpeed preys_speed_min
  if ([distance myself] of closestTurtle < preys_safe-distance)
  [
    set maxSpeed preys_speed_max
  ]

  let fleeingHeading [heading] of closestTurtle

  advance-with-heading-and-speed-here fleeingHeading maxSpeed

  if (print-messages) [ print (word "distance after: " (distance closestTurtle)) ]

  ;;; account for exertion
  set running-counter running-counter + 1

end

;to-report get-latest-track-direction-from [ aTurtle ]
;
;  let direction heading
;
;  if (length tracks > 0)
;  [
;    ;;; find all tracks from turtle
;    let theTrack filter [ aTrack -> (item 0 aTrack) = aTurtle ] tracks
;
;    if (length theTrack > 0)
;    [
;      ;;; sort by time
;      set theTrack sort-by [ [ track1 track2 ] -> (item 2 track1) > (item 2 track2) ] theTrack
;
;      set theTrack first theTrack
;
;      set direction (item 1 theTrack)
;    ]
;  ]
;
;  report direction
;
;end

to advance-with-heading-and-speed-here [ aHeading aSpeed ]

  ;;; keep track of the target heading
  let targetHeading aHeading

  let MoveDistance (get-speed-in-patch aSpeed patch-here)

  set heading (get-best-route-heading targetHeading moveDistance)

  fd MoveDistance

  if (breed = hunters)
  [ set distance-moved distance-moved + aSpeed ]

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

to-report find-element [elementToFind listOfLists]
  ;;; procedure generated with Chat GPT-4o:
  ;;; "my Netlogo Assistant" By Stefano Cacciaguerra
  ;;; prompt:
  ;;; "Suggest a procedure in NetLogo that searches a given number in each of the first elements in a list of lists,
  ;;; and returns the corresponding element, if it exists, or an empty list, if it doesn't"

  let result []
  foreach listOfLists [
    element ->
    if (item 0 element = elementToFind) [
      set result element
    ]
  ]
  report result

end

to update-display

  paint-patches

  scale-agents

  update-hunters-shape

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
    if (display-mode = "tracks")
    [
      set pcolor black

      let track-owners get-track-owners tracks

      if (length track-owners > 0)
      [
        set pcolor [color] of first track-owners
      ]
    ]
  ]

  if (display-target-point)
  [
    ask target-point
    [
      set pcolor orange
      set plabel "TARGET"
    ]
  ]

end

to-report get-track-owners [ trackList ]

  let trackOwners []

  foreach trackList
  [
    aTrack ->
    set trackOwners lput (item 0 aTrack) trackOwners
  ]

  ;;; ensure to get those still around
  set trackOwners filter [i -> i != nobody] trackOwners

  report trackOwners

end

to scale-agents

  let ref patch-size * agent-scale

  ask (turtle-set preys hunters)
  [
    set size ref
  ]

end

to update-hunters-shape

  ask hunters
  [
    ifelse (stealth)
    [
      set shape "wolf"
    ]
    [
      set shape "person"
    ]
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

to-report convert-ticks-to-hours

  report floor (ticks / 3600)

end

to-report convert-ticks-to-remainder-minutes

  report floor (ticks / 60)

end

to-report convert-ticks-to-remainder-seconds

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
1
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
2
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
7.0
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
"elevation" "obstacle" "elevation+obstacle" "prey-attraction" "tracks"
4

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
"set-plot-x-range 0 (par_init-obstacle-scale + 1)\nset-histogram-num-bars 20" ""
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
3
NIL
NIL
1

INPUTBOX
126
98
194
158
agent-scale
1.5
1
0
Number

MONITOR
30
11
87
56
hours
convert-ticks-to-hours
17
1
11

MONITOR
86
11
136
56
minutes
convert-ticks-to-remainder-minutes
17
1
11

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
5.0
0.01
1
m height
HORIZONTAL

SLIDER
638
314
862
347
par_starting-point-buffer-distance
par_starting-point-buffer-distance
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
0.1
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
1
0.1
0.01
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
7.0
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
116
428
205
473
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
1.0
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
881
192
1031
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
634
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
634
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
869
351
1060
384
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
869
385
1060
418
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
869
430
1062
463
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
869
464
1062
497
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
869
507
1062
540
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
869
542
1062
575
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
1069
617
par_preys_reactiontime_min
par_preys_reactiontime_min
1
par_preys_reactiontime_max
60.0
1
1
secs
HORIZONTAL

SLIDER
854
619
1069
652
par_preys_reactiontime_max
par_preys_reactiontime_max
par_preys_reactiontime_min
300
100.0
1
1
secs
HORIZONTAL

SLIDER
871
213
1061
246
par_num-preys
par_num-preys
0
100
15.0
1
1
preys
HORIZONTAL

SLIDER
831
245
1064
278
par_preys_group_max_size
par_preys_group_max_size
0
100
6.0
1
1
preys/group
HORIZONTAL

MONITOR
635
243
723
288
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
0
1
-1000

SLIDER
846
280
1064
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

SWITCH
36
317
176
350
print-messages
print-messages
0
1
-1000

MONITOR
137
10
195
55
seconds
convert-ticks-to-remainder-seconds
17
1
11

SLIDER
631
654
849
687
par_hunters_cooldowntime_min
par_hunters_cooldowntime_min
0
par_hunters_cooldowntime_max
400.0
1
1
secs
HORIZONTAL

SLIDER
632
690
851
723
par_hunters_cooldowntime_max
par_hunters_cooldowntime_max
par_hunters_cooldowntime_min
20 * 60
800.0
1
1
secs
HORIZONTAL

SLIDER
851
654
1069
687
par_preys_cooldowntime_min
par_preys_cooldowntime_min
0
par_preys_cooldowntime_max
200.0
1
1
secs
HORIZONTAL

SLIDER
851
689
1070
722
par_preys_cooldowntime_max
par_preys_cooldowntime_max
par_preys_cooldowntime_min
20 * 60
600.0
1
1
secs
HORIZONTAL

PLOT
210
580
623
730
Sightings
NIL
NIL
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"preys" 1.0 0 -1184463 true "" "plot prey-hunter-sightings"
"hunters" 1.0 0 -2674135 true "" "plot hunter-prey-sightings"

PLOT
209
732
621
882
Tracks
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot sum [length tracks] of patches"

SLIDER
637
280
850
313
par_max-shooting-distance
par_max-shooting-distance
10
100
50.0
1
1
m
HORIZONTAL

MONITOR
99
473
205
518
world-width (Km)
world-width * patch-width * 1E-3
17
1
11

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
