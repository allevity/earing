classdef Htk < RunObject  
    
    properties 
        % Parameters
        n_states double = 5      % number of states for phoneme HMM model
        n_states_sil double = 5  % number of states for silence model
        n_mixtures double = 5    % number of mixtures
        n_features  % number of features of input (vectSize)
        
        flag_p_dvpt = -200:30:60  % all values to test on dvpt set
        flag_p double = 0.0
        flag_s double = 0.0
        
        n_passes_HERest_1 double = 8  % Number of passes for training steps
        n_passes_HERest_2 double = 6
        n_passes_HERest_with_sp = 3
        n_passes_HERest_aligned = 3
        n_passes_HERest_mix = 4
        
        % in TIMIT there are triphones in TEST that don't appear in TRAIN. Otherwise, we would use 1
        minimum_n_instances= 0
        
        par_type = 'USER'
        dataset = 'CUAVE'
        level {ismember(level,{'phone','triphone','word'})} = 'phone'  % level for HMM training
        
        pass_indices = 'a':'z'  % up to 26 steps for a training phase
        pass = '0'
    end
    
    properties (SetAccess=private)
        accuracy
    end
    
    properties (Access=private)  % Folders
        htktools  
        root   
        scripts
        labels 
        etc
        models
        results
        defaults % contains original files; a run should only copy from these
    end
    
    properties (Access=private)  % Extensions
        htk_ext = '.usr'
        lab_ext = '.lab'
        listing_files_ext = '.scp'
        % recext = rec
    end
    
    properties (Access=private)  % Files
        config
        proto
        train_list_file
        dvpt_list_file
        test_list_file
        test_results  % file in which results are saved; skip run if file exists
        globalded
        hdmanlog
        monophones0
        monophones0sp 
        dict_default  % original dict to copy without modification
        dict   % word to phone dict 
        dict_phone
        dictsp  % dict with sp at the end of words
        dictspded % .ded file to create dictsp from dict
        mkphones0
        wordsmlf
        alignedmlf  % words.mlf but aligned by hvite
        phones0mlf
        dict_without_sp
        phones0_without_sp_mlf
        mixup_sil_hed
        wdnet 
        wdnet_default
        
        words_list % need for final test
    end
    
    properties (Access=private)  % Commands
        % All HTK tools should be in a folder contained in $PATH
        % All *.sh files assumed to be in htk.scripts
        cmd_hcompv = 'HCompV -C "%s" -o hmmdef -f 0.01 -m -S "%s" -M "%s" "%s"'
        cmd_make_macro = 'sh make_macro.sh "%s/macros" "%s/vFloors" %d "%s"'
        cmd_hdman = 'HDMan -g "%s" -b sp -m -n "%s" -l "%s" "%s" "%s"' 
        cmd_make_proto = 'sh make_proto.sh "%s" "%d" "%d" "%d" "%s"'
        cmd_make_models = 'sh make_models.sh "%s/models" "%s" "%s" "%s/sp.ded"'
        % cmd_remove_phones = 'sh remove_exception_phones.sh list "%s"'
        cmd_hled ='HLEd -d "%s" -i "%s" "%s" "%s"'
        cmd_make_labels = 'sh make_labelmlf.sh "%s" "%s" "%s"'
        cmd_herest1 = 'HERest -C "%s" -m %d -I "%s" -t 250.0 150.0 1000.0 -S "%s" -H "%s/macros" -H "%s/models" -M "%s" -s "%s/stats_HERest1" "%s"'
        cmd_make_sp_model = 'sh make_sp_model.sh "%s/models" "%s/sp.ded" %d %d'
        cmd_hhed = 'HHEd -T 0 -C "%s" -H "%s/macros" -H "%s/models" -M "%s" "%s" "%s"'
        cmd_hdman_sp = 'HDMan -g "%s" "%s" "%s"'    
        cmd_hvite='HVite -A -D -T 0 -o SWT -b sil -y lab -C "%s" -a -m -t 250.0 150.0 3600.0 -H "%s/macros" -H "%s/models" -S "%s" -I "%s" -i "%s" "%s" "%s"'
        cmd_make_mixupto = 'sh make_mixupto.sh "%s" "%d" "%s" %d %d'
        cmd_hhed_mix = 'HHEd -T 0 -C "%s" -H "%s/models" -M "%s" "%s" "%s"'
        % herest_b: save as binary because models start to be too big
        cmd_herest_b = 'HERest -B -C "%s" -m %d -I "%s" -t 250.0 150.0 1000.0 -S "%s" -H "%s/models" -M "%s" -s "%s/stats_HERest1" "%s"'
        cmd_hvite_reco = 'HVite -T 0 -C "%s" -l "*" -y rec -S "%s" -w "%s" -H "%s" -i "%s" -p %.2f -s %d "%s" "%s"'
        cmd_hresult      = 'HResults -e \"???\" \"sil\"    -t -I "%s" "%s" "%s"'   % without confusion matrix
        cmd_hresult_conf = 'HResults -e \"???\" \"sil\" -p -t -I "%s" "%s" "%s"'   % with confusion matrix
    end
    
    %%%%%%%%%%%%%  METHODS  %%%%%%%%%%%%%
    
    methods
        function h = Htk(params)
            global HTK_PATHS;
            h.htktools = HTK_PATHS.htktools;  
            h.root = HTK_PATHS.root;  
            h.scripts = HTK_PATHS.scripts;  
            h.labels = HTK_PATHS.labels;  

            % Folders
            h.etc = fullfile(h.root, sprintf('etc_%s', h.dataset));
            h.scripts = fullfile(fileparts(which('Htk.m')), '..', 'scripts');
            h.defaults = fullfile(h.root, 'default');
            
            % Add htktools to system env var (nicer than path in commands)
            [~, res] = system('echo $PATH');
            if ~contains(res, h.htktools)
                setenv('PATH', strcat(res, ':', h.htktools))
            end
            
            %if ~contains(res, h.scripts),  setenv('PATH', strcat(res, ':', h.scripts)); end
            
            % Parameters
            h.change_parameters(params)  % n_states  n_mixtures
            h.name = str(h);
            
            % Files
            h.dict_default = fullfile(h.defaults, sprintf('dict_%s_%s', h.dataset, h.level));
            h.dict = fullfile(h.etc, 'dict');
            h.wdnet_default = fullfile(h.defaults, sprintf('wdnet_%s', h.dataset));
            h.wdnet = fullfile(h.etc, 'wdnet');
            h.dictsp = fullfile(h.etc, 'dictsp');
            h.dictspded = fullfile(h.etc, 'dictsp.ded');
            h.hdmanlog = fullfile(h.etc, 'HDMan.log');
            h.globalded = fullfile(h.etc, 'global.ded');
            h.monophones0 = fullfile(h.etc, 'monophones0');
            h.monophones0sp = fullfile(h.etc, 'monophones0sp');
            h.dict_phone = fullfile(h.etc, 'dict_phone');
            h.mkphones0 = fullfile(h.etc, 'mkphones0.led');
            h.phones0mlf = fullfile(h.etc, 'phones0.mlf');
            h.wordsmlf = fullfile(h.etc, 'words.mlf');  
            h.alignedmlf = fullfile(h.etc, 'aligned.mlf');              
            h.dict_without_sp = fullfile(h.etc, 'dictNoSp');
            h.phones0_without_sp_mlf = fullfile(h.etc, 'phones0_without_sp.mlf');
            h.config = fullfile(h.etc, strcat('config_expt_', strrep(h.htk_ext, '.', '')));  % sh $scriptsdir/make_config.sh $config $mfcctype
            h.mixup_sil_hed = fullfile(h.etc, 'mixup_sil.hed');
            copyfile(h.wdnet_default, h.wdnet)
        end
        
        function run(htk, usr_master, n_features)
            htk_init(htk, usr_master, n_features)
            if exist(htk.test_results, 'file') > 0
                f = fopen(htk.test_results);
                t = textscan(f, '%s');
                fclose(f);
                htk.accuracy = htk.get_accuracy(sprintf('%s ', t{1}{:}));
                return
            end
            final_model = htk_train(htk);   % trains model; returns final ones
            htk_develop(htk, final_model);  % optimise htk.flag_p
            htk.accuracy = htk_test(htk, final_model); % returns accuracy
        end
    end
    
    methods (Access=private)
        
        function open(htk, property_name)
            assert(exist(htk.(property_name), 'file')>0, htk.(property_name))
            system(sprintf('open %s', htk.(property_name)))
        end
        
        function s = str(h)
            s = sprintf('s%dm%d', h.n_states, h.n_mixtures);
        end
        
        function sort_and_replace(htk, some_file, some_other_file)
            % Copy first input to second, sorting/uniq'ing. 
            % If only one input, does it inplace.
            if ~exist('some_other_file', 'var')
                some_other_file = some_file;
            end
            assert(exist(some_file, 'file') >0, some_file)
	    % LC_COLLATE=C is used to ensure that upper case comes before lower case (otherwise, default varies)
            htk.eval(sprintf('cat "%s" | LC_COLLATE=C sort -u -o "%s"', some_file, some_other_file));
        end
        
        function r = eval(htk, cmd, varargin)
            assert(sum(cellfun(@(k)isempty(k), varargin))==0, sprintf('%s ', varargin{:}))
            cmd_double_backslash = strrep(cmd, '\', '\\');
            command = sprintf(cmd_double_backslash, varargin{:});
            
            % Avoids preadding htk.scripts manually to all .sh scripts
            % If htktools not found, a solution is to concat (htk.htktools, ' ')
            command = regexprep(command, '^sh\s+"?(.+).sh\s*"?\s+', sprintf('sh "%s/$1.sh" ', htk.scripts));
            % Check this existence of .sh script
            c = regexp(command, sprintf('%s/\\w+.sh', htk.scripts), 'match');
            if ~isempty(c)
                script = c{1};
                assert(exist(script, 'file')>0, script)
            end
            [~,r] = system(  command  );
            to_print = strcat(command, '\n', r);
            if contains(r, 'ERROR [') || contains(r, '/bin/bash: -c:')
                error(to_print)
            else
                disp(to_print)  % fprintf sensitive to backslashes
            end
        end
        
        function clean(obj)
            for k = 1:length(obj.files_created)
                delete(obj.files_created{k})
            end
        end
        
        function overwrite(htk, file_path, input)
            htk.write_to_file(file_path, input, 'w')
        end
        
        function append(htk, file_path, input)
            htk.write_to_file(file_path, input, 'a')
        end
        
        function dict2wordslist(htk, dict, words_list)
            system(sprintf('cat "%s" |  sed "s_ .*__g" > "%s"', dict, words_list));
            htk.sort_and_replace(words_list)
        end
        
        function sed_d(htk, file, str)
            % sed -i "" /str/d" file     format on mac 
            % sed -i "" file "/str/d/"   format on server
            tmp_file = strcat(file, '.tmp');
            htk.eval('cat "%s" | sed "/%s/d" > %s && mv "%s" "%s"', file, str, tmp_file, tmp_file, file);
	end

    end
    
    methods (Static)
        function data = load(usr_path)
            data = htkread(usr_path);
        end
        
        function save(usr_path, data)
            % Save in HTK format: a row per time step
            parent_folder = fileparts(usr_path);
            assert(exist(parent_folder, 'dir')==7, usr_path)
            assert(endsWith(usr_path, '.usr'), usr_path)
            htkwrite(data', usr_path, 9);
        end
        
        function write_to_file(file_path, input, option)
            % input is str/char or cell of
            if ~isa(input, 'cell')
                input = {input};
            end
            f = fopen(file_path, option);
            for k = 1:length(input)
                fprintf(f, sprintf('%s\n', input{k}));
            end
            fclose(f);
        end
        
        function acc = get_accuracy(hresult)
            try
                m = regexp(hresult, 'Corr=(?<corr>.*), Acc=(?<acc>\d+\.?\d*)\s+\[', 'names');
                acc = m.acc;
            catch
                acc = '0';
            end
            acc = str2double(acc);
        end
        
    end
    
end
