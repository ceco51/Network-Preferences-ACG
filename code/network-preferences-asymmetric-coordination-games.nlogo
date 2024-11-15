extensions [nw]

turtles-own [
  innate-color-preference ;initial exogenous color preference (l_{i}), remains unchanged during simulations
  individual-cost ;Exogenous d_{i}^{*}, determining agent-specific entry and total network formation costs; remains unchanged during simulations
  utility ;current utility level (Equation 1 of the manuscript)
  potential-utility ;attribute used to store potential utility changes when considering to add or remove a tie
  paired-agent ;attribute used to store agent j of randomly selected pair ij; storing agent j makes the code less redundant and more "Netlogish"
]

to setup
  clear-all
  reset-ticks ;start tick counter
end

to create-agents
  create-turtles N [
    set label who
    set-innate-color-preferences
    set color innate-color-preference ;at t = 0, color (i.e., a_{i}^{t=0}) is set to l_{i} i.e., exogenous color preference
  ]                                   ;Note that a_{i}^{t} is signalled by color of turtles
  set-individual-cost
end

;half agents will prefer blue, half will prefer yellow ;as d_{i}^{*} is randomly distributed, no correlation between d_{i}^{*} and color preference
to set-innate-color-preferences
  ifelse who <= (N / 2) - 1
  [set innate-color-preference 45] ;yellow (l_{i} = 0 in the manuscript)
  [set innate-color-preference 85] ;blue   (l_{i} = 1 in the manuscript)
end

to set-individual-cost
  let low-entry-costs-agents n-of number-low-entry-costs turtles ;reading number-low-entry-costs from the interface slider
  let high-entry-costs-agents turtles with [not member? self low-entry-costs-agents]
  ask low-entry-costs-agents [
    set individual-cost 1 + random (max-costs-low - 1) ;between 1 and max-costs-low. In the manuscript, between 1 and 5
    set shape "circle"
    set size sqrt individual-cost
  ]
  ask high-entry-costs-agents [
    set individual-cost min-costs-high + random (max-costs-high - min-costs-high) ;between min-costs-high and max-costs-high. In the manuscript, 7 and 10
    set shape "square"
    set size sqrt (0.4 * individual-cost)
  ]
end ;in this procedure and in the interface, "low" refers to L-agents, and "high" to H-agents

to go
  clear-turtles ;see "Info" tab (i.e., the Documentation) for an explanation on why this is needed
  create-agents
  repeat 3000 [iteration-step]
  tick
  if ticks >= 1000 [stop]
end

to iteration-step ;inspired by Jackson and Watts (2002) ;for each iteration-step, we change at most one tie and one color
  optimize-network ;randomly select a pair _ij_ and decide whether to add or sever it
  choose-color     ;randomòy select an agent and give it the opportunity to change color (i.e., a_{i}^{t}) by best-responding to neighbors
  apply-spring-layout ;visualization ;if display? switch in the GUI is set to "off", no visualization is provided
end

to optimize-network
  ask one-of turtles [ ;pick i
    set paired-agent one-of other turtles ;pick j, store it in paired-agent attribute ;"other turtles" ensures j != i
    adjust-utilities ;To obtain results outlined in Section 7 of the SM (no adjustment), simply comment-out this line
    ifelse link-neighbor? paired-agent ;if ij was present in g^{t-1}
    [consider-to-remove]
    [consider-to-add]
  ]
end

to adjust-utilities ;before potential-utility calculations, which will tell us the new levels of u_{i} and u_{j} from adding or severing ij
  if count link-neighbors != 0  [set utility compute-network-utility + fictitious-play-acg] ;only if not isolates
  if count [link-neighbors] of paired-agent != 0 [
    ask paired-agent [
      set utility compute-network-utility + fictitious-play-acg
    ]
  ]
end

to consider-to-remove
  ask link who [who] of paired-agent [die] ;actually remove ij (otherwise, we cannot compute potentialy utility of this move)
  compute-new-utility ;compute potential utility on g^{t-1} - ij
  ifelse stability-met-remove? ;is stability condition met? (Jackson and Watts, 2002; see manuscript for details)
  [update-utility] ;if so, set utility to potential-utility for both i and j
  [create-link-with paired-agent] ;if not, do not update utility and re-add ij i.e., g^{t} will be identical to g^{t-1}. Both i and j didn't find convenient to remove ij
end

to consider-to-add
  create-link-with paired-agent ;add ij (opposite logic of "consider-to-remove" procedure)
  compute-new-utility ;compute potential utility on g^{t-1} + ij
  ifelse stability-met-add?
  [update-utility]
  [ask link who [who] of paired-agent [die]] ;re-remove ij. Both i and j didn't finf convenient to add ij
end

to compute-new-utility
  set potential-utility compute-network-utility + fictitious-play-acg ;compute new utility from combination of network and coordination (acg = asymm. coord. game) preferences for i
  ask paired-agent [ ;compute new utility from combination of network and coordination (acg) preferences for paired-agent j
    set potential-utility compute-network-utility + fictitious-play-acg
  ]
end

to update-utility ;called only if stability-conditions are met
  set utility potential-utility
  ask paired-agent [
    set utility potential-utility
  ]
end

;for stability conditions, see Jackson and Watts (2002), footnote 8, p. 274. The full reference is in the manuscript
;however, in our case we do not randomly reverse the decision
to-report stability-met-add? ;in case we are considering to add ij
  report (potential-utility > utility and [potential-utility] of paired-agent >= [utility] of paired-agent) or
  (potential-utility >= utility and [potential-utility] of paired-agent > [utility] of paired-agent)
end

to-report stability-met-remove? ;in case we are considering to remove ij
  report (potential-utility > utility) or ([potential-utility] of paired-agent > [utility] of paired-agent)
end

to-report compute-network-utility ;executed in a turtle context (by both i and j) ;compute cost term and network-related preferences of utility function (see main manuscript)
  let my-degree count my-links ;compute current degree
  let neighbors-degree [count my-links] of link-neighbors ;compute degree of every neighbor ;store these values as a list
  let neigh-degree-diff sum (map - neighbors-degree n-values length neighbors-degree [my-degree]) ;compute aggregate degree difference ;it's a scalar
  let delta max (list neigh-degree-diff 0) ;see if "neigh-degree-diff" is positive
  report beta * delta - (alpha * abs(my-degree - individual-cost))
end

to-report fictitious-play-acg ;executed in a turtle context (by both i and j) ;play acg with prospective neighbors ("what would happen if I add/remove link with/to j?")
  let same link-neighbors with [color = [innate-color-preference] of myself] ;neighbors playing my preferred color (e.g., yellow in Figure1 of manuscript)
  let diff link-neighbors with [not member? self same] ;neighbors playing the other color (e.g., blue in Figure1 of manuscript)
  let utility-same 2 * count same ;I would gain 2 for every interaction with neighbors playing the preferred color (potential outcome for playing preferred color)
  let utility-diff count diff ;I would gain 1 by playing blue with every neighbor playing blue (potential outcome for playing least preferred color)
  report max (list utility-same utility-diff) ;best-response of fictitious play (here, no-one changes colors yet)
end

to choose-color
  ask one-of turtles [
    ifelse count link-neighbors != 0  [ ;if not isolate
      let same link-neighbors with [color = [innate-color-preference] of myself]
      let diff link-neighbors with [not member? self same]
      let utility-same 2 * count same
      let utility-diff count diff
      ifelse utility-diff > utility-same ;if utility-diff = utility-equal keep the preferred-color choice
      [set color [color] of one-of diff] ;play actually blue if my preference is yellow, hence I need to signal this to others by chaging my color
      [set color innate-color-preference] ;Else, keep my innate color or re-set it in case I previously played the other one
      set utility max (list utility-diff utility-same) + compute-network-utility
    ]
    [ ;if an isolate
      ifelse random-float 1 < epsilon
      [set color ifelse-value innate-color-preference = 85 [45][85]] ;switch a_{i} to least favorite l_{i}, with probability epsilon
      [set color innate-color-preference] ;keep a_{i} concordant with l_{i} or re-set a_{i} concordant with l_{i} if I am still an isolate and I previously changed a_{i}
    ]
  ]
end

to apply-spring-layout
  if display? [spring-layout] ;set display? off to achieve computational speed-ups (especially when running BehaviorSpace)
end

to spring-layout
  repeat 100 [layout-spring turtles links 0.9 10 2]
  ask links [
    set thickness 0.2
  ]
end

;;;;;Reporters measuring social coordination and network metrics;;;;;

;Reporters are activated when "tick" is called in "go" procedure. "tick" is called when "iteration-step" is in equilibrium

;Social coordination metrics
to-report color-unanimity? ;reports true or false
  report all? turtles [color = 45] or all? turtles [color = 85]
end

to-report unanimity? ;converts true/false in 1 or 0
  report ifelse-value color-unanimity? [1][0]
end

;a group might not achive unanimity, but it might have a clear color majority (e.g., 18 yellow and 2 blue if N = 20)
;Here, we compute the fraction of agents playing yellow and the fraction playing blue in equilibrium. We then report the max between the two.
;At the beginning of every simulation, by design this is always these fractions are always 0.5 (half yellow, half blue)
;0.5 is also the minimum value we can report in "color-prevalence" reporter
to-report color-prevalence
  let prob-yellow count turtles with [color = 45] / count turtles
  let prob-blue count turtles with [color = 85] / count turtles
  report max (list prob-yellow prob-blue)
end

;network metrics (networks are undirected)
to-report density
  report (2 * count links) / (count turtles * (count turtles - 1))
end

to-report no-components
  report length nw:weak-component-clusters
end

to-report median-local-clustering
  report median [nw:clustering-coefficient] of turtles
end

to-report modularity-color ;computed only when the final network has 10 components or less ;to have a stable metric
  report ifelse-value no-components <= 10 [nw:modularity (list (turtles with [color = 45]) (turtles with [color = 85]))]["NaN"]
end

to-report modularity-pref ;computed only when the final network has 10 components or less ;to have a stable metric
  report ifelse-value no-components <= 10 [nw:modularity (list (turtles with [innate-color-preference = 45]) (turtles with [innate-color-preference = 85]))]["NaN"]
end

to-report variance-deg-distr
  report variance [count my-links] of turtles
end

;total utility (or "welfare") is used to check convergence
to-report welfare
  report sum [utility] of turtles
end
@#$#@#$#@
GRAPHICS-WINDOW
459
10
896
448
-1
-1
13.0
1
10
1
1
1
0
0
0
1
-16
16
-16
16
0
0
1
ticks
30.0

BUTTON
23
37
86
70
setup
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
93
38
156
71
go
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

TEXTBOX
25
17
175
35
#Main Procedures
11
0.0
1

INPUTBOX
27
112
77
172
N
20.0
1
0
Number

INPUTBOX
88
113
145
173
alpha
1.75
1
0
Number

INPUTBOX
155
113
205
173
beta
1.4
1
0
Number

TEXTBOX
29
93
179
111
#Input parameters
11
0.0
1

SLIDER
215
126
432
159
number-low-entry-costs
number-low-entry-costs
1
N - 1
16.0
1
1
agents
HORIZONTAL

INPUTBOX
28
188
112
248
max-costs-low
5.0
1
0
Number

INPUTBOX
115
188
196
248
min-costs-high
7.0
1
0
Number

INPUTBOX
202
188
288
248
max-costs-high
10.0
1
0
Number

SWITCH
319
42
422
75
display?
display?
1
1
-1000

MONITOR
915
46
972
91
density
density
3
1
11

MONITOR
911
156
993
201
median-clust
median-local-clustering
3
1
11

MONITOR
912
207
1010
252
no-components
no-components
3
1
11

TEXTBOX
921
16
1071
34
#Emerging Network Metrics
11
0.0
1

MONITOR
981
47
1066
92
unanimity?
unanimity?
3
1
11

MONITOR
913
101
1006
146
modularity-adj
ifelse-value no-components <= 10 [nw:modularity (list (turtles with [ color = 45 ]) (turtles with [ color = 85 ]))][\"NaN\"]
3
1
11

MONITOR
1018
210
1075
255
welfare
sum [utility] of turtles
3
1
11

PLOT
231
271
431
421
Welfare TS
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
"default" 1.0 0 -16777216 true "" "plot sum [utility] of turtles"

PLOT
1028
267
1330
417
Some Metrics
NIL
NIL
0.0
10.0
0.0
1.0
true
true
"" ""
PENS
"Segregation" 1.0 0 -13791810 true "" "plot ifelse-value ticks >= 1 [modularity-color][1]"
"Clustering" 1.0 0 -12087248 true "" "plot ifelse-value ticks >= 1 [median-local-clustering][1]"
"Link-Loners" 1.0 0 -2674135 true "" "plot ifelse-value ticks >= 1 [(sum [count my-links] of turtles with [ individual-cost < min-costs-high ]) / (2 * count links)][1]"

MONITOR
1016
102
1087
147
modularity
nw:modularity (list (turtles with [ color = 45 ]) (turtles with [ color = 85 ]))
3
1
11

MONITOR
912
257
1005
302
prop-links-loners
(sum [count my-links] of turtles with [ individual-cost < min-costs-high ]) / (2 * count links)
3
1
11

PLOT
17
270
217
420
Coordination?
NIL
NIL
0.0
10.0
0.0
1.0
true
false
"" ""
PENS
"unanimity?" 1.0 0 -16777216 true "" "plot unanimity?"

TEXTBOX
321
24
471
42
#Visualization?
11
0.0
1

MONITOR
911
312
1021
357
modularity-innate
ifelse-value no-components <= 10 [nw:modularity (list (turtles with [ innate-color-preference = 45 ]) (turtles with [ innate-color-preference = 85 ]))][1]
3
1
11

MONITOR
911
364
1025
409
NIL
variance-deg-distr
3
1
11

MONITOR
998
157
1096
202
modularity-pref
ifelse-value no-components <= 10 [nw:modularity (list (turtles with [ innate-color-preference = 45 ]) (turtles with [ innate-color-preference = 85 ]))][\"NaN\"]
3
1
11

INPUTBOX
294
189
353
249
epsilon
0.2
1
0
Number

MONITOR
910
417
1015
462
NIL
color-prevalence
3
1
11

@#$#@#$#@
## WHAT IS IT?

In this model, the emphasis is on understanding the complex dynamics of coordination and the resulting network structures that arise as a population of N self-interested agents optimize a utility function that encompasses both coordination payoffs and network-based preferences.

Turtles in our model represent utility-maximizing agents, serving as versatile entities that can represent various real-world actors such as individuals, firms, or states.


Turtles possess several attributes:

* `innate-color-preference` (denoted as _l_<sub>_i_</sub> in the main manuscript), which stores the exogenous color preference of each agent, either yellow (_l_<sub>_i_</sub>_= 0_) or blue (_l_<sub>_i_</sub>_= 1_). It remains unchanged during iterations;

* `individual-cost` (denoted as _d_<sub>_i_</sub><sup>*</sup> in the main manuscript), which represents the agent-specific parameter determining entry and total network formation costs. It remains unchanged as well;

* `utility` (calculated following Equation 1 of the manuscript), which stores the current utility level;

* `potential-utility`, which stores the prospective utility when contemplating the addition or removal of a tie; it calls Equation 1 of the manuscript as well;

* `paired-agent`, which is used to store the identity of agent _j_ in a randomly selected pair _ij_, contributing to more efficient and less redundant NetLogo code.


## HOW IT WORKS

The initial procedure that gets called is `setup`, which performs tasks such as clearing all and resetting the tick counter to zero.

Regarding the `go` procedure, its logic and scheduling are explained as follows.
 
In each call of the `go` procedure, turtles and their links are first cleared, excluding the tick counter and plots, and then recreated by calling the `create-agents` procedure. Although this might seem redundant, it is essential for concurrently executing multiple calls.

Indeed, each `go` call executes the main algorithm of the model for a specific parameter combination only, such as `N = 20`, `max-costs-low = 5`, `min-costs-high = 7`, `max-costs-high = 10`, `alpha = 1.25`, `beta = 1`, `epsilon = 0.20`, `number-low-entry-costs = 3` (the green input widgets and sliders in the GUI). With a specific parameter combination in place, `iteration-step` is repeated 3000 times consecutively. `iteration-step` encapsulates game dynamics, as detailed in Section 2.3 of the main manuscript (see also Jackson and Watts, 2002). Initially, the `optimize-network` procedure is called, assessing whether to add or sever a randomly selected tie _ij_. `optimize-network` is designed in a modular fashion. Subsequently, `choose-color` is called, giving a random agent the opportunity to adjust its color choices in response to past neighbors' choices following a best-response dynamics. Visual adjustments to the network are then made. 

The choice of 3000 repetitions ensures the attainment of equilibrium for the parameter combinations presented in the main manuscript, starting from an empty network. In essence, the use of 3000 repetitions approximates the long-run behavior of the model. While the user has the flexibility to introduce a stopping condition to check for equilibrium (see **STOPPING-CONDITION** Section), this has been omitted here to enhance computational efficiency and maintain code readability. It is important to emphasize that 3000 repetitions extend well beyond the typical point (number of ticks) at which total welfare (i.e., the sum of individual utilities) stabilizes and networks cease to undergoe tie changes.

After repeating `iteration-step` 3000 times and reaching equilibrium, `tick` is called, activating reporters to save and/or plot network metrics and coordination at the last iteration (equilibrium) for a specific parameter combination. These metrics are not commented here as they are straightforward. The number of ticks corresponds to parallel runs of the model with the same parameters. For example, `go` is called 1000 times for a given parameter combination (`if ticks >= 1000 [stop]`). Consequently, there will be 1000 ticks – 1000 "parallel" calls of `iteration-step` for the same initial parameter combination (e.g., `number-low-entry-costs = 5`, `alpha = 1.25`, `beta = 1`, etc.).

This explains why agents need to be cleared and recreated at each tick. Since each `go` call corresponds to a specific parameter combination, and each `tick` represents a parallel execution of the model under the same parameters, each `tick` explores the same parameters with different agents (e.g., different distributions of _d_<sub>i</sub><sup>*</sup>, once the number of _LH_ and _m_ agents and bounds are fixed; see the main manuscript).

Next, in the **BREAK-DOWN OF `go` PROCEDURE** section, we delve into a detailed analysis of the crucial procedures embedded in our NetLogo code.

## BREAK-DOWN OF `go` PROCEDURE

Let's start when `ticks` is 0. 

First call.

```
to go
  clear-turtles
  create-agents
  ;;; [...continues...] ;;;
end
```

We initiate the process by clearing both turtles and links. Subsequently, we proceed to create agents (refer to Procedure CRT). Specifically, we generate _N_ agents, obtaining the value of _N_ from the input widget in the GUI. Graphics operations, such as `set label who`, are executed, and the procedure `set-innate-color-preferences` is called (see Procedure SET-COLOR below). The name perfectly describes its functioning, and accordingly, we assign preferences for yellow to _N/2_ agents and preferences for blue to the remaining _N/2_ agents. It is essential to note that the first _N/2_ agents, based on their who number, are designated a preference for yellow, while the others are assigned a preference for blue. Note that this allocation rule does not introduce hidden correlations between who, color preferences, and `individual-cost`, as `individual-cost` is randomly distributed (see Procedure SET-INDIVIDUAL-COSTS below).

```
;Procedure CRT
to create-agents
  create-turtles N [
    set label who
    set-innate-color-preferences
    set color innate-color-preference 
  ]
  set-individual-cost
end
```

```
;Procedure SET-COLOR
to set-innate-color-preferences
  ifelse who <= (N / 2) - 1
  [set innate-color-preference 45]
  [set innate-color-preference 85]
end
```

The parameter `number-low-entry-costs`, obtained from an input slider in the GUI with a range from 1 to _N_ - 1, determines the amount of _L_ agents in the group. These _L_ agents are assigned a random `who` number through the code lines `let low-entry-costs-agents n-of number-low-entry-costs turtles` and then `ask low-entry-costs-agents [...]`. Consequently, _H_ agents also receive a random `who` number.


_L_ agents set their _d_<sub>i</sub><sup>*</sup> i.e., `individual-cost` to a number extracted randomly from a uniform distribution with bounds between 1 and `max-costs-low` (5 in the main manuscript for N = 20). A similar procedure is carried out for _H_ agents, but now with different bounds for the uniform distribution (in the manuscript, `min-costs-high` is set to 7, while `max-costs-high` to 10 for N = 20). 


```
;Procedure INDIVIDUAL-COSTS
ìto set-individual-cost
  let low-entry-costs-agents n-of number-low-entry-costs turtles 
  let high-entry-costs-agents turtles with [not member? self low-entry-costs-agents]
  ask low-entry-costs-agents [
    set individual-cost 1 + random (max-costs-low - 1)
    set shape "circle"
    set size sqrt individual-cost
  ]
  ask high-entry-costs-agents [
    set individual-cost min-costs-high + random (max-costs-high - min-costs-high)
    set shape "square"
    set size sqrt (0.4 * individual-cost)
  ]
end
```

Going back to our `go`, we are now ready to call for 3000 times in a row the main procedure i.e., `iteration-step` (see Procedure MAIN).


```
to go
  clear-turtles
  create-agents
  repeat 3000 [iteration-step]
  ;;; [...continues...] ;;
end
```
`iteration-step` was inspired by Jackson and Watts (2002). For each of the 3000 repetitions, a random couple _ij_ is selected, and they decide to either add or sever _ij_ depending on whether _ij_ belonged to _g_<sup>_t_-1</sup> or not (see Procedure NET). Subsequently, a random agent is selected and given the opportunity to change its color choices, by best responding to the last colors played by neighbors. This is accomplished by `choose-color`.

```
;Procedure MAIN
to iteration-step 
  optimize-network
  choose-color
  apply-spring-layout ;visualization
end
```

_ij_ is selected as follows. A random agent is chosen using `ask one-of turtles [...]`. Let's designate this agent as _i_. As previously mentioned, agent _j_ is stored in the `paired-agent` attribute of _i_. _j_ is randomly selected as well. The `adjust-utilities` procedure is executed to address potential changes resulting from interactions in past iterations, which could have influenced the degrees of neighbors of both agent _i_ and _j_. For instance, _k_, a neighbor of _i_, may have formed three new links while _i_ remained inactive. The objective of the `adjust-utilities` procedure (see ;Procedure ADJUST) is to ensure that network formation decisions consider the most recent utility calculations derived from the updated network neighborhoods of both _i_ and _j_. Subsequently, `consider-to-remove` is called if _ij_ is already existing in the current state of the network, whereas `consider-to-add` is called if _i_ and _j_ are not link-neighbors in the current network configuration. We only show the logic behind the decision to remove _ij_ in Procedure NET-REMOVE,  with the understanding that `consider-to-add` operates in the exactly opposite manner. However, it's essential to note that the stability conditions differ between these two procedures (refer to the main manuscript and Jackson and Watts, 2002).


```
;Procedure NET
to optimize-network
  ask one-of turtles [ ;pick i
    set paired-agent one-of other turtles ;pick j, store it in paired-agent attribute
    adjust-utilities
    ifelse link-neighbor? paired-agent ;if ij was present in g^{t-1}
    [consider-to-remove]
    [consider-to-add]
  ]
end
```

```
;Procedure ADJUST
to adjust-utilities
  if count link-neighbors != 0  [set utility compute-network-utility + fictitious-play-acg]
  if count [link-neighbors] of paired-agent != 0 [
    ask paired-agent [
      set utility compute-network-utility + fictitious-play-acg
    ]
  ]
end
```

To evaluate the potential benefit of removing link _ij_ for either agent _i_ or _j_ (refer to the stability condition outlined in Procedure STABILITY-REMOVE, to the main manuscript and to Jackson and Watts, 2002), the link _ij_ needs to actually be removed. The resulting change in utility on this modified network is then computed by calling `compute-new-utility`, which assigns a value to the `potential-utility` attribute. If the stability condition holds, meaning the `potential-utility` resulting from the removal of _ij_ for either _i_ or _j_ is strictly greater than the current and adjusted utility stored in the `utility` attribute, the network modification is retained. Utilities are consequently updated by setting `utility` to the computed `potential-utility`. It's crucial to highlight that this updating process is carried out for both _i_ and _j_ since the network has undergone a change, necessitating the adjustment of utilities. In case the `potential-utility` resulting from removing _ij_ is lower or equal than `utility` for both _i_ and _j_, `utility` is not updated and the _ij_ link is re-added to the network. Therefore, if the condition in Procedure STABILITY-REMOVE is not met (i.e., it outputs `false`), then the network and utilities of both _i_ and _j_ remain unchanged.

```
;Procedure NET-REMOVE
to consider-to-remove
  ask link who [who] of paired-agent [die]
  compute-new-utility
  ifelse stability-met-remove? 
  [update-utility]
  [create-link-with paired-agent]
end

```

```
;Procedure STABILITY-REMOVE
to-report stability-met-remove?
  report (potential-utility > utility) or 
         ([potential-utility] of paired-agent > [utility] of paired-agent)
end

```

When a random agent is presented with the opportunity to alter its color choices, the `choose-color` procedure governs its decision-making process (see the Procedure CHOOSE-COL below).

If the chosen agent is not an isolate (i.e.,`count link-neighbors` is not 0), it first identifies neighbors playing its preferred color (`let same link-neighbors with [color = [innate-color-preference] of myself]`) and those playing the least preferred color (`diff`). The utility that the agent would derive from selecting the preferred color is computed as 2 times the count of neighbors playing the preferred color (`utility-same`). Conversely, the utility from opting for the least preferred color is calculated as 1 times the count of neighbors playing the least preferred color, which is simply `count diff` (`utility-diff`). If the utility from choosing the least preferred color (`utility-diff`) is strictly greater than the utility of selecting the preferred color (`utility-same`), the agent adopts the least preferred color and communicates this change to others by updating the `color` attribute. Otherwise, it maintains its initial color choice. `utility` is then updated, including the recomputation of the cost and network-preferences terms (refer to Equation 1 in the main manuscript). Further details can be found in Zhao et al. (2008), with the full reference available in the main manuscript.

Note that `utility-same` and `utility-diff` are local variables not turtles' attributes. Also note that `innate-color-preference` never changes and agents see only color choices and not the `innate-color-preference` of others.

If the randomly chosen agent is an isolate, there is a probability equal to `epsilon` (specified in the corresponding input widget in the GUI) that it will adopt the least preferred color. Additional information is provided in the main manuscript.

```
;Procedure CHOOSE-COL
to choose-color
  ask one-of turtles [
    ifelse count link-neighbors != 0  [ ;if not isolate
      let same link-neighbors with [color = [innate-color-preference] of myself]
      let diff link-neighbors with [not member? self same]
      let utility-same 2 * count same
      let utility-diff count diff
      ifelse utility-diff > utility-same
      [set color [color] of one-of diff]
      [set color innate-color-preference]
      set utility max (list utility-diff utility-same) + compute-network-utility
    ]
    [ ;if an isolate
      ifelse random-float 1 < epsilon
      [set color ifelse-value innate-color-preference = 85 [45][85]]
      [set color innate-color-preference]
    ]
  ]
end

```

After the sub-procedures nested within `iteration-step` have been executed 3000 times, `go` proceeds to `tick`, activating reporters responsible for computing network and coordination metrics (refer to the main manuscript and NetLogo code). Subsequently, `go` checks whether the number of parallel executions with the same parameter combination has reached its limit, determined by examining whether `ticks` is greater than or equal to 1000. If `ticks >= 1000`, the exploration of our model with the current parameter combination is complete. We are then prepared to select another combination from `BehaviorSpace`, running it 1000 times in parallel, and repeating this process accordingly.

```
to go
  clear-turtles
  create-agents
  repeat 3000 [iteration-step]
  tick
  if ticks >= 1000 [stop]
end
```

If `ticks` has not exceeded 1000, the loop is repeated. This involves clearing turtles and links, initializing agents through the use of `set-innate-color-preferences` and `set-individual-cost` (with the **same** `max-costs-low`, `max-costs-high`, etc. parameters). Subsequently, `iteration-step` is called 3000 times for this newly initialized population. Due to the randomness in `set-individual-cost`, this new population operates under the same parameter combination but with different assignments of _L_ and _H_ agents, although the overall number of _L_ and _H_ agents remains constant.


## HOW TO USE IT

To execute a specific parameter combination, navigate to the GUI, adjust the desired parameters using the input widgets and sliders (the green widgets). After configuring the parameters, click on `setup` followed by `go` to generate results for the selected combination of parameters.

To conduct computational experiments with various parameter combinations, open `BehaviorSpace` (Ctrl+Maiusc+B or Tools --> `BehaviorSpace`) and define the desired values and intervals for the input widgets and sliders you wish to explore. For example, to investigate values of `alpha` from 1 to 3 in steps of 0.5, write `["alpha" 1 0.5 3]`. If exploring only a couple of values, write `["alpha" 1 3]`. NetLogo will systematically execute `setup` and then `go` for each unique combination of parameters derived from the intervals you have defined.

The code includes predefined examples of computational experiments, each named according to the scenarios outlined in the main manuscript and the Supplementary Material (SM). To access them, click on the desired experiment and then on `edit`. You will see how to specify parameters ranges and inserting the desired output metrics (network and coordination reporters, in our case).

## THINGS TO NOTICE

The entire code follows a modular structure, wherein each procedure is designed to execute a specific task. While this approach might slightly increase the "namespace" of the code i.e., the number of procedures, thus hurting a bit readability, it contributes to improved maintainability and facilitates future extensions.

## BREAK-DOWN OF `compute-network-utility` AND `fictitious-play-acg`

Procedures `compute-network-utility` and `fictitious-play-acg` play crucial roles in assessing the potential utility resulting from a change in the status of _ij_. As illustrated earlier, it's noteworthy that `compute-network-utility` is called also by `adjust-utilities` and `choose-color` procedures.

Let's start with `compute-network-utility`.

```
to-report compute-network-utility 
  let my-degree count my-links
  let neighbors-degree [count my-links] of link-neighbors 
  let neigh-degree-diff sum (map - neighbors-degree n-values length neighbors-degree [my-degree])
  let delta max (list neigh-degree-diff 0)
  report beta * delta - (alpha * abs(my-degree - individual-cost))
end
```

In its core functionality, `compute-network-utility` implements the cost and preferential attachment terms outlined in Equation 1 of the main manuscript. Initially, it calculates _d_<sub>_i_</sub>, representing the current agent's degree. Subsequently, it assesses _d_<sub>_j_</sub> for each neighbor _j_, and stores these values in a list named `neighbors-degree`. It then computes the sum of differences between each _d_<sub>_j_</sub> and _d_<sub>_i_</sub> (the preferential attachment term). This is done with a list operation `map -`, therefore requiring to repeat _d_<sub>_i_</sub> `length neighbors-degree` times. In the scenario where this sum is negative, `delta` is set to zero, consequently rendering `beta * delta` zero as well. The cost term is computed as `alpha * abs(my-degree -individual-cost)` and subtracted from the (eventual) preferential attachment term. Therefore, `compute-network-utility` can yield either a positive (if the preferential attachment term is greater than the costs component) or a negative number (when the preferential attachment term is either zero or not sufficiently big to offset the network formation costs).


The `fictitious-play-acg` procedure mirrors the operations of `choose-color`. The key distinction lies in the fact that, at this point in the process, the `color` attribute remains unchanged. Specifically, both _i_ and _j_ evaluate the utility that **would be realized** by best-responding to neighbors within the **hypothetical new neighborhood**. Essentially, they simulate the best-response scenario without implementing it, and the actual best-response occurs when they are selected in the subsequent `choose-color` procedure.

```
to-report fictitious-play-acg 
  let same link-neighbors with [color = [innate-color-preference] of myself] 
  let diff link-neighbors with [not member? self same]
  let utility-same 2 * count same
  let utility-diff count diff
  report max (list utility-same utility-diff)
end

```

## VISUALIZATION 

In the GUI, there is a switch called "display?". When set to "off", all turtles (agents) appear at the origin of the NetLogo world. To view the actual network formation, switch "display?" to "on". 

It is recommended to conduct experiments with "display?" set to "off" to save computational time by not rendering the network formation process.

## STOPPING-CONDITION

In this section, we illustrate an example of a stopping condition that can be implemented.
 
Consider the agent's utility as a reflection of its overall satisfaction with color and network choices. Total welfare, the sum of individual utilities, provides insight into group-level satisfaction with the current configuration of play, encompassing color choices and network ties. When an agent can no longer benefit from changing color or ties, its utility becomes constant over iterations (e.g., refer to Bojanowski and Buskens, 2011). If all agents reach this state, total welfare will exhibit a flat trend as iterations progresses, signifying equilibrium has been reached. Monitoring the stabilization of total welfare over a sufficiently long period can serve as a practical stopping condition.

Implementing this in code involves an initial "burn-in" phase where `iteration-step` runs for a fixed number of iterations, for instance 2000. As N = 20, this means giving each agent an average 100 opportunities to be involved in `optimize-networks` and `choose-color`. This burn-in phase ensures that flat trends in total welfare represent global equilibrium rather than local optima. After the burn-in phase, a time series of total welfare (`sum [utilities] of turtles`) is computed and stored in a NetLogo list.

After 2000 iterations, the first element of the list will be the total welfare at the 2000th run of `iteration-step`. The second element will be the total welfare at the 2001th run `iteration-step`, and so on. If 100 consecutive values in this list are the same, the model stops. If 99 consecutive values are the same and the 100th is different, the model continues for at least another 100 iterations, and so on.

For the parameter combinations presented in the main manuscript and SM, this stopping condition effectively halted the model well before 3000 iterations. In the specific case where `epsilon = 0.10`, we ran it for 5000 iterations to ensure convergence, although 3000 iterations might have been sufficient.
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

circle-2
false
4
Circle -13345367 true false 30 30 300
Line -1184463 true 150 15 150 300
Rectangle -1184463 true true 60 45 150 270

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
NetLogo 6.3.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="alpha2.25" repetitions="1" sequentialRunOrder="false" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>unanimity?</metric>
    <metric>color-prevalence</metric>
    <metric>density</metric>
    <metric>no-components</metric>
    <metric>median-local-clustering</metric>
    <metric>modularity-color</metric>
    <metric>modularity-pref</metric>
    <metric>variance-deg-distr</metric>
    <metric>welfare</metric>
    <enumeratedValueSet variable="N">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="alpha">
      <value value="2.25"/>
    </enumeratedValueSet>
    <steppedValueSet variable="number-low-entry-costs" first="1" step="1" last="19"/>
    <enumeratedValueSet variable="beta">
      <value value="0.45"/>
      <value value="0.9"/>
      <value value="1.35"/>
      <value value="1.8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="epsilon">
      <value value="0.2"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="alpha1.75" repetitions="1" sequentialRunOrder="false" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>unanimity?</metric>
    <metric>color-prevalence</metric>
    <metric>density</metric>
    <metric>no-components</metric>
    <metric>median-local-clustering</metric>
    <metric>modularity-color</metric>
    <metric>modularity-pref</metric>
    <metric>variance-deg-distr</metric>
    <metric>welfare</metric>
    <enumeratedValueSet variable="N">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="alpha">
      <value value="1.75"/>
    </enumeratedValueSet>
    <steppedValueSet variable="number-low-entry-costs" first="1" step="1" last="19"/>
    <enumeratedValueSet variable="beta">
      <value value="0.35"/>
      <value value="0.7"/>
      <value value="1.05"/>
      <value value="1.4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="epsilon">
      <value value="0.2"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="alpha1.5" repetitions="1" sequentialRunOrder="false" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>unanimity?</metric>
    <metric>color-prevalence</metric>
    <metric>density</metric>
    <metric>no-components</metric>
    <metric>median-local-clustering</metric>
    <metric>modularity-color</metric>
    <metric>modularity-pref</metric>
    <metric>variance-deg-distr</metric>
    <metric>welfare</metric>
    <enumeratedValueSet variable="N">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="alpha">
      <value value="1.5"/>
    </enumeratedValueSet>
    <steppedValueSet variable="number-low-entry-costs" first="1" step="1" last="19"/>
    <enumeratedValueSet variable="beta">
      <value value="0.3"/>
      <value value="0.6"/>
      <value value="0.9"/>
      <value value="1.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="epsilon">
      <value value="0.2"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="alpha1.25" repetitions="1" sequentialRunOrder="false" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>unanimity?</metric>
    <metric>color-prevalence</metric>
    <metric>density</metric>
    <metric>no-components</metric>
    <metric>median-local-clustering</metric>
    <metric>modularity-color</metric>
    <metric>modularity-pref</metric>
    <metric>variance-deg-distr</metric>
    <metric>welfare</metric>
    <enumeratedValueSet variable="N">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="alpha">
      <value value="1.25"/>
    </enumeratedValueSet>
    <steppedValueSet variable="number-low-entry-costs" first="1" step="1" last="19"/>
    <enumeratedValueSet variable="beta">
      <value value="0.25"/>
      <value value="0.5"/>
      <value value="0.75"/>
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="epsilon">
      <value value="0.2"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="alpha0.75" repetitions="1" sequentialRunOrder="false" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>unanimity?</metric>
    <metric>color-prevalence</metric>
    <metric>density</metric>
    <metric>no-components</metric>
    <metric>median-local-clustering</metric>
    <metric>modularity-color</metric>
    <metric>modularity-pref</metric>
    <metric>variance-deg-distr</metric>
    <metric>welfare</metric>
    <enumeratedValueSet variable="N">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="alpha">
      <value value="0.75"/>
    </enumeratedValueSet>
    <steppedValueSet variable="number-low-entry-costs" first="1" step="1" last="19"/>
    <enumeratedValueSet variable="beta">
      <value value="0.15"/>
      <value value="0.3"/>
      <value value="0.45"/>
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="epsilon">
      <value value="0.2"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="alpha0.5" repetitions="1" sequentialRunOrder="false" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>unanimity?</metric>
    <metric>color-prevalence</metric>
    <metric>density</metric>
    <metric>no-components</metric>
    <metric>median-local-clustering</metric>
    <metric>modularity-color</metric>
    <metric>modularity-pref</metric>
    <metric>variance-deg-distr</metric>
    <metric>welfare</metric>
    <enumeratedValueSet variable="N">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="alpha">
      <value value="0.5"/>
    </enumeratedValueSet>
    <steppedValueSet variable="number-low-entry-costs" first="1" step="1" last="19"/>
    <enumeratedValueSet variable="beta">
      <value value="0.1"/>
      <value value="0.2"/>
      <value value="0.3"/>
      <value value="0.4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="epsilon">
      <value value="0.2"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="alpha0.25" repetitions="1" sequentialRunOrder="false" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>unanimity?</metric>
    <metric>color-prevalence</metric>
    <metric>density</metric>
    <metric>no-components</metric>
    <metric>median-local-clustering</metric>
    <metric>modularity-color</metric>
    <metric>modularity-pref</metric>
    <metric>variance-deg-distr</metric>
    <metric>welfare</metric>
    <enumeratedValueSet variable="N">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="alpha">
      <value value="0.25"/>
    </enumeratedValueSet>
    <steppedValueSet variable="number-low-entry-costs" first="1" step="1" last="19"/>
    <enumeratedValueSet variable="beta">
      <value value="0.05"/>
      <value value="0.1"/>
      <value value="0.15"/>
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="epsilon">
      <value value="0.2"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="alpha1.25-epsilon10" repetitions="1" sequentialRunOrder="false" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>unanimity?</metric>
    <metric>color-prevalence</metric>
    <metric>density</metric>
    <metric>no-components</metric>
    <metric>median-local-clustering</metric>
    <metric>modularity-color</metric>
    <metric>modularity-pref</metric>
    <metric>variance-deg-distr</metric>
    <metric>welfare</metric>
    <enumeratedValueSet variable="N">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="alpha">
      <value value="1.25"/>
    </enumeratedValueSet>
    <steppedValueSet variable="number-low-entry-costs" first="1" step="1" last="19"/>
    <enumeratedValueSet variable="beta">
      <value value="0.25"/>
      <value value="0.5"/>
      <value value="0.75"/>
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="epsilon">
      <value value="0.1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="N30-alpha0.75" repetitions="1" sequentialRunOrder="false" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>unanimity?</metric>
    <metric>color-prevalence</metric>
    <metric>density</metric>
    <metric>no-components</metric>
    <metric>median-local-clustering</metric>
    <metric>modularity-color</metric>
    <metric>modularity-pref</metric>
    <metric>variance-deg-distr</metric>
    <metric>welfare</metric>
    <enumeratedValueSet variable="N">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="alpha">
      <value value="0.75"/>
    </enumeratedValueSet>
    <steppedValueSet variable="number-low-entry-costs" first="1" step="1" last="29"/>
    <enumeratedValueSet variable="beta">
      <value value="0.15"/>
      <value value="0.3"/>
      <value value="0.45"/>
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="epsilon">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-costs-low">
      <value value="7"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="min-costs-high">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-costs-high">
      <value value="15"/>
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
