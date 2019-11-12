classdef EarSumner2002 < Ear
    
    % ear.run uses cochlear model from Sumner2002 to simulate CN activation:
    % - init_input:  resamples input to 10kHz and to given sound level
    % - ear.ome.run: simulates the stapes velocity
    % - ear.bm.run: simulates the basilar membrane velocity
    % - ear.cilia.run: simulates the IHC cilia potential and resting voltage
    % - ear.synapse.run: simulates the synapses molecular variations
    % - ear.an.run: simulates the probability of firing (and optionally the spikes)
    
    properties 
        db double = 80
        best_frequencies double  % set at initialisation for consistency
    end
    
    properties (Access=private)
        fs = 1e5  % Hz; expected as input to model
    end
    
    methods
        
        function ear = EarSumner2002(params)
            if ~exist('params', 'var'), params = struct(); end
            try
                if isfield(params, 'best_frequencies') && ~isfield(params.bm, 'best_frequencies')
                    params.bm.best_frequencies = params.best_frequencies; 
                end
            catch
                params.bm.best_frequencies = params.best_frequencies; 
            end
            ear = ear@Ear(params);
            ear.change_parameters(params)  % change db and BF
            ear.parameters2name();  % change the name
        end
        
        function stimulus = init_input(ear, wav_file_or_signal)
            % Stimulus
            [stimulus, fs_] = audioread_at_given_dB(wav_file_or_signal, ear.db);
            
            % Checks
            if length(stimulus) > 10000000
                warning('Cut unless you have a lot of memory'); end
            if abs(fs_ - ear.fs)>10
                error('The sample rate should be 1e5 Hz: Use function ''resample''.'); end
            
            % Stimulus must be row vector
            [r, signal_length] = size(stimulus);
            if r > signal_length
                stimulus = stimulus';
            end
        end
        
        function run(ear, wav_file_or_signal)
            stimulus = init_input(ear, wav_file_or_signal);
            
            ear.ome.run(stimulus, ear.fs);
            ear.bm.run(ear.ome.stapes_velocity, ear.ome.stapes_scalar, ear.fs); % TODO: remove stapes_scalar transmission
            ear.cilia.run(ear.bm.velocity, ear.fs);
            ear.synapse.run(ear.cilia.receptor_potential, ear.cilia.restingV, ear.fs);
            ear.an.run(ear.synapse, stimulus, ear.fs);  % TODO: relocate init_speedUpFactor
            ear.has_run = true;
        end
     
    end
    
    methods (Access=private)
        
        function prob_firing = run_prob(obj, wav_file)
            obj.run(wav_file);
            if obj.ear.refractoriness
                prob_firing = obj.ear.an.prob_firing_refractory;
            else
                prob_firing = obj.ear.an.prob_firing;
            end
        end
    end

end