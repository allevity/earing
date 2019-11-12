function htk_develop(htk, model)
% Uses development set to optimise weight of silences
% We select the optimal p_flag based on the accuracy on dvpt set

p_flags = htk.flag_p_dvpt;
best_p = NaN;
best_acc = -inf;
summary_p = fullfile(htk.results, 'dvpt_p.txt');
htk.overwrite(summary_p, strcat(sprintf('%d ', p_flags)));
for p = p_flags
    recognisedmlf = fullfile(htk.results, sprintf('recout_p%d.mlf', p));
    htk.eval(htk.cmd_hvite_reco, htk.config, htk.dvpt_list_file, htk.wdnet, model, recognisedmlf, p, htk.flag_s, htk.dictsp, htk.monophones0sp);
    
    hresult = htk.eval(htk.cmd_hresult, htk.wordsmlf, htk.words_list, recognisedmlf);
    acc = htk.get_accuracy(hresult);
    % htk.append(summary_p, sprintf('p=%d, acc=%f', p, acc));
    htk.append(summary_p, strrep(hresult, '%', ''));
    htk.append(summary_p, '\n\n');
    if acc >= best_acc
        best_acc = acc;
        best_p = p;
    end
end
htk.append(summary_p, sprintf('best_p=%d',best_p));
htk.flag_p = best_p;
end
