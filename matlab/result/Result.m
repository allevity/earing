classdef Result < handle
    
    properties (SetAccess=private)
        file string
        
        SingleRunAsr SingleRunAsr
        AsrExperiment AsrExperiment
    end
    
    methods
        function obj = Result(input)
            global SPEECHRECOHTK
            if (isa(input, 'char') && strcmp(input, 'AsrExperiment')) || isa(input, 'AsrExperiment')
                result_folder = fullfile(SPEECHRECOHTK, 'results');
                if exist(result_folder, 'dir') == 0
                    mkdir(result_folder);
                end
                obj.file = fullfile(result_folder, 'asr_experiments.mat');
            else
                error(input)
            end
            
            obj.init()
        end
        
        function bool = has_run(obj, input)
            input_class = class(input);
            if ~isprop(obj, input_class)
                error(input_class);
            end
            
            for k = 1:length(obj.(input_class))
                if strcmp(obj.(input_class)(k).name, input.name)
                    bool = true;
                    return
                end
            end
            bool = false;
        end
        
        % function r = find(obj, x_struc)
        
        function obj = add(obj, res)
            result_class = class(res);
            if ~isprop(obj, result_class)
                error(result_class);
            end
            obj.(result_class)(end+1) = res;
        end
        
        function load(obj)
            o = load(obj.file);
            obj.SingleRunAsr = o.obj.SingleRunAsr;
            obj.AsrExperiment = o.obj.AsrExperiment;
        end
        
        function save(obj)
            fprintf('Saving obj to %s\n', obj.file);
            try
                save(obj.file, 'obj');
            catch ME
                disp(ME);
                try
                    % Happened to break because too big; prefer to continue
                    save(obj.file, 'obj');
                catch ME
                    disp(ME);
                    disp('Saving cancelled in this run');
                end
            end
        end
    end
    
    methods (Access=private)
        function init(obj)
            if exist(obj.file, 'file')
                obj.load();
            else
                obj.save();
            end
        end 
    end
    
end
