classdef DRNLFilter < RunObject 
    % Applies and sums linear and nonlinear filters
    
    properties 
        gt GammaToneFilter
        lp LPFilter
        frequencies 
        response
    end
    
    properties (Access=private)
        % DRNL nonlinear path: broken stick compression
        % Parameters taken from Sumner & O'Mard 2003 "A nonlinear filter-bank 
        %  model of the guinea-pig cochlear nerve: Rate responses". 
        p0 = struct('BWnl', 0.8,  'a', 1.87, 'b', -5.65,  'CFlin', 0.339, 'BWlin', 1.3,  'Glin', 5.68);
        m  = struct('BWnl', 0.58, 'a', 0.45, 'b',  0.875, 'CFlin', 0.895, 'BWlin', 0.53, 'Glin', -0.97);
    end
    
    methods
        function drnl = DRNLFilter(params, frequencies)  
            if ~isfield(params, 'drnl'), params.drnl = struct(); end
            drnl.frequencies = frequencies;
            drnl.gt = GammaToneFilter(params.drnl, frequencies);
            drnl.gt.init_linear(drnl.p0, drnl.m)
            drnl.lp = LPFilter(params.drnl, drnl.gt.linCFs, frequencies);
            drnl.parameters2name();
        end
        
        function init(drnl, fs)
            drnl.gt.init_a_b(fs);
            drnl.lp.init(fs);
        end
        
        function run(drnl, n_BFs, input_velocity, input_gain) % stapesVelocity, stapes_scalar_gain
            drnl.response = zeros(n_BFs, length(input_velocity));
            for BFno = 1:n_BFs
                drnl.response(BFno, :) = drnl.apply_lin_nonlin_filters(BFno, input_velocity, input_gain);
            end
        end
    end
    
    methods (Access=private)
        
        function out = apply_lin_nonlin_filters(drnl, BFno, input_velocity, input_gain)
            linear_vel = drnl.linear_path(BFno, input_velocity); 
            nonlin_vel = drnl.nonlinear_path(BFno, input_velocity, input_gain);
            out = linear_vel + nonlin_vel;
        end
        
        function out = nonlinear_path(drnl, BFno, input_velocity, input_gain)
            y = input_velocity / input_gain;
            out = input_velocity;
            
            % First gammatone filter 
            out = drnl.apply_n_times(@drnl.nonlin_filter, drnl.gt, out, BFno, drnl.gt.nonlinCascade);
            
            % Compression
            out = drnl.apply_broken_stick(drnl.gt.a(BFno), drnl.gt.b(BFno), drnl.gt.c, y, out);
            
            % Second filter (gammatone+lowpass)
            out = drnl.apply_n_times(@drnl.nonlin_filter, drnl.gt, out, BFno, drnl.gt.nonlinCascade);
            out = drnl.apply_n_times(@drnl.nonlin_filter, drnl.lp, out, BFno, drnl.lp.nonlinCascade);
        end
        
        function out = linear_path(drnl, BFno, stapesVelocity)
            % Linear gain
            % out = bsxfun(@times, stapesVelocity, drnl.gt.linGain');
            out = stapesVelocity * drnl.gt.linGain(BFno);
            
            % Filter
            out = drnl.apply_n_times(@drnl.lin_filter, drnl.gt, out, BFno, drnl.gt.linCascade);
            out = drnl.apply_n_times(@drnl.lin_filter, drnl.lp, out, BFno, drnl.lp.linCascade);
        end
        
    end
    
    methods (Static)
      
        function output = apply_n_times(filter_fun, my_filter, input, BFno, n_times)
            output = input; 
            for filterNum = 1:n_times
                output = filter_fun(my_filter, BFno, output);
            end
        end
        
        function y = apply_broken_stick(a, b, c, y, nonlin_output)
            % Mark's compression algorithm
            CtS = exp(log(a / b) / (c - 1));
            abs_x = abs(nonlin_output);
            y(abs_x < CtS)  = a * nonlin_output(abs_x < CtS);
            y(abs_x >= CtS) = sign(nonlin_output(abs_x >= CtS)) .* ...
                (b * abs_x(abs_x >= CtS) .^ c);
        end
        
        function lin_output = lin_filter(my_filter, BFno, lin_input)
            lin_output = filter(...
                my_filter.lin_b(BFno, :), ...
                my_filter.lin_a(BFno, :), ...
                lin_input);
        end
        
        function nonlin_output = nonlin_filter(my_filter, BFno, nonlin_output)
            nonlin_output = filter(...
                my_filter.nonlin_b(BFno, :), ...
                my_filter.nonlin_a(BFno, :), ...
                nonlin_output);
        end
    end
end
