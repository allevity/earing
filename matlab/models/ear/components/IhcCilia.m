classdef IhcCilia < RunObject
    
    % IHC cilia activity and receptor potential
    
    % Parameters taken from Sumner et al. 2002 "A revised model of the
    % inner-hair cell and auditory-nerve complex"
    
    % N.B. Displacement sensitivity s1 was erroneously published as 5e-7 and is
    % corrected here (5e-9) (Meddis, 2006)
    
    properties 
        dt double  % Time frame: 1/fs
        
        % Receptor Potential parameters
        Et   =  0.1;      % endocochlear potential (V)
        Ek   = -70.45e-3; % potassium reversal potential (V)
        Ekp double
        G0   =  1.974e-9; % resting conductance
        Gk   =  18e-9;    % potassium conductance (S)
        Rpc  =  0.04;     % correction, Rp/(Rt + Rp)
        Gmax =  8e-9;     % max. mechanical conductance (S)
        s0   =  85e-9;    % displacement sensitivity (/m)
        u0   =  7e-9;     % displacement offset (m)
        s1   =  5e-9;     % displacement sensitivity (/m)
        u1   =  7e-9;     % displacement offset (m)
        Cab  =  6e-12;    % total capacitance (F)
        tc   =  2.13e-3;  % cilia/BM time constant (s)
        C    =  16;       % gain factor (dB)
        C_s  double       % scalar version of C  % used 
        Ga double         % leakage
        Gu double
        restingCiliaCond double
        restingV double
        
        cilia_displacement double % first run part output
        run_cilia_displacement = @run_CD_mex  % fastest option; requires mex
        
        receptor_potential double % second run part output
        run_receptor_potential = @run_RP_mex  % fastest (x80 run_RP_for_loop)
    end
    
    methods
        function cilia = IhcCilia(params)
            cilia.C_s = 10 ^ (cilia.C / 20);
            cilia.init_restingV();
            cilia.init_params(params);
        end
        
        function clean(cilia)
            cilia.cilia_displacement = [];
            cilia.receptor_potential = [];
            cilia.Gu = [];
        end
        
        function run(o, bm_velocity, fs)
            [n_BFs, signal_length] = size(bm_velocity);
            
            % init
            o.dt = 1/fs;
            o.init_cilia_displacement(n_BFs, signal_length);
            % o.C_s = 10 ^ (o.C / 20); % Scalar conversion; used later? should be calculated later then
            o.init_receptor_potential(n_BFs, signal_length);
            
            % Apply gain
            bm_velocity_g = bm_velocity * o.C_s; 
            
            % calculate cilia displacement
            [uNow,cParam,A_] = get_CD_inputs(o, bm_velocity_g);
            o.run_cilia_displacement(o, uNow,cParam,A_);
            
            % calculate receptor potential
            o.init_Gu();
            
            [IHC_Vnow, C_, A_] = o.get_RP_inputs();
            o.run_receptor_potential(o, IHC_Vnow, C_, A_);
        end
        
        function plot(cilia)
           imagesc(cilia.cilia_displacement)
        end
    end
    
    methods (Access=private)
        
        %%%%%%% RECEPTOR POTENTIAL %%%%%%%
        
        function init_receptor_potential(o, n_BFs, signal_length)
            o.receptor_potential = zeros(n_BFs, signal_length);
        end
        
        function [IHC_Vnow, C, A] = get_RP_inputs(o)
            n_BFs = size(o.cilia_displacement, 1);
            IHC_Vnow = o.restingV * ones(n_BFs,1);
            C = 1 + (- o.Gk - o.Gu) * o.dt / o.Cab;
            A = (o.Gu .* o.Et + o.Gk * o.Ekp) * o.dt / o.Cab;
        end
        
        function run_RP_mex(o, IHC_Vnow, C_,A_)
            MAP_AN_forLoop_mex(o.receptor_potential, IHC_Vnow, C_,A_);
        end
        
        function run_RP_for_loop(o, IHC_Vnow, C_,A_)
            % If there's a problem with the mex file MAP_AN_forLoop_mex, use this instead (slower)
            [~, signal_length] = size(o.cilia_displacement);
            for idx = 1:signal_length
                IHC_Vnow = IHC_Vnow .* C_(:,idx) + A_(:,idx);
                o.receptor_potential(:,idx) = IHC_Vnow;
            end
        end
        
        %%%%%%% CILIA_DISPLACEMENT %%%%%%%
        
        function init_cilia_displacement(o, n_BFs, signal_length)
            o.cilia_displacement = zeros(n_BFs,signal_length);
        end
        
        function [uNow,cParam,A] = get_CD_inputs(o, DRNLresponse)
            [n_BFs, ~] = size(o.cilia_displacement);
            A = o.dt * DRNLresponse;    % Matrix
            uNow = zeros(n_BFs, 1);     % Vector
            cParam = (1-o.dt/o.tc);     % Double
        end
        
        function run_CD_mex(o, uNow,cParam,A)
            MAP_AN_forLoop_mex(o.cilia_displacement,uNow,cParam,A);
        end
        
        function run_CD_fft(o, uNow,cParam,A)
            [~, signal_length] = size(o.cilia_displacement);
            vectTc = cParam.^(0:1:(signal_length - 1));
            o.cilia_displacement = fftTrick(A,vectTc)+(bsxfun(@times,uNow,(vectTc))*cParam);
            
        end
        
        function run_CD_for_loop(o,uNow,cParam,A)
            [~, signal_length_] = size(o.cilia_displacement);
            for idx = 1:signal_length_
            
                % Faster in this form (x3) than for loop
                uNow = uNow * cParam + A(:, idx) ;
                o.IHCciliaDisplacement(:, idx) = uNow;
           
                % N.B. Corrected typo. Used to read (Note '_' in some uNows):
                %     u_Now = uNow + gbst.dt * (DRNLresponse(:, idx) - ...
                %             uNow / gbst.IHC_cilia_RPParams.tc);
                %     IHCciliaDisplacement(:, idx) = u_Now;
            end
        end
        
        %%%%%%%% OTHER %%%%%%%%
    
        function init_Gu(o)
            o.Gu = o.Ga + o.Gmax ./ ...
                (1+exp(-(o.cilia_displacement-o.u0)/o.s0).*...
                (1+exp(-(o.cilia_displacement-o.u1)/o.s1)));
        end
        
        function init_ekp(o)
            o.Ekp = o.Ek + o.Et * o.Rpc;
        end
        
        %%%%%%%% RESTING V %%%%%%%%
        
        function init_ga(o) 
            o.Ga = o.G0 - o.Gmax ./ (1 + exp(o.u0 / o.s0) .* ...
                (1 + exp(o.u1 / o.s1))); 
        end
        
        function init_restingCiliaCond(o)
            % IHC apical conductance (Boltzman function)
            o.init_ga();
            o.restingCiliaCond = ...
                o.Ga + o.Gmax ./ (1 + exp(o.u0 / o.s0) .* ...
                (1 + exp(o.u1 / o.s1)));
        end
         
        function init_restingV(o)
            o.init_restingCiliaCond();
            o.init_ekp();
            Gu0 = o.restingCiliaCond;
            o.restingV = (o.Gk * o.Ekp + Gu0 * o.Et) / (Gu0 + o.Gk);
        end
        
        function s = str(o)
            s = sprintf('Ga%.2f_Gu%.2f_rc%.2f_rv%.2f_', o.Ga, o.Gu, o.restingCiliaCond, o.restingV);
        end
        
    end
end