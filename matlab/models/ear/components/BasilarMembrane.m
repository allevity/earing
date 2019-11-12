classdef BasilarMembrane < RunObject
    
    % BM is represented as a list of locations identified by BF

    properties
        drnl DRNLFilter
        best_frequencies = 10.^(linspace(log10(100), log10(8000), 128))
        velocity  % output: BM velocity
    end
    
    methods  
        function bm = BasilarMembrane(params)
            if ~exist('params', 'var') || ~isfield(params, 'best_frequencies')
                params.best_frequencies = bm.best_frequencies;
            end
            bm.drnl = DRNLFilter(params, params.best_frequencies);  % params.drnl, params.best_frequencies
            bm.init_params(params);  % define best_frequencies
        end
        %             ear.bm.run(ear.ome.stapes_velocity, ear.ome.stapes_scalar, fs_);
        function run(bm, stapesVelocity, stapes_scalar_gain, fs)
            % Calculate separately the linear and nonlinear paths
            % Combine the two paths to obtain BM velocity
            % Each location (BF) is computed separately
            
            % Init arrays/params
            bm.drnl.init(fs)
            
            n_BFs = length(bm.best_frequencies);

            bm.drnl.run(n_BFs, stapesVelocity, stapes_scalar_gain);
            bm.velocity = bm.drnl.response;
        end
        
        function clean(bm)
            bm.velocity = [];
        end
        
        function plot(bm)
            % plot the BM velocity
            imagesc(bm.velocity); 
        end
    end
    
end