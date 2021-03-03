import Reproduce

abstract type LoggerKeyData end

function step!(self::LoggerKeyData, env, agent, s, a, s_next, r, is_terminal, cur_step_in_episode, cur_step_total)
    error("step! for this logger is unimplemented")
end

function episode_end!(self::LoggerKeyData, cur_step_in_episode, cur_step_total)
    error("episode_end! for this logger is unimplemented")
end

function save_log(self::LoggerKeyData, save_dict::Dict)
    error("save_log for this logger is unimplemented")
end



include("goal_visitation.jl")
include("episode_length.jl")
include("mountain_car_error.jl")
include("temp_print.jl")

# Module for scoping key names
module LoggerKey
    const GOAL_VISITATION = "GOAL_VISITATION"
    const EPISODE_LENGTH = "EPISODE_LENGTH"
    const MC_ERROR = "MC_ERROR"
    const TEMP_PRINT = "TEMP_PRINT"
end

module LoggerInitKey
    const TOTAL_STEPS = "TOTAL_STEPS"
    const INTERVAL = "INTERVAL"
end

const LOGGER_KEY_MAP = Dict(
    LoggerKey.GOAL_VISITATION => GoalVisitation,
    LoggerKey.EPISODE_LENGTH => EpisodeLength,
    LoggerKey.MC_ERROR => MCError,
    LoggerKey.TEMP_PRINT => TempPrint
)

# Common logger for all experiments. It has multiple functionalities so pass in what you need to get started
mutable struct Logger
    save_file:: String
    # Tracks what needs to be logged
    logger_keys::Array{String}
    # Array of structs for logger logic
    logger_key_data::Array{LoggerKeyData}

    # This should only track info that makes sense to track across ALL loggers.
    cur_step_in_episode::Int64
    cur_step_total::Int64

    function Logger(parsed, logger_init_info, save_file)
        logger_keys = parsed["logger_keys"]
        logger_key_data = LoggerKeyData[]
        save_results = Dict()

        cur_step_in_episode = 0;
        cur_step_total = 0;


        # Set up for each key
        for key in logger_keys
            if haskey(LOGGER_KEY_MAP, key)
                push!(logger_key_data, LOGGER_KEY_MAP[key](logger_init_info))
            else
                throw(ArgumentError("Logger Key $(key) is not in the LOGGER_KEY_MAP"))
            end
        end
        new(save_file, logger_keys, logger_key_data, cur_step_in_episode, cur_step_total)
    end
end

function logger_step!(self::Logger, env, agent, s, a, s_next, r, is_terminal)
    self.cur_step_in_episode += 1;
    self.cur_step_total += 1;

    for data in self.logger_key_data
        step!(data, env, agent, s, a, s_next, r, is_terminal, self.cur_step_in_episode, self.cur_step_total)
    end
end

function logger_episode_end!(self::Logger)
    for data in self.logger_key_data
        episode_end!(data, self.cur_step_in_episode, self.cur_step_total)
    end

    self.cur_step_in_episode = 0
end

function logger_save(self::Logger)
    save_dict = Dict()
    for data in self.logger_key_data
        save_log(data, save_dict)
    end
    save_results(self.save_file, save_dict)
end
