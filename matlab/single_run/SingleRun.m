classdef (Abstract) SingleRun < RunObject
  
    properties (Abstract)
        dataset Dataset
        model Model
        processing Processing
    end
    
    properties 
        output = struct([]) % contains paths towards output files
    end
    
    methods
        function this = SingleRun(dataset, ear, processing)
            this.dataset = dataset;
            this.ear = ear;
            this.processing = processing;
        end
    end
end