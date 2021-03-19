module MountainCarExperiment

import Random

using GVFHordes
using Curiosity
using MinimalRLCore
using SparseArrays
using ProgressMeter

import Flux: Descent

const MCU = Curiosity.MountainCarUtils

default_args() =
    Dict(
        "steps" => 1000,
        "seed" => 1,

        #Tile coding params used by Rich textbook for mountain car
        "numtilings" => 8,
        "numtiles" => 8,
        "behaviour_alpha" => 0.5/8,

        "behaviour_learner" => "ESARSA",
        # "behaviour_rew" => "env",
        "behaviour_gamma" => 0.99,
        "intrinsic_reward" =>"no_reward",
        "behaviour_trace" => "replacing",
        "use_external_reward" => true,

        "lambda" => 0.9,
        "demon_alpha" => 1.0/8,
        "demon_alpha_init" => 1.0/8,
        "demon_policy_type" => "greedy_to_cumulant",
        "demon_learner" => "q",
        "demon_update" => "TB",
        "exploring_starts"=>true,
        "save_dir" => "MountainCarExperiment",
        "logger_keys" => [LoggerKey.EPISODE_LENGTH, LoggerKey.MC_ERROR],

    )


function construct_agent(parsed)
    observation_size = 2
    action_space = 3
    lambda = parsed["lambda"]
    demon_alpha = parsed["demon_alpha"]
    demon_alpha_init = parsed["demon_alpha_init"]
    demon_learner = parsed["demon_learner"]
    demon_lu = parsed["demon_update"]
    behaviour_learner = parsed["behaviour_learner"]
    # behaviour_lu = parsed["behaviour_update"]
    behaviour_alpha = parsed["behaviour_alpha"]
    behaviour_gamma = parsed["behaviour_gamma"]
    behaviour_trace = parsed["behaviour_trace"]
    intrinsic_reward_type = parsed["intrinsic_reward"]
    use_external_reward = parsed["use_external_reward"]


    #Create state constructor
    state_constructor_tc = TileCoder(parsed["numtilings"], parsed["numtiles"], observation_size)

    feature_size = size(state_constructor_tc)
    function state_constructor(obs, feature_size, tc)
        s = spzeros(Int, feature_size)
        s[tc(obs)] .= 1
        return s
    end

    demons = get_horde(parsed,
                       feature_size,
                       action_space, (obs) ->
                       state_constructor(obs, feature_size, state_constructor_tc))

    demon_lu = if demon_lu == "TB"
        TB(lambda=lambda, opt=Descent(demon_alpha))
    elseif demon_learner == "TBAuto"
        TB(lambda,
           Auto(demon_alpha, demon_alpha_init),
           feature_size, length(demons), action_space)
    else
        throw(ArgumentError("Not a valid demon learner"))
    end

    # (update, num_features, num_actions, num_demons; init=(s...)->zeros(s...)) =
    demon_learner = if demon_learner ∈ ["Q", "QLearner", "q"]
        LinearQLearner(demon_lu, feature_size, action_space, length(demons))
    elseif demon_learner ∈ ["SR", "SRLearner", "sr"]
        SRLearner(demon_lu,
                  feature_size,
                  length(demons),
                  action_space,
                  demons.num_tasks)
    else
        throw(ArgumentError("Not a valid demon learner"))
    end

    behaviour_lu = if behaviour_learner == "ESARSA"
        ESARSA(lambda, feature_size, 1, action_space, behaviour_alpha, behaviour_trace)
    else
        throw(ArgumentError("Not a valid behaviour learner"))
    end

    Agent(demons,
          feature_size,
          behaviour_lu,
          behaviour_gamma,
          demon_learner,
          observation_size,
          action_space,
          intrinsic_reward_type,
          (obs) -> state_constructor(obs, feature_size, state_constructor_tc),
          use_external_reward)

    # Agent(demons,
    #       feature_size,
    #       feature_size,
    #       observation_size,
    #       action_space,
    #       demon_learner,
    #       behaviour_learner,
    #       intrinsic_reward_type,
    #       (obs) -> state_constructor(obs, feature_size, state_constructor_tc),
    #       behaviour_gamma,
    #       use_external_reward)
end

function get_horde(parsed, feature_size, action_space, state_constructor)
    horde = Horde([MCU.steps_to_wall_gvf(), MCU.steps_to_goal_gvf()])
    if parsed["demon_learner"] == "SR"
         SF_horde = MCU.make_SF_horde(feature_size, action_space, state_constructor)
         num_SFs = 2
         horde = Curiosity.GVFSRHordes.SRHorde(horde, SF_horde, num_SFs, state_constructor)
    end
    return horde
end

function main_experiment(parsed=default_args(); progress=false, working=false)

    num_steps = parsed["steps"]

    Random.seed!(parsed["seed"])

    normalized = true
    env = MountainCar(0.0,0.0,normalized)

    agent = construct_agent(parsed)

    logger_init_dict = Dict(
        LoggerInitKey.TOTAL_STEPS => num_steps,
        LoggerInitKey.INTERVAL => 1000,
    )

    Curiosity.experiment_wrapper(parsed, logger_init_dict, working) do parsed, logger
        eps = 1
        max_num_steps = num_steps
        steps = Int[]

        prg_bar = ProgressMeter.Progress(num_steps, "Step: ")
        while sum(steps) < max_num_steps
            is_terminal = false

            max_episode_steps = min(max_num_steps - sum(steps), 200)
            tr, stp =
                run_episode!(env, agent, max_episode_steps) do (s, a, s_next, r, t)
                    logger_step!(logger, env, agent, s, a, s_next, r, t)
                    if progress
                        next!(prg_bar)
                    end
                end
            logger_episode_end!(logger)

            push!(steps, stp)
            eps += 1
        end
        logger
    end
end

end
