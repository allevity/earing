classdef Ear < Model
    
    % Gathers ear components
    % Subclasses should implement run(). See EarSumner2002.m
    
    properties (SetAccess=private)
        ome OuterMiddleEar
        bm BasilarMembrane
        cilia IhcCilia
        synapse AnIhcSynapse
        an AuditoryNerve
    end
    
    methods
        function ear = Ear(params)    
            % Initialise components with parameter changes
            if ~exist('params', 'var'), params=struct(); end 
            sub = {'ome','bm','cilia','synapse','an'};
            for k =1:length(sub)
                if isfield(params, sub{k})
                    continue
                end
                params.(sub{k}) = [];
            end
            ear = ear@Model(params);
            ear.ome     = OuterMiddleEar(params.ome);
            ear.bm      = BasilarMembrane(params.bm);
            ear.cilia   = IhcCilia(params.cilia);
            ear.synapse = AnIhcSynapse(params.synapse);
            ear.an      = AuditoryNerve(params.an);
            ear.parameters2name();
        end
        
        function run(ear, fun, wav_path)
            fun(ear, wav_path);
        end
           
        function clean(ear)
            ear.ome.clean()
            ear.bm.clean()
            ear.cilia.clean()
            ear.synapse.clean()
            ear.an.clean()
        end
        
    end
end
