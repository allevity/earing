function final_model = htk_train(htk)
% Training pass of HMM model: Initialisation, train without silences, 
% add silences, retrain, improve silence models, add mixtures, retrain.
htk.pass = 0;
init_train(htk)
initial_herest(htk)
retrain_with_silences(htk)
fix_silence_models(htk)
align(htk)
final_model = add_mixtures_retrain(htk);
end

function init_train(htk)
%% HCompV
% Produce seed HMM
% Generate initial HMM "hmmdef" with global data means and variances (flat start)
% Creates a file "vFloors" containing the global variances times 0.01
hmm0 = make_current_dir(htk, 'hmm1mix');
if ~exist(hmm0, 'dir')
    mkdir(hmm0)
end
htk.eval(htk.cmd_hcompv, htk.config, htk.train_list_file, hmm0, htk.proto);
htk.eval(htk.cmd_make_macro, hmm0, hmm0, htk.n_features, htk.par_type);

%% Words mlf (takes a few seconds so skip if file exists)
if ~exist(htk.wordsmlf, 'file')
    htk.eval(htk.cmd_make_labels, htk.wordsmlf, htk.labels, htk.lab_ext);
end

%% Phones mlf?

%% HDman
% Prepare a pronunciation dictionary from one or more sources.
htk.overwrite(htk.globalded, 'RS cmu\nMP sil sp sil\nMP sil sil sp\nMP sp sp sp\n')

% Sort words->phones dict
htk.append(htk.dict, 'SENT-END    []  sil')
htk.append(htk.dict, 'SENT-START  []  sil')
htk.eval(htk.cmd_hdman, htk.globalded, htk.monophones0, htk.hdmanlog, htk.dict, htk.dict_default);

% Add [] for SENT-END -START if they disappeared
htk.sed_d(htk.dict, 'SENT-END');
htk.sed_d(htk.dict, 'SENT-START');
htk.append(htk.dict, 'SENT-END    []  sil')
htk.append(htk.dict, 'SENT-START  []  sil')
htk.append(htk.dict, 'sil             sil')
htk.sort_and_replace(htk.dict)

% Adding 'sil' to monophones0
htk.append(htk.monophones0, 'sil');
htk.sort_and_replace(htk.monophones0)

% Test: Adding 'exceptions' to monophones0 (for TIMIT dataset)
if contains(htk.dataset, 'TIMIT')
    % exceptions={'bcl' 'dcl' 'gcl' 'pcl' 'tck' 'kcl' 'tcl' 'pau' 'epi' 'eng' 'nx' 'hv' 'axr' 'ax-h' 'ux' 'q' 'dx'};
    % Lee & Jon 1989 managing of the test phonemes
    htk.eval(htk.cmd_remove_phones, htk.monophones0);
    htk.sort_and_replace(htk.monophones0)
    error('to reimplement')
end

% Make 'phoneme' (phone->phone) dictionary by copying each monophone twice 
% ('[]' for sp and sil). Remove any sp just to add it after to deal with 
% any case (if by mistake it was in monophones0)
htk.eval('cat "%s" | sed "s/\(.*\)/\1 \1/g" | sed "/sp /d" | sed "s/sil sil/sil [] sil/g" > "%s"', htk.monophones0, htk.dict_phone);

% Add sp to dict_phone as it is required later (and simpler to do here)
append(htk, htk.dict_phone, 'sp [] sp')
append(htk, htk.dict_phone, 'SENT-END    []  sil')
append(htk, htk.dict_phone, 'SENT-START  []  sil')
sort_and_replace(htk, htk.dict_phone)

%% Making complete models
% Creates the file "models" containing the HMM definition of all 11 digits and the silence model
htk.eval(htk.cmd_make_models, hmm0, htk.proto, htk.monophones0, hmm0);

%% -------- Make phone level transcript ---------
switch htk.level
    case {'phone', 'triphone'}
        
        % 'EX': expand words into phonemes, using dictionary
        % 'IS sil sil': inserts sil in the beginning and end
        % 'ME sil sp sil': merge a sequence 'sp sil' into 'sil'
        % Removed "DE sp" because we do want the sp models put in the dictionary
        htk.overwrite(htk.mkphones0, 'EX\nIS sil sil\nME sil sp sil\n')
        
        % Make phone-level .mlf, with and without sp
        % Switching to no sp to avoid training sp
        htk.eval('cat "%s" | sed "s/ sp//g" > "%s"', htk.dict, htk.dict_without_sp);
        htk.eval(htk.cmd_hled, htk.dict_without_sp, htk.phones0_without_sp_mlf, htk.mkphones0, htk.wordsmlf);
        htk.eval(htk.cmd_hled, htk.dict, htk.phones0mlf, htk.mkphones0, htk.wordsmlf);
        
        %  Renaming wordsmlf and wordlist with sed
        % warning('improve pipeline');  % 
        % htk.wordsmlf = htk.phones0_without_sp_mlf; %NOPENOPENOPE
        % htk.wordlist = htk.monophones0;
        % should not be necessary anymore
        % htk.eval('sh "changeLabelfilesMlf.sh" "%s" lab', htk.phones0_without_sp_mlf)
        % htk.eval('sh "changeLabelfilesMlf.sh" "%s" lab', htk.phones0mlf)
end
end

function initial_herest(htk)
% Used to perform a single re-estimation of the parameters of a set of HMMs,
% or linear transforms, using an embedded training version of the Baum-Welch algorithm.
assert(htk.n_passes_HERest_1 <= length(htk.pass_indices))
previous_dir = make_current_dir(htk, 'hmm1mix');
for n_pass = 1:htk.n_passes_HERest_1
    htk.pass = htk.pass + 1;
    current_dir = make_current_dir(htk, 'hmm1mix');
    
    htk.eval(htk.cmd_herest1, htk.config, htk.minimum_n_instances, htk.phones0_without_sp_mlf, htk.train_list_file, previous_dir, previous_dir, current_dir, current_dir, htk.monophones0);
    previous_dir = current_dir;

end
end

function retrain_with_silences(htk)
% Add silence model
previous_dir = make_current_dir(htk, 'hmm1mix');
htk.pass = htk.pass + 1;
current_dir = make_current_dir(htk, 'hmm1mix');
current_dir = sprintf('%s_sp', current_dir);
copyfile(previous_dir, current_dir) 
htk.eval(htk.cmd_make_sp_model, current_dir, previous_dir, htk.n_states, htk.n_states_sil);

% Make wordlist_sp
% MAKE_wordlist_sp="sh $scriptsdir/make_wordlist_sp.sh $wordlist $wordlist_sp"

copyfile(htk.monophones0, htk.monophones0sp);
htk.append(htk.monophones0sp, '\nsp\nsil\n');
htk.sort_and_replace(htk.monophones0sp)

% wordlist="$wordlist_sp"
previous_dir = current_dir;

% Retraining with new sp HMM
for k = 1:htk.n_passes_HERest_with_sp
    htk.pass = htk.pass + 1;
    current_dir = make_current_dir(htk, 'hmm1mix');
    %     HEREST2="HERest -C $config -m $minNumInst -I $labelmlf -t 250.0 150.0 1000.0 -S $trainscp -H $prevdir/macros -H $prevdir/models -M $dir -s $dir/stats_HERest1 $wordlist"
    htk.eval(htk.cmd_herest1, htk.config, htk.minimum_n_instances, htk.phones0_without_sp_mlf, htk.train_list_file, previous_dir, previous_dir, current_dir, current_dir, htk.monophones0sp);
    previous_dir = current_dir;

end
end

function fix_silence_models(htk)
% HHEd is a script driven editor for manipulating sets of HMM definitions.
% Its basic operation is to load in a set of HMMs, apply a sequence of edit operations
% and then output the transformed set. HHEd is mainly used for applying tyings across
% selected HMM parameters. It also has facilities for cloning HMMs,
% clustering states and editing HMM structures.
previous_dir = make_current_dir(htk, 'hmm1mix');
htk.pass = htk.pass + 1;
current_dir = make_current_dir(htk, 'hmm1mix');

% Change sil.transP topology and make sp a tee-model (possibly non-emitting)
htk.overwrite(htk.mixup_sil_hed, 'AT 2 4 0.2 {sil.transP}\nAT 4 2 0.2 {sil.transP}\nAT 1 3 0.3 {sp.transP}\nTI silst {sil.state[3],sp.state[2]}')
htk.eval(htk.cmd_hhed, htk.config, previous_dir, previous_dir, current_dir, htk.mixup_sil_hed, htk.monophones0sp);

end

function align(htk)
% Add silences sp in dict and between words in mlf, retrain and Hvite align
% AS A B ... Append silence models A, B, etc to each pronunciation.
% MP X A B ...Merge any sequence of phones A B ... and rename as X.
htk.overwrite(htk.dictspded, 'AS sp\nMP sil sil sp');
htk.eval(htk.cmd_hdman_sp, htk.dictspded, htk.dictsp, htk.dict);
% dunno why but the '[]' disappear

htk.sed_d(htk.dictsp, 'SENT-END');
htk.sed_d(htk.dictsp, 'SENT-START');
htk.append(htk.dictsp, 'SENT-END    []  sil')
htk.append(htk.dictsp, 'SENT-START  []  sil')
sort_and_replace(htk, htk.dictsp)

% Align (find the time of each phone in data sequence)
current_dir = make_current_dir(htk, 'hmm1mix');
htk.eval(htk.cmd_hvite, htk.config, current_dir, current_dir, htk.train_list_file, htk.wordsmlf, htk.alignedmlf, htk.dictsp, htk.monophones0sp);

% Retrain
for k = 1:htk.n_passes_HERest_aligned
    previous_dir = current_dir;
    htk.pass = htk.pass + 1;
    current_dir = make_current_dir(htk, 'hmm1mix');  
    htk.eval(htk.cmd_herest1, htk.config, htk.minimum_n_instances, htk.alignedmlf, htk.train_list_file, previous_dir, previous_dir, current_dir, current_dir, htk.monophones0sp);  %monophones0?
end
end

function final_model = add_mixtures_retrain(htk)
% HHEd & HERest: .n_mixtures mixtures
previous_dir = make_current_dir(htk, 'hmm1mix');

for n_mix = 2:htk.n_mixtures
    htk.pass = 0;
    mix_folder = sprintf('hmm%dmix', n_mix);
    current_dir = make_current_dir(htk, mix_folder);
    mixuptohed = sprintf('%s/mixupto%d.hed', htk.etc, n_mix);
    % Create .hed file
    htk.eval(htk.cmd_make_mixupto, mixuptohed, n_mix, htk.monophones0sp, htk.n_states, htk.n_states_sil);
    % Increase number mixtures using .hed file
    htk.eval(htk.cmd_hhed_mix, htk.config, previous_dir, current_dir, mixuptohed, htk.monophones0sp);
    for j = 1:htk.n_passes_HERest_mix
        previous_dir = current_dir;
        htk.pass  = htk.pass  + 1;
        current_dir = make_current_dir(htk, mix_folder);
        htk.eval(htk.cmd_herest_b, htk.config, htk.minimum_n_instances, htk.alignedmlf, htk.train_list_file, previous_dir, current_dir, current_dir, htk.monophones0sp);  %monophones0?
    end
    previous_dir = current_dir;
end
final_model = fullfile(current_dir, 'models');
end

function current_dir = make_current_dir(htk, hmm_dir_base, detail)
if ~exist('detail', 'var')
    detail = '';
end
% ex: hmm_dir_base='hmm1mix.%s' makes 'hmm1mix.0'/'hmm1mix.a'/
if htk.pass == 0 || str2double(htk.pass) == 0
    current_letter = '0';
else
    current_letter = htk.pass_indices(htk.pass);
end
current_dir = fullfile(htk.models, sprintf('%s.%s%s', hmm_dir_base, current_letter, detail));
if ~exist(current_dir, 'dir')
    mkdir(current_dir);
end
end
