globals
[
  ;;; constants
  patch-width
  max-perception-distance
  track-maximum
  good-daylight-duration
  starting-point
  wind-spread-angle

  ;;; parameters
  ;;;; contextual
  starting-point-buffer-distance
  obstacle-damage
  track-mark-probability
  track-pregeneration-period
  ;;; NOTE: candidates for variable
  wind-speed
  wind-direction

  ;;;; hunters (population)
  num-hunters

  num-planned-waypoints

  hunters_height_stealth
  hunters_height_min
  hunters_height_max
  hunters_visualacuity_mean
  hunters_visualacuity_sd
  hunters_speed_stealth
  hunters_speed_min
  hunters_speed_max
  hunters_speed_avmax
  hunters_tte_min
  hunters_tte_max
  hunters_reactiontime_min
  hunters_reactiontime_max
  hunters_cooldowntime_min
  hunters_cooldowntime_max

  max-shooting-distance

  hunters_hearing_radius
  hunters_fov

  ;;;; preys (population)
  num-preys
  preys_group_max_size
  preys_safe-distance

  preys_height_min
  preys_height_max
  preys_visualacuity_mean
  preys_visualacuity_sd
  preys_speed_min
  preys_speed_max
  preys_speed_avmax
  preys_tte_min
  preys_tte_max
  preys_reactiontime_min
  preys_reactiontime_max
  preys_cooldowntime_min
  preys_cooldowntime_max

  preys_hearing_radius
  preys_fov

  ;;;; environment
  init-obstacle-scale
  init-obstacle-frequency
  init-obstacle-diffuse-times
  init-obstacle-diffuse-rate

  prey-attractor-probability
  attractiveness-diffuse-times
  attractiveness-diffuse-rate

  fires-number
  fires-radius

  ;;; variables
  attractiveness-to-prey-max

  planned-waypoints
  visited-waypoints
  discarded-waypoints

  hunter-prey-detections
  prey-hunter-detections

  sneaks
  pursues
  shots

  was-bout-successful
  is-bout-finished
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
  visual-acuity
  speed-max
  time-to-exhaustion
  reaction-time
  cooldown-time

  any-detection
  any-unseen-target
  stealth
  success

  hunters-detected
  preys-detected

  unseen-target-location

  follow-track-target
  approaching-target
  pursuing-target

  ;;; internal/private
  approach-path

  reaction-counter
  relax-counter

  exhaustion-counter
  cooldown-counter
  moved-this-turn

  ;;; measurements
  distance-moved

  hunting-mode-series
  position-series-x
  position-series-y
]

preys-own
[
  height
  visual-acuity
  speed-max
  time-to-exhaustion
  reaction-time
  cooldown-time

  group_id
  group-leader

  any-detection
  any-unseen-target

  ;;; internal/private
  hunters-detected
  preys-detected

  unseen-target-location

  reaction-counter
  relax-counter

  exhaustion-counter
  cooldown-counter
  moved-this-turn
]

track-makers-own
[
  owner
  maximum-track-antiquity
]

patches-own
[
  elevation
  obstacle
  attractiveness-to-prey

  tracks

  ;;; path-finding related
  parent-patch ; patch's predecessor
  f ; the value of knowledge plus heuristic cost function f()
  g ; the value of knowledge cost function g()
  h ; the value of heuristic cost function h()
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

  reset-ticks

  update-display

end

to set-input

  set-constants

  set-parameters

end

to set-constants

  set patch-width 50 ;;; meters

  set max-perception-distance 1000 * 5 / patch-width ;;; patch-width unit (default: 1000 * 5 / patch-width, i.e. 5 km approximation on person standing on flat terrain on Earth)

  set track-maximum 5

  set good-daylight-duration 8 * 60 * 60 ;;; default: 8 hours in seconds
  ;;; NOTE: the range in Namibia study areas of total daylight 9-10 hours; discouting an hour to get back to camp

  set starting-point patch (min-pxcor + floor (world-width / 2)) (min-pycor + floor (world-height / 2))

  set wind-spread-angle 30 ; degrees, each side of main direction

end

to set-parameters

  random-seed SEED

  ;;; parameters

  set-scenario-environment-parameters

  set obstacle-damage par_obstacle-damage ;;; damage (m obstacle) / 1 (m height) * 1 (sec)

  set track-mark-probability par_track-mark-probability ;;; prob. / 1 (m height) * 1 (sec)

  set track-pregeneration-period par_track-pregeneration-period

  set wind-speed convert-kmperh-to-patchpersec par_wind-speed ; patch width (m) per second
  set wind-direction par_wind-direction ; degrees, from default NetLogo's (North = 0)

  ;;;; hunters
  set num-hunters par_num-hunters
  set hunters_height_min par_hunters_height_min ; meters
  set hunters_height_max par_hunters_height_max
  set hunters_height_stealth par_hunters_height_stealth ; metre
  set hunters_visualacuity_mean par_hunters_visualacuity_mean ; % of maximum perception distance
  set hunters_visualacuity_sd par_hunters_visualacuity_sd
  set hunters_speed_min convert-kmperh-to-patchpersec par_hunters_speed_min ; patch width (m) per second
  set hunters_speed_max convert-kmperh-to-patchpersec par_hunters_speed_max
  set hunters_speed_avmax convert-kmperh-to-patchpersec par_hunters_speed_avmax
  set hunters_speed_stealth hunters_speed_min * (par_hunters_speed_stealth / 100)
  set hunters_tte_min par_hunters_tte_min ; minutes
  set hunters_tte_max par_hunters_tte_max
  set hunters_reactiontime_min par_hunters_reactiontime_min
  set hunters_reactiontime_max par_hunters_reactiontime_max
  set hunters_cooldowntime_min par_hunters_cooldowntime_min
  set hunters_cooldowntime_max par_hunters_cooldowntime_max

  set max-shooting-distance par_max-shooting-distance / patch-width ;;; metres

  set hunters_hearing_radius par_hunters_hearing_radius / patch-width
  set hunters_fov par_hunters_fov ;;; degrees

  set num-planned-waypoints par_num-planned-waypoints

  ;;;; preys
  set num-preys par_num-preys
  set preys_group_max_size par_preys_group_max_size
  set preys_safe-distance par_preys_safe-distance / patch-width
  set preys_height_min par_preys_height_min ; meters
  set preys_height_max par_preys_height_max
  set preys_visualacuity_mean par_preys_visualacuity_mean ; % of maximum perception distance
  set preys_visualacuity_sd par_preys_visualacuity_sd
  set preys_speed_min convert-kmperh-to-patchpersec par_preys_speed_min ; patch width (m) per second
  set preys_speed_max convert-kmperh-to-patchpersec par_preys_speed_max
  set preys_speed_avmax convert-kmperh-to-patchpersec par_preys_speed_avmax
  set preys_tte_min par_preys_tte_min ; minutes
  set preys_tte_max par_preys_tte_max
  set preys_reactiontime_min par_preys_reactiontime_min
  set preys_reactiontime_max par_preys_reactiontime_max
  set preys_cooldowntime_min par_preys_cooldowntime_min
  set preys_cooldowntime_max par_preys_cooldowntime_max

  set preys_hearing_radius par_preys_hearing_radius / patch-width
  set preys_fov par_preys_fov ;;; degrees

  set starting-point-buffer-distance par_starting-point-buffer-distance ; km

end

to set-scenario-environment-parameters

  if (scenario-environment = "user-defined")
  [
    set init-obstacle-scale par_init-obstacle-scale
    set init-obstacle-frequency par_init-obstacle-frequency
    set init-obstacle-diffuse-times par_init-obstacle-diffuse-times
    set init-obstacle-diffuse-rate par_init-obstacle-diffuse-rate

    set prey-attractor-probability par_prey-attractor-probability
    set attractiveness-diffuse-times par_attractiveness-diffuse-times
    set attractiveness-diffuse-rate par_attractiveness-diffuse-rate

    set fires-number par_fires-number
    set fires-radius par_fires-radius
  ]
  if (scenario-environment = "default")
  [
    set init-obstacle-scale 5
    set init-obstacle-frequency 5
    set init-obstacle-diffuse-times 10
    set init-obstacle-diffuse-rate 0.3

    set prey-attractor-probability 1
    set attractiveness-diffuse-times 10
    set attractiveness-diffuse-rate 0.3

    ;;; no fires
    set fires-number 0
    set fires-radius 0
  ]
  if (scenario-environment = "wet and no fires")
  [
    set init-obstacle-scale 10
    set init-obstacle-frequency 10
    set init-obstacle-diffuse-times 5
    set init-obstacle-diffuse-rate 0.3

    set prey-attractor-probability 20
    set attractiveness-diffuse-times 10
    set attractiveness-diffuse-rate 0.3

    ;;; no fires
    set fires-number 0
    set fires-radius 0
  ]
  if (scenario-environment = "dry and no fires")
  [
    set init-obstacle-scale 2
    set init-obstacle-frequency 5
    set init-obstacle-diffuse-times 5
    set init-obstacle-diffuse-rate 0.3

    set prey-attractor-probability 0.1
    set attractiveness-diffuse-times 10
    set attractiveness-diffuse-rate 0.3

    ;;; no fires
    set fires-number 0
    set fires-radius 0
  ]
  if (scenario-environment = "wet with fires")
  [
    set init-obstacle-scale 10
    set init-obstacle-frequency 10
    set init-obstacle-diffuse-times 5
    set init-obstacle-diffuse-rate 0.3

    set prey-attractor-probability 20
    set attractiveness-diffuse-times 10
    set attractiveness-diffuse-rate 0.3

    ;;; with fires
    set fires-number 20
    set fires-radius 100
  ]
  if (scenario-environment = "dry with fires")
  [
    set init-obstacle-scale 2
    set init-obstacle-frequency 5
    set init-obstacle-diffuse-times 5
    set init-obstacle-diffuse-rate 0.3

    set prey-attractor-probability 0.1
    set attractiveness-diffuse-times 10
    set attractiveness-diffuse-rate 0.3

    ;;; with fires
    set fires-number 20
    set fires-radius 100
  ]

end

to initialise-output

  set hunter-prey-detections 0
  set prey-hunter-detections 0

  set sneaks 0
  set pursues 0
  set shots 0

  set was-bout-successful false
  set hunter-who-shot ""
  set prey-who-got-shot ""

  set is-bout-finished false

end

to setup-environment

  ask patches
  [
    set elevation random-float 10

    set tracks []
  ]

  repeat 10 [ diffuse elevation 0.5 ]

;  ask patches with [pxcor = floor (world-width / 2) and (pycor < floor ((world-height / 2) - 10) or pycor > floor ((world-height / 2) + 10))]
;  [
;    set obstacle 5
;  ]

  let num-patches-with-init-obstacle ((init-obstacle-frequency / 100) * count patches)

  ask n-of num-patches-with-init-obstacle patches [ set obstacle init-obstacle-scale ]

  repeat init-obstacle-diffuse-times [ diffuse obstacle init-obstacle-diffuse-rate ]

  ask patches [ if (random-float 100 < prey-attractor-probability) [ set attractiveness-to-prey 100 ] ]

  repeat attractiveness-diffuse-times [ diffuse attractiveness-to-prey attractiveness-diffuse-rate ]

  set attractiveness-to-prey-max max [attractiveness-to-prey] of patches

  ask n-of fires-number patches
  [
    set obstacle 0
    set attractiveness-to-prey 100

    ask patches in-radius floor (fires-radius / patch-width)
    [
      set obstacle 0
      set attractiveness-to-prey 100
    ]
  ]

  set attractiveness-to-prey-max max [attractiveness-to-prey] of patches

end

to setup-prey-groups

  create-preys num-preys
  [
    set height preys_height_min + random-float (preys_height_max - preys_height_min)
    set visual-acuity min list (random-normal preys_visualacuity_mean preys_visualacuity_sd) 100
    set speed-max sample-skewed-speed preys_speed_min preys_speed_max preys_speed_avmax

    set time-to-exhaustion (preys_tte_min + random (preys_tte_max - preys_tte_min)) * 60
    set reaction-time preys_reactiontime_min + random (preys_reactiontime_max - preys_reactiontime_min)
    set cooldown-time preys_cooldowntime_min + random (preys_cooldowntime_max - preys_cooldowntime_min)

    set group-leader false
    set any-unseen-target false
    set unseen-target-location no-patches
    set moved-this-turn false
    set shape "sheep"
  ]

  ;; Initialize variables for grouping
  let unassigned preys
  let currentID 0
  let buffer-distance starting-point-buffer-distance * 1000 / patch-width ;;; km -> m -> patch widths
  let valid-initial-positions patches with [distance starting-point > buffer-distance]

  ;; Group assignment loop
  while [any? unassigned]
  [
    let groupSize min list preys_group_max_size (count unassigned)
    let newGroupMembers n-of (1 + random groupSize) unassigned
    ask newGroupMembers
    [
      set group_id currentID
    ]

    ;; Assign group leader
    ask one-of newGroupMembers
    [
      set group-leader true
    ]

    ;; Position the group
    let preyPosition one-of valid-initial-positions
    ask preys with [group_id = currentID]
    [
      move-to preyPosition
      if (not group-leader)
      [
        ;;; shuffle initial position around leader
        move-to one-of neighbors
      ]
    ]

    set unassigned unassigned with [not member? self newGroupMembers]

    set currentID currentID + 1
  ]

end

to generate-recent-tracks

  let trackPregenerationPeriodInSeconds convert-hours-to-seconds track-pregeneration-period

  ask preys
  [
    hatch-track-makers 1
    [
      let me self
      set owner [group_id] of myself
      set maximum-track-antiquity trackPregenerationPeriodInSeconds
      set heading (mean [heading] of preys with [group_id = [owner] of me]) - 180
    ]
  ]

  ask track-makers
  [
    let me self
    let previousTrackMarkProbability track-mark-probability * 100 * (mean [height] of preys with [group_id = [owner] of me]) * (count preys with [group_id = [owner] of me])
    let obstacleDamage obstacle-damage * (mean [height] of preys with [group_id = [owner] of me]) * (count preys with [group_id = [owner] of me])
    let trackAntiquity 0

    ;;; shuffle within neighbors to emulate group distribution
    ;move-to one-of neighbors

    while [ trackAntiquity < maximum-track-antiquity ]
    [
      set obstacle max (list 0 (obstacle - obstacleDamage))

      if (previousTrackMarkProbability > random-float 100)
      [
        let preyLeavingTrack one-of preys with [group_id = [owner] of me]
        add-track-from preyLeavingTrack (heading) (0 - trackAntiquity)
      ]

      if (count neighbors < 8) [ die ] ;;; delete once it reaches the edges of the area

      ;;; get a relative measure of how attractive is the current patch
      let patch-pull 0
      if (attractiveness-to-prey-max > 0)
      [ set patch-pull 100 * ([attractiveness-to-prey] of patch-here) / attractiveness-to-prey-max ]

      if (random-float 100 > patch-pull)
      [
        rt (- 30 + random 60) ;;; add random direction biased by default heading

        fd 1
      ]
      set trackAntiquity trackAntiquity + 1
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
      set stealth-height height * (hunters_height_stealth / 100)
      set visual-acuity clamp0100 (random-normal hunters_visualacuity_mean hunters_visualacuity_sd)
      set speed-max sample-skewed-speed hunters_speed_min hunters_speed_max hunters_speed_avmax

      set time-to-exhaustion hunters_tte_min + random (hunters_tte_max - hunters_tte_min)
      set time-to-exhaustion time-to-exhaustion * 60 ; convert minutes to seconds
      set reaction-time hunters_reactiontime_min + random (hunters_reactiontime_max - hunters_reactiontime_min)
      set cooldown-time hunters_cooldowntime_min + random (hunters_cooldowntime_max - hunters_cooldowntime_min)

      set any-unseen-target false
      set unseen-target-location no-patches

      set follow-track-target nobody
      set approaching-target nobody
      set pursuing-target nobody

      set approach-path []

      set stealth false
      set success false

      set moved-this-turn false

      set shape "person"

      set distance-moved 0
      set hunting-mode-series []
      set position-series-x []
      set position-series-y []
    ]
  ]

  ;;; hunters group movement planning
  set planned-waypoints get-planned-waypoints num-planned-waypoints
  set visited-waypoints []
  set discarded-waypoints []

end

to-report get-planned-waypoints [ numPoints ]

  let valid-candidates patches with [count neighbors = 8]
  ; NOTE: ignore edge patches that might peak because of the use of the diffuse command in setup-environment

  let selected-waypoints n-of numPoints valid-candidates

  ;;; filter candidates with the most prey attractiveness (known points of interest)
  if (waypoints-to-prey-attractors)
  [
    set selected-waypoints max-n-of numPoints valid-candidates [attractiveness-to-prey]
  ]
  ;;; TO-DO - better definition/representation of previous planning
  ;;; (e.g., interesting points, attractors?, must be "economic", knowledge of area, movement patterns, wind direction of the day)

  report selected-waypoints

end

to initialise-perceptions

  ask (turtle-set preys hunters)
  [
    set any-detection false
    set hunters-detected (turtle-set)
    set preys-detected (turtle-set)

    initialise-perception-links
  ]

end

to initialise-perception-links

  ifelse (breed = preys)
  [
    create-links-from other hunters [ set color red set hidden? true ]
    create-links-from other preys [ set color violet  set hidden? true ]
  ]
  [
    create-links-from other hunters [ set color cyan set hidden? true ]
    create-links-from other preys [ set color yellow set hidden? true ]
  ]

end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; GO ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to go

  ask (turtle-set preys hunters with [cooldown-counter = 0])
  [
    ifelse (any-detection)
    [
      ifelse (breed = preys)
      [
        prey-detection-move
      ]
      [
        hunter-detection-move
      ]

      set moved-this-turn true
    ]
    [
      ;;; if there are no detection, reaction counter is reset
      set reaction-counter 0
    ]
  ]

  ask (turtle-set preys hunters) with [not moved-this-turn and cooldown-counter = 0]
  [
    ifelse (any-unseen-target)
    [
      ifelse (breed = preys)
      [
        prey-memory-move
      ]
      [
        hunter-memory-move
      ]
    ]
    [
      ifelse (breed = preys)
      [
        prey-default-move
      ]
      [
        hunter-default-move
      ]
    ]
  ]

  ask (turtle-set preys hunters) with [has-message]
  [
    ifelse (breed = preys)
    [
      prey-communicate
    ]
    [
      hunter-communicate
    ]
  ]

  ask preys
  [
    check-escape-condition
  ]

  ask hunters
  [
    update-waypoints
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

  ask hunters [ save-position ]

  clear-older-tracks

  update-display

  if (print-messages) [ print "second has passed." ]

  if (was-bout-successful or is-bout-finished) [ stop ] ;;; interrupt simulation once there is a successful shot or a hunter arrives back to camp

  tick

end

to prey-detection-move

  if (print-messages) [ print (word "prey " who " sees hunter" ([who] of hunters-detected)) ]

  ifelse (reaction-counter > 0)
  [
    if (print-messages) [ print (word "thinking... " reaction-counter " secs to reaction") ]

    ;;; PROCESS REACTION
    set reaction-counter reaction-counter - 1
  ]
  [
    ;;; FLEE
    move-away-from hunters-detected
  ]

end

to prey-message-move

  let fleeing-preys preys-detected with [ any-detection and exhaustion-counter > 0 ]

  if (any? fleeing-preys)
  [
    ;;; FOLLOW FLEEING PREYS
    move-along-with fleeing-preys
  ]
  ;;; else, STAY ALERT
  ;;; message received, but the emmiting part is still not reacting.

end

to hunter-detection-move

  if (print-messages) [ print (word "hunter " who " sees prey" ([who] of preys-detected)) ]

  ;;; reset follow-track-target (detection takes priority)
  set follow-track-target nobody

  ifelse (reaction-counter > 0)
  [
    if (print-messages) [ print (word "thinking... " reaction-counter " secs to reaction") ]

    ;;; PROCESS REACTION
    set reaction-counter reaction-counter - 1
  ]
  [
    let me self
    let alerted-preys preys-detected with [any-detection and member? me hunters-detected]

    ifelse (any? alerted-preys)
    [
      ;;; prey becomes aware of this hunter, if not already before
      ask min-one-of alerted-preys [distance myself]
      [
       set hunters-detected (turtle-set myself hunters-detected)
      ]

      ifelse (min [distance myself] of alerted-preys < max-shooting-distance)
      [
        ;;; SHOOT
        save-hunting-mode "SHOOT"
        set shots shots + 1
        hunter-shoot (min-one-of alerted-preys [distance myself])
      ]
      [
        ;;; TO-DO: STANDING-LIKE-A-BUSH

        ;;; PURSUE
        save-hunting-mode "PURSUE"
        set pursues pursues + 1
        hunter-pursue (min-one-of alerted-preys [distance myself])
      ]
    ]
    [
      ;;; STEALTH APPROACH
      save-hunting-mode "APPROACH-STEALTH"
      set sneaks sneaks + 1
      hunter-approach (min-one-of preys-detected [distance myself])
    ]
  ]

end

to hunter-shoot [ aPrey ]

  if (print-messages) [ print (word "hunter " who " shoots prey " ([who] of aPrey)) ]

  let me self

  ;;; stand, if stealth
  set stealth false

  ;;; reset approaching-target
  set approaching-target nobody
  set approach-path []

  ;;; reset pursuing-target
  set pursuing-target nobody

  ifelse (random-float 100 < (1 - ( (distance aPrey) / max-shooting-distance )) * 100)
  [
    ;;; SUCCESS

    ;;; signal successful hunt and head back to camp
    set discarded-waypoints planned-waypoints
    set planned-waypoints (patch-set starting-point)
    save-hunting-mode "SUCCESSFUL-SHOT"
    save-hunting-mode "BACK-TO-CAMP"
    if (print-messages) [ print "success!" ]
    set success true
    set was-bout-successful true

    ;;; keep successful hunt information
    set prey-who-got-shot (word prey-who-got-shot " " aPrey)
    set hunter-who-shot (word hunter-who-shot " " self)

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

    ;;; the prey agent is alerted and will start to flee
    ask aPrey
    [

      ;die
      set any-unseen-target true
      set unseen-target-location (patch-set ([patch-here] of me))
    ]
  ]
  [
    ;;; FAIL
    if (print-messages) [ print "fail!" ]
  ]

end

to hunter-pursue [ aPrey ]

  if (print-messages) [ print (word "hunter " who " pursues prey " ([who] of aPrey)) ]

  ;;; stand, if stealth
  set stealth false

  ;;; reset approaching-target
  set approaching-target nobody
  set approach-path []

  set pursuing-target aPrey

  let MoveDistance (get-speed-in-patch hunters_speed_max patch-here)

  face aPrey

  make-a-move speed-max speed-max

end

to hunter-approach [ aPrey ]

  if (print-messages) [ print (word "hunter " who " approaches prey " ([who] of aPrey)) ]

  ;;; reset pursuing-target
  set pursuing-target nobody

  let me self
  set approaching-target aPrey

  ifelse ([distance me] of aPrey < preys_safe-distance)
  [
    ;;; target is close by:
    ;;; assume stealth posture
    set stealth true
  ]
  [
    ;;; unseen-target is still far:
    ;;; stand, if stealth
    set stealth false
  ]

  ;;; find path with most obstacles (hiding)
  ;;; TO-DO: correct direction to account for smell (test wind)
  set approach-path find-a-path patch-here [patch-here] of aPrey

  face item 1 approach-path ;;; face towards the next patch in the path

  make-a-move hunters_speed_stealth speed-max

end

to hunter-memory-move

  save-hunting-mode "APPROACH-BLIND"

  ;;; reset approaching-target and pursuing-target
  set approaching-target nobody
  set pursuing-target nobody

  let me self
  let unseenTarget min-one-of unseen-target-location [distance me]

  ifelse ([distance me] of unseenTarget < preys_safe-distance)
  [
    ;;; unseen-target is close by:
    ;;; assume stealth posture, if not already
    set stealth true
  ]
  [
    ;;; unseen-target is still far:
    ;;; stand, if stealth
    set stealth false
  ]

  ;;; discard stealthy route
  ;set approach-path []
  ;;; continue towards the point of last detection
  ;face unseenTarget

  ;;; find path with most obstacles (hiding)
  ;;; TO-DO: correct direction to account for smell (test wind)
  set approach-path find-a-path patch-here unseenTarget

  face item 1 approach-path ;;; face towards the next patch in the path

  make-a-move hunters_speed_min speed-max

end

to prey-memory-move

  let me self
  let unseenTarget min-one-of unseen-target-location [distance me]

  ;;; continue moving away from the point of last detection
  face unseenTarget
  set heading heading - 180

  make-a-move preys_speed_min speed-max

  ;;; forget unseen target if safe enough distance
  if (distance unseenTarget >= preys_safe-distance)
  [
    set unseen-target-location unseen-target-location with [self != unseenTarget]
  ]

end

to prey-default-move

  ;;; relaxing (alertness is decreased)
  if (relax-counter > 0)
  [ set relax-counter relax-counter - 1 ]

  let moving false

  ;;; *Define target heading* ;;;

  ;;; First priority: keeping the group together
  ;;; NOTE: checks if all group members are in sight and, if so, head towards the closest one
  let myGroupId group_id
  let groupMembers preys with [group_id = myGroupId]
  let groupMembersNotInSight other groupMembers with [not presence-detected-by myself]
  let groupLeader one-of groupMembers with [group-leader]

  let leaderNotInSight false
  if (not group-leader and count groupMembers > 1) [ set leaderNotInSight member? groupLeader groupMembersNotInSight ]

  ifelse (leaderNotInSight)
  [
    face groupLeader
    set moving true
  ]
  [
    ;;; Second priority: staying in an attractive patch (or moving out from unattractive ones)
    ;;; get a relative measure of how attractive is the current patch
    let patch-pull 0
    if (attractiveness-to-prey-max > 0)
    [ set patch-pull 100 * ([attractiveness-to-prey] of patch-here) / attractiveness-to-prey-max ]

    if (random-float 100 > patch-pull)
    [
      ;;; if patch-pull is low enough, move.
      ;;; add random direction biased by default heading
      rt (- (preys_fov / 2) + random preys_fov)
      set moving true
    ]
  ]

  ;;; *Move towards target heading* ;;;

  if (moving)
  [
    make-a-move preys_speed_min speed-max
  ]

end

to hunter-default-move

  ;;; relaxing (alertness is decreased)
  if (relax-counter > 0)
  [ set relax-counter relax-counter - 1 ]

  ;;; stand, if stealth
  set stealth false

  ;;; reset approaching-target
  set approaching-target nobody
  set approach-path []

  ;;; reset pursuing-target
  set pursuing-target nobody

  let tracksHere get-all-tracks-but-hunters tracks

  ;;; search for tracks
  ifelse (length tracksHere > 0)
  [
    ;;; TRACKING
    save-hunting-mode "TRACK"
    ;;; get the most recent track
    set follow-track-target (item 0 (item 0 tracksHere))
    ;;; and face it
    set heading (item 1 (item 0 tracksHere))
  ]
  [
    ;;; SEARCHING
    save-hunting-mode "SEARCH"
    set follow-track-target nobody ;;; erase reference to last track followed? (no consequence if the most recent track is always followed)
    ;;; continue path towards next waypoint
    let me self
    face min-one-of planned-waypoints [distance me]
    ;;; add random direction biased by default heading
    rt (- (hunters_fov / 2) + random hunters_fov)
  ]

  ;;; move
  make-a-move hunters_speed_min speed-max

end

to-report get-all-tracks-but-hunters [ tracksList ]

  let filteredList []

  foreach tracksList
  [
    aTrack ->
    let trackOwnerStillExists (first aTrack != nobody)
    if (trackOwnerStillExists)
    [
      let trackOwnerIsNotHunter ([breed] of first aTrack != hunters)
      if (trackOwnerIsNotHunter)
      [
        set filteredList lput aTrack filteredList
      ]
    ]
  ]

  report filteredList

end

to hunter-communicate

  let me self
  ;;; Option A: send message to any hunters seen me
  let receivers hunters with [member? me hunters-detected]
  ;;; Option B: send message only to hunters seen me that are also seen by me
  ;let receivers hunters-detected with [member? me hunters-detected]

  ask receivers
  [
    ;;; communicate success
    ifelse ([success] of me)
    [
      set planned-waypoints (patch-set starting-point)
      save-hunting-mode "BACK-TO-CAMP"
      set success true
      set stealth false
    ]
    [
      ;;; communicate stealth
      if ([stealth] of me)
      [
        set stealth true
      ]

      ;;; add unseen location to any other already in memory
      set unseen-target-location (patch-set ([unseen-target-location] of me) unseen-target-location)
      ;;; but if the current patch of either hunter is in this set, discard it
      let patchISee patch-here
      let patchSenderSee [patch-here] of me
      set unseen-target-location unseen-target-location with [self != patchISee and self != patchSenderSee]

      ;;; get track target if not already following one
      if (follow-track-target = nobody and [follow-track-target] of me != nobody)
      [
        save-hunting-mode "TRACK"
        set follow-track-target [follow-track-target] of me
      ]

      ;;; get approaching target if not already pursuing or approaching one
      if (approaching-target = nobody and pursuing-target = nobody and [approaching-target] of me != nobody)
      [
        save-hunting-mode "APPROACH-STEALTH"
        set approaching-target [approaching-target] of me
      ]

      ;;; get pursuing target if not already pursuing or approaching one
      if (approaching-target = nobody and pursuing-target = nobody and [pursuing-target] of me != nobody)
      [
        save-hunting-mode "PURSUE"
        set pursuing-target [pursuing-target] of me
      ]
    ]
  ]

end

to prey-communicate

  let me self
  let receivers preys-detected with [member? me preys-detected]

  ask receivers
  [
    ;;; add unseen location to any other already in memory
    set unseen-target-location (patch-set ([unseen-target-location] of me) unseen-target-location)
  ]

end

to check-escape-condition ;;; preys

  if (count [neighbors4] of patch-here < 4)
  [
    if (print-messages) [ print (word "Prey " who " and group " group_id " escaped from hunting area") ]
    ask other preys with [group_id = [group_id] of myself] [ die ]
    die
  ]

end

to update-waypoints

  if (member? patch-here planned-waypoints)
  [
    set visited-waypoints lput patch-here visited-waypoints

    ifelse (patch-here = starting-point AND count planned-waypoints = 1)
    [
      ;;; signal end of bout
      set is-bout-finished true
    ]
    [
      ask patch-here [ set planned-waypoints other planned-waypoints ]

      ;;; if no more waypoints, add starting point (back to camp)
      if (count planned-waypoints = 0)
      [
        set planned-waypoints (patch-set starting-point)
        save-hunting-mode "BACK-TO-CAMP"
      ]
    ]
  ]

  if (ticks > good-daylight-duration and not member? starting-point planned-waypoints)
  [
    set planned-waypoints (patch-set starting-point)
    save-hunting-mode "BACK-TO-CAMP"
  ]

end

to check-cooldown-condition

  ifelse (exhaustion-counter >= time-to-exhaustion)
  [
    if (print-messages) [ print (word self " is exhausted!") ]
    ;;; exhasted, starts cooling down
    set cooldown-counter cooldown-time

    set exhaustion-counter 0

    if (breed = hunters) [ save-hunting-mode "PAUSE" ]
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

  set hunters-detected other hunters with [presence-detected-by me]
  set preys-detected other preys with [presence-detected-by me]

  ask my-out-links [ set hidden? true ]

  ask hunters-detected [ ask in-link-from me [ set hidden? false ] ]
  ask preys-detected [ ask in-link-from me [ set hidden? false ] ]

end

to update-alertness

  ;;; forget unseen target if already there
  let patchHere patch-here
  set unseen-target-location unseen-target-location with [self != patchHere]

  let oldDetection any-detection

  ifelse (breed = preys)
  [
    set any-detection (any? hunters-detected)

    ;;; new prey-hunter-detections
    if (any-detection and not oldDetection)
    [
      set reaction-counter reaction-time - relax-counter
      set relax-counter reaction-time

      ;;; mark patches of detections as unseen target locations, used once the hunters are no more in sight
      ;;; NOTE: all former unseen target locations are cleared from memory
      set unseen-target-location (patch-set ([patch-here] of hunters-detected))

      ;;; add to global count
      set prey-hunter-detections prey-hunter-detections + count hunters-detected
    ]

    set any-unseen-target false
    if (count unseen-target-location > 0)
    [
      let me self
      set any-unseen-target (min [distance me] of unseen-target-location < preys_safe-distance)
    ]
  ]
  [
    set any-detection (any? preys-detected)

    ;;; account for new hunter-prey-detections
    if (any-detection and not olddetection)
    [
      set reaction-counter reaction-time - relax-counter
      set relax-counter reaction-time

      ;;; mark patches of detections as unseen target locations, used once prey are no more in sight
      ;;; NOTE: all former unseen target locations are clearer from memory
      set unseen-target-location (patch-set ([patch-here] of preys-detected))

      ;;; add to global count
      set hunter-prey-detections hunter-prey-detections + count preys-detected
    ]

    set any-unseen-target false
    if (count unseen-target-location > 0)
    [
      set any-unseen-target true
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

  let response false

  let me self
  let meIsStealthy false
  if (breed = hunters) [ set meIsStealthy stealth ]

  ask theOther
  [
    ;;; SOUND
    if (not meIsStealthy)
    [
      if (hearing me) [ set response true ]
    ]

    ;;; SMELL
    if ((not response) and (wind-speed > 0) and (breed = preys)) ;;; NOTE: skip for hunters, assuming poor human smelling
    [
      if (smelling me) [ set response true ]
    ]

    ;;; SIGHT
    if (not response)
    [
      if (seeing me) [ set response true ]
    ]
  ]

  report response

end

to-report hearing [ anotherTurtle ]

  let response false

  let hearingRadius hunters_hearing_radius
  if (breed = preys) [ set hearingRadius preys_hearing_radius ]

  if (distance anotherTurtle < hearingRadius) [ report true ]

  report response

end

to-report smelling [ anotherTurtle ]

  let response false

  let headingFromAnotherTurtle atan (xcor - [xcor] of anotherTurtle) (ycor - [ycor] of anotherTurtle)

  let withinSpreadAngle (headingFromAnotherTurtle > wind-direction - wind-spread-angle) and (headingFromAnotherTurtle < wind-direction + wind-spread-angle)

  if (withinSpreadAngle and distance anotherTurtle < wind-speed) [ report true ]

  report response

end

to-report seeing [ anotherTurtle ]

  let response false

  let headingToAnotherTurtle atan ([xcor] of anotherTurtle - xcor) ([ycor] of anotherTurtle - ycor)

  ;;; calculate vision field
  let theOtherVisionfield hunters_fov
  if (breed = preys) [ set theOtherVisionfield preys_fov ]
  let visionfieldLimitLeft heading - (theOtherVisionfield / 2)
  let visionfieldLimitRight heading + (theOtherVisionfield / 2)

  ;;; test if within the vision field of theOther
  if (headingToAnotherTurtle > visionfieldLimitLeft and headingToAnotherTurtle < visionfieldLimitRight)
  [
    ;;; test line-of-sight
    let currentHeading heading
    ;;; NOTE: line-of-sight modifies theOther's heading, so we keep its current value and recover it later

    let lineOfSightToAnotherTurtle line-of-sight-with anotherTurtle
    set response member? ([patch-here] of anotherTurtle) lineOfSightToAnotherTurtle

    ;;; test sighting skill of theOther
    if (distance anotherTurtle > max-perception-distance * visual-acuity / 100)
    [ set response false ]

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

to-report has-message

  let value (count unseen-target-location > 0)

  if (breed = hunters)
  [
    set value value or (follow-track-target != nobody) or (approaching-target != nobody) or (pursuing-target != nobody)
  ]

  report value

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
  let desiredSpeed preys_speed_min
  if ([distance myself] of closestTurtle < preys_safe-distance)
  [
    set desiredSpeed speed-max
  ]

  set heading (towards closestTurtle - 180)

  make-a-move desiredSpeed speed-max

  if (print-messages) [ print (word "distance after: " (distance closestTurtle)) ]

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
  let desiredSpeed preys_speed_min
  if ([distance myself] of closestTurtle < preys_safe-distance)
  [
    set desiredSpeed speed-max
  ]

  set heading [heading] of closestTurtle

  make-a-move desiredSpeed speed-max

  if (print-messages) [ print (word "distance after: " (distance closestTurtle)) ]

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

to make-a-move [ desiredSpeed maxSpeed ]

  ;;; wrapper where an agent will move itself according to:
  ;;; - current heading (implicit)
  ;;; - desired speed (actual speed depending on patch-here)
  ;;; - maximum speed for this individual, which is considered to regulate exertion

  move-with-speed-here desiredSpeed

  apply-exertion desiredSpeed maxSpeed

end

to move-with-speed-here [ aSpeed ]

  let MoveDistance (get-speed-in-patch aSpeed patch-here)

  fd MoveDistance

  if (breed = hunters)
  [ set distance-moved distance-moved + aSpeed ]

end

to apply-exertion [ aSpeed maxSpeed ]

  set exhaustion-counter exhaustion-counter + (aSpeed / maxSpeed)

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

to save-hunting-mode [ huntingModeName ]

  let lastHuntingModeName ""
  if (length hunting-mode-series > 0)
  [ set lastHuntingModeName item 0 (last hunting-mode-series) ]

  ;;; register only if changed
  if (huntingModeName != lastHuntingModeName)
  [
    set hunting-mode-series lput (list huntingModeName ticks) hunting-mode-series
  ]

end

to save-position

  set position-series-x lput xcor position-series-x

  set position-series-y lput ycor position-series-y

end

to export-data [ paramConfig ]

  let FilePath "output//"
  let filename (word FilePath behaviorspace-experiment-name "_" paramConfig "_huntingbout" SEED "_hunters" ".csv")

  file-open filename

  file-print "hunter,tick,x,y,mode"

  foreach sort hunters
  [
    aHunter ->
    ask aHunter
    [
      foreach n-values ticks [ i -> i ]
      [
        aTick ->
        file-type who file-type ", "
        file-type aTick file-type ", "
        file-type item aTick position-series-x file-type ", "
        file-type item aTick position-series-x file-type ", "
        file-print (word "'" (get-hunting-mode-in-tick aTick) "'")
      ]
    ]
  ]

  file-close

  set display-mode "elevation+obstacle"
  paint-patches
  export-view (word FilePath behaviorspace-experiment-name "_" paramConfig "_huntingbout" SEED "_hunters_elevation+obstacle" ".png")

  set display-mode "attractiveness-to-prey"
  paint-patches
  export-view (word FilePath behaviorspace-experiment-name "_" paramConfig "_huntingbout" SEED "_hunters_attractiveness-to-prey" ".png")

  set display-mode "tracks (prey)"
  paint-patches
  export-view (word FilePath behaviorspace-experiment-name "_" paramConfig "_huntingbout" SEED "_hunters_tracks (prey)" ".png")

  set display-mode "tracks (hunters)"
  paint-patches
  export-view (word FilePath behaviorspace-experiment-name "_" paramConfig "_huntingbout" SEED "_hunters_tracks (hunters)" ".png")

end

to-report get-hunting-mode-in-tick [ aTick ]

  let huntingMode 0

  foreach hunting-mode-series [
    entry ->
      let entryHuntingMode first entry
      let entryTick last entry
      if aTick >= entryTick [
        set huntingMode entryHuntingMode
      ]
  ]

  report huntingMode

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
  let min-attraction min [attractiveness-to-prey] of patches
  let max-attraction max [attractiveness-to-prey] of patches
  let tracksGradientReference ticks - (min [item 2 (first tracks)] of patches with [length tracks > 0])

  ask patches
  [
    if (display-mode = "elevation")
    [ set pcolor scale-color brown elevation min-elevation max-elevation ]
    if (display-mode = "obstacle")
    [ set pcolor scale-color green obstacle min-obstacle max-obstacle ]
    if (display-mode = "elevation+obstacle")
    [ set pcolor scale-color grey (elevation + obstacle) min-height max-height ]
    if (display-mode = "attractiveness-to-prey")
    [ set pcolor scale-color red (attractiveness-to-prey) min-attraction max-attraction ]
    if (display-mode = "tracks (prey)")
    [
      paint-track-individual preys tracksGradientReference
    ]
    if (display-mode = "tracks (hunters)")
    [
      paint-track-individual hunters tracksGradientReference
    ]
  ]

  if (display-waypoints)
  [
    ask planned-waypoints
    [
      set pcolor orange
      set plabel "WP"
    ]
  ]

end

to paint-track-individual [ aBreed gradientReference ]

  set pcolor black

  if (length tracks > 0)
  [
    let mostRecentTrack first tracks
    let mostRecentTrackOwner item 0 mostRecentTrack
    let mostRecentTrackAntiquity ticks - (item 2 mostRecentTrack)

    ifelse (mostRecentTrackOwner != nobody)
    [
      if ([breed] of mostRecentTrackOwner = aBreed)
      [
        set pcolor [color] of mostRecentTrackOwner
        set pcolor pcolor + (-3 + 3 * (1 - mostRecentTrackAntiquity / gradientReference))
      ]
    ]
    [
      if (aBreed = preys)
      [
        ;;; dark grey if track owner no longer in area
        set pcolor 1
      ]
    ]
  ]

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
;;; A* path finding algorithm ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; modified from Meghendra Singh's Astardemo1 model in NetLogo User Community Models
; http://ccl.northwestern.edu/netlogo/models/community/Astardemo1
; modified lines/fragments are marked with ";-------------------------------*"
; In this version, patches have different movement cost.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; the actual implementation of the A* path finding algorithm
; it takes the source and destination patches as inputs
; and reports the optimal path if one exists between them as output
to-report find-a-path [ source-patch destination-patch]

  ; initialize all variables to default values
  let search-done? false
  let search-path []
  let current-patch 0
  let open [] ;-------------------------------*
  let closed [] ;-------------------------------*

  ;-------------------------------*
  ask patches with [ f != 0 ]
  [
    set f 0
    set h 0
    set g 0
  ]
  ;-------------------------------*

  ; add source patch in the open list
  set open lput source-patch open

  ; loop until we reach the destination or the open list becomes empty
  while [ search-done? != true]
  [
    ifelse length open != 0
    [
      ; sort the patches in open list in increasing order of their f() values
      set open sort-by [ [?1 ?2] -> [f] of ?1 < [f] of ?2 ] open

      ; take the first patch in the open list
      ; as the current patch (which is currently being explored (n))
      ; and remove it from the open list
      set current-patch item 0 open
      set open remove-item 0 open

      ; add the current patch to the closed list
      set closed lput current-patch closed

      ; explore the Von Neumann (left, right, top and bottom) neighbors of the current patch
      ask current-patch
      [
        ; if any of the neighbors is the destination stop the search process
        ifelse any? neighbors4 with [ (pxcor = [ pxcor ] of destination-patch) and (pycor = [pycor] of destination-patch)] ;-------------------------------*
        [
          set search-done? true
        ]
        [
          ; the neighbors should not already explored patches (part of the closed list)
          ask neighbors4 with [ (not member? self closed) and (self != parent-patch) ] ;-------------------------------*
          [
            ; the neighbors to be explored should also not be the source or
            ; destination patches or already a part of the open list (unexplored patches list)
            if not member? self open and self != source-patch and self != destination-patch
            [
              ;set pcolor 45 ;-------------------------------*

              ; add the eligible patch to the open list
              set open lput self open

              ; update the path finding variables of the eligible patch
              set parent-patch current-patch
              set g [g] of parent-patch - obstacle ;-------------------------------*
              set h distance destination-patch
              set f (g + h)
            ]
          ]
        ]
;        if self != source-patch ;-------------------------------*
;        [
;          set pcolor 35
;        ]
      ]
    ]
    [
      ; if a path is not found (search is incomplete) and the open list is exhausted
      ; display a user message and report an empty search path list.
      user-message( "A path from the source to the destination does not exist." )
      report []
    ]
  ]

  ; if a path is found (search completed) add the current patch
  ; (node adjacent to the destination) to the search path.
  set search-path lput current-patch search-path

  ; trace the search path from the current patch
  ; all the way to the source patch using the parent patch
  ; variable which was set during the search for every patch that was explored
  let temp first search-path
  while [ temp != source-patch ]
  [
;    ask temp ;-------------------------------*
;    [
;      set pcolor 85
;    ]
    set search-path lput [parent-patch] of temp search-path
    set temp [parent-patch] of temp
  ]

  ; add the destination patch to the front of the search path
  set search-path fput destination-patch search-path

  ; reverse the search path so that it starts from a patch adjacent to the
  ; source patch and ends at the destination patch
  set search-path reverse search-path

  ; report the search path
  report search-path

end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; HELPERS ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to-report sample-skewed-speed [ minSpeed maxSpeed averageMaxSpeed ]
  ;;; solution suggested by ChatGPT (modified by human author)
  let distributionRange (maxSpeed - minSpeed)
  let distributionMode averageMaxSpeed / distributionRange
  ; Alpha controls skewness, adjust for more/less skew; fixed arbitrarly
  let alpha 2
  ; Beta controls skewness, adjust for more/less skew; derived from mode solution = (alpha - 1) / (alpha + beta - 2)
  let beta ((alpha - 1) / distributionMode) - alpha + 2
  let beta-sample random-float 1
  if beta-sample <= 0 [ set beta-sample 0.00001 ]
  if beta-sample >= 1 [ set beta-sample 0.99999 ]
  let x-value (minSpeed + distributionRange * ((random-exponential (alpha * beta-sample)) ^ (1 / beta)))
  report x-value
end

to-report convert-patch-to-km [ numOfPatches ]

  report numOfPatches * patch-width * 1E-3

end

to-report convert-kmperh-to-patchpersec [ kmperh ]
  ; km/h -> m/sec -> patch/sec
  let mpersec kmperh * (1000 / 3600)
  let patchpersec mpersec / patch-width
  report patchpersec
end

to-report convert-seconds-to-hours [ timeInSeconds ]

  report floor (timeInSeconds / 3600)

end

to-report convert-hours-to-seconds [ timeInHours ]

  report timeInHours * 3600

end

to-report convert-seconds-to-minutes [ timeInSeconds ]

  report floor (timeInSeconds / 60)

end

to-report convert-seconds-to-remainder-seconds [ timeInSeconds ]

  report timeInSeconds mod 60

end

to-report clamp0100 [ value ]

  report min (list (max (list value 0)) 100)

end

to paint-visionfield [ aTurtle ]

  ask patches
  [
    set pcolor black

    let response false
    let response2 false
    let me self

    ask aTurtle
    [
      if (patch-here != me)
      [
        let currentHeading heading

        let headingToMe atan ([pxcor] of me - xcor) ([pycor] of me - ycor)

        if (round currentHeading = round headingToMe) [ set response2 true ]
        ;;; calculate vision field
        let theOtherVisionfield hunters_fov
        if (breed = preys) [ set theOtherVisionfield preys_fov ]
        let visionfieldLimitLeft currentHeading - (theOtherVisionfield / 2)
        let visionfieldLimitRight currentHeading + (theOtherVisionfield / 2)

        ;;; test if within the vision field of theOther
        if (headingToMe > visionfieldLimitLeft and headingToMe < visionfieldLimitRight)
        [
          set response true
        ]
      ]
    ]

    if (response) [ set pcolor yellow ]
    if (response2) [ set pcolor red ]
  ]

end

to paint-approach-path [ aHunter ]

  ask aHunter
  [
    foreach approach-path
    [
      aPatch ->
      ask aPatch
      [
        set pcolor yellow
      ]
    ]
  ]

end
@#$#@#$#@
GRAPHICS-WINDOW
210
10
618
419
-1
-1
2.0
1
10
1
1
1
0
0
0
1
0
199
0
199
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
1497
79
1806
199
height
height (m)
NIL
0.0
10.0
0.0
10.0
true
true
"set-plot-x-range 0 ceiling (1.1 * max (list (max [height] of hunters) (max [height] of preys)))\nset-histogram-num-bars 20" ""
PENS
"preys" 1.0 1 -4079321 true "set-plot-pen-interval 0.1\nhistogram [height] of preys" "set-plot-pen-interval 0.1\nhistogram [height] of preys"
"hunters" 1.0 1 -5298144 true "set-plot-pen-interval 0.1\nhistogram [height] of hunters" "set-plot-pen-interval 0.1\nhistogram [height] of hunters"

PLOT
1497
435
1807
555
time to exhaustion (TTE)
TTE (seconds)
NIL
0.0
10.0
0.0
10.0
true
true
"set-plot-x-range 0 ceiling (1.1 * max (list (max [time-to-exhaustion] of hunters) (max [time-to-exhaustion] of preys)))\nset-histogram-num-bars 20" ""
PENS
"preys" 1.0 1 -4079321 true "histogram [time-to-exhaustion] of preys" "histogram [time-to-exhaustion] of preys"
"hunters" 1.0 1 -5298144 true "histogram [time-to-exhaustion] of hunters" "histogram [time-to-exhaustion] of hunters"

INPUTBOX
21
98
99
158
SEED
3.0
1
0
Number

CHOOSER
35
160
199
205
display-mode
display-mode
"elevation" "obstacle" "elevation+obstacle" "attractiveness-to-prey" "tracks (prey)" "tracks (hunters)"
5

BUTTON
42
252
173
285
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
845
101
1005
221
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
convert-seconds-to-hours ticks
17
1
11

MONITOR
86
11
136
56
minutes
(convert-seconds-to-minutes ticks) mod 60
17
1
11

SLIDER
630
240
824
273
par_prey-attractor-probability
par_prey-attractor-probability
0
100
49.0
1
1
%
HORIZONTAL

SLIDER
624
128
824
161
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
632
454
876
487
par_starting-point-buffer-distance
par_starting-point-buffer-distance
0
10
1.5
0.1
1
Km
HORIZONTAL

SLIDER
635
572
1004
605
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
635
606
1005
639
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
422
879
455
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
632
10
782
28
Environment
14
0.0
1

MONITOR
80
348
185
393
patch-width (m)
patch-width
17
1
11

SLIDER
1026
80
1218
113
par_num-hunters
par_num-hunters
0
10
5.0
1
1
hunters
HORIZONTAL

TEXTBOX
1029
61
1179
79
Hunters
14
0.0
1

TEXTBOX
1269
60
1419
78
Preys
14
0.0
1

SLIDER
1038
182
1229
215
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
1037
216
1228
249
par_hunters_height_max
par_hunters_height_max
par_hunters_height_min
2
500.0
0.01
1
m
HORIZONTAL

SLIDER
1030
419
1221
452
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
1029
449
1222
482
par_hunters_speed_max
par_hunters_speed_max
par_hunters_speed_min
30
50.0
0.1
1
km/h
HORIZONTAL

SLIDER
1034
564
1224
597
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
1034
598
1225
631
par_hunters_tte_max
par_hunters_tte_max
par_hunters_tte_min
360
600.0
1
1
minutes
HORIZONTAL

SLIDER
1023
639
1237
672
par_hunters_reactiontime_min
par_hunters_reactiontime_min
1
par_hunters_reactiontime_max
1.0
1
1
seconds
HORIZONTAL

SLIDER
1023
672
1237
705
par_hunters_reactiontime_max
par_hunters_reactiontime_max
par_hunters_reactiontime_min
360
500.0
1
1
seconds
HORIZONTAL

SLIDER
1266
183
1457
216
par_preys_height_min
par_preys_height_min
1
par_preys_height_max
1.0
0.01
1
m
HORIZONTAL

SLIDER
1266
217
1457
250
par_preys_height_max
par_preys_height_max
par_preys_height_min
2
100.0
0.01
1
m
HORIZONTAL

SLIDER
1258
419
1451
452
par_preys_speed_min
par_preys_speed_min
1
par_preys_speed_max
5.0
0.1
1
km/h
HORIZONTAL

SLIDER
1258
453
1451
486
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
1258
562
1451
595
par_preys_tte_min
par_preys_tte_min
1
par_preys_tte_max
6.0
1
1
minutes
HORIZONTAL

SLIDER
1258
597
1451
630
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
1243
639
1458
672
par_preys_reactiontime_min
par_preys_reactiontime_min
1
par_preys_reactiontime_max
1.0
1
1
secs
HORIZONTAL

SLIDER
1243
674
1458
707
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
1259
81
1449
114
par_num-preys
par_num-preys
0
100
25.0
1
1
preys
HORIZONTAL

SLIDER
1242
112
1475
145
par_preys_group_max_size
par_preys_group_max_size
0
100
5.0
1
1
preys/group
HORIZONTAL

MONITOR
197
728
635
765
Planned waypoints
sort planned-waypoints
17
1
9

SWITCH
42
209
189
242
display-waypoints
display-waypoints
0
1
-1000

SLIDER
1243
151
1461
184
par_preys_safe-distance
par_preys_safe-distance
1
2000
500.0
1
1
m
HORIZONTAL

SWITCH
38
293
178
326
print-messages
print-messages
1
1
-1000

MONITOR
137
10
195
55
seconds
convert-seconds-to-remainder-seconds ticks
17
1
11

SLIDER
1020
709
1238
742
par_hunters_cooldowntime_min
par_hunters_cooldowntime_min
0
par_hunters_cooldowntime_max
50.0
1
1
secs
HORIZONTAL

SLIDER
1021
745
1240
778
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
1240
709
1458
742
par_preys_cooldowntime_min
par_preys_cooldowntime_min
0
par_preys_cooldowntime_max
1.0
1
1
secs
HORIZONTAL

SLIDER
1240
744
1459
777
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
211
425
624
575
Detections
seconds
NIL
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"preys->hunters" 1.0 0 -1184463 true "" "plot prey-hunter-detections"
"hunters->preys" 1.0 0 -2674135 true "" "plot hunter-prey-detections"

PLOT
210
577
622
727
Tracks
seconds
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
1038
149
1229
182
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
65
393
185
438
world-width (Km)
precision (convert-patch-to-km world-width) 4
17
1
11

SLIDER
1027
249
1270
282
par_hunters_height_stealth
par_hunters_height_stealth
0
100
50.0
1
1
% of height
HORIZONTAL

SLIDER
1029
521
1283
554
par_hunters_speed_stealth
par_hunters_speed_stealth
0
100
50.0
1
1
% of min speed
HORIZONTAL

SLIDER
1032
320
1240
353
par_hunters_fov
par_hunters_fov
0
360
200.0
1
1
degrees
HORIZONTAL

SLIDER
1260
321
1458
354
par_preys_fov
par_preys_fov
0
360
300.0
1
1
degrees
HORIZONTAL

SLIDER
1012
354
1254
387
par_hunters_visualacuity_mean
par_hunters_visualacuity_mean
0
100
65.0
1
1
% max. dist.
HORIZONTAL

SLIDER
1255
353
1491
386
par_preys_visualacuity_mean
par_preys_visualacuity_mean
0
100
33.0
1
1
% max. dist.
HORIZONTAL

SLIDER
1017
386
1242
419
par_hunters_visualacuity_sd
par_hunters_visualacuity_sd
0
100
15.0
1
1
% max. dist.
HORIZONTAL

SLIDER
1255
385
1475
418
par_preys_visualacuity_sd
par_preys_visualacuity_sd
0
100
20.0
1
1
% max. dist.
HORIZONTAL

SLIDER
1026
110
1242
143
par_num-planned-waypoints
par_num-planned-waypoints
1
10
5.0
1
1
waypoints
HORIZONTAL

TEXTBOX
637
406
787
424
Contextual
14
0.0
1

SLIDER
1258
485
1450
518
par_preys_speed_avmax
par_preys_speed_avmax
par_preys_speed_min
par_preys_speed_max
30.0
1
1
km/h
HORIZONTAL

SLIDER
1029
479
1223
512
par_hunters_speed_avmax
par_hunters_speed_avmax
par_hunters_speed_min
par_hunters_speed_max
50.0
1
1
km/h
HORIZONTAL

PLOT
1497
198
1805
318
visual acuity
% of max. dist
NIL
0.0
10.0
0.0
10.0
true
true
"set-plot-x-range 0 ceiling (1.1 * max (list (max [visual-acuity] of hunters) (max [visual-acuity] of preys)))\nset-histogram-num-bars 20" ""
PENS
"preys" 1.0 1 -4079321 true "" "histogram [visual-acuity] of preys"
"hunters" 1.0 1 -5298144 true "" "histogram [visual-acuity] of hunters"

PLOT
1497
317
1804
437
Maximum speed (potential)
patch-width/second
NIL
0.0
10.0
0.0
10.0
true
true
"set-plot-x-range 0 ceiling (1.1 * max (list (max [speed-max] of hunters) (max [speed-max] of preys)))\nset-histogram-num-bars 20" ""
PENS
"preys" 1.0 1 -4079321 true "" "histogram [speed-max] of preys"
"hunters" 1.0 0 -5298144 true "" "histogram [speed-max] of hunters"

PLOT
1498
556
1807
676
Reaction time
seconds
NIL
0.0
10.0
0.0
10.0
true
true
"set-plot-x-range 0 ceiling (1.1 * max (list (max [reaction-time] of hunters) (max [reaction-time] of preys)))\nset-histogram-num-bars 20" ""
PENS
"preys" 1.0 1 -4079321 true "" "histogram [reaction-time] of preys"
"hunters" 1.0 1 -5298144 true "" "histogram [reaction-time] of preys"

PLOT
1499
676
1806
796
cooldown time
seconds
NIL
0.0
10.0
0.0
10.0
true
true
"set-plot-x-range 0 ceiling (1.1 * max (list (max [cooldown-time] of hunters) (max [cooldown-time] of preys)))\nset-histogram-num-bars 20" ""
PENS
"preys" 1.0 1 -4079321 true "" "histogram [cooldown-time] of preys"
"hunters" 1.0 1 -5298144 true "" "histogram [cooldown-time] of hunters"

MONITOR
197
764
636
801
Visited waypoints
sort visited-waypoints
17
1
9

SLIDER
1041
287
1252
320
par_hunters_hearing_radius
par_hunters_hearing_radius
0
500
50.0
1
1
m
HORIZONTAL

SLIDER
1252
286
1452
319
par_preys_hearing_radius
par_preys_hearing_radius
0
500
300.0
1
1
m
HORIZONTAL

SLIDER
654
527
808
560
par_wind-speed
par_wind-speed
0
40
20.0
1
1
km/h
HORIZONTAL

SLIDER
642
496
833
529
par_wind-direction
par_wind-direction
0
360
0.0
1
1
degrees from N
HORIZONTAL

MONITOR
6
445
63
490
NIL
sneaks
17
1
11

MONITOR
65
445
122
490
NIL
pursues
17
1
11

MONITOR
125
446
182
491
NIL
shots
17
1
11

MONITOR
56
497
182
542
NIL
was-bout-successful
17
1
11

MONITOR
12
546
199
591
NIL
hunter-who-shot
17
1
11

MONITOR
12
594
199
639
NIL
prey-who-got-shot
17
1
11

MONITOR
196
802
635
839
Discarded waypoints
sort discarded-waypoints
17
1
9

SLIDER
622
92
844
125
par_init-obstacle-frequency
par_init-obstacle-frequency
0
100
5.0
1
1
% patches
HORIZONTAL

CHOOSER
643
37
798
82
scenario-environment
scenario-environment
"user-defined" "wet and no fires" "dry and no fires" "wet with fires" "dry with fires" "default"
5

SLIDER
624
162
813
195
par_init-obstacle-diffuse-rate
par_init-obstacle-diffuse-rate
0
1
0.3
0.01
1
NIL
HORIZONTAL

SLIDER
624
195
813
228
par_init-obstacle-diffuse-times
par_init-obstacle-diffuse-times
0
100
5.0
1
1
x
HORIZONTAL

SLIDER
623
273
821
306
par_attractiveness-diffuse-rate
par_attractiveness-diffuse-rate
0
1
0.3
0.01
1
NIL
HORIZONTAL

SLIDER
622
307
822
340
par_attractiveness-diffuse-times
par_attractiveness-diffuse-times
0
100
10.0
1
1
x
HORIZONTAL

SLIDER
834
292
1006
325
par_fires-radius
par_fires-radius
0
100
3.0
1
1
m
HORIZONTAL

SLIDER
834
258
1006
291
par_fires-number
par_fires-number
0
10
5.0
1
1
NIL
HORIZONTAL

SWITCH
663
652
881
685
waypoints-to-prey-attractors
waypoints-to-prey-attractors
0
1
-1000

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
NetLogo 6.4.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="experiment-numbers" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <postRun>let paramConfig (word "par_num-preys=" par_num-preys "_par_num-hunters=" par_num-hunters)
export-data paramConfig</postRun>
    <metric>patch-width</metric>
    <metric>max-perception-distance</metric>
    <metric>track-maximum</metric>
    <metric>good-daylight-duration</metric>
    <metric>starting-point</metric>
    <metric>wind-spread-angle</metric>
    <metric>starting-point-buffer-distance</metric>
    <metric>obstacle-damage</metric>
    <metric>track-mark-probability</metric>
    <metric>track-pregeneration-period</metric>
    <metric>wind-speed</metric>
    <metric>wind-direction</metric>
    <metric>num-hunters</metric>
    <metric>num-planned-waypoints</metric>
    <metric>hunters_height_stealth</metric>
    <metric>hunters_height_min</metric>
    <metric>hunters_height_max</metric>
    <metric>hunters_visualacuity_mean</metric>
    <metric>hunters_visualacuity_sd</metric>
    <metric>hunters_speed_stealth</metric>
    <metric>hunters_speed_min</metric>
    <metric>hunters_speed_max</metric>
    <metric>hunters_speed_avmax</metric>
    <metric>hunters_tte_min</metric>
    <metric>hunters_tte_max</metric>
    <metric>hunters_reactiontime_min</metric>
    <metric>hunters_reactiontime_max</metric>
    <metric>hunters_cooldowntime_min</metric>
    <metric>hunters_cooldowntime_max</metric>
    <metric>max-shooting-distance</metric>
    <metric>hunters_hearing_radius</metric>
    <metric>hunters_fov</metric>
    <metric>num-preys</metric>
    <metric>preys_group_max_size</metric>
    <metric>preys_safe-distance</metric>
    <metric>preys_height_min</metric>
    <metric>preys_height_max</metric>
    <metric>preys_visualacuity_mean</metric>
    <metric>preys_visualacuity_sd</metric>
    <metric>preys_speed_min</metric>
    <metric>preys_speed_max</metric>
    <metric>preys_speed_avmax</metric>
    <metric>preys_tte_min</metric>
    <metric>preys_tte_max</metric>
    <metric>preys_reactiontime_min</metric>
    <metric>preys_reactiontime_max</metric>
    <metric>preys_cooldowntime_min</metric>
    <metric>preys_cooldowntime_max</metric>
    <metric>preys_hearing_radius</metric>
    <metric>preys_fov</metric>
    <metric>init-obstacle-scale</metric>
    <metric>prey-attractor-probability</metric>
    <metric>attractiveness-to-prey-max</metric>
    <metric>planned-waypoints</metric>
    <metric>visited-waypoints</metric>
    <metric>discarded-waypoints</metric>
    <metric>hunter-prey-detections</metric>
    <metric>prey-hunter-detections</metric>
    <metric>sneaks</metric>
    <metric>pursues</metric>
    <metric>shots</metric>
    <metric>was-bout-successful</metric>
    <metric>is-bout-finished</metric>
    <metric>hunter-who-shot</metric>
    <metric>prey-who-got-shot</metric>
    <enumeratedValueSet variable="display-waypoints">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_hunters_reactiontime_max">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_obstacle-damage">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_preys_tte_min">
      <value value="60"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_preys_fov">
      <value value="300"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="agent-scale">
      <value value="1.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_preys_reactiontime_max">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_preys_height_min">
      <value value="1.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_track-pregeneration-period">
      <value value="7"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_hunters_visualacuity_sd">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_preys_safe-distance">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_hunters_height_min">
      <value value="1.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_init-obstacle-scale">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_starting-point-buffer-distance">
      <value value="1.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_hunters_speed_avmax">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_preys_cooldowntime_min">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_track-mark-probability">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_preys_height_max">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_hunters_speed_stealth">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_hunters_speed_max">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_preys_speed_min">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_hunters_tte_max">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_num-preys">
      <value value="5"/>
      <value value="10"/>
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_num-hunters">
      <value value="1"/>
      <value value="2"/>
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_hunters_fov">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_preys_speed_max">
      <value value="75"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_prey-attractor-probability">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_num-planned-waypoints">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_preys_reactiontime_min">
      <value value="60"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_hunters_cooldowntime_min">
      <value value="400"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_wind-direction">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_preys_tte_max">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_preys_visualacuity_mean">
      <value value="33"/>
    </enumeratedValueSet>
    <steppedValueSet variable="SEED" first="0" step="1" last="10"/>
    <enumeratedValueSet variable="par_hunters_height_stealth">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_preys_hearing_radius">
      <value value="300"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_preys_visualacuity_sd">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="print-messages">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_hunters_visualacuity_mean">
      <value value="65"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_hunters_hearing_radius">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_hunters_cooldowntime_max">
      <value value="800"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_preys_speed_avmax">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_max-shooting-distance">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_hunters_height_max">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_preys_group_max_size">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_hunters_speed_min">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_hunters_reactiontime_min">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="display-mode">
      <value value="&quot;tracks (hunters)&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_wind-speed">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_hunters_tte_min">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_preys_cooldowntime_max">
      <value value="600"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment-hunter-speed" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <postRun>let paramConfig (word "par_hunters_speed_min=" par_hunters_speed_min "_par_hunters_speed_avmax=" par_hunters_speed_avmax)
export-data paramConfig</postRun>
    <metric>patch-width</metric>
    <metric>max-perception-distance</metric>
    <metric>track-maximum</metric>
    <metric>good-daylight-duration</metric>
    <metric>starting-point</metric>
    <metric>wind-spread-angle</metric>
    <metric>starting-point-buffer-distance</metric>
    <metric>obstacle-damage</metric>
    <metric>track-mark-probability</metric>
    <metric>track-pregeneration-period</metric>
    <metric>wind-speed</metric>
    <metric>wind-direction</metric>
    <metric>num-hunters</metric>
    <metric>num-planned-waypoints</metric>
    <metric>hunters_height_stealth</metric>
    <metric>hunters_height_min</metric>
    <metric>hunters_height_max</metric>
    <metric>hunters_visualacuity_mean</metric>
    <metric>hunters_visualacuity_sd</metric>
    <metric>hunters_speed_stealth</metric>
    <metric>hunters_speed_min</metric>
    <metric>hunters_speed_max</metric>
    <metric>hunters_speed_avmax</metric>
    <metric>hunters_tte_min</metric>
    <metric>hunters_tte_max</metric>
    <metric>hunters_reactiontime_min</metric>
    <metric>hunters_reactiontime_max</metric>
    <metric>hunters_cooldowntime_min</metric>
    <metric>hunters_cooldowntime_max</metric>
    <metric>max-shooting-distance</metric>
    <metric>hunters_hearing_radius</metric>
    <metric>hunters_fov</metric>
    <metric>num-preys</metric>
    <metric>preys_group_max_size</metric>
    <metric>preys_safe-distance</metric>
    <metric>preys_height_min</metric>
    <metric>preys_height_max</metric>
    <metric>preys_visualacuity_mean</metric>
    <metric>preys_visualacuity_sd</metric>
    <metric>preys_speed_min</metric>
    <metric>preys_speed_max</metric>
    <metric>preys_speed_avmax</metric>
    <metric>preys_tte_min</metric>
    <metric>preys_tte_max</metric>
    <metric>preys_reactiontime_min</metric>
    <metric>preys_reactiontime_max</metric>
    <metric>preys_cooldowntime_min</metric>
    <metric>preys_cooldowntime_max</metric>
    <metric>preys_hearing_radius</metric>
    <metric>preys_fov</metric>
    <metric>init-obstacle-scale</metric>
    <metric>prey-attractor-probability</metric>
    <metric>attractiveness-to-prey-max</metric>
    <metric>planned-waypoints</metric>
    <metric>visited-waypoints</metric>
    <metric>discarded-waypoints</metric>
    <metric>hunter-prey-detections</metric>
    <metric>prey-hunter-detections</metric>
    <metric>sneaks</metric>
    <metric>pursues</metric>
    <metric>shots</metric>
    <metric>was-bout-successful</metric>
    <metric>is-bout-finished</metric>
    <metric>hunter-who-shot</metric>
    <metric>prey-who-got-shot</metric>
    <enumeratedValueSet variable="display-waypoints">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_hunters_reactiontime_max">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_obstacle-damage">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_preys_tte_min">
      <value value="60"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_preys_fov">
      <value value="300"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="agent-scale">
      <value value="1.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_preys_reactiontime_max">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_preys_height_min">
      <value value="1.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_track-pregeneration-period">
      <value value="7"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_hunters_visualacuity_sd">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_preys_safe-distance">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_hunters_height_min">
      <value value="1.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_init-obstacle-scale">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_starting-point-buffer-distance">
      <value value="1.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_hunters_speed_avmax">
      <value value="10"/>
      <value value="15"/>
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_preys_cooldowntime_min">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_track-mark-probability">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_preys_height_max">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_hunters_speed_stealth">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_hunters_speed_max">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_preys_speed_min">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_hunters_tte_max">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_num-preys">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_num-hunters">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_hunters_fov">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_preys_speed_max">
      <value value="75"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_prey-attractor-probability">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_num-planned-waypoints">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_preys_reactiontime_min">
      <value value="60"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_hunters_cooldowntime_min">
      <value value="400"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_wind-direction">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_preys_tte_max">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_preys_visualacuity_mean">
      <value value="33"/>
    </enumeratedValueSet>
    <steppedValueSet variable="SEED" first="0" step="1" last="10"/>
    <enumeratedValueSet variable="par_hunters_height_stealth">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_preys_hearing_radius">
      <value value="300"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_preys_visualacuity_sd">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="print-messages">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_hunters_visualacuity_mean">
      <value value="65"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_hunters_hearing_radius">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_hunters_cooldowntime_max">
      <value value="800"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_preys_speed_avmax">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_max-shooting-distance">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_hunters_height_max">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_preys_group_max_size">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_hunters_speed_min">
      <value value="2"/>
      <value value="5"/>
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_hunters_reactiontime_min">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="display-mode">
      <value value="&quot;tracks (hunters)&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_wind-speed">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_hunters_tte_min">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_preys_cooldowntime_max">
      <value value="600"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment-numbers2" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <postRun>let paramConfig (word "par_num-preys=" par_num-preys "_par_num-hunters=" par_num-hunters)
export-data paramConfig</postRun>
    <metric>patch-width</metric>
    <metric>max-perception-distance</metric>
    <metric>track-maximum</metric>
    <metric>good-daylight-duration</metric>
    <metric>starting-point</metric>
    <metric>wind-spread-angle</metric>
    <metric>starting-point-buffer-distance</metric>
    <metric>obstacle-damage</metric>
    <metric>track-mark-probability</metric>
    <metric>track-pregeneration-period</metric>
    <metric>wind-speed</metric>
    <metric>wind-direction</metric>
    <metric>num-hunters</metric>
    <metric>num-planned-waypoints</metric>
    <metric>hunters_height_stealth</metric>
    <metric>hunters_height_min</metric>
    <metric>hunters_height_max</metric>
    <metric>hunters_visualacuity_mean</metric>
    <metric>hunters_visualacuity_sd</metric>
    <metric>hunters_speed_stealth</metric>
    <metric>hunters_speed_min</metric>
    <metric>hunters_speed_max</metric>
    <metric>hunters_speed_avmax</metric>
    <metric>hunters_tte_min</metric>
    <metric>hunters_tte_max</metric>
    <metric>hunters_reactiontime_min</metric>
    <metric>hunters_reactiontime_max</metric>
    <metric>hunters_cooldowntime_min</metric>
    <metric>hunters_cooldowntime_max</metric>
    <metric>max-shooting-distance</metric>
    <metric>hunters_hearing_radius</metric>
    <metric>hunters_fov</metric>
    <metric>num-preys</metric>
    <metric>preys_group_max_size</metric>
    <metric>preys_safe-distance</metric>
    <metric>preys_height_min</metric>
    <metric>preys_height_max</metric>
    <metric>preys_visualacuity_mean</metric>
    <metric>preys_visualacuity_sd</metric>
    <metric>preys_speed_min</metric>
    <metric>preys_speed_max</metric>
    <metric>preys_speed_avmax</metric>
    <metric>preys_tte_min</metric>
    <metric>preys_tte_max</metric>
    <metric>preys_reactiontime_min</metric>
    <metric>preys_reactiontime_max</metric>
    <metric>preys_cooldowntime_min</metric>
    <metric>preys_cooldowntime_max</metric>
    <metric>preys_hearing_radius</metric>
    <metric>preys_fov</metric>
    <metric>init-obstacle-scale</metric>
    <metric>prey-attractor-probability</metric>
    <metric>attractiveness-to-prey-max</metric>
    <metric>planned-waypoints</metric>
    <metric>visited-waypoints</metric>
    <metric>discarded-waypoints</metric>
    <metric>hunter-prey-detections</metric>
    <metric>prey-hunter-detections</metric>
    <metric>sneaks</metric>
    <metric>pursues</metric>
    <metric>shots</metric>
    <metric>was-bout-successful</metric>
    <metric>is-bout-finished</metric>
    <metric>hunter-who-shot</metric>
    <metric>prey-who-got-shot</metric>
    <enumeratedValueSet variable="display-waypoints">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_hunters_reactiontime_max">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_obstacle-damage">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_preys_tte_min">
      <value value="60"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_preys_fov">
      <value value="300"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="agent-scale">
      <value value="1.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_preys_reactiontime_max">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_preys_height_min">
      <value value="1.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_track-pregeneration-period">
      <value value="7"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_hunters_visualacuity_sd">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_preys_safe-distance">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_hunters_height_min">
      <value value="1.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_init-obstacle-scale">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_starting-point-buffer-distance">
      <value value="1.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_hunters_speed_avmax">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_preys_cooldowntime_min">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_track-mark-probability">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_preys_height_max">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_hunters_speed_stealth">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_hunters_speed_max">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_preys_speed_min">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_hunters_tte_max">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_num-preys">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_num-hunters">
      <value value="1"/>
      <value value="2"/>
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_hunters_fov">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_preys_speed_max">
      <value value="75"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_prey-attractor-probability">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_num-planned-waypoints">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_preys_reactiontime_min">
      <value value="60"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_hunters_cooldowntime_min">
      <value value="400"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_wind-direction">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_preys_tte_max">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_preys_visualacuity_mean">
      <value value="33"/>
    </enumeratedValueSet>
    <steppedValueSet variable="SEED" first="0" step="1" last="10"/>
    <enumeratedValueSet variable="par_hunters_height_stealth">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_preys_hearing_radius">
      <value value="300"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_preys_visualacuity_sd">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="print-messages">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_hunters_visualacuity_mean">
      <value value="65"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_hunters_hearing_radius">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_hunters_cooldowntime_max">
      <value value="800"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_preys_speed_avmax">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_max-shooting-distance">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_hunters_height_max">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_preys_group_max_size">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_hunters_speed_min">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_hunters_reactiontime_min">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="display-mode">
      <value value="&quot;tracks (hunters)&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_wind-speed">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_hunters_tte_min">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_preys_cooldowntime_max">
      <value value="600"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment-numbers3" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <postRun>let paramConfig (word "par_num-preys=" par_num-preys "_par_num-hunters=" par_num-hunters)
export-data paramConfig</postRun>
    <metric>patch-width</metric>
    <metric>max-perception-distance</metric>
    <metric>track-maximum</metric>
    <metric>good-daylight-duration</metric>
    <metric>starting-point</metric>
    <metric>wind-spread-angle</metric>
    <metric>starting-point-buffer-distance</metric>
    <metric>obstacle-damage</metric>
    <metric>track-mark-probability</metric>
    <metric>track-pregeneration-period</metric>
    <metric>wind-speed</metric>
    <metric>wind-direction</metric>
    <metric>num-hunters</metric>
    <metric>num-planned-waypoints</metric>
    <metric>hunters_height_stealth</metric>
    <metric>hunters_height_min</metric>
    <metric>hunters_height_max</metric>
    <metric>hunters_visualacuity_mean</metric>
    <metric>hunters_visualacuity_sd</metric>
    <metric>hunters_speed_stealth</metric>
    <metric>hunters_speed_min</metric>
    <metric>hunters_speed_max</metric>
    <metric>hunters_speed_avmax</metric>
    <metric>hunters_tte_min</metric>
    <metric>hunters_tte_max</metric>
    <metric>hunters_reactiontime_min</metric>
    <metric>hunters_reactiontime_max</metric>
    <metric>hunters_cooldowntime_min</metric>
    <metric>hunters_cooldowntime_max</metric>
    <metric>max-shooting-distance</metric>
    <metric>hunters_hearing_radius</metric>
    <metric>hunters_fov</metric>
    <metric>num-preys</metric>
    <metric>preys_group_max_size</metric>
    <metric>preys_safe-distance</metric>
    <metric>preys_height_min</metric>
    <metric>preys_height_max</metric>
    <metric>preys_visualacuity_mean</metric>
    <metric>preys_visualacuity_sd</metric>
    <metric>preys_speed_min</metric>
    <metric>preys_speed_max</metric>
    <metric>preys_speed_avmax</metric>
    <metric>preys_tte_min</metric>
    <metric>preys_tte_max</metric>
    <metric>preys_reactiontime_min</metric>
    <metric>preys_reactiontime_max</metric>
    <metric>preys_cooldowntime_min</metric>
    <metric>preys_cooldowntime_max</metric>
    <metric>preys_hearing_radius</metric>
    <metric>preys_fov</metric>
    <metric>init-obstacle-scale</metric>
    <metric>prey-attractor-probability</metric>
    <metric>attractiveness-to-prey-max</metric>
    <metric>planned-waypoints</metric>
    <metric>visited-waypoints</metric>
    <metric>discarded-waypoints</metric>
    <metric>hunter-prey-detections</metric>
    <metric>prey-hunter-detections</metric>
    <metric>sneaks</metric>
    <metric>pursues</metric>
    <metric>shots</metric>
    <metric>was-bout-successful</metric>
    <metric>is-bout-finished</metric>
    <metric>hunter-who-shot</metric>
    <metric>prey-who-got-shot</metric>
    <enumeratedValueSet variable="display-waypoints">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_hunters_reactiontime_max">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_obstacle-damage">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_preys_tte_min">
      <value value="60"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_preys_fov">
      <value value="300"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="agent-scale">
      <value value="1.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_preys_reactiontime_max">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_preys_height_min">
      <value value="1.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_track-pregeneration-period">
      <value value="7"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_hunters_visualacuity_sd">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_preys_safe-distance">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_hunters_height_min">
      <value value="1.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_init-obstacle-scale">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_starting-point-buffer-distance">
      <value value="1.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_hunters_speed_avmax">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_preys_cooldowntime_min">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_track-mark-probability">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_preys_height_max">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_hunters_speed_stealth">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_hunters_speed_max">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_preys_speed_min">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_hunters_tte_max">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_num-preys">
      <value value="5"/>
      <value value="10"/>
      <value value="15"/>
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_num-hunters">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_hunters_fov">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_preys_speed_max">
      <value value="75"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_prey-attractor-probability">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_num-planned-waypoints">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_preys_reactiontime_min">
      <value value="60"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_hunters_cooldowntime_min">
      <value value="400"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_wind-direction">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_preys_tte_max">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_preys_visualacuity_mean">
      <value value="33"/>
    </enumeratedValueSet>
    <steppedValueSet variable="SEED" first="0" step="1" last="10"/>
    <enumeratedValueSet variable="par_hunters_height_stealth">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_preys_hearing_radius">
      <value value="300"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_preys_visualacuity_sd">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="print-messages">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_hunters_visualacuity_mean">
      <value value="65"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_hunters_hearing_radius">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_hunters_cooldowntime_max">
      <value value="800"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_preys_speed_avmax">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_max-shooting-distance">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_hunters_height_max">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_preys_group_max_size">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_hunters_speed_min">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_hunters_reactiontime_min">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="display-mode">
      <value value="&quot;tracks (hunters)&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_wind-speed">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_hunters_tte_min">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_preys_cooldowntime_max">
      <value value="600"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment-numbers4" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <postRun>let paramConfig (word "par_num-preys=" par_num-preys "_par_num-hunters=" par_num-hunters)
export-data paramConfig</postRun>
    <metric>patch-width</metric>
    <metric>max-perception-distance</metric>
    <metric>track-maximum</metric>
    <metric>good-daylight-duration</metric>
    <metric>starting-point</metric>
    <metric>wind-spread-angle</metric>
    <metric>starting-point-buffer-distance</metric>
    <metric>obstacle-damage</metric>
    <metric>track-mark-probability</metric>
    <metric>track-pregeneration-period</metric>
    <metric>wind-speed</metric>
    <metric>wind-direction</metric>
    <metric>num-hunters</metric>
    <metric>num-planned-waypoints</metric>
    <metric>hunters_height_stealth</metric>
    <metric>hunters_height_min</metric>
    <metric>hunters_height_max</metric>
    <metric>hunters_visualacuity_mean</metric>
    <metric>hunters_visualacuity_sd</metric>
    <metric>hunters_speed_stealth</metric>
    <metric>hunters_speed_min</metric>
    <metric>hunters_speed_max</metric>
    <metric>hunters_speed_avmax</metric>
    <metric>hunters_tte_min</metric>
    <metric>hunters_tte_max</metric>
    <metric>hunters_reactiontime_min</metric>
    <metric>hunters_reactiontime_max</metric>
    <metric>hunters_cooldowntime_min</metric>
    <metric>hunters_cooldowntime_max</metric>
    <metric>max-shooting-distance</metric>
    <metric>hunters_hearing_radius</metric>
    <metric>hunters_fov</metric>
    <metric>num-preys</metric>
    <metric>preys_group_max_size</metric>
    <metric>preys_safe-distance</metric>
    <metric>preys_height_min</metric>
    <metric>preys_height_max</metric>
    <metric>preys_visualacuity_mean</metric>
    <metric>preys_visualacuity_sd</metric>
    <metric>preys_speed_min</metric>
    <metric>preys_speed_max</metric>
    <metric>preys_speed_avmax</metric>
    <metric>preys_tte_min</metric>
    <metric>preys_tte_max</metric>
    <metric>preys_reactiontime_min</metric>
    <metric>preys_reactiontime_max</metric>
    <metric>preys_cooldowntime_min</metric>
    <metric>preys_cooldowntime_max</metric>
    <metric>preys_hearing_radius</metric>
    <metric>preys_fov</metric>
    <metric>init-obstacle-scale</metric>
    <metric>prey-attractor-probability</metric>
    <metric>attractiveness-to-prey-max</metric>
    <metric>planned-waypoints</metric>
    <metric>visited-waypoints</metric>
    <metric>discarded-waypoints</metric>
    <metric>hunter-prey-detections</metric>
    <metric>prey-hunter-detections</metric>
    <metric>sneaks</metric>
    <metric>pursues</metric>
    <metric>shots</metric>
    <metric>was-bout-successful</metric>
    <metric>is-bout-finished</metric>
    <metric>hunter-who-shot</metric>
    <metric>prey-who-got-shot</metric>
    <enumeratedValueSet variable="display-waypoints">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_hunters_reactiontime_max">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_obstacle-damage">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_preys_tte_min">
      <value value="60"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_preys_fov">
      <value value="300"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="agent-scale">
      <value value="1.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_preys_reactiontime_max">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_preys_height_min">
      <value value="1.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_track-pregeneration-period">
      <value value="7"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_hunters_visualacuity_sd">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_preys_safe-distance">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_hunters_height_min">
      <value value="1.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_init-obstacle-scale">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_starting-point-buffer-distance">
      <value value="1.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_hunters_speed_avmax">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_preys_cooldowntime_min">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_track-mark-probability">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_preys_height_max">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_hunters_speed_stealth">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_hunters_speed_max">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_preys_speed_min">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_hunters_tte_max">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_num-preys">
      <value value="5"/>
      <value value="10"/>
      <value value="15"/>
      <value value="20"/>
      <value value="25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_num-hunters">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_hunters_fov">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_preys_speed_max">
      <value value="75"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_prey-attractor-probability">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_num-planned-waypoints">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_preys_reactiontime_min">
      <value value="60"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_hunters_cooldowntime_min">
      <value value="400"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_wind-direction">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_preys_tte_max">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_preys_visualacuity_mean">
      <value value="33"/>
    </enumeratedValueSet>
    <steppedValueSet variable="SEED" first="0" step="1" last="10"/>
    <enumeratedValueSet variable="par_hunters_height_stealth">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_preys_hearing_radius">
      <value value="300"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_preys_visualacuity_sd">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="print-messages">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_hunters_visualacuity_mean">
      <value value="65"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_hunters_hearing_radius">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_hunters_cooldowntime_max">
      <value value="800"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_preys_speed_avmax">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_max-shooting-distance">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_hunters_height_max">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_preys_group_max_size">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_hunters_speed_min">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_hunters_reactiontime_min">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="display-mode">
      <value value="&quot;tracks (hunters)&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_wind-speed">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_hunters_tte_min">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_preys_cooldowntime_max">
      <value value="600"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment-hunter-height" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <postRun>let paramConfig (word "par_hunters_speed_min=" par_hunters_speed_min "_par_hunters_speed_avmax=" par_hunters_speed_avmax)
export-data paramConfig</postRun>
    <metric>patch-width</metric>
    <metric>max-perception-distance</metric>
    <metric>track-maximum</metric>
    <metric>good-daylight-duration</metric>
    <metric>starting-point</metric>
    <metric>wind-spread-angle</metric>
    <metric>starting-point-buffer-distance</metric>
    <metric>obstacle-damage</metric>
    <metric>track-mark-probability</metric>
    <metric>track-pregeneration-period</metric>
    <metric>wind-speed</metric>
    <metric>wind-direction</metric>
    <metric>num-hunters</metric>
    <metric>num-planned-waypoints</metric>
    <metric>hunters_height_stealth</metric>
    <metric>hunters_height_min</metric>
    <metric>hunters_height_max</metric>
    <metric>hunters_visualacuity_mean</metric>
    <metric>hunters_visualacuity_sd</metric>
    <metric>hunters_speed_stealth</metric>
    <metric>hunters_speed_min</metric>
    <metric>hunters_speed_max</metric>
    <metric>hunters_speed_avmax</metric>
    <metric>hunters_tte_min</metric>
    <metric>hunters_tte_max</metric>
    <metric>hunters_reactiontime_min</metric>
    <metric>hunters_reactiontime_max</metric>
    <metric>hunters_cooldowntime_min</metric>
    <metric>hunters_cooldowntime_max</metric>
    <metric>max-shooting-distance</metric>
    <metric>hunters_hearing_radius</metric>
    <metric>hunters_fov</metric>
    <metric>num-preys</metric>
    <metric>preys_group_max_size</metric>
    <metric>preys_safe-distance</metric>
    <metric>preys_height_min</metric>
    <metric>preys_height_max</metric>
    <metric>preys_visualacuity_mean</metric>
    <metric>preys_visualacuity_sd</metric>
    <metric>preys_speed_min</metric>
    <metric>preys_speed_max</metric>
    <metric>preys_speed_avmax</metric>
    <metric>preys_tte_min</metric>
    <metric>preys_tte_max</metric>
    <metric>preys_reactiontime_min</metric>
    <metric>preys_reactiontime_max</metric>
    <metric>preys_cooldowntime_min</metric>
    <metric>preys_cooldowntime_max</metric>
    <metric>preys_hearing_radius</metric>
    <metric>preys_fov</metric>
    <metric>init-obstacle-scale</metric>
    <metric>prey-attractor-probability</metric>
    <metric>attractiveness-to-prey-max</metric>
    <metric>planned-waypoints</metric>
    <metric>visited-waypoints</metric>
    <metric>discarded-waypoints</metric>
    <metric>hunter-prey-detections</metric>
    <metric>prey-hunter-detections</metric>
    <metric>sneaks</metric>
    <metric>pursues</metric>
    <metric>shots</metric>
    <metric>was-bout-successful</metric>
    <metric>is-bout-finished</metric>
    <metric>hunter-who-shot</metric>
    <metric>prey-who-got-shot</metric>
    <enumeratedValueSet variable="display-waypoints">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_hunters_reactiontime_max">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_obstacle-damage">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_preys_tte_min">
      <value value="60"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_preys_fov">
      <value value="300"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="agent-scale">
      <value value="1.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_preys_reactiontime_max">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_preys_height_min">
      <value value="1.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_track-pregeneration-period">
      <value value="7"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_hunters_visualacuity_sd">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_preys_safe-distance">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_hunters_height_min">
      <value value="1.3"/>
      <value value="1.4"/>
      <value value="1.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_init-obstacle-scale">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_starting-point-buffer-distance">
      <value value="1.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_hunters_speed_avmax">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_preys_cooldowntime_min">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_track-mark-probability">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_preys_height_max">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_hunters_speed_stealth">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_hunters_speed_max">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_preys_speed_min">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_hunters_tte_max">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_num-preys">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_num-hunters">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_hunters_fov">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_preys_speed_max">
      <value value="75"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_prey-attractor-probability">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_num-planned-waypoints">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_preys_reactiontime_min">
      <value value="60"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_hunters_cooldowntime_min">
      <value value="400"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_wind-direction">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_preys_tte_max">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_preys_visualacuity_mean">
      <value value="33"/>
    </enumeratedValueSet>
    <steppedValueSet variable="SEED" first="0" step="1" last="10"/>
    <enumeratedValueSet variable="par_hunters_height_stealth">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_preys_hearing_radius">
      <value value="300"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_preys_visualacuity_sd">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="print-messages">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_hunters_visualacuity_mean">
      <value value="65"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_hunters_hearing_radius">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_hunters_cooldowntime_max">
      <value value="800"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_preys_speed_avmax">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_max-shooting-distance">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_hunters_height_max">
      <value value="1.6"/>
      <value value="1.8"/>
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_preys_group_max_size">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_hunters_speed_min">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_hunters_reactiontime_min">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="display-mode">
      <value value="&quot;tracks (hunters)&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_wind-speed">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_hunters_tte_min">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_preys_cooldowntime_max">
      <value value="600"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment-waypoints" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <postRun>let paramConfig (word "par_num-planned-waypoints=" par_num-planned-waypoints)
export-data paramConfig</postRun>
    <metric>patch-width</metric>
    <metric>max-perception-distance</metric>
    <metric>track-maximum</metric>
    <metric>good-daylight-duration</metric>
    <metric>starting-point</metric>
    <metric>wind-spread-angle</metric>
    <metric>starting-point-buffer-distance</metric>
    <metric>obstacle-damage</metric>
    <metric>track-mark-probability</metric>
    <metric>track-pregeneration-period</metric>
    <metric>wind-speed</metric>
    <metric>wind-direction</metric>
    <metric>num-hunters</metric>
    <metric>num-planned-waypoints</metric>
    <metric>hunters_height_stealth</metric>
    <metric>hunters_height_min</metric>
    <metric>hunters_height_max</metric>
    <metric>hunters_visualacuity_mean</metric>
    <metric>hunters_visualacuity_sd</metric>
    <metric>hunters_speed_stealth</metric>
    <metric>hunters_speed_min</metric>
    <metric>hunters_speed_max</metric>
    <metric>hunters_speed_avmax</metric>
    <metric>hunters_tte_min</metric>
    <metric>hunters_tte_max</metric>
    <metric>hunters_reactiontime_min</metric>
    <metric>hunters_reactiontime_max</metric>
    <metric>hunters_cooldowntime_min</metric>
    <metric>hunters_cooldowntime_max</metric>
    <metric>max-shooting-distance</metric>
    <metric>hunters_hearing_radius</metric>
    <metric>hunters_fov</metric>
    <metric>num-preys</metric>
    <metric>preys_group_max_size</metric>
    <metric>preys_safe-distance</metric>
    <metric>preys_height_min</metric>
    <metric>preys_height_max</metric>
    <metric>preys_visualacuity_mean</metric>
    <metric>preys_visualacuity_sd</metric>
    <metric>preys_speed_min</metric>
    <metric>preys_speed_max</metric>
    <metric>preys_speed_avmax</metric>
    <metric>preys_tte_min</metric>
    <metric>preys_tte_max</metric>
    <metric>preys_reactiontime_min</metric>
    <metric>preys_reactiontime_max</metric>
    <metric>preys_cooldowntime_min</metric>
    <metric>preys_cooldowntime_max</metric>
    <metric>preys_hearing_radius</metric>
    <metric>preys_fov</metric>
    <metric>init-obstacle-scale</metric>
    <metric>prey-attractor-probability</metric>
    <metric>attractiveness-to-prey-max</metric>
    <metric>planned-waypoints</metric>
    <metric>visited-waypoints</metric>
    <metric>discarded-waypoints</metric>
    <metric>hunter-prey-detections</metric>
    <metric>prey-hunter-detections</metric>
    <metric>sneaks</metric>
    <metric>pursues</metric>
    <metric>shots</metric>
    <metric>was-bout-successful</metric>
    <metric>is-bout-finished</metric>
    <metric>hunter-who-shot</metric>
    <metric>prey-who-got-shot</metric>
    <enumeratedValueSet variable="display-waypoints">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_hunters_reactiontime_max">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_obstacle-damage">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_preys_tte_min">
      <value value="60"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_preys_fov">
      <value value="300"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="agent-scale">
      <value value="1.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_preys_reactiontime_max">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_preys_height_min">
      <value value="1.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_track-pregeneration-period">
      <value value="7"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_hunters_visualacuity_sd">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_preys_safe-distance">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_hunters_height_min">
      <value value="1.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_init-obstacle-scale">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_starting-point-buffer-distance">
      <value value="1.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_hunters_speed_avmax">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_preys_cooldowntime_min">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_track-mark-probability">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_preys_height_max">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_hunters_speed_stealth">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_hunters_speed_max">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_preys_speed_min">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_hunters_tte_max">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_num-preys">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_num-hunters">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_hunters_fov">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_preys_speed_max">
      <value value="75"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_prey-attractor-probability">
      <value value="1"/>
    </enumeratedValueSet>
    <steppedValueSet variable="par_num-planned-waypoints" first="1" step="2" last="10"/>
    <enumeratedValueSet variable="par_preys_reactiontime_min">
      <value value="60"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_hunters_cooldowntime_min">
      <value value="400"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_wind-direction">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_preys_tte_max">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_preys_visualacuity_mean">
      <value value="33"/>
    </enumeratedValueSet>
    <steppedValueSet variable="SEED" first="0" step="1" last="10"/>
    <enumeratedValueSet variable="par_hunters_height_stealth">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_preys_hearing_radius">
      <value value="300"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_preys_visualacuity_sd">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="print-messages">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_hunters_visualacuity_mean">
      <value value="65"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_hunters_hearing_radius">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_hunters_cooldowntime_max">
      <value value="800"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_preys_speed_avmax">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_max-shooting-distance">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_hunters_height_max">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_preys_group_max_size">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_hunters_speed_min">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_hunters_reactiontime_min">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="display-mode">
      <value value="&quot;tracks (hunters)&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_wind-speed">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_hunters_tte_min">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_preys_cooldowntime_max">
      <value value="600"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment-prey-attractivess" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <postRun>let paramConfig (word "par_prey-attractor-probability=" par_prey-attractor-probability)
export-data paramConfig</postRun>
    <metric>patch-width</metric>
    <metric>max-perception-distance</metric>
    <metric>track-maximum</metric>
    <metric>good-daylight-duration</metric>
    <metric>starting-point</metric>
    <metric>wind-spread-angle</metric>
    <metric>starting-point-buffer-distance</metric>
    <metric>obstacle-damage</metric>
    <metric>track-mark-probability</metric>
    <metric>track-pregeneration-period</metric>
    <metric>wind-speed</metric>
    <metric>wind-direction</metric>
    <metric>num-hunters</metric>
    <metric>num-planned-waypoints</metric>
    <metric>hunters_height_stealth</metric>
    <metric>hunters_height_min</metric>
    <metric>hunters_height_max</metric>
    <metric>hunters_visualacuity_mean</metric>
    <metric>hunters_visualacuity_sd</metric>
    <metric>hunters_speed_stealth</metric>
    <metric>hunters_speed_min</metric>
    <metric>hunters_speed_max</metric>
    <metric>hunters_speed_avmax</metric>
    <metric>hunters_tte_min</metric>
    <metric>hunters_tte_max</metric>
    <metric>hunters_reactiontime_min</metric>
    <metric>hunters_reactiontime_max</metric>
    <metric>hunters_cooldowntime_min</metric>
    <metric>hunters_cooldowntime_max</metric>
    <metric>max-shooting-distance</metric>
    <metric>hunters_hearing_radius</metric>
    <metric>hunters_fov</metric>
    <metric>num-preys</metric>
    <metric>preys_group_max_size</metric>
    <metric>preys_safe-distance</metric>
    <metric>preys_height_min</metric>
    <metric>preys_height_max</metric>
    <metric>preys_visualacuity_mean</metric>
    <metric>preys_visualacuity_sd</metric>
    <metric>preys_speed_min</metric>
    <metric>preys_speed_max</metric>
    <metric>preys_speed_avmax</metric>
    <metric>preys_tte_min</metric>
    <metric>preys_tte_max</metric>
    <metric>preys_reactiontime_min</metric>
    <metric>preys_reactiontime_max</metric>
    <metric>preys_cooldowntime_min</metric>
    <metric>preys_cooldowntime_max</metric>
    <metric>preys_hearing_radius</metric>
    <metric>preys_fov</metric>
    <metric>init-obstacle-scale</metric>
    <metric>prey-attractor-probability</metric>
    <metric>attractiveness-to-prey-max</metric>
    <metric>planned-waypoints</metric>
    <metric>visited-waypoints</metric>
    <metric>discarded-waypoints</metric>
    <metric>hunter-prey-detections</metric>
    <metric>prey-hunter-detections</metric>
    <metric>sneaks</metric>
    <metric>pursues</metric>
    <metric>shots</metric>
    <metric>was-bout-successful</metric>
    <metric>is-bout-finished</metric>
    <metric>hunter-who-shot</metric>
    <metric>prey-who-got-shot</metric>
    <enumeratedValueSet variable="display-waypoints">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_hunters_reactiontime_max">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_obstacle-damage">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_preys_tte_min">
      <value value="60"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_preys_fov">
      <value value="300"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="agent-scale">
      <value value="1.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_preys_reactiontime_max">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_preys_height_min">
      <value value="1.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_track-pregeneration-period">
      <value value="7"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_hunters_visualacuity_sd">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_preys_safe-distance">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_hunters_height_min">
      <value value="1.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_init-obstacle-scale">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_starting-point-buffer-distance">
      <value value="1.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_hunters_speed_avmax">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_preys_cooldowntime_min">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_track-mark-probability">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_preys_height_max">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_hunters_speed_stealth">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_hunters_speed_max">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_preys_speed_min">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_hunters_tte_max">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_num-preys">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_num-hunters">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_hunters_fov">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_preys_speed_max">
      <value value="75"/>
    </enumeratedValueSet>
    <steppedValueSet variable="par_prey-attractor-probability" first="1" step="2" last="20"/>
    <enumeratedValueSet variable="par_num-planned-waypoints">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_preys_reactiontime_min">
      <value value="60"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_hunters_cooldowntime_min">
      <value value="400"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_wind-direction">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_preys_tte_max">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_preys_visualacuity_mean">
      <value value="33"/>
    </enumeratedValueSet>
    <steppedValueSet variable="SEED" first="0" step="1" last="10"/>
    <enumeratedValueSet variable="par_hunters_height_stealth">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_preys_hearing_radius">
      <value value="300"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_preys_visualacuity_sd">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="print-messages">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_hunters_visualacuity_mean">
      <value value="65"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_hunters_hearing_radius">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_hunters_cooldowntime_max">
      <value value="800"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_preys_speed_avmax">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_max-shooting-distance">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_hunters_height_max">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_preys_group_max_size">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_hunters_speed_min">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_hunters_reactiontime_min">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="display-mode">
      <value value="&quot;tracks (hunters)&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_wind-speed">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_hunters_tte_min">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_preys_cooldowntime_max">
      <value value="600"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment-scenarios" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <postRun>let paramConfig (word "scenario-environment=" scenario-environment "_waypoints-to-prey-attractors=" waypoints-to-prey-attractors)
export-data paramConfig</postRun>
    <metric>patch-width</metric>
    <metric>max-perception-distance</metric>
    <metric>track-maximum</metric>
    <metric>good-daylight-duration</metric>
    <metric>starting-point</metric>
    <metric>wind-spread-angle</metric>
    <metric>starting-point-buffer-distance</metric>
    <metric>obstacle-damage</metric>
    <metric>track-mark-probability</metric>
    <metric>track-pregeneration-period</metric>
    <metric>wind-speed</metric>
    <metric>wind-direction</metric>
    <metric>num-hunters</metric>
    <metric>num-planned-waypoints</metric>
    <metric>hunters_height_stealth</metric>
    <metric>hunters_height_min</metric>
    <metric>hunters_height_max</metric>
    <metric>hunters_visualacuity_mean</metric>
    <metric>hunters_visualacuity_sd</metric>
    <metric>hunters_speed_stealth</metric>
    <metric>hunters_speed_min</metric>
    <metric>hunters_speed_max</metric>
    <metric>hunters_speed_avmax</metric>
    <metric>hunters_tte_min</metric>
    <metric>hunters_tte_max</metric>
    <metric>hunters_reactiontime_min</metric>
    <metric>hunters_reactiontime_max</metric>
    <metric>hunters_cooldowntime_min</metric>
    <metric>hunters_cooldowntime_max</metric>
    <metric>max-shooting-distance</metric>
    <metric>hunters_hearing_radius</metric>
    <metric>hunters_fov</metric>
    <metric>num-preys</metric>
    <metric>preys_group_max_size</metric>
    <metric>preys_safe-distance</metric>
    <metric>preys_height_min</metric>
    <metric>preys_height_max</metric>
    <metric>preys_visualacuity_mean</metric>
    <metric>preys_visualacuity_sd</metric>
    <metric>preys_speed_min</metric>
    <metric>preys_speed_max</metric>
    <metric>preys_speed_avmax</metric>
    <metric>preys_tte_min</metric>
    <metric>preys_tte_max</metric>
    <metric>preys_reactiontime_min</metric>
    <metric>preys_reactiontime_max</metric>
    <metric>preys_cooldowntime_min</metric>
    <metric>preys_cooldowntime_max</metric>
    <metric>preys_hearing_radius</metric>
    <metric>preys_fov</metric>
    <metric>init-obstacle-scale</metric>
    <metric>init-obstacle-frequency</metric>
    <metric>init-obstacle-diffuse-times</metric>
    <metric>init-obstacle-diffuse-rate</metric>
    <metric>prey-attractor-probability</metric>
    <metric>attractiveness-diffuse-times</metric>
    <metric>attractiveness-diffuse-rate</metric>
    <metric>fires-number</metric>
    <metric>fires-radius</metric>
    <metric>attractiveness-to-prey-max</metric>
    <metric>planned-waypoints</metric>
    <metric>visited-waypoints</metric>
    <metric>discarded-waypoints</metric>
    <metric>hunter-prey-detections</metric>
    <metric>prey-hunter-detections</metric>
    <metric>sneaks</metric>
    <metric>pursues</metric>
    <metric>shots</metric>
    <metric>was-bout-successful</metric>
    <metric>is-bout-finished</metric>
    <metric>hunter-who-shot</metric>
    <metric>prey-who-got-shot</metric>
    <enumeratedValueSet variable="par_obstacle-damage">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_hunters_reactiontime_max">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_preys_fov">
      <value value="300"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_track-pregeneration-period">
      <value value="7"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_preys_safe-distance">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_init-obstacle-scale">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_track-mark-probability">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_preys_cooldowntime_min">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_preys_height_max">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_hunters_speed_stealth">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_init-obstacle-diffuse-times">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_hunters_speed_max">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_hunters_tte_max">
      <value value="600"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_num-hunters">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_hunters_fov">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_num-planned-waypoints">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_init-obstacle-frequency">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_preys_speed_max">
      <value value="75"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_preys_tte_max">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_preys_visualacuity_mean">
      <value value="33"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_preys_visualacuity_sd">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_attractiveness-diffuse-times">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_hunters_hearing_radius">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_hunters_cooldowntime_max">
      <value value="800"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_fires-radius">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_hunters_height_max">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_preys_group_max_size">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_hunters_reactiontime_min">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_hunters_speed_min">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="display-mode">
      <value value="&quot;attractiveness-to-prey&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_fires-number">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_hunters_tte_min">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="display-waypoints">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_preys_tte_min">
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="agent-scale">
      <value value="1.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_preys_reactiontime_max">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_preys_height_min">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_hunters_visualacuity_sd">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_hunters_height_min">
      <value value="1.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_starting-point-buffer-distance">
      <value value="1.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_hunters_speed_avmax">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="scenario-environment">
      <value value="&quot;default&quot;"/>
      <value value="&quot;wet and no fires&quot;"/>
      <value value="&quot;dry and no fires&quot;"/>
      <value value="&quot;wet with fires&quot;"/>
      <value value="&quot;dry with fires&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_preys_speed_min">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_num-preys">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_hunters_cooldowntime_min">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_prey-attractor-probability">
      <value value="49"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_preys_reactiontime_min">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_attractiveness-diffuse-rate">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_wind-direction">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_hunters_height_stealth">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_preys_hearing_radius">
      <value value="300"/>
    </enumeratedValueSet>
    <steppedValueSet variable="SEED" first="0" step="1" last="9"/>
    <enumeratedValueSet variable="print-messages">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_hunters_visualacuity_mean">
      <value value="65"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_preys_speed_avmax">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_max-shooting-distance">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_wind-speed">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_preys_cooldowntime_max">
      <value value="600"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="par_init-obstacle-diffuse-rate">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="waypoints-to-prey-attractors">
      <value value="false"/>
      <value value="true"/>
    </enumeratedValueSet>
  </experiment>
</experiments>
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
