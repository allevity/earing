classdef AsrExperiment < RunObject
    
    properties (SetAccess=private)
        datasets DatasetAsr % probably just one
        models EarSumner2002 % array of Ear models 
        % (matlab forces declaration of actual class, not just superclass Ear...)
        processings ProcessingAsr % array of Processing
        htks Htk  % array of Htk
    end
    
    properties (Access=private)
        runs SingleRunAsr % array of SingleRun
        summary struct % keep constructor's inputs
    end
    
    methods (Access=public)
        
        function obj = AsrExperiment(datasets, models, processings, htks)
            obj.init_datasets(datasets);
            obj.init_models(models);
            obj.init_processings(processings);
            obj.init_htks(htks);
            obj.summary = struct(...
                'datasets', datasets, 'models', models, ...
                'processings', processings, 'htks', htks);
            obj.init_runs();
            
            obj.name = str(obj);
        end
       
        function run(experiment, results)
            if results.has_run(experiment)
                return
            end
            for dataset = experiment.datasets
                for ear = experiment.models
                    for processing = experiment.processings
                        for htk = experiment.htks
                            single = experiment.fetch_from_runs(dataset, ear, processing, htk);
                            
                            for wav_file = dataset.data.input
                                wav_path = fullfile(dataset.folder.input, wav_file.name);
                                wav_type = wav_file.type;
                        
                                % Get correct SingleRun; it remembers usr files
                                single.wav2usr(wav_path, wav_type);
                            end
                            % Once all files were done for this ear, we run htk
                            single.run();
                            results.add(single).save();
                        end
                    end
                end
                results.add(experiment).save();
            end
        end
        
    end
    
    methods (Access=private)  
        
        function single = fetch_from_runs(obj, dataset, ear, processing, htk)
            % returns the SingleRun object corresponding to inputs
            single_ = SingleRunAsr(dataset, ear, processing, htk);
            name_compared = arrayfun(@(single)strcmp(single.name, single_.name), obj.runs);
            assert(sum(name_compared)==1, sprintf('Should be 1 instead of %d', sum(name_compared)));
            single = obj.runs(name_compared);
        end
        
        function init_datasets(obj, dataset)
            d = DatasetAsr(dataset);
            d.init();
            obj.datasets(end+1) = d.reinitialise_with_outputs();
            fprintf('ASRExp: init_dataset: Dataset %s initialised\n', d.name);
        end
        
        function init_models(obj, models)
            % Ear model (like: @EarSumner2002)
            ear = models.model; 
            
            % Fixed params
            base_ear_params = struct(...
                'ome', models.ome, ....
                'bm', models.bm, ...
                'cilia', models.cilia, ...
                'an', models.an); 
            
            % Varying  params
            % c = combvec(models.ca_thresh, models.gmaxca, models.db, models.psth);
            c = combvec(...
                models.db, ...
                models.synapse.n_fibers_per_type_per_channel, ...
                models.synapse.presynapse.gmaxca, ...
                models.synapse.presynapse.ca_thresh);
            for k = 1:size(c,2)
                ear_params = base_ear_params;
                ear_params.db = c(1, k);
                ear_params.synapse.n_fibers_per_type_per_channel = c(2, k);
                ear_params.synapse.presynapse.gmaxca = c(3, k);
                ear_params.synapse.presynapse.ca_thresh = c(4, k);
                obj.models(end+1) = ear(ear_params);
            end
            
            
        end
        
        function init_processings(obj, processings)
            % Fixed params
            base_processing = struct(...
                'window', processings.window...
                );
            % Varying params: 
            if ischar(processings.features)
                processings.features = {processings.features};  % should already be the case tho
            end
            
            features_ind = 1:length(processings.features);
            
            c = combvec(processings.rate_window_duration, features_ind);
            
            for k = 1:size(c,2)
                processing = base_processing;
                processing.rate_window_duration = c(1,k);
                processing.features = processings.features(c(2,k));
                obj.processings(end+1) = ProcessingAsr(processing);
            end
        end
        
        function init_htks(obj, htks)
            % Fixed params
            base_htk = struct(...
                'n_states', htks.n_states,    ...
                'n_mixtures', htks.n_mixtures ...
                );
          
            htk = base_htk;    
            obj.htks(end+1) = Htk(htk);
        end
        
        function init_runs(obj)
            % Used by run() to agregate usr files
            for dataset = obj.datasets
                for ear = obj.models
                    for processing = obj.processings
                        for htk = obj.htks
                            obj.runs(end+1) = SingleRunAsr(dataset, ear, processing, htk);
                        end
                    end
                end
            end
        end
        
        function s = str(obj)
            s = '';
            l = {'datasets', 'models', 'processings', 'htks'};
            for ll = 1:length(l)
                for k = 1:length(obj.(l{ll}))
                    s = strcat(s, upper(l{ll}), obj.(l{ll})(k).name, '_');
                end
            end
        end
                    
        function clean(obj)
            fprintf('CLEAN TO IMPLEMENT %s\n', obj.name);
        end
        
    end
    
end