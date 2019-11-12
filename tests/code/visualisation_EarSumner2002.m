function visualisation_EarSumner2002()
% Shows intermediate variable to obtain the spike trains from a sound wave
% played at different sound levels

clear visualisation_EarSumner2002; % makes sure persistent var plot_index=0

test_folder = fullfile(fileparts(matlab.desktop.editor.getActiveFilename), '..');
data_folder = fullfile(test_folder, 'data');
plots_folder = fullfile(test_folder, 'plots');

addpath(genpath(fullfile('..', test_folder, '..'))); % adding all paths 

mp3_file = fullfile(data_folder, 'very_short_sound.mp3');
assert(exist(mp3_file, 'file')==2, sprintf('%s not found', mp3_file))
disp('Visualisations of EarSumner2002 on their way. May take couple minutes...')

% Plot spectrogram & cochlear response when played at different sound levels
sound_levels = [45, 60, 75, 90]; 
figure;
hold on
for sound_level = sound_levels
    plot_sound_level(mp3_file, sound_level, sound_levels);
end

set(gcf, 'PaperSize', [45 15])    
set(gcf, 'PaperPosition', [0 0 30 10])    % can be bigger than screen 
output_file = fullfile(plots_folder, 'visualisation_EarSumner2002.jpg');
fprintf('Saving figure to %s...\n', output_file);
print(gcf, output_file, '-djpeg', '-r0' );   % save file
end

function plot_sound_level(mp3_file, sound_level, sound_levels)
n_sound_levels = length(sound_levels);
n_plot_per_line = 8;
persistent plot_index  % To put plots in the right column
if isempty(plot_index) || plot_index >= n_plot_per_line
    plot_index = 0;
else
    plot_index = plot_index + 1;
end

ear = EarSumner2002();
ear.db = sound_level;  % 80dB by default
ear.run(mp3_file);

subplot(n_sound_levels, n_plot_per_line, 1 + plot_index*n_plot_per_line)
stimulus = ear.init_input(mp3_file);
plot(stimulus);
title(sprintf('Soundwave at %d dB', sound_level));

subplot(n_sound_levels, n_plot_per_line, 2 + plot_index*n_plot_per_line)
ear.ome.plot();
title(sprintf('OME stapes velocity'));

subplot(n_sound_levels, n_plot_per_line, 3 + plot_index*n_plot_per_line)
ear.bm.plot();
caxis([0 0.0035])
title(sprintf('BM velocity'));

subplot(n_sound_levels, n_plot_per_line, 4 + plot_index*n_plot_per_line)
ear.cilia.plot();
caxis([0.0 3.42e-6])  
title(sprintf('IHC cilia displacement'));

subplot(n_sound_levels, n_plot_per_line, 5 + plot_index*n_plot_per_line)
ear.synapse.plot();
caxis([0 5.3e4])
title(sprintf('AN-IHC Vesicle release rate'));

subplot(n_sound_levels, n_plot_per_line, 6 + plot_index*n_plot_per_line)
ear.an.plot();
caxis([0 0.5])
title(sprintf('Proba of firing'))

subplot(n_sound_levels, n_plot_per_line, 7 + plot_index*n_plot_per_line)
ear.an.plot_smoothed_proba_firing();
caxis([0, 10]);
title('... with temporal smoothing')

subplot(n_sound_levels, n_plot_per_line, 8 + plot_index*n_plot_per_line)
ear.an.plot_smoothed_spike_trains();
caxis([0 0.5])
title('Generated spikes')
end