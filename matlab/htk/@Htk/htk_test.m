function word_acc = htk_test(htk, model)  
% Input: model is the path to a model file (binary or text)

word_acc = word_level_recognition(htk, model);
% phone_acc = phone_level_recognition(htk, model);  % not used here
end

function acc = word_level_recognition(htk, model)
word_level_recognitionmlf = fullfile(htk.results, 'recognition_words.mlf');
htk.eval(htk.cmd_hvite_reco, htk.config, htk.test_list_file, htk.wdnet, model, word_level_recognitionmlf, htk.flag_p, htk.flag_s, htk.dictsp, htk.monophones0sp);
hresult = htk.eval(htk.cmd_hresult_conf, htk.wordsmlf, htk.words_list, word_level_recognitionmlf);

hresult = strrep(hresult, '%', '');
htk.overwrite(htk.test_results, hresult);
acc = htk.get_accuracy(hresult);
end