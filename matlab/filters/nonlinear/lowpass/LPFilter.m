classdef LPFilter < NLFilter
    % A Low-Pass Filter
    
    methods 
        function lp = LPFilter(params, linear_CF, nonlin_CF)  
            lp = lp@NLFilter(params, linear_CF);
            lp.linCFs = linear_CF;
            lp.nonlinCFs = nonlin_CF;
            lp.linOrder = 2;
            lp.linCascade = 4; 
            lp.nonlinOrder = 2;
            lp.nonlinCascade = 4;
            if exist('params', 'var') && isfield('params', 'lp')
                lp.init_params(params.lp);
            end
        end
       
        function init(o, fs)
            nyquist = fs / 2;
            assert(~isempty(o.linCFs));
            
            % Linear
            [o.lin_a, o.lin_b] = o.get_low_pass_filters(o.linCFs, o.linOrder, nyquist);
            
            % Nonlinear
            [o.nonlin_a, o.nonlin_b] = o.get_low_pass_filters(o.nonlinCFs, o.nonlinOrder, nyquist);
        end
        
        
        function [a, b, cutoff] = get_low_pass_filters(lp, cf, low_pass_order, nyquist)
            % Low pass filters; CF used as cutoff frequencies (nonlinCFs=best_frequencies)
            cutoff = cf;
            n_BFs = length(lp.nonlinCFs);
            
            b = zeros(n_BFs, low_pass_order + 1);
            a = zeros(n_BFs, low_pass_order + 1);
            
            for i = 1: length(cutoff)
                [b(i, :), a(i, :)] = butter(low_pass_order, cutoff(i) / nyquist);
            end
            
        end
    end
end