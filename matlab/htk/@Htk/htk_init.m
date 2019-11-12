function htk_init(htk, usr_master, n_features)

% Parameters
htk.n_features = n_features;

% Folders
htk.models = fullfile(usr_master, 'models');
htk.results = fullfile(usr_master, 'results');

dirs2make = {'models','results','scripts','etc'};
for k=1:length(dirs2make)
    f = dirs2make{k};
    assert(~isempty(htk.(f)), f)
    if ~exist(htk.(f), 'dir')
        mkdir(htk.(f))
    end
end

% Init values/files
htk.proto = fullfile(htk.models, 'proto');
init_list_files(htk, usr_master)
manage_dict(htk);
htk.words_list = fullfile(htk.etc, 'words_list');
htk.dict2wordslist(htk.dict, htk.words_list);
disp('htk_init: cmd_hled to add!!');

eval(htk, htk.cmd_make_proto, htk.proto, htk.n_states, htk.n_mixtures, htk.n_features, htk.par_type);
init_config_file(htk);
htk.test_results = fullfile(htk.results, 'test.txt');

end

function init_config_file(htk)
% put tergetkind and make reading data machine dependent
htk.overwrite(htk.config, 'TARGETKIND = USER\nBYTEORDER = VAX\n');
end

function init_list_files(htk, usr_master)
htk.train_list_file = make_list_file(htk, usr_master, 'TRAIN');
htk.dvpt_list_file  = make_list_file(htk, usr_master, 'DVPT');
htk.test_list_file  = make_list_file(htk, usr_master, 'TEST');
end

function scp_file = make_list_file(htk, usr_master, files_type)
scp_file = fullfile(usr_master, sprintf('list_%s%s', files_type, htk.listing_files_ext));
if exist(scp_file, 'file')
    return
end
current_folder = fullfile(usr_master, files_type);
files_list = dir(sprintf('%s/*%s', current_folder, htk.htk_ext));
files_list = arrayfun(@(f)fullfile(f.folder, f.name), files_list, 'uni', false);
files_list = strrep(files_list, '\', '\\');  % windows paths
htk.overwrite(scp_file, files_list);
end

function manage_dict(htk)
htk.sort_and_replace(htk.dict_default, htk.dict)
end
