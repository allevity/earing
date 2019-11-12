function results_test = test_EarSumner2002()
% Plots responses of LSR/MSR/HSR fibers of 250/.../24000 best frequency to
% sinusoids at their BF, varying intensity up to 100dB. 

test_file = fullfile(fileparts(matlab.desktop.editor.getActiveFilename), '..', 'data', 'test_EarSumner2002.mat');
if ~exist(test_file, 'file')
    results_test = struct();
else
    a = load(test_file);
    results_test = a.results_test;
end

best_frequencies = [250, 500, 1000, 3000, 6000, 12000, 24000];
list_dbs = 100:-5:0;
types_an = {'HSR', 'MSR', 'LSR'};
ome_filters = {'chris', 'mark'};
disp('These graphs show the firing rate (#spikes/s) of LSR, MSP, HSR fibers of varying best frequencies,')
disp('as response to sinusoids at this frequency and different decibels (0dB to 100dB)');

externalResonanceFilters_struct = struct(...
    'chris', [ 0 1 4000 25000; 0 1 4000 25000; 0 1  700 30000;   0 1  700 30000;    0 1  700 30000], ...
    'mark',  [ 0 1 4000 25000; 0 1 4000 25000; 0 1  700 30000;   0 1  700 30000]);
disp('The two colours correspond to different filters:')
disp(externalResonanceFilters_struct);

for k=1:length(types_an)
    type_an = types_an{k};
    for j=1:length(ome_filters)
        ome_filt = ome_filters{j};
        % Already calculated
        if isfield(results_test, ome_filt) && isfield(results_test.(ome_filt), type_an)
            continue
        end
        externalResonanceFilters = externalResonanceFilters_struct.(ome_filt);
        results_test.(ome_filt).(type_an) = get_results(type_an, ome_filt, externalResonanceFilters, best_frequencies, list_dbs);
        save(test_file, 'results_test')
    end
end

plot_colours = struct('chris', 'b', 'mark', 'r');
disp('Colour code:');
disp(plot_colours)

for k=1:length(types_an)
    figure;
    hold on;
    for j=1:length(ome_filters)
        ome_filt = ome_filters{j};
        
        c = plot_colours.(ome_filt);
        type_an = types_an{k};
        subtitle = sprintf('%s', type_an);
        plot_results(results_test.(ome_filt).(type_an), subtitle, c)
    end
end

end

function plot_results(results, subtitle, c)
ff = [results.frequency];
for freq = unique(ff)
    hold on
    ind = find(freq==unique(ff));
    subplot(length(unique(ff)), 1, 1+length(unique(ff))-ind);
    subres = results(ff==freq);
    plot([subres.db], [subres.rate], 'o-', 'Color', c)
    title(sprintf('%s: Frequency = %f', subtitle, freq))
    ylim([0 300])
end
xlabel('Sound intensity (dB)');
ylabel('Response rate (#spikes/s)');
end

function results_test = get_results(type_nerve, ome_filters, externalResonanceFilters, best_frequencies, list_db)
switch type_nerve
    case 'HSR'
        type_an.gmaxca = 7.2e-9;
        type_an.ca_thresh = 0;
        
    case 'MSR'
        type_an.gmaxca = 2.4e-9;
        type_an.ca_thresh = 3.35e-14;
        
    case 'LSR'
        type_an.gmaxca = 1.6e-9;
        type_an.ca_thresh = 1.4e-11;
        
    otherwise, error(type_nerve)
end

assert(length(best_frequencies) > 1, 'Code bugs if only one best_freq given to ear');
l = 1;
results_test = struct([]);
for db = list_db
    fprintf('db: %f\n', db)
    
    % Ear
    % TODO: fix!! Has to have at least 2 values otherwise code breaks. 
    ear_input = get_ear_param(type_an, externalResonanceFilters, best_frequencies, db);  % only at this frequency because that's the one evaluated in this test
    
    for frequency = best_frequencies % sound frequency
        fprintf('frequency: %f\n', frequency)
    
        % Signal
        signal_duration = 5; % seconds
        ear = run_sinusoid(ear_input, frequency, signal_duration);
        
        % Plots (prob=ear.an.prob_firing could be used)
        spikes = ear.an.spikes_sparse;
        
        % Spontaneous rate at BF=sound frequency
        initial_time_remove = 0.3; % seconds; time before adaptation
        spontaneous_rate = full(sum(spikes(best_frequencies==frequency, floor(1e5*initial_time_remove):end), 2)'/(signal_duration-initial_time_remove));  % removing the beginning
        fprintf('type_nerve: %s, ome_filters: %s, rate: %f\n', type_nerve, ome_filters, spontaneous_rate);
        assert(length(spontaneous_rate)==1);
        results_test(l).frequency = frequency;
        results_test(l).db = db;
        results_test(l).rate = spontaneous_rate;
        results_test(l).type = type_nerve;
        results_test(l).ome_filters = ome_filters;
        l = l+1;
    end
end
end

function ear_input = get_ear_param(type_an, externalResonanceFilters, best_frequencies, db)
ear_input = ...
 struct(...
    'model', @EarSumner2002, ...
    'db', db, ...  
    'ome', struct(...
        'externalResonanceFilters', externalResonanceFilters), ...
    'bm',  struct(...
        'drnl', struct(...
            'lin', struct(), ...
            'gt', struct(...
                    'nl', struct(...
                    'lin', struct())),...
            'lp', struct(...
                'nl', struct(...
                    'lin', struct()))), ...
        'best_frequencies', best_frequencies), ...
    'cilia',  struct(),...
    'synapse',  struct(...
        'n_fibers_per_type_per_channel', 1, ...
        'presynapse', struct(...
            'gmaxca', type_an.gmaxca, ...
            'ca_thresh', type_an.ca_thresh)),...
    'an',  struct());
end

function ear = run_sinusoid(ear_input, frequency, signal_duration)
fs = 1e5;
stimulus = sin(2*pi*frequency*(0:1/fs:signal_duration));
ear = EarSumner2002(ear_input);
ear.run(stimulus);
end