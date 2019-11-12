classdef AnIhcSynapse < IhcPreSynapse
    
    % Compute the vesicle release rate for each fiber type at each BF

    properties
        dt                    % time frame: 1/fs
        
        y =	10                % replenishment rate
        l =	2580              % loss rate
        x =	66.3              % reprocessing rate
        r =	6580              % recovery rate
        M =	10                % maximum vesicles at synapse
        refractory_period = 0.75e-3 % refractory period
        spikesTargetSampleRate = 100000
        n_fibers_per_type_per_channel =	2        % set to 0 for output_mode='PROB'
        
        TWdelay = 0.000;      % delay before stimulus first spike
        tauCas % vectorised version of presynaps.tauCa (one tauCa value per BF)
        
        synapticCa
        presynapse
        
        mICaCurrent
        % CaCurrent
        mICa  % output run 1
        ICaCurrent
        kt0
        n_AN_fiber_types 
        n_AN_channels 
        n_AN_fibers_per_type
        n_AN_fibers  % = n_AN_channels * nFibersPerChannel * n_AN_fiber_types
        
        run_mICa = @run_mICa_mex % faster
        run_synapticCa = @run_SCa_mex  % fastest
        vesicle_release_rate  % output 
        
    end
    
    methods
        function obj = AnIhcSynapse(params)
            if ~exist('params', 'var') || ~isfield(params, 'presynapse')
                params.presynapse = struct();
            end
            obj = obj@IhcPreSynapse(params.presynapse); % inherit parameters
            obj.change_parameters(params);
            obj.parameters2name();
        end
        
        function clean(synapse)
            synapse.synapticCa = [];
            synapse.mICaCurrent = [];
            synapse.mICa = [];
            synapse.ICaCurrent = [];
            synapse.kt0 = [];
            synapse.vesicle_release_rate = [];
        end
        
        function run(o, ihc_receptor_potential, ihc_cilia_restingV, fs)
            [n_BFs, signal_length] = size(ihc_receptor_potential);
            % init
            o.dt = 1/fs;
            o.init(signal_length, ihc_cilia_restingV, n_BFs);
            
            % Replicate IHC_RP for each fiber type to obtain the driving voltage
            Vsynapse = repmat(ihc_receptor_potential, o.n_AN_fiber_types, 1);
            
            % mICa
            [c, mICaINF] = o.get_mICa_inputs(Vsynapse);
            o.run_mICa(o, c, mICaINF);
            
            % synaptic Ca
            [CaCurrent, C, ICa] = o.get_SCa_inputs(Vsynapse);
            o.run_synapticCa(o, CaCurrent, C, ICa);
            
            o.init_vesicle_release_rate();
        end
        
        function plot(synapse)
           imagesc(synapse.vesicle_release_rate);
        end
    end
    
    methods (Access=private)
        
        %%%%%%%%% VESICLE RELEASE RATE
        
        function init_vesicle_release_rate(o)
            o.vesicle_release_rate = max(o.z * (o.synapticCa .^ o.power ...
                - o.ca_thresh ^ o.power), 0);
        end
        
        %%%%%%%%% mICa
        
        function [c, mICaINF] = get_mICa_inputs(o, Vsynapse)
            c = 1 - o.dt / o.tauM;
            % Fraction of channels open
            mICaINF = 1 ./ (1 + exp(-o.gamma  * Vsynapse) / o.beta);
        end
        
        function run_mICa_mex(o, c, mICaINF)
            MAP_AN_forLoop_mex(o.mICa, o.mICaCurrent, c, mICaINF * (1-c))
        end
        
        function run_mICa_fft(o, c, mICaINF)
            signal_length = size(obj.mICa, 2);
            A = mICaINF  * o.dt / o.presynapse.tauM;
            vectTc = c.^(0:1:(signal_length-1));
            o.mICa = bsxfun(@times, o.mICaCurrent, (vectTc)*c) + fftTrick(vectTc,A);
        end
        
        function run_mICa_forloop(o, c, mICaINF)
            for idx = 1: signalLength
                o.mICaCurrent = o.mICaCurrent * c + mICaINF(:,idx) * (1 - c);
                o.mICa(:, idx) = o.mICaCurrent;
            end
        end
        
        %%%%%%%% synaptic Ca
    
        function [CaCurrent, C, ICa] = get_SCa_inputs(o, Vsynapse)
            CaCurrent = -o.ICaCurrent .* o.tauCa;
            C = 1 - o.dt ./ o.tauCa;            % vector
            ICa = (o.gmaxca * o.mICa .^ 3) .* (Vsynapse - o.ECa);
        end
        
        function run_SCa_mex(o, CaCurrent, C, ICa)
            A = bsxfun(@times, ICa, 1-C);       % matrix
            MAP_AN_forLoop_mex(o.synapticCa, CaCurrent, C, A);
            o.synapticCa = -o.synapticCa;
        end
        
        function run_SCa_fft(o, CaCurrent, C, ICa)
            signal_length = size(obj.mICa, 2);
            A = bsxfun(@times, ICa, 1-C);       % matrix
            vectTc = bsxfun(@power,C,(0:1:(signal_length-1))); % vector
            o.synapticCa = bsxfun(@times,CaCurrent.*C,vectTc) - fftTrick(vectTc,A);
        end
        
        function run_SCa_forloop(o, CaCurrent, ~, ICa)
            signal_length = size(obj.mICa, 2);
            for idx = 1:signal_length
                CaCurrent = CaCurrent + (ICa(:, idx) - CaCurrent) .* (o.dt ./ o.tauCa);
                o.synapticCa(:,idx) = -CaCurrent;
            end
        end
        
        %%%%%%%%
      
        function init(o, signal_length, ihc_cilia_restingV, n_BFs)
            n_AN_fiber_types_ = length(o.tauCa); % TODO: this is strange though...
            n_AN_channels_ = n_AN_fiber_types_ * n_BFs;

            o.synapticCa = zeros(n_AN_channels_, signal_length);
            o.mICa = zeros(n_AN_channels_, signal_length);
            
            % tauCas vector is established across channels to allow vectorization
            %  (one tauCa per channel).
            %  Do not confuse with gbst.ANtauCas vector (one per fiber type)
            o.tauCas = repmat(o.tauCa, n_BFs, 1);
            o.tauCas = reshape(o.tauCas, n_AN_channels_, 1);
            
            % presynapse startup values (vectors, length:nANchannels)
            % proportion (0 - 1) of Ca channels open at gbst.IHCrestingV
            o.mICaCurrent = (1 / (1 + exp(-o.gamma * ihc_cilia_restingV) / o.beta)) .* ...
                ones(n_BFs * n_AN_fiber_types_,1);
            
            % corresponding startup currents
            o.ICaCurrent = (o.gmaxca * o.mICaCurrent .^ 3) * (ihc_cilia_restingV  -o.ECa);
            CaCurrent = -o.ICaCurrent .* o.tauCa;
            
            if o.n_fibers_per_type_per_channel == 0 
                % will only run AN_prob
                n_fibers_per_type_per_channel_ = 1;
            else
                % will only run AN_spikes
                n_fibers_per_type_per_channel_ = o.n_fibers_per_type_per_channel; 
            end
            n_AN_fibers_per_type_ = n_AN_channels_ * n_fibers_per_type_per_channel_;

            % vesicle release rate at startup (one per channel)
            % kt0 is used only at initialisation
            kt0_ = o.z * (CaCurrent .^ o.power);
            
            % kt0  is initial release rate; used to multiply size by n_fibers_per_type_per_channel_
            assert(size(kt0_, 1)==n_AN_channels_, sprintf('%d != %d', size(kt0_, 1), n_AN_channels_))
            
            o.kt0 = kt0_;
            o.n_AN_fiber_types = n_AN_fiber_types_;
            o.n_AN_fibers_per_type = n_AN_fibers_per_type_;
            o.n_AN_channels = n_AN_channels_; 
        end
        
    end
end