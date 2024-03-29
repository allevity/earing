% File for an HTK experiment; allows to create many ears, postprocessing,
% and run HTK on each when everything has been properly setup. 

datasets = struct(...
    'set_name', 'CUAVE5', ...
    'n_train', 50, ...  
    'n_test', 25, ...  
    'n_development', 5); 

models = struct(...
    'model', @EarSumner2002, ...
    'db', [80], ...  
    'ome', struct(), ...
    'bm',  struct(...
        'drnl', struct(...
            'lin', struct(), ...
            'gt', struct(...
                'nl', struct(...
                    'lin', struct())),...
            'lp', struct(...
                'nl', struct(...
                    'lin', struct()))), ...
        'best_frequencies', 10.^(linspace(log10(100), log10(8000), 128))), ...
    'cilia',  struct(),...
    'synapse',  struct(...
        'n_fibers_per_type_per_channel', 1, ...  % more than 1 is very slow
        'presynapse', struct(...
            'gmaxca', [7.2e-9], ... % default: HSR
            'ca_thresh', [0])),...
    'an',  struct());

processings = struct(...
    'features', {{{'SPIKE','f','lu','r','l','d','dd','z'}}},  ...  
    'window', @hann, ...
    'rate_window_duration', 10.^linspace(-2,-1,10) ... [0.1, 0.125]   <0.15 if stimu not cut
    );

htks = struct(... 
    'n_states', 5, ...
    'n_mixtures', 5);

default_params = struct('datasets', datasets, 'models', models, 'processings', processings, 'htks', htks);

% exp1 done, but 1e-13 was missing
params_exp1 = default_params; 
params_exp1.models.db = [80];
params_exp1.models.synapse.presynapse.gmaxca = [7e-9];
params_exp1.models.synapse.presynapse.ca_thresh = [1e-15,1e-14,1e-13,1e-12,1e-11,2e-11,3e-11,4e-11,5e-11,6e-11,8e-11,1e-10]; 

params_exp2 = default_params; 
params_exp2.models.db = 50:10:90;
params_exp2.models.synapse.presynapse.gmaxca = (2:9)*1e-9;
params_exp2.models.synapse.presynapse.ca_thresh = [1e-12]; 

% Objects initiation
% current_exp = params_exp1;
current_exp = params_exp2;
global HTK_PATHS
assert(~isempty(HTK_PATHS))
    
if ~exist('asr_exp', 'var')
    asr_exp = AsrExperiment(current_exp.datasets, current_exp.models, current_exp.processings, current_exp.htks);
end
if ~exist('res', 'var')
    res = Result('AsrExperiment');
end

% Experiment run
asr_exp.run(res)

% Plot results 
plot_different_Ca(res);
