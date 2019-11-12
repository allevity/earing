%% Single parameters for comparison
this_file = matlab.desktop.editor.getActiveFilename;
code = fileparts(matlab.desktop.editor.getActiveFilename);
addpath(genpath(fullfile(code, '..', '..')));

% Model parameters: G_max^Ca and Ca_thresh together define the type of 
% fiber (Low/Medium/High Spontaneous Rate)
gmax_ca = 7.2e-9;     
ca_thresh = 4.48e-11;
fiber_best_frequencies = [250, 500, 1000, 3000, 6000, 12000, 24000];

% Signal parameters
frequency = 500; % Hz, sound input freq (modulated)
signal_duration = 1; % s
db = 100; % dBs
fs = 1e5; % model freq
stimulus = sin(2*pi*3*(0:1/fs:signal_duration)).^2.*sin(2*pi*frequency*(0:1/fs:signal_duration));

%% Old implementation
assert(exist('MAP_AN_only', 'file') > 0, 'The former implementation MAP_AN_only.m is supposed to be in PATH')
assert(exist('MAPparamsGP', 'file') > 0, 'The parameter file MAPparamsGP.m is expected to be in PATH')

numANfibers = 0; % To compute the proba of firing
[stimulus_renormalised, fs_] = audioread_at_given_dB(stimulus, db);

changes = [{['AN_IHCsynapseParams.numFibers = ' num2str(numANfibers) ';']}, ...
           {['IHCpreSynapseParams.GmaxCa = ' num2str(gmax_ca) ';']}, ...
           {['IHCpreSynapseParams.Ca_thresh = ' num2str(ca_thresh) ';']}];

MAP_AN_only(stimulus_renormalised, fs, fiber_best_frequencies, 'GP', changes);

%% New implementation
externalResonanceFilters = [ 0 1 4000 25000; 0 1 4000 25000; 0 1  700 30000;   0 1  700 30000;    0 1  700 30000];
params = struct(...
    'ome', struct('externalResonanceFilters', externalResonanceFilters), ...
    'synapse',  struct(...
        'n_fibers_per_type_per_channel', 1, ...
        'presynapse', struct(...
            'gmaxca', gmax_ca, ...
            'ca_thresh', ca_thresh)),...
    'best_frequencies', fiber_best_frequencies...
    );
ear = EarSumner2002(params);
ear.db = db; % dBs
ear.run(stimulus);
proba_firing_new_model = ear.an.prob_firing;

%% Comparison of the output
global OMEoutput IHC_cilia_output IHCoutput ANproboutput;  
global vesicleReleaseRate;  % added for the test

m = @(x, y)mean(mean(abs(x-y)))/mean(mean(abs(x)));

results = struct();
results.ome_stapes_velocity = m(OMEoutput, ear.ome.stapes_velocity);
results.cilia_displacement = m(IHC_cilia_output, ear.cilia.cilia_displacement);
results.cilia_receptor_potential = m(IHCoutput, ear.cilia.receptor_potential);
if ~isempty(vesicleReleaseRate)
    % 'vesicleReleaseRate' Was not a global var in old code
    results.vesicle_release = m(vesicleReleaseRate, ear.synapse.vesicle_release_rate);
end
results.proba_firing = m(ANproboutput, ear.an.prob_firing);

fi = fieldnames(results);
for k = 1:length(fi)
    key = fi{k};
    % Let's say that the new implementation is correct enough if it's
    % on average within 0.001% of the old one
    if results.(key) < 0.00001
        fprintf('Test on %s went alright\n', key);
    else
        warning(' <<< Test on %s was too high (%f). To debug >>>\n', key, results.(key));
    end
end

figure;

subplot(3, 1, 1)
plot(stimulus)
xlim([1 length(stimulus)])
title('Input sound waveform')

proba_firing_old_model = ANproboutput;
max_val = max(max(max(proba_firing_old_model)), max(max((proba_firing_new_model))));

subplot(3, 1, 2)
imagesc(proba_firing_old_model)
caxis([0 max_val]);
title('Old model proba firing');

subplot(3, 1, 3)
imagesc(proba_firing_new_model)
caxis([0 max_val]);
title('New model proba firing');

print(gcf, fullfile(code, '..', 'plots', 'test_EarSumner2002_comparison_MAP_AN_only.jpeg'), '-djpeg', '-r0')
