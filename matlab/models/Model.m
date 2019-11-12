classdef (Abstract) Model < RunObject
    
    properties
        parameters 
        input = struct('stimulus', [], 'fs', 100000)  % 100 kHz for model
        output
    end
    
    methods
        function obj = Model(params)
            % Can't initialise ear now because stimulus is required
            obj.parameters = params;
            obj.parameters2name();
        end
        
        function run_dataset(model, dataset)
            if model.has_run
                return
            end
            dataset.folder.output = model.get_output_folder(dataset);
            assert(isa(dataset, 'Dataset'), class(dataset));
            for k = 1:length(dataset.data.input)
                f_name = dataset.data.input(k).name;
                % Keep name and type
                mat_name = strrep(f_name, '.wav', '.mat');
                dataset.data.output(end+1).name = mat_name;
                dataset.data.output(end).type = dataset.data.input(k).type;
                % Run
                wav_file = fullfile(dataset.folder.input, f_name);
                mat_file = fullfile(dataset.folder.output, mat_name);
                model.wav2mat(wav_file, mat_file);
            end
            model.dataset_modelled = dataset.reinitialise_with_outputs();
            model.has_run = true;
        end
        
        function wav2mat(obj, wav_file, mat_file)
            if exist(mat_file, 'file')
                return
            end
            obj.wav2prob(wav_file)
            obj.prob2mat(mat_file)
        end
        
        function prob_firing = wav2prob(obj, wav_file)
            obj.run(wav_file)
            if obj.ear.an.refractoriness
                prob_firing = obj.ear.an.prob_firing_refractory;
            else
                prob_firing = obj.ear.an.prob_firing;
            end
        end
        
        function spikes = wav2spikes(obj, wav_file)
            obj.run(wav_file)
            spikes = obj.an.spikes_sparse;
        end
        
        function prob2mat(obj, mat_file)
            folder = fileparts(mat_file);
            if ~exist(folder, 'dir')
                mkdir(folder)
            end
            prob_firing = obj.ear.an.prob_firing;
            save(mat_file, 'prob_firing');
        end
        
        function run(obj, wav_file)
            obj.ear = Ear(obj.parameters, wav_file, @MAPparamsGP_Alban);
            obj.ear.run();
        end
        
        function output_folder = get_output_folder(obj, dataset)
            parent_folder = fileparts(dataset.folder.input);
            dataset.set_name.output = strcat(dataset.set_name.input, '_', obj.name);
            output_folder = fullfile(parent_folder, dataset.set_name.output);
        end
    end
        
    
end

