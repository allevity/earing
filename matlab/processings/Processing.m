classdef (Abstract) Processing < RunObject
    
    properties 
        features cell
        parameters 
        dataset_processed
    end
    
    methods
        function obj = Processing(processing_params)
            obj.features = processing_params.features{1}(2:end);
            obj.parameters = processing_params;
        end
        
        function out = run(obj, data)
            % proba_firing_or_spikes
            out = ProcessingAsr(obj.parameters).run(obj.features, data);
        end
        
        function clean(processing)
            processing.dataset_processed = [];
        end
    end
    
    
    
end