classdef LFilter < RunObject
    % Basic linear filter
    % Subclass `NLFilter` adds the nonlinear parameters

    properties
        lin_a
        lin_b
        linCFs
        linCascade = 3 % number of time to use this filter
        linBWs
        linOrder = 2 % order of the filter
        linGain  
        response
    end
    
    methods
        function obj = LFilter(params)
            if ~isfield(params, 'lin'), params.lin = struct(); end            
            obj.init_params(params.lin);
        end
    end
    
    methods (Static)
        function run()
            % Was simply not used
        end
    end
end