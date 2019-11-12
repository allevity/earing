classdef NLFilter < LFilter
    % Nonlinear Filter
    
    properties 
        nonlin_a
        nonlin_b
        nonlinCFs
        nonlinCascade = 3 % number of time to use this filter
        nonlinOrder % order of the filter
        nonlinBWs  
        
    end
    
    methods 
        function obj = NLFilter(params, best_frequencies)
            % if ~isfield(params, 'nl'), params.nl = struct(); end            
            obj = obj@LFilter(params);
            obj.nonlinCFs = best_frequencies;
            obj.init_params(params);
        end
        
    end
end