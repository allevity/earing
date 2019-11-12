classdef SingleRunAsr < RunObject
    
    properties
        dataset DatasetAsr
        model Ear
        processing ProcessingAsr
        htk Htk
        
        from_ear function_handle % specifies whether extract spikes/proba
        output = struct([])  % contains paths towards output files
        output_folder_name
        output_folder
    end
    
    properties (SetAccess=private)
        result  % set at the end of a run
    end
    
    methods
        function this = SingleRunAsr(dataset, model, processing, htk)
            this.dataset = dataset;
            this.model = model;
            this.processing = processing;
            this.htk = htk;
            this.name = str(this);
            switch processing.input_type
                % wav2spikes returns sparse spikes (unless psth>1, then double)
                % wav2prob gives proba with refractoriness if was asked in model
                case 'SPIKE', this.from_ear = @wav2spikes;
                case 'PROB', this.from_ear = @wav2prob;
                otherwise, error(this.processing.input_type)
            end
            this.output_folder_name = this.get_folder_name();
        end
        
        function run(this)
            % run htk on usr
            n_feat = this.output(1).n_features;
            assert(sum(arrayfun(@(k)double(k.n_features ~= n_feat), this.output))==0)
                
            this.htk.run(this.output_folder, n_feat)
            this.result = this.htk.accuracy;
            this.clean()
        end
        
        function wav2usr(this, wav_path, usr_type)
            if nargin < 3
                usr_type = '';
            end
            [input_folder, wav_name] = fileparts(wav_path);
            
            parent_folder = fileparts(input_folder);
            % this.name is way too long; using hash function to cut it
            output_folder_ = fullfile(parent_folder, this.output_folder_name);
            assert(isempty(this.output_folder) || strcmp(this.output_folder, output_folder_))
            this.output_folder = output_folder_;
            
            if ~exist(output_folder_, 'dir')
                mkdir(output_folder_);
            end
            if ~isempty(usr_type)
                output_folder_ = fullfile(output_folder_, usr_type);
                if ~exist(output_folder_, 'dir')
                    mkdir(output_folder_);
                end
            end
            
            usr_name = strrep(wav_name, '.wav', '');  % in case
            usr_path = fullfile(output_folder_, strcat(usr_name, '.usr'));
            if exist(usr_path, 'file') % && ~ isempty(this.dataset.data.output)
                % if ismember(usr_path, {this.dataset.data.output.path})    
                if isfield('path', this.output) && ismember(usr_path, {this.output.path})
                    % Clear
                    return
                else
                    % Was run and saved, but object got reinitialised
                    data = this.htk.load(usr_path);
                    k = length(this.output);
                    this.output(k+1).path = usr_path;
                    this.output(k+1).name = usr_name;
                    this.output(k+1).type = usr_type;
                    this.output(k+1).n_features = size(data, 2);  % here, size(,2)=n_features
                    return
                end
            end
            fprintf('SingleRunAsr: Run model on %s\n', wav_path);
            
            % Run model on waveform (skip if already done; spikes or proba)
            % neural_data = this.model.run(this.model, this.from_ear, wav_path);
            neural_data = this.from_ear(this.model, wav_path);
            
            % Process proba of firing (skip if already done)
            processed_neural_data = this.processing.run(neural_data);
            
            % Save in usr file for HTK
            this.htk.save(usr_path, processed_neural_data);
            
            % Keep output (can't save in this.htk unless Htk objects are
            % copied when SingleRun objects are initialised (otherwise they
            % will share this data).
            k = length(this.output);
            this.output(k+1).path = usr_path;
            this.output(k+1).name = usr_name;
            this.output(k+1).type = usr_type;
            this.output(k+1).n_features = size(processed_neural_data, 1); % here, size(,1)=n_features
            
        end
       
    end
    
    methods (Access=private)
        function s = str(this)
            s = sprintf('%s_%s_%s_%s', ...
                this.dataset.name, this.model.name, ...
                this.processing.name, this.htk.name);
        end
        
        function clean(this)
            this.model.clean()
            this.processing.clean()
        end
        
        
        function s = get_folder_name(this)
            s = this.dataset.name;
            % hash value for simplicity
            s = strcat(s, hash(this.name, 'SHA256'));
            s = char(s); % avoid string
        end
        
        
        
    end
end