include("plot_single_reward.jl")
include("plot_single_intrinsic_reward.jl")
include("plot_single_state_visitation_heatmap_ttmaze.jl")
include("plot_single_goal_visitation.jl")


folder = "TabularTMazeExperiment/RP_0_0x506adc8d66fce4d4/"

log_interval = 100
num_steps = 30000

# Loading results file
results_file = folder * "results.jld2"
@load results_file results

# Loading settings file
settings_file = folder * "settings.jld2"
settings = FileIO.load(settings_file)["parsed_args"]

# Various plotting scripts
plot_single_reward(results)
plot_single_intrinsic_reward(results)
plot_single_goal_visitation(results; step_size=20)
plot_single_state_visitation_heatmap(results, 50, log_interval; fps=10)