classdef AuditoryNerve < RunObject
    % Each row of the AN matrices represents one AN fiber
    % The results computed either for probabiities *or* for spikes (not both)
    % Spikes are necessary if CN and IC are to be computed
    
    % Option to specify output as probability only is done by 
    % setting numFibers to zero at input parameters.
    
    % Switch `refractoriness` to 1 to calculate the firing probability
    % maxtrix with refractoriness.
    
    properties
        ydt
        ldt
        xdt
        rdt
        rdt_plus_ldt
        M
        
        n_fibers_per_channel
        n_channels
        n_fibers  % n_fibers_per_channel * n_channels (*n_fiber_types?)
        dt
        tauCas
        
        prob_firing
        prob_firing_refractory % probability of firing with refractoriness
        % speedUpFactor % should be put back 
        speedup_vector
        refractory_period
        lengthAbsRefractory
        
        % PSTH 
        % If psth>1, MAP_AN_generatePoissonSpikeTrains generates PSTH
        % (double array) instead of spike trains (logical array),
        % counting the nnumber of spikes falling in each bins for 'PSTH'
        % repetitions of the stimulus (useful for easy firing rate evaluation)
        psth = 1 
        spikes_sparse  % output of run_spike
        
        % Reservoirs
        cleft
        available
        reprocess
        
        % PROB = Synapse vessicle release probability 
        % SPIKE = spikes generation
        output_mode {mustBeMember(output_mode,{'SPIKE','PROB'})} = 'SPIKE'
        
        refractoriness = false  % if True, calculate the refractoriness
    end
    
    methods
        function an = AuditoryNerve(params)
            an.init_params(params);
        end
        
        function init(an, synapse)
            an.ydt = repmat(synapse.y * an.dt, an.n_channels, 1);
            an.ldt = repmat(synapse.l * an.dt, an.n_channels, 1);
            an.xdt = repmat(synapse.x * an.dt, an.n_channels, 1);
            an.rdt = repmat(synapse.r * an.dt, an.n_channels, 1);
            an.rdt_plus_ldt = an.rdt + an.ldt;
            an.M = round(synapse.M);
            
            synapse_refractory_period = synapse.refractory_period;
            an.refractory_period = synapse_refractory_period;
            an.lengthAbsRefractory= round(synapse_refractory_period / an.dt);
            
            kt0 = synapse.kt0;
            % starting values for reservoirs
            an.cleft     = kt0 * synapse.y * synapse.M ./ (synapse.y * (synapse.l+synapse.r) + kt0 *synapse.l);
            an.available = round(an.cleft * (synapse.l+synapse.r) ./ kt0);  % must be integer
            an.reprocess = an.cleft * synapse.r / synapse.x;
        end
        
        function run(an, synapse, stimulus, fs)
            if synapse.n_fibers_per_type_per_channel > 0
                an.n_fibers_per_channel = synapse.n_fibers_per_type_per_channel;
                an.output_mode = 'SPIKE';
            else
                an.n_fibers_per_channel = 1;
                an.output_mode = 'PROB';
            end
            an.n_channels = synapse.n_AN_channels;
            an.n_fibers = an.n_channels * an.n_fibers_per_channel;
            
            % obj.n_channels = synapse.n_AN_channels;
            an.init_speedUpFactor(stimulus, fs, synapse.spikesTargetSampleRate)
            an.init(synapse);
            
            an.run_prob(synapse.vesicle_release_rate)
            
            if an.refractoriness
                an.run_prob_refractoriness()
            end
            
            switch an.output_mode
                case 'PROB'  % all done
                case 'SPIKE' % actually, more to do...
                    an.run_spike()
            end
            an.has_run = 1;
        end
        
        function plot(an)
            % Display cochleogram
            if ~an.check_run()
                return
            end
            imagesc(an.prob_firing)
        end
        
        function plot_smoothed_proba_firing(an)
            % Plot proba of firing with temporal smoothing
            if ~an.check_run()
                return
            end
            proba_of_firing = an.prob_firing;
            smoothed_proba = conv2(proba_of_firing, ones(1, 250));
            imagesc(smoothed_proba)
        end
        
        function plot_smoothed_spike_trains(an)
            % Plot spike trains with temporal smoothing
            if ~an.check_run()
                return
            end
            spikes = conv2(full(an.spikes_sparse), ones(2,10));
            imagesc(spikes)
        end
        
        function clean(an)
            an.prob_firing = [];
            an.prob_firing_refractory = [];
            an.spikes_sparse = [];
            an.ydt = [];
            an.ldt = [];
            an.xdt = [];
            an.rdt = [];
            an.rdt_plus_ldt = [];
            an.cleft = [];
            an.available = [];
            an.reprocess = [];
            an.speedup_vector = [];
        end
        
        function init_speedUpFactor(an, stimulus, fs, synapse_spikesTargetSampleRate)
            % warning('init_speedUpFactor: NOT REIMPLEMENTED YET; probably shouldn''t be at this point in pipeline');
            spdupf = ceil(fs / synapse_spikesTargetSampleRate);
            
            % stimulus = obj.input.stimulus;
            [~, signal_length] = size(stimulus);  %[r
            
            segment_length = ceil(signal_length / spdupf) * spdupf;
            % Make the signal length a whole multiple of the segment length
            % padSize = segment_length - signal_length;
            % pad = zeros(r, padSize);
            % stimulus = [stimulus pad];
            
            signal_length = segment_length;
            % reducedSegmentLength = round(segment_length / spdupf);
            
            an.dt = (1 / fs) * spdupf;
            
            % an.speedUpFactor = spdupf;
            an.speedup_vector= spdupf:spdupf:signal_length;
        end
        
    end
    
    methods (Static)
        function s = str()
            s = sprintf('AN');
        end
    end
    
    methods (Access=private)
        
        function bool = check_run(an)
            if ~an.has_run
                disp('... AN has not run yet...');
                bool = false;
                return
            else
                bool = true;
            end
        end
        
        function run_prob(an, synapse_vesicle_release_rate)
            % speed up code removed out of sheer laziness
            prob_release = synapse_vesicle_release_rate * an.dt;
            an.prob_firing = MAP_finalForLoop_mex(1, prob_release, an.available, an.reprocess, an.M, an.xdt, an.ydt, an.rdt_plus_ldt,an.rdt,an.cleft,int32(an.speedup_vector),an.lengthAbsRefractory);
        end
        
        function run_prob_refractoriness(an)
            an.prob_firing_refractory = MAP_addRefractoriness(an.prob_firing, an.lengthAbsRefractory * an.dt, an.dt);
        end
        
        function run_spike(an)
            n_fiberPerInd = 1;
            
            if an.psth == 1
                an.spikes_sparse = sparse(an.n_channels * an.n_fibers_per_channel, size(an.prob_firing,2));
                for k = 1:an.n_fibers_per_channel
                    spikes_partial = get_spikes(an, n_fiberPerInd);
                    if an.n_fibers_per_channel == 1
                        % fast enough
                        an.spikes_sparse = sparse(spikes_partial); 
                    else
                        % very, very slow
                        an.spikes_sparse(k:an.n_fibers_per_channel:end) = sparse(spikes_partial); 
                    end
                end
                return
            end
            
            spa_ANspikes = sparse(an.n_fibers .* size(an.prob_release,1), size(an.prob_release,2));
            for kk = 1:(an.n_fibers / n_fiberPerInd)
                % strides 
                cind = kk - 1 + 1:(an.n_fibers / n_fiberPerInd):an.n_fibers;
                spikes = get_spikes(an, n_fiberPerInd);
                for pp = 2:an.psth
                    spikes = spikes + get_spikes(an, n_fiberPerInd);
                end
                
                % This is slow, but haven't seen faster:
                spa_ANspikes(cind, :) = sparse(spikes/an.psth); %#ok
            end
            an.spikes_sparse = spa_ANspikes;
        end
        
        function spikes = get_spikes(an, n_fiberPerInd)
            algo = 1;
            print_stuff = 0;
            spikes =  MAP_AN_generatePoissonSpikeTrains(n_fiberPerInd, an.lengthAbsRefractory, an.prob_firing, algo, print_stuff);
        end
        
    end
end