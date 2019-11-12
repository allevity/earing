classdef Dataset < RunObject
    
    properties
        folder = struct('input', '', 'output', '')
        set_name string
        data = struct('input', struct([]), 'output', struct([]))
        
        n_train double = 50
        n_test double = 25
        n_development double = 5
    end
    
    properties (Access = private)
        changes struct  % how to change datasets
    end
    
    methods
        function obj = Dataset(params)
            obj.change_parameters(params);
            obj.name = sprintf('%sT%dt%dd%d', obj.set_name, obj.n_train, obj.n_test, obj.n_development);
        end
        
        function new_obj = reinitialise_with_outputs(obj)
            obj_class = class(obj);
            obj_constructor = str2func(obj_class);
            new_obj = obj_constructor(obj);
            new_obj.('data').input = obj.('data').output;
            new_obj.('data').output = struct([]);
            new_obj.('folder').input = obj.('folder').output;
            new_obj.('folder').output = '';
        end
    end
    
end