classdef DatasetAsr < Dataset
    
    properties (Access=private)
        changes = struct()
        max_duration = 15  % for wav files, in seconds
    end
        
    methods
        function obj = DatasetAsr(params)
            obj = obj@Dataset(params);
        end
        
        function init_folders(obj)
            global DATASET_PATHS   % startup.m
            assert(~isempty(DATASET_PATHS),'Variable DATASET_PATHS should be filled in startup.m')
            if strcmp(obj.set_name, 'CUAVE5')
                input_folder = DATASET_PATHS.CUAVE5;
            else
                % Add options here if needed
                error(obj.set_name)
            end
            obj.folder.input = input_folder;
            obj.folder.output = fullfile(fileparts(input_folder), char(obj.name));
        end
        
        function run(obj)  % copy files
            all_input_files = obj.data.input;
            if ~exist(obj.folder.output, 'dir')
                mkdir(obj.folder.output);
            end
            for k = 1:length(all_input_files)
                input = fullfile(obj.folder.input, obj.data.input(k).name);
                output = fullfile(obj.folder.output, obj.data.output(k).name);
                if exist(output, 'file')
                    continue
                end
                fprintf('Dataset>copy_files Copying file to %s\n', output);
                copyfile(input, output);
                
            end
        end
        
        function init(obj)
            
            obj.init_folders();  % .folder
            obj.init_changes();  % .data
            obj.init_subsets();  % .data
            obj.run()            % copy files
        end
    end
    
    methods (Access=private)
       
        function s = str(obj)
            s = sprintf('%sT%dt%dd%d', obj.set_name, ...
                obj.n_train, obj.n_test, obj.n_development);
        end
        
        function init_changes(obj)
            % For sTIMIT
            obj.changes.train.dvpt = {'DR3_MKXL0_SX15', 'DR3_MSFV0_SX452', 'DR4_MGJC0_SX75', 'DR7_MDED0_SX360','DR7_MBBR0_SX425'};
            % For CUAVE5
            % Turn chosen TEST files into DVPT or NOT (if too much silence)
            obj.changes.test.dvpt = {'s13m_13', 's15f_2', 's17m_6', 's18f_11', 's20f_1',...
                's22m_14', 's26f_13', 's34f_4', 's35m_13', 's36f_12', 's26f_13',...
                's26f_9', 's26f_4', 's16f_17', 's16f_6', 's15f_12', 's13m_8', 's12m_9'};
            % These contain too much silence, HTK gets confused
            obj.changes.test.not = {'s02m_4', 's02m_9', 's06f_11', 's06f_4'};
        end
        
        function init_subsets(obj)
            
            struct_array_ls = dir(fullfile(obj.folder.input, '*.wav'));
            n_T = 0;
            n_t = 0;
            n_d = 0;
            
            for k = 1:length(struct_array_ls)
                file = struct_array_ls(k).name;
                info = audioinfo(fullfile(obj.folder.input, file));
                duration = info.Duration;
                if duration > obj.max_duration
                    fprintf('DatasetAsr: %s too long (%f s), skipping.\n', file, duration)
                    continue
                end
                file_split = regexp(strrep(file, '.wav', ''), '_', 'split');
                file_type = file_split{1};
                speech_filename = [file_split{2} '_' file_split{3}];
                switch file_type
                    case 'TEST'
                        if ismember(speech_filename, obj.changes.test.dvpt)
                            if n_d < obj.n_development
                                obj.data.input(end+1).name = file;
                                obj.data.input(end).type = 'DVPT';
                                obj.data.output(end+1).name = ['DVPT_' speech_filename '.wav'];
                                obj.data.output(end).type = 'DVPT';
                                n_d = n_d + 1;
                            end
                        end
                        if ismember(speech_filename, obj.changes.test.not)
                            % Pass on this one
                            continue
                        end
                        if n_t >= obj.n_test
                            continue
                        end
                        obj.data.input(end+1).name = file;
                        obj.data.input(end).type = 'TEST';
                        obj.data.output(end+1).name = ['TEST_' speech_filename '.wav'];
                        obj.data.output(end).type = 'TEST';
                        n_t = n_t + 1;
                        
                    case 'TRAIN'
                        if n_T < obj.n_train
                            obj.data.input(end+1).name = file;
                            obj.data.input(end).type = 'TRAIN';
                            obj.data.output(end+1).name = ['TRAIN_' speech_filename '.wav'];
                            obj.data.output(end).type = 'TRAIN';
                            n_T = n_T + 1;
                        end
                    otherwise
                        error(file)
                end
                
            end
            assert(n_t == obj.n_test, 'Not enough tests')
            assert(n_T == obj.n_train, 'Not enough trains')
            assert(n_d == obj.n_development, 'Not enough developments')
        end
    end
    
end