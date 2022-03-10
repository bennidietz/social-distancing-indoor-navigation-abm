extensions [ csv ]

breed [ peds ped ]
breed [ decision-points decision-point ]
breed [ circles circle ]

globals [
  environment
  wait-and-return?
  entrance-area?
  obstacle-patches
  opened-gates
  spatial-scale
  agents-died-nb
  all-possible-paths
  starting-corner-x starting-corner-y starting-extent-x starting-extent-y
  time
  mean-speed
  entire-contacts-nb entire-contact-time
  distinct-contacts-nb
  critical-contacts-nb
  distance-of-contacts-nb distance-of-contacts-accum
  csv
  fileList
  average-contact-nb
  average-critical-contact-nb
]
peds-own [
  speedx speedy ; for base movement
  state ; 2 = orange = navigating with mobile navigation system ; 0 = without navigation aid
  keeps-sd
  elevator-time-left
  final-destination next-destination-id starting-point last-decision-point-id all-paths shortest-path ; for navigation
  all-contacts-nb all-present-contacts present-contacts-duration contact-history ; for contact tracing
  distinct-contacts-to-others-nb ; distinct
  visit-time
]
decision-points-own [
  id
  reachable-decision-points
  is-destination is-origin
  gate-is-opened gate-opened-time gate-got-closed
]


; set up colors of patches and agents + their properties
to setup
  reset-timer
  clear-all reset-ticks
  ifelse airport-environment? [
    set environment "airport_dus2"
  ][
    set environment "hospital"
  ]
  set average-contact-nb 0
  set average-critical-contact-nb 0
  set spatial-scale 1
  establish-environment
  if visualize? [ set-default-shape circles "circle 2" ]
  set all-possible-paths []
  set agents-died-nb  0
  loadNodes
  loadConnections
  load-all-paths
  if not continuous-birth? [ set-agents continuous-birth? true [ patch-here ] of one-of decision-points with [ is-origin = true ] ]
  if logs? [print "--- NEW SIMULATION ---"]
end

; builds the network of the environemnt on which pedestrians can navigate on
to establish-environment
  import-pcolors word "network/" word environment "/floorplan.png"
  set obstacle-patches patches with [ pcolor = 71.4 ]; darkgreen patches


  ifelse airport-environment? [
    set wait-and-return? false
    set entrance-area? true
    set spatial-scale 4.45
    resize-world -720 720 -576 576
    set starting-corner-x 386
    set starting-corner-y -570
    set starting-extent-x 25
    set starting-extent-y 0
  ][
    set wait-and-return? true
    set entrance-area? false
    set spatial-scale 4.4
    resize-world -576 576 -576 576
    set starting-corner-x -555
    set starting-corner-y 7
    set starting-extent-x 40
    set starting-extent-y 60
  ]
end

to-report collapse-string-list [str]
  let return-list []
  set str word str ","  ; add comma for loop termination
  while [not empty? str] [
    let $x position "," str
    let $item substring str 0 $x
    carefully [set $item read-from-string $item][] ; convert if number
    set return-list lput $item return-list  ; append to list
    set str substring str ($x + 1) length str
    ;report reduce word ( sentence map [ str -> word str ", " ] but-last str-list last str-list )
  ]
  report return-list
end

; get all nodes (descision points, origins and destinations) from CSV files
to loadNodes
  file-open word "network/" word environment "/decision_points.csv"
  set fileList []

  while [not file-at-end?] [
    set csv file-read-line
    set csv word csv ";"  ; add comma for loop termination

    let mylist []  ; list of values
    while [not empty? csv]
    [
      let $x position ";" csv
      let $item substring csv 0 $x  ; extract item
      carefully [set $item read-from-string $item][] ; convert if number
      set mylist lput $item mylist  ; append to list
      set csv substring csv ($x + 1) length csv  ; remove item and comma
    ]
    set fileList lput mylist fileList
  ]

  foreach fileList [ line ->
    c-decision-point item 0 line item 1 line item 2 line false false
  ]
  file-close

  file-open word "network/" word environment "/origins_destinations.csv"
  set fileList []

  while [not file-at-end?] [
    set csv file-read-line
    set csv word csv ";"  ; add comma for loop termination

    let mylist []  ; list of values
    while [not empty? csv]
    [
      let $x position ";" csv
      let $item substring csv 0 $x  ; extract item
      carefully [set $item read-from-string $item][] ; convert if number
      set mylist lput $item mylist  ; append to list
      set csv substring csv ($x + 1) length csv  ; remove item and comma
    ]
    set fileList lput mylist fileList
  ]

  foreach fileList [ line ->
    ifelse item 3 line [
      ; destination
      c-decision-point item 0 line item 1 line item 2 line true false
    ] [
      ; origin
      c-decision-point item 0 line item 1 line item 2 line false true
    ]
  ]
  file-close
end


to loadConnections
  file-open word "network/" word environment "/connections.csv"
  set fileList []

  while [not file-at-end?] [
    set csv file-read-line
    set csv word csv ";"  ; add comma for loop termination

    let mylist []  ; list of values
    while [not empty? csv]
    [
      let $x position ";" csv
      let $item substring csv 0 $x  ; extract item
      carefully [set $item read-from-string $item][] ; convert if number
      set mylist lput $item mylist  ; append to list
      set csv substring csv ($x + 1) length csv  ; remove item and comma
    ]
    set fileList lput mylist fileList
  ]

  foreach fileList [ line ->
    build-connection-between item 0 line item 1 line
  ]
  file-close
end


to-report replace-subitem [index1 index2 lists value]
  let old-sublist item index1 lists
  report replace-item index1 lists (replace-item index2 old-sublist value)
end



to load-all-paths
  file-open word "network/" word environment "/paths.csv"
  set fileList []

  while [not file-at-end?] [
    set csv file-read-line
    set csv word csv ";"  ; add comma for loop termination

    let mylist []  ; list of values
    let counter 0
    while [not empty? csv]
    [
      let $x position ";" csv
      let $item substring csv 0 $x  ; extract item
      if member? "," $item [
        set $item collapse-string-list $item
      ]
      carefully [set $item read-from-string $item][] ; convert if number
      ifelse counter < 2 [
       set mylist lput $item mylist  ; append to list
      ][
        ifelse counter = 2 [
          set mylist lput (list $item) mylist
        ] [
          let new-sublist item 2 mylist
          set new-sublist lput $item new-sublist
          set mylist replace-item 2 mylist new-sublist
        ]
      ]
      set csv substring csv ($x + 1) length csv  ; remove item and comma
      set counter counter + 1
    ]
    set fileList lput mylist fileList
  ]

  set all-possible-paths fileList
  file-close
end


to show-coordinate
  if mouse-down? and timer > .2 [
    reset-timer
    print word "Clicked at coordinate (" word round mouse-xcor word "/" word round mouse-ycor ")"
  ]
end


; birth of agents
to set-agents [ continuously departure predef_s_point ]
  ifelse continuously [
    repeat c-birth-nb [ c-ped continuously departure predef_s_point ]
  ][
   repeat nb-peds [ c-ped continuously departure predef_s_point ]
  ]
end


; set properties for new born agents
to c-ped  [ continuously departure? predef_s_point ]
  let x nobody
  let y nobody
  let s-point nobody
  let distance-s-point 9999999999

  ; set random destination
  ifelse departure? and entrance-area? [
    set x starting-corner-x + random-float starting-extent-x set y starting-corner-y + random-float starting-extent-y
  ][
    set x [pxcor] of predef_s_point set y [pycor] of predef_s_point
  ]
  ask decision-points with [ is-origin = true ] [
    if distancexy x y < distance-s-point [
      set distance-s-point distancexy x y
      set s-point self
    ]
  ]

  create-peds 1 [
    ; base properties
    if visualize? [
      ifelse airport-environment? [
        set size 2 * spatial-scale
      ][
        set size 3 * spatial-scale
      ]
      ifelse airport-environment? [
        set shape "person business"
      ][
        set shape "person"
      ]
      set color cyan
      if show-turtle-labels? [ set label who ]
      set label-color cyan
    ]
    set xcor x + random-normal 0 .2
    set ycor y + random-normal 0 .2

    set elevator-time-left 0

    set visit-time 0

    ; for navigation
    ifelse airport-environment? [
      ifelse departure? [
        set final-destination one-of decision-points with [ is-destination = true and id < 600 ]
      ][
        set final-destination one-of decision-points with [ is-destination = true and id >= 600 ]
      ]
    ][
      set final-destination one-of decision-points with [ is-destination = true and floor(id / 100) = floor([ id ] of s-point / 100) ]
      set elevator-time-left floor([ id ] of s-point / 100) * 20 / dt
      if elevator-time-left > 0 [ ht ]
    ]

    set next-destination-id nobody
    set starting-point s-point
    set last-decision-point-id s-point
    set all-paths []
    set shortest-path []

    ; for contact tracing
    set contact-history []
    set all-present-contacts []
    set present-contacts-duration []
    set-initial-path-and-next-destination self

    let orangePeds count peds with [ state = 2 ]
    if count peds > 0 [
      if orangePeds / count peds < navigation-system-rate [
        set state 2
        if visualize? [
          set label-color orange
          set color orange
        ]
      ]
      ifelse count peds with [ not (self = myself) and keeps-sd ] / count peds < keeping-sd-rate / 100 [
        set keeps-sd true
      ][
        set keeps-sd false
      ]
    ]
  ]
end


; handle the creation of a decision point
; @param: id : int => id of the decision point
; @param: x : int , y : int => coordinates of decision point
; @param: isDestination : bool => is it a destination for pedestrians?
; @param: isOrigin : bool => is it a origin for pedestians?
to c-decision-point [identification x y isDestination isOrigin]
  create-decision-points 1 [
    set xcor x
    set ycor y
    set is-origin isOrigin
    set is-destination isDestination

    set reachable-decision-points []
    set id identification
    set gate-is-opened false set gate-opened-time 0 set gate-got-closed false
    if visualize? [
      set shape "circle"
      ifelse isDestination [ set color blue ] [ set color green ]
      if isOrigin [ set color orange ]
      set size 12
      set label-color red
      if show-dp-labels? [ set label id ]
    ]
    if not show-decision-points? or not visualize?[ ht ]
  ]
end


to-report dp-by-id [id1]
  let output nobody
  ask decision-points with [ id = id1 ] [ set output self ]
  report output
end


; builds a connection between two decision points bidirectionally
; @param: dp1 : decision-point
; @param: dp2 : decision-point
to build-connection-between [id1 id2]
  let dp1 nobody
  let dp2 nobody
  ask decision-points with [ id = id1 ] [ set dp1 self ]
  ask decision-points with [ id = id2 ] [ set dp2 self ]
  ask dp1 [ set reachable-decision-points fput dp2 reachable-decision-points ]
  ask dp2 [
    set reachable-decision-points fput dp1 reachable-decision-points
    if show-paths? and visualize? [ create-link-with dp1 ]
  ]
end

; initially search for all paths and choose shortest one plus next destination
; @sets all-paths, shortest-path, nextdestination
; @param: k : ped => agent for which the calculation is done
to set-initial-path-and-next-destination [k]
  let isset false
  foreach all-possible-paths [origin-destination-pair ->
    if first origin-destination-pair = [id] of [starting-point] of self and
       item 1 origin-destination-pair = [id] of [final-destination] of self [
      set all-paths item 2 origin-destination-pair
      set isset true
    ]
  ]
  if isset = false [ print word "ERRROR:: " word [id] of starting-point [id] of final-destination ]
  set-shortest-path-and-next-destination k
end


; chooses the appropriate path out of 'all-paths' at the beginning for all
; and when recalculating the route
; @param: k : ped => agent for which the calculation is done
; @sets shortest-path, next-destination-id
to set-shortest-path-and-next-destination [k]
  ifelse state = 2 [
   ; users of the navigation system
    set-navigation-system-path self
  ][
   ; pedestrians without a navigation aid
   ifelse random-path? [
    set shortest-path one-of all-paths
  ][
    if empty? all-paths [
        print [ id ] of starting-point
        print [ id ] of final-destination
      print "Error: Paths could not be loaded. Make sure to run the python script before so that the paths can be generated. "
    ]
    ifelse easiest? [
        ifelse length all-paths > 1 [
          set shortest-path one-of sublist all-paths 0 (length all-paths / 2)
        ][
          set shortest-path first all-paths
        ]
     ][
      set shortest-path last all-paths
    ]
  ]
  ]
  ifelse length shortest-path > 1 [
    set next-destination-id item 0 shortest-path
    if item 0 shortest-path = starting-point [ set next-destination-id item 0 shortest-path ]
  ][
    if logs?  [ print word "WARNING: only one left: " word shortest-path final-destination ]
    set next-destination-id item 0 shortest-path
  ]
end


; updatest the shortest-path after reaching a specific node
; @param: k : ped => agent for which the calculation is done
; @param: reached-node : decision-point => node that was reached and that will function as the new starting point
; @sets shortest-path, next-destination-id
to recalculate-shortest-path [k reached-node]
  set all-paths map [ i -> sublist i (position reached-node i + 1) length i ] (filter [ i -> member? reached-node i ] all-paths) ; filters all with paths reached-node in it and sets it as the starting point of each path
  if empty? all-paths [ print word "WARNING: " all-paths ]
  set-shortest-path-and-next-destination self
end


; choses the appropriate path from one decision-point according to the implementation in the mobile navgation system
; @param: k : ped => agent for which the calculation is done
; @sets shortest-path
to set-navigation-system-path [k]
  let filtered-paths all-paths; TODO: filter paths that are not traveled yet and do not make a huge detour

  ; select least traveled route out of these
  let min-travelers 99999999999 ; unreachable number
  let min-travelers-path nobody

  foreach filtered-paths [path ->
    let current-travelers nobody
    ifelse expected? [
      ifelse include-sensors? [
        set current-travelers count peds with [
          (next-destination-id = [ last-decision-point-id ] of k and last-decision-point-id = item 0 path)
          and not (self = myself)
        ]
        set current-travelers (current-travelers + (expected-weight * count peds with [ (next-destination-id = item 0 path) and not (self = myself) ]) )

      ][
        set current-travelers count peds with [
          (next-destination-id = [ last-decision-point-id ] of k and last-decision-point-id = item 0 path)
          and not (self = myself) and state = 2
        ]
        set current-travelers (current-travelers + (expected-weight * count peds with [ (next-destination-id = item 0 path) and not (self = myself) and state = 2 ]) )
      ]
    ][
      ifelse include-sensors? [
        set current-travelers count peds with [
          ( (last-decision-point-id = [ last-decision-point-id ] of k and next-destination-id = item 0 path) or (next-destination-id = [ last-decision-point-id ] of k and last-decision-point-id = item 0 path) )
          and not (self = myself)
        ]
    ][
        set current-travelers count peds with [
          ( (last-decision-point-id = [ last-decision-point-id ] of k and next-destination-id = item 0 path) or (next-destination-id = [ last-decision-point-id ] of k and last-decision-point-id = item 0 path) )
          and not (self = myself) and state = 2
        ]
    ]
    ]

    if current-travelers < min-travelers [
      if logs? [ print word "Travelers: " word current-travelers word " - path: " path ]
      set min-travelers current-travelers
      set min-travelers-path path
    ]
  ]

  if logs? [ print word "Min Travelers: " word min-travelers word " - min path: " min-travelers-path ]
  set shortest-path min-travelers-path
end

; encounter all contacts between two agents
to track-contacts
  ask peds [
    let current-contacts-with []

    ask peds in-radius (social-distancing-radius * spatial-scale) with [not (self = myself)] [

      ifelse not member? [who] of myself all-present-contacts [
        set all-present-contacts lput [who] of myself all-present-contacts
        set present-contacts-duration lput 1 present-contacts-duration
      ] [
        let pos position [who] of myself all-present-contacts
        let counter-value item pos present-contacts-duration
        set counter-value counter-value + 1
        set present-contacts-duration replace-item pos present-contacts-duration counter-value
      ]

      set current-contacts-with lput [who] of self current-contacts-with

      set distance-of-contacts-nb distance-of-contacts-nb + 1
      set distance-of-contacts-accum distance-of-contacts-accum + distance myself

    ]



    foreach all-present-contacts [ x ->

      if not member? x current-contacts-with [

        let present-contact-index position x all-present-contacts
        let counter-value item present-contact-index present-contacts-duration

        set all-present-contacts remove-item present-contact-index all-present-contacts
        set present-contacts-duration remove-item present-contact-index present-contacts-duration

        if counter-value > 4 [
          set entire-contact-time entire-contact-time + counter-value
          set all-contacts-nb all-contacts-nb + 1
          set entire-contacts-nb entire-contacts-nb + 1

          if not (ped x = nobody) [
            ask ped x [
              if member? [who] of myself all-present-contacts [
                let pos2 position [who] of myself all-present-contacts

                if item pos2 present-contacts-duration != counter-value [
                  set present-contacts-duration replace-item pos2 present-contacts-duration counter-value
                ]
              ]
            ]

            if not member? x contact-history [
              set distinct-contacts-to-others-nb distinct-contacts-to-others-nb + 1
              set contact-history lput x contact-history

              set distinct-contacts-nb distinct-contacts-nb + 1
            ]
          ]


          if counter-value >= critical-period / dt [
            set critical-contacts-nb critical-contacts-nb + 1
          ]
        ]
      ]


    ]


  ]
end


; is executed after each tick, moves each ped accordingly, plots and check
to move
  set time precision (time + dt) 5 tick-advance 1

  ask peds with [ hidden? and elevator-time-left > 0 ][
    set elevator-time-left elevator-time-left - 1
    if elevator-time-left = 0 [ st ]
  ]

  if open-gate? and time mod round open-gate-period = 0 [
    let nb_s count decision-points with [ not gate-is-opened and not gate-got-closed and is-origin and id >= 200 ]
    if nb_s > 0 [
      ask one-of decision-points with [ not gate-is-opened and not gate-got-closed and is-origin and id >= 200 ] [
      set gate-is-opened true
      set gate-opened-time time
        if logs? [ print word "Gate was opened: " word time word " - " [id] of self ]
    ]
    ]
  ]

  if performance-debugging? [ print word "Gates open end: " timer ]
  reset-timer

  if continuous-birth? [
    if time mod round birth-tick-period = 0 [
      set-agents continuous-birth? true [ patch-here ] of one-of decision-points with [ is-origin = true ]
      if open-gate? [
        let dps []
        let sz count decision-points with [ gate-is-opened and not gate-got-closed ]
        if sz > 0 [
          ask decision-points with [ gate-is-opened and not gate-got-closed ][
            set dps fput patch xcor ycor dps
            if (time - gate-opened-time) / round birth-tick-period * c-birth-nb >= passengers-nb [
              set gate-got-closed true
            ]
          ]
          foreach dps [dp ->
            set-agents continuous-birth? false dp
          ]
        ]
      ]
    ]
  ]

  track-contacts

  ask peds with [state > -1]
    [
      if wait-and-return? and visit-time > 0 [
        ifelse visit-time > 1800 [
          st
          set visit-time 0
          set xcor [ xcor ] of starting-point - 0.5
          set ycor [ ycor ] of starting-point - 0.5
        ][
          set visit-time visit-time + 1 * dt
        ]
      ]

      if not hidden? [

        let hd towards dp-by-id next-destination-id
        let h hd
        face dp-by-id next-destination-id
        let repx 0
        let repy 0
        if not (speedx * speedy = 0)
        [set h atan speedx speedy]

        ifelse keeps-sd [
          ask peds in-cone (social-force-radius * spatial-scale) 90 with [not (self = myself) and not hidden? and distance myself > 0 ]
          [
            ifelse distance final-destination < (destination-reached-radius * spatial-scale) or distance dp-by-id next-destination-id <  (decision-point-radius * spatial-scale) [
              set repx repx + social-force-weight / 2 * exp((1 - distance myself) / social-force-radius * spatial-scale) * sin(towards myself) * (1 - cos(towards myself - h))
              set repy repy + social-force-weight / 2 * exp((1 - distance myself) / social-force-radius * spatial-scale) * cos(towards myself) * (1 - cos(towards myself - h))
            ][
              set repx repx + social-force-weight * exp((1 - distance myself) / social-force-radius) * sin(towards myself) * (1 - cos(towards myself - h))
              set repy repy + social-force-weight * exp((1 - distance myself) / social-force-radius) * cos(towards myself) * (1 - cos(towards myself - h))
            ]
          ]
        ][
          ask peds in-cone (0.5 * spatial-scale) 90 with [ not (self = myself) and not hidden? and distance myself > 0 ]
          [
            ifelse distance final-destination < (destination-reached-radius * spatial-scale) or distance dp-by-id next-destination-id <  (decision-point-radius * spatial-scale) [
              set repx repx + social-force-weight / 2 * exp((1 - distance myself) / social-force-radius * spatial-scale) * sin(towards myself) * (1 - cos(towards myself - h))
              set repy repy + social-force-weight / 2 * exp((1 - distance myself) / social-force-radius * spatial-scale) * cos(towards myself) * (1 - cos(towards myself - h))
            ][
              set repx repx + social-force-weight * exp((1 - distance myself) / social-force-radius) * sin(towards myself) * (1 - cos(towards myself - h))
              set repy repy + social-force-weight * exp((1 - distance myself) / social-force-radius) * cos(towards myself) * (1 - cos(towards myself - h))
            ]
          ]
        ]

        if performance-debugging? [ print word "First: " timer ]
        reset-timer

        ifelse airport-environment? [
          ask patches in-radius (wall-force-radius * spatial-scale) with [ pcolor = 71.4 and distance myself > 0 ]
          [
            set repx repx + wall-force-weight * exp((1 - distance myself) / wall-force-radius * spatial-scale) * sin(towards myself) * (1 - cos(towards myself - h))
            set repy repy + wall-force-weight * exp((1 - distance myself) / wall-force-radius * spatial-scale) * cos(towards myself) * (1 - cos(towards myself - h))
          ]
        ][
          ask patches in-radius (wall-force-radius * spatial-scale) with [ pcolor <= 7 and distance myself > 0 ]
          [
            set repx repx + wall-force-weight * exp((1 - distance myself) / wall-force-radius * spatial-scale) * sin(towards myself) * (1 - cos(towards myself - h))
            set repy repy + wall-force-weight * exp((1 - distance myself) / wall-force-radius * spatial-scale) * cos(towards myself) * (1 - cos(towards myself - h))
          ]
        ]

        if performance-debugging? [ print word "Second: " timer ]
        reset-timer

        set speedx speedx + dt * (repx + (maximum-speed * sin hd - speedx) / Tr)
        set speedy speedy + dt * (repy + (maximum-speed * cos hd - speedy) / Tr)

        if distance dp-by-id next-destination-id < (decision-point-radius * spatial-scale) or distance final-destination < (destination-reached-radius * spatial-scale) [
          set last-decision-point-id next-destination-id
          ifelse distance final-destination < (destination-reached-radius * spatial-scale) [
            ifelse not wait-and-return? or [ is-origin ] of final-destination [
              set agents-died-nb agents-died-nb + 1
              die
            ][
              let dest final-destination
              set final-destination starting-point
              set starting-point dest
              set-initial-path-and-next-destination self
              ht
              set visit-time 1 * dt
            ]
          ][
            let pos (position next-destination-id shortest-path) + 1

            ifelse state = 2 [ ;orange agents
              recalculate-shortest-path self next-destination-id
            ][
              set next-destination-id item pos shortest-path
            ]

          ]
        ]

      ]

    ]

  if performance-debugging? [ print word "5: " timer ]
  reset-timer

  ; actually moving the ped
  ask peds with [ not (hidden?) ] [
    set xcor xcor + speedx * dt
    set ycor ycor + speedy * dt
  ]

  if performance-debugging? [ print word "Movement: " timer ]
  reset-timer

  update-after-movement

  if performance-debugging? [ print word "Post calculations: " timer ]
  reset-timer


  if (count peds + agents-died-nb) > 0 [
    set average-contact-nb (round entire-contacts-nb / 2) / (count peds + agents-died-nb)
    set average-critical-contact-nb (round critical-contacts-nb / 2) / (count peds + agents-died-nb)
  ]
end


; updates plots and checks if the simulation needs to be ended
to update-after-movement
  if count peds with [state > -1] > 1 [set mean-speed mean-speed + mean [sqrt(speedx ^ 2 + speedy ^ 2)] of peds with [state > -1]]
  update-plots
end
@#$#@#$#@
GRAPHICS-WINDOW
26
10
1055
836
-1
-1
0.25
1
10
1
1
1
0
0
0
1
-720
720
-576
576
1
1
1
Ticks
30.0

SLIDER
1142
162
1245
195
Nb-peds
Nb-peds
0
200
3.0
1
1
NIL
HORIZONTAL

BUTTON
1548
338
1603
372
NIL
Setup
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
1547
383
1602
416
NIL
Move
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
1072
221
1215
254
maximum-speed
maximum-speed
0
5
1.7
0.1
1
NIL
HORIZONTAL

MONITOR
1610
333
1723
378
Time in seconds
time
17
1
11

SWITCH
1459
278
1564
311
easiest?
easiest?
0
1
-1000

SLIDER
1284
27
1387
60
dt
dt
0
1
0.1
.01
1
NIL
HORIZONTAL

SLIDER
1071
443
1257
476
social-force-radius
social-force-radius
0.1
5
1.5
.1
1
NIL
HORIZONTAL

BUTTON
1611
388
1666
421
NIL
Move
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
1452
444
1604
477
social-force-weight
social-force-weight
0
5
2.5
.1
1
NIL
HORIZONTAL

SLIDER
1246
228
1338
261
Tr
Tr
.1
2
2.0
.1
1
NIL
HORIZONTAL

SLIDER
1074
279
1277
312
navigation-system-rate
navigation-system-rate
0
1
0.7
.05
1
NIL
HORIZONTAL

SWITCH
1294
278
1440
311
random-path?
random-path?
0
1
-1000

SWITCH
1073
718
1176
751
logs?
logs?
1
1
-1000

SLIDER
1072
558
1245
591
social-distancing-radius
social-distancing-radius
0
10
1.5
.1
1
NIL
HORIZONTAL

MONITOR
1074
597
1209
642
Number of contacts
entire-contacts-nb / 2
0
1
11

MONITOR
1229
596
1400
641
Avg. number of contacts per person
distinct-contacts-nb / 2 / Nb-peds
3
1
11

MONITOR
1410
597
1591
642
Unique contacts (nb)
distinct-contacts-nb / 2
0
1
11

MONITOR
1074
648
1244
693
Average contact duration
entire-contact-time / distinct-contacts-nb
3
1
11

MONITOR
1437
649
1606
694
Average contact distance
distance-of-contacts-accum / distance-of-contacts-nb
3
1
11

BUTTON
1037
1001
1175
1034
NIL
show-coordinate\n
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
1071
501
1304
534
decision-point-radius
decision-point-radius
0
10
2.5
0.1
1
meter
HORIZONTAL

SLIDER
1314
500
1542
533
destination-reached-radius
destination-reached-radius
0
10
3.5
0.1
1
NIL
HORIZONTAL

SLIDER
1262
444
1434
477
wall-force-radius
wall-force-radius
0
10
1.0
.1
1
NIL
HORIZONTAL

SWITCH
1076
125
1246
158
continuous-birth?
continuous-birth?
0
1
-1000

SLIDER
1242
86
1468
119
birth-tick-period
birth-tick-period
0.5
200
3.5
1
1
seconds
HORIZONTAL

SLIDER
1143
86
1235
119
c-birth-nb
c-birth-nb
1
50
1.0
1
1
NIL
HORIZONTAL

SWITCH
1074
761
1274
794
show-decision-points?
show-decision-points?
1
1
-1000

SWITCH
1190
719
1326
752
show-paths?
show-paths?
1
1
-1000

SWITCH
1075
801
1253
834
show-turtle-labels?
show-turtle-labels?
1
1
-1000

SWITCH
1282
761
1443
794
show-dp-labels?
show-dp-labels?
1
1
-1000

TEXTBOX
1072
10
1222
38
-- Environment --\n\n
11
0.0
1

TEXTBOX
1072
697
1222
715
-- Debugging --\n
11
0.0
1

TEXTBOX
1073
202
1281
230
-- Agent base movement --\n
11
0.0
1

TEXTBOX
1074
261
1224
289
-- Path generation --\n\n
11
0.0
1

TEXTBOX
1072
423
1222
441
-- (Social) Forces --\n
11
0.0
1

TEXTBOX
1073
483
1323
511
-- Proximity decison-points --\n
11
0.0
1

TEXTBOX
1074
540
1224
558
-- Evaluation --\n
11
0.0
1

TEXTBOX
1075
70
1225
88
-- Entry --
11
0.0
1

TEXTBOX
1075
318
1300
346
-- Mobile navigation algorithm --\n
11
0.0
1

SWITCH
1073
336
1237
369
include-sensors?
include-sensors?
0
1
-1000

SWITCH
1221
381
1340
414
expected?
expected?
0
1
-1000

SWITCH
1369
137
1496
170
open-gate?
open-gate?
0
1
-1000

SLIDER
1500
137
1728
170
open-gate-period
open-gate-period
1
1000
615.0
1
1
seconds
HORIZONTAL

SLIDER
1504
182
1676
215
passengers-nb
passengers-nb
10
100
88.0
1
1
NIL
HORIZONTAL

SLIDER
1618
445
1762
478
wall-force-weight
wall-force-weight
0.0
2.0
1.0
.1
1
NIL
HORIZONTAL

SWITCH
1268
801
1484
834
performance-debugging?
performance-debugging?
1
1
-1000

SWITCH
1607
773
1723
806
visualize?
visualize?
0
1
-1000

SWITCH
1074
28
1264
61
airport-environment?
airport-environment?
0
1
-1000

SLIDER
1359
383
1517
416
expected-weight
expected-weight
0
1
0.4
.1
1
NIL
HORIZONTAL

SLIDER
1498
560
1670
593
keeping-sd-rate
keeping-sd-rate
0
100
30.0
10
1
%
HORIZONTAL

MONITOR
1261
652
1420
697
NIL
critical-contacts-nb / 2
17
1
11

SLIDER
1259
557
1456
590
critical-period
critical-period
0
100
47.0
1
1
seconds
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

ambulance
false
0
Rectangle -7500403 true true 30 90 210 195
Polygon -7500403 true true 296 190 296 150 259 134 244 104 210 105 210 190
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Circle -16777216 true false 69 174 42
Rectangle -1 true false 288 158 297 173
Rectangle -1184463 true false 289 180 298 172
Rectangle -2674135 true false 29 151 298 158
Line -16777216 false 210 90 210 195
Rectangle -16777216 true false 83 116 128 133
Rectangle -16777216 true false 153 111 176 134
Line -7500403 true 165 105 165 135
Rectangle -7500403 true true 14 186 33 195
Line -13345367 false 45 135 75 120
Line -13345367 false 75 135 45 120
Line -13345367 false 60 112 60 142

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

computer server
false
0
Rectangle -7500403 true true 75 30 225 270
Line -16777216 false 210 30 210 195
Line -16777216 false 90 30 90 195
Line -16777216 false 90 195 210 195
Rectangle -10899396 true false 184 34 200 40
Rectangle -10899396 true false 184 47 200 53
Rectangle -10899396 true false 184 63 200 69
Line -16777216 false 90 210 90 255
Line -16777216 false 105 210 105 255
Line -16777216 false 120 210 120 255
Line -16777216 false 135 210 135 255
Line -16777216 false 165 210 165 255
Line -16777216 false 180 210 180 255
Line -16777216 false 195 210 195 255
Line -16777216 false 210 210 210 255
Rectangle -7500403 true true 84 232 219 236
Rectangle -16777216 false false 101 172 112 184

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

person business
false
0
Rectangle -1 true false 120 90 180 180
Polygon -13345367 true false 135 90 150 105 135 180 150 195 165 180 150 105 165 90
Polygon -7500403 true true 120 90 105 90 60 195 90 210 116 154 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 183 153 210 210 240 195 195 90 180 90 150 165
Circle -7500403 true true 110 5 80
Rectangle -7500403 true true 127 76 172 91
Line -16777216 false 172 90 161 94
Line -16777216 false 128 90 139 94
Polygon -13345367 true false 195 225 195 300 270 270 270 195
Rectangle -13791810 true false 180 225 195 300
Polygon -14835848 true false 180 226 195 226 270 196 255 196
Polygon -13345367 true false 209 202 209 216 244 202 243 188
Line -16777216 false 180 90 150 165
Line -16777216 false 120 90 150 165

person doctor
false
0
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Polygon -13345367 true false 135 90 150 105 135 135 150 150 165 135 150 105 165 90
Polygon -7500403 true true 105 90 60 195 90 210 135 105
Polygon -7500403 true true 195 90 240 195 210 210 165 105
Circle -7500403 true true 110 5 80
Rectangle -7500403 true true 127 79 172 94
Polygon -1 true false 105 90 60 195 90 210 114 156 120 195 90 270 210 270 180 195 186 155 210 210 240 195 195 90 165 90 150 150 135 90
Line -16777216 false 150 148 150 270
Line -16777216 false 196 90 151 149
Line -16777216 false 104 90 149 149
Circle -1 true false 180 0 30
Line -16777216 false 180 15 120 15
Line -16777216 false 150 195 165 195
Line -16777216 false 150 240 165 240
Line -16777216 false 150 150 165 150

person police
false
0
Polygon -1 true false 124 91 150 165 178 91
Polygon -13345367 true false 134 91 149 106 134 181 149 196 164 181 149 106 164 91
Polygon -13345367 true false 180 195 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285
Polygon -13345367 true false 120 90 105 90 60 195 90 210 116 158 120 195 180 195 184 158 210 210 240 195 195 90 180 90 165 105 150 165 135 105 120 90
Rectangle -7500403 true true 123 76 176 92
Circle -7500403 true true 110 5 80
Polygon -13345367 true false 150 26 110 41 97 29 137 -1 158 6 185 0 201 6 196 23 204 34 180 33
Line -13345367 false 121 90 194 90
Line -16777216 false 148 143 150 196
Rectangle -16777216 true false 116 186 182 198
Rectangle -16777216 true false 109 183 124 227
Rectangle -16777216 true false 176 183 195 205
Circle -1 true false 152 143 9
Circle -1 true false 152 166 9
Polygon -1184463 true false 172 112 191 112 185 133 179 133
Polygon -1184463 true false 175 6 194 6 189 21 180 21
Line -1184463 false 149 24 197 24
Rectangle -16777216 true false 101 177 122 187
Rectangle -16777216 true false 179 164 183 186

person soldier
false
0
Rectangle -7500403 true true 127 79 172 94
Polygon -10899396 true false 105 90 60 195 90 210 135 105
Polygon -10899396 true false 195 90 240 195 210 210 165 105
Circle -7500403 true true 110 5 80
Polygon -10899396 true false 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Polygon -6459832 true false 120 90 105 90 180 195 180 165
Line -6459832 false 109 105 139 105
Line -6459832 false 122 125 151 117
Line -6459832 false 137 143 159 134
Line -6459832 false 158 179 181 158
Line -6459832 false 146 160 169 146
Rectangle -6459832 true false 120 193 180 201
Polygon -6459832 true false 122 4 107 16 102 39 105 53 148 34 192 27 189 17 172 2 145 0
Polygon -16777216 true false 183 90 240 15 247 22 193 90
Rectangle -6459832 true false 114 187 128 208
Rectangle -6459832 true false 177 187 191 208

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
NetLogo 6.0.4
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
