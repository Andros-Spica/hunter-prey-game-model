# Agent-Based Modeling of Traditional Bow-and-Arrow Hunting: A Simulation approach to Hunter and Prey Behavior
Repository for simulation models about traditional bow-and-arrow hunting, created within the framework of the [Modelling Prehistoric Hunting (MPJ) project](https://mpj.uni-koeln.de/).

# Design concepts

Agent-based modelling informed by empirical and ethnographic studies of traditional bow-and-arrow hunting with poisonous arrows.

Hunting phases: 
1. planning 
2. hunting bout – modes:  
   1. searching
   2. tracking
   3. spotting/approaching 
   4. pursuing 
   5. shooting 
3. retrieval and butchering/processing

Other practices affecting hunting and foraging success (Niche construction): 
* Fire management  
* Monitoring and managing key non-prey species, such as elephants and large predators

## The Hunting Bout

The Hunting bout concepts towards a model:

- Sequence of modes
- Often not linear (e.g., interrupted tracks, pursue not feasible, etc)
- Ends with: 
  - a successful shot, or
  - when hunters desist, considering success to be unlikely 
- Scale of seconds to hours, and metres to kilometres
The hunting bout contains phases from tracking to shooting, given that the sequence is often not a linear progression (e.g., tracking leads to dead ends, pursuit is not possible, etc.).
- Opposed goals: Hunters want to shoot and kill prey, and prey wants to escape hunters unharmed.
A hunting bout ends if there is a successful shot or when hunters desist, e.g., by considering that future shots will be unlikely. 
- The hunting bout develops in the scale of hours and metres.
- A complex game of presence, perception, stamina, speed, technology, and skill. The balance between the number of hunters for boosting perception and stealth to minimize the presence of the hunting party.
  - Hunters’ best outcome is approaching and shooting prey without first being detected.
  Prey’s best outcome is to detect hunters before they approach or to avoid detection altogether.
- Hunter and prey properties that modify (increase or decrease) presence (e.g., camouflage, stealth skill, body size, etc.), perception (e.g., sight and auditory capabilities), speed, and stamina (genetic potential and current health state).  
- Mechanisms:
  - Movement
    - Prey: default (non-alert), flee (alert)
    - Hunter: search, track, stealth approach, pursue, pause 
  - Line-of-sight
  - Sound propagation and detection 
  - Smell cloud and detection (only prey)  
- Hunter/prey properties
  - Height (proxy of presence, e.g., body weight, camouflage, stealth)
  - Speed (minimum and maximum)
  - Time to exhaustion (proxy of “stamina”, maximum VO2).
  - Reaction time (proxy of sensory and cognitive capabilities)
  - Group size increases both presence and perception (intrinsic trade-off)
  - Group composition/assets: tools and skills vary between and within hunting groups, giving a critical edge or disadvantage (e.g., tracking skills, stealth, strength of poison, quality of arrows, etc)
- Environmental conditions
  - Terrain morphology (elevation model)
  - Ground cover
  - Permeable obstacles (all vegetation)
  - Prey attractors (some vegetation, water sources, shade)
  - Prey repellers
  - Wind intensity and direction
  - Temperature
  - Overarching factors: ecological zones, seasons, fire management, key fauna (elephants, non-human predators, etc.)

## Planning, retrieving and butchering/processing

Planning and retrieving are the critical phases for cooperation and tool availability for hunting.

Group size impacts the probability of hunting success and the probability of retrieving complete and fresh prey once shot.

# Details

## Initialisation (`setup`)

Summary of steps:  
1. **`clear-all`**: Clears any existing data, resetting the simulation environment.

2. **`set-input`**: Calls another procedure that sets up simulation constants and parameters:

   - **`set-constants`**: Defines fixed values (like dimensions and perception ranges).

   - **`set-parameters`**: Sets various parameters, potentially randomizing some aspects to simulate variability in the environment and agents.

3. **Environment and Agent Initialization**:

   - **`setup-environment`**: Configures the environment, including obstacles and prey attraction sites.

   - **`setup-prey-groups`**: Creates groups of prey agents, assigning positions and attributes like speed and sight range.

   - **`setup-hunting-party`**: Sets up hunters with attributes like height, speed, and perception.

4. **Perceptions and Tracks**:

   - **`initialise-perceptions`**: Initializes each agent’s perception links to detect others (e.g., prey detecting hunters).

   - **`generate-recent-tracks`**: Generates tracks for the prey, which can be followed by hunters.

5. **Output and Display**:

   - **`initialise-output`**: Resets or initializes variables used for tracking the simulation outcomes.

   - **`update-display`**: Updates the visual display to reflect the initial state.

6. **`reset-ticks`**: Resets the tick counter to begin the simulation time from zero.

## Simulation step (`go`)

The `go` procedure orchestrates the behavior of prey and hunter agents in a simulated hunting bout. Each agent (prey or hunter) reacts based on sightings, memory of previous interactions, and environmental context.

Hunting bout: overall cycle (per second)
![Hunting bout: overall cycle (per second)](docs/behaviour-diagrams_cycle.png)

Summary of steps:

1. **Sight-Based Reactions**:

   - Agents (prey and hunters) check for immediate sightings. 

   - **Prey**: If they see a hunter, they either flee or plan action based on reaction time.
  
   - **Hunters**: If a prey is seen, they decide to either shoot, pursue, or stealthily approach depending on distance and if they are detected.

2. **Hunter Actions**:

   - **Shoot**: Attempts to shoot the nearest prey within range.

   - **Pursue**: Chase fleeing prey if too far to shoot.

   - **Approach Stealthily**: Move towards prey using stealth.

3. **Memory-Based Movements**:

   - Agents who haven’t moved and have memory of previous targets:

     - **Prey**: Move away from the last known sighting.

     - **Hunters**: Move towards the last known sighting blindly.

4. **Communication and Alerts**:
  
   - If an agent has messages (e.g., received from other agents):

     - **Prey**: mimic movement based on other fleeing prey.
  
     - **Hunters**: Communicate their status and memory to other hunters.

5. **Default Movements**:
   - Agents with no recent sightings:

     - **Prey**: Browse or graze vegetation, rest, digest, perform other behaviours unrelated to the hunt, adjust position based on group and patch attractiveness.

     - **Hunters**: Track recent prey tracks or explore the area.

Hunting bout: movement modes (states with transitions)
![Hunting bout: movement modes](docs/behaviour-diagrams-prey-state.png)

Hunting bout: alertness, reaction and relaxation
![Hunting bout: alertness, reaction and relaxation](docs/alertness.png)

5. **Environmental and Status Updates**:

   - Prey check if they need to escape.

   - Both prey and hunters update their perception and interact with the environment, such as affecting vegetation.

   - Clear outdated tracks and update display as needed.

Hunting bout: line of sight with permeable obstacles (i.e. vegetation)
![Hunting bout: line of sight with permeable obstacles (i.e. vegetation)](docs/line-of-sight.png)

This structured approach ensures that each agent acts based on their immediate context (sighting or short-term memory), coordinates with others, and interacts with the environment to reflect a dynamic hunting scenario.
