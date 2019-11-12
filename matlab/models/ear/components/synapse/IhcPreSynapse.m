classdef (Abstract) IhcPreSynapse < RunObject
    % Each BF is replicated using a different fiber type to make a 'channel'
    % The number of channels is nBFs x nANfiberTypes
    % Fiber types are specified in terms of tauCa

    properties
        % Calcium control (more calcium, greater release rate)
        z      = 2e32;
        ECa    = 0.066;  % calcium equilibrium potential
        beta   = 400;    % determine Ca channel opening
        gamma  = 130;    % determine Ca channel opening
        tauM   = .75e-4; % calcium current time constant (s)
        tauCa  = [.75e-4]; %#ok % (length gives number of channel per type) 
        
        power    = 3;        % k(t) = z([Ca_2+](t)^IHCpreSynapseParams.power)
        gmaxca   = 8.0e-9;   % MSR fiber g_max^ca
        ca_thresh= 4.48e-11; % MSR fiber calcium threshold
    end
    
    methods
        function obj = IhcPreSynapse(params) 
            obj.change_parameters(params);
            obj.parameters2name();
        end
    end
end