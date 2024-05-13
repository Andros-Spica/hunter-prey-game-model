import shuffle from random

# Initialize simulation parameters
num_hunters = 20
hunting_party_max_size = 3
num_prey = 100
prey_group_size = 3
poison_strength = 0.01  # rate of stamina decrease per time step 

# auxiliary global variables
hunter_ids = list()
hunting_parties_ids = list()

# Define hunter and prey properties
class Hunter:
    def __init__(self, camouflage, stealth_skill, body_size, perception, speed, stamina, technology, skill):
        self.id = id
        self.camouflage = camouflage
        self.stealth_skill = stealth_skill
        self.body_size = body_size
        self.perception = perception
        self.speed = speed
        self.stamina = stamina
        self.technology = technology
        self.skill = skill
        self.group_id = None  # ID of the hunting party the hunter belongs to

class Prey:
    def __init__(self, presence, perception, speed, stamina):
        self.id = id
        self.presence = presence
        self.perception = perception
        self.speed = speed
        self.stamina = stamina
        self.group_id = None  # ID of the group the prey belongs to

# Initialisation
def initialize_agents():
    # Initialize hunter and prey agents with properties
    # ...

def set_environmental_conditions():
    # Set up environmental conditions and obstacles
    # ...

# Planning, cooperation and tool availability within the social group
def plan_hunting_strategy():
    
    

    
    # iterate for each hunter
    for hunter_id in shuffle(hunter_ids):
        
        # chose target points


def reset_hunting_parties():
    # reset hunting parties
    hunting_parties_ids = list()
    # 

# Functions for presence, perception, speed, and stamina modification
def modify_presence(agent, environment):
    # Modify presence based on environment (e.g., vegetation, terrain effects)

def modify_perception(agent, environment):
    # Modify perception based on environment and agent properties

def modify_speed(agent, environment):
    # Modify speed based on environment and agent properties

def modify_stamina(agent, environment):
    # Modify stamina based on environment and agent properties

# Environmental stochasticity
def apply_obstacles(environment, agent):
    # Apply obstacles affecting movement and properties of both hunter and prey

# Cooperation and tool availability within the social group
def plan_hunting_parties(hunters, group_sizes):
    # Organize hunters into hunting parties during the planning phase
    # Returns a dictionary with group_id as keys and lists of hunters as values

# Retrieve and freshness of prey’s body after a successful shot
def retrieve_prey(hunter):
    # Process of retrieving prey's body after a successful shot, impacted by group size




def evaluate_outcomes():
    # Evaluate outcomes and success probability based on group size
    # ...
