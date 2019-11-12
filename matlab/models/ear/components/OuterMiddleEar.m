classdef OuterMiddleEar < RunObject
    
    % Models the transformation sound pressure->stapes velocity
   
    properties
        % Removed one '0 1  700 30000' line to follow Mark  (5 lines initially)
        externalResonanceFilters = [...
            0 1 4000 25000;
            0 1 4000 25000;
            0 1  700 30000;
            0 1  700 30000]
        stapes_scalar = 1.4e-10
        
        gain_scalar double
        external_filter_a cell
        external_filter_b cell
        stapes_velocity  % output
        % extEarPressure = zeros(1,signal_length); % no use found
    end
    
    methods
        function obj = OuterMiddleEar(params)
            obj.change_parameters(params);
            obj.parameters2name();
            obj.init_gain_scalar();  % has to be after in case size externalFilters changes
        end
        
        function run(o, stimulus, fs)
            o.init_external_filters(fs);
            o.stapes_velocity = o.apply_filters(stimulus);
        end
        
        function stapes_velocity = apply_filters(ome, stimulus)
            y = stimulus; % input to the filter in Pascals
            nOMEExtFilters = length(ome.external_filter_b);
            
            for n=1:nOMEExtFilters
                y = filter(ome.external_filter_b{n}, ome.external_filter_a{n}, y); 
                y = y * ome.gain_scalar(n); 
            end
            
            stapes_velocity = y * ome.stapes_scalar;
        end
        
        function init_gain_scalar(ome)
            gain_dBs = ome.externalResonanceFilters(:, 1);
            ome.gain_scalar = 10 .^ (gain_dBs / 20);
        end
        
        function [ExtFilter_a, ExtFilter_b] = init_external_filters(ome, fs)
            nyquist = fs / 2;
            % external ear resonances
            ext_res_filters = ome.externalResonanceFilters;
            [nOMEExtFilters, ~] = size(ext_res_filters);
            
            % details of external (outer ear) resonances
            filterOrder = ext_res_filters(:, 2);
            lowerCutOff = ext_res_filters(:, 3);
            upperCutOff = ext_res_filters(:, 4);
            
            if nyquist < max(upperCutOff)
                upperCutOff = nyquist * ones(size(ext_res_filters, 1), 1) - 1;
            end
            
            % external resonance coefficients
            ExtFilter_b = cell(nOMEExtFilters,1);
            ExtFilter_a = cell(nOMEExtFilters,1);
            for idx = 1:nOMEExtFilters
                [b, a] = butter(filterOrder(idx), [lowerCutOff(idx) upperCutOff(idx)] / nyquist);
                ExtFilter_b{idx} = b;
                ExtFilter_a{idx} = a;
            end
            ome.external_filter_a = ExtFilter_a;
            ome.external_filter_b = ExtFilter_b;
        end
        
        function clean(ome)
            ome.stapes_velocity = [];
        end
        
        function plot(ome)
            % Plot the stapes velocity
            plot(ome.stapes_velocity)
        end
    end
end