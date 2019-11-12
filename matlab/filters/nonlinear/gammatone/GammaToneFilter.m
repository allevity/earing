classdef GammaToneFilter < NLFilter
    % A Gamma-Tone nonlinear filter 
    
    properties
        dt
        n_BFs
        
        a
        b
        c = 0.1; % compression exponent
    end
    
    methods
        function gt = GammaToneFilter(params, frequencies) % drnl, best_frequencies, signal_length, fs)            
            gt = gt@NLFilter(params, frequencies);
            
            gt.nonlinCFs = frequencies;
            gt.n_BFs = length(frequencies);
            gt.init_params(params);
        end
        
        function init_linear(gt, p0, m)
            frequencies = gt.nonlinCFs;
            gt.a = gt.evaluateParameter(p0.a, m.a, frequencies);
            gt.b = gt.evaluateParameter(p0.b, m.b, frequencies);
            gt.nonlinBWs = gt.evaluateParameter(p0.BWnl, m.BWnl, frequencies);
            
            gt.linGain = gt.evaluateParameter(p0.Glin, m.Glin, frequencies); % linear path gain factor
            
            % linCF is not necessarily the same as nonlinCF
            gt.linCFs = gt.evaluateParameter(p0.CFlin, m.CFlin, frequencies);
            gt.linBWs = gt.evaluateParameter(p0.BWlin, m.BWlin, frequencies);
        end
        
        function init_a_b(o, fs)
            o.dt = 1/fs;
            
            % linear gammatone filter coefficients
            [o.lin_a, o.lin_b] = get_coefficients(o, o.linBWs', o.linCFs');
            
            % nonlinear gammatone filter coefficients
            [o.nonlin_a, o.nonlin_b] = get_coefficients(o, o.nonlinBWs', o.nonlinCFs');
        end
        
        function [GTlin_a, GTlin_b] = get_coefficients(obj, bw, cf)
            phi = 2 * pi * bw * obj.dt;
            theta = 2 * pi * cf * obj.dt;
            cos_theta = cos(theta);
            sin_theta = sin(theta);
            alpha = -exp(-phi).* cos_theta;
            b0 = ones(obj.n_BFs,1);
            b1 = 2 * alpha;
            b2 = exp(-2 * phi);
            z1 = (1 + alpha .* cos_theta) - (alpha .* sin_theta) * 1i;
            z2 = (1 + b1 .* cos_theta) - (b1 .* sin_theta) * 1i;
            z3 = (b2 .* cos(2 * theta)) - (b2 .* sin(2 * theta)) * 1i;
            tf = (z2 + z3) ./ z1;
            a0 = abs(tf);
            a1 = alpha .* a0;
            GTlin_a = [b0, b1, b2];
            GTlin_b = [a0, a1];
        end
    end
    
    methods (Static)
        function parameter = evaluateParameter(p0, m, BFlist)
            parameter = 10 .^ (p0 + m * log10(BFlist));
        end
    end
end