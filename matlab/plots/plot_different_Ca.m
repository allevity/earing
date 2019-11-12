function plot_different_Ca(res)
% Private function to plot calcium relared results

global SPEECHRECOHTK % base folder for saving plots

[mar, col] = get_mar_col();

cr.soundLevel = 80;
cr.gmaxCa = 7e-9;
cr.features = 'SPIKEflurldddz';
cr.dataset   = 'CUAVE5T50t25d5';
listCaThresh = [1e-15,1e-14,1e-12,1e-11,2e-11,3e-11,4e-11,5e-11,6e-11,8e-11,1e-10];
get_rate_window_indices = @(x)(0.025 < x) & (x < 0.050);  % in s
listaccu = {'WORD_ACC'};  % or 'PHON_ACC'

typplot = @semilogx;
for accind = 1
    cAcc = listaccu{accind};
    
    f1 = figure;
    % f1_lin = figure;
    f2 = figure;
    ftrend_lin = figure;     hold on;
    ftrend_log = figure;     hold on;
    
    for kk = 1:length(listCaThresh)
        caThresh = listCaThresh(kk);
        cr.caThresh = caThresh;
        switch cr.caThresh % special case
            case '448e11', cr.caThresh = '4_48e11';
        end
        
        % Finding runs of current Ca_thresh
        sr = [res.SingleRunAsr];
        mask = ones(1, length(sr));
        % dataset
        d = [sr.dataset];
        mask = mask & [d.name] == cr.dataset;
        % features (Ugly but haven't seen simpler)
        processings = [sr.processing];
        for k = 1:length(processings)
            mask(k) = mask(k) && strcmp(strcat(processings(k).features{:}{:}), cr.features);
        end
        % Model
        m = [sr.model];
        s = [m.synapse];
        p = [s.presynapse];
        %   sound level
        mask = mask & ([m.db] == cr.soundLevel);
        %   ca threshold
        mask = mask & ([p.ca_thresh] == cr.caThresh);
        %   g_max
        mask = mask & ([p.gmaxca] == cr.gmaxCa);
        inds = mask;
        
        % Process list for NaNs or missing values
        if isempty(inds)
            disp('Not in dataset:');
            disp(cr);
            continue;
        end
        
        rate_window_durations = [processings(inds).rate_window_duration];
        val = [sr(inds).result];
        
        % Reorder
        [~, I] = sort(rate_window_durations);
        rate_window_durations = rate_window_durations(I);
        val = val(I);
        nonnan = ~isnan(val); % remove NaNs
        
        figure(f2);
        cca_str = strrep(strrep(num2str(cr.caThresh), '_', '.'), '-', '');
        
        windows_indices_for_averaging = get_rate_window_indices(rate_window_durations);
        cval = val(windows_indices_for_averaging);
        
        if ~all(isnan(cval))
            typplot(cr.caThresh, mean(cval, 'omitnan'), 'o', 'Color', col.(['ca' cca_str]),...
                'DisplayName',cca_str);
        end
        if kk==1
            ylim([0 100])
            hold on;
            %disp(ANind(cathreshValAverage));
            %title(sprintf('%d ',cathreshValAverage))
        end
        
        rate_window_durations = rate_window_durations(nonnan);
        val = val(nonnan);
        if all(~nonnan)
            disp('----------')
            disp('No non NaN values found in')
            disp(inds')
            disp('with')
            disp(cr);
        end
        switch caThresh
            case '448e11', caThreshNAme = '4.48e11';
            otherwise,     caThreshNAme = caThresh;
        end
        
    
        cstyles = {...
            mar.(['ca' cca_str]), ...
            'LineWidth', 1.2,...
            'Color', col.(['ca' cca_str]), ... col.(snumspk) ...
            'DisplayName', strrep(num2str(caThreshNAme), '-', '-'), ...
            'MarkerSize', 10};
      
        figure(f1);
      
        typplot(rate_window_durations, val, cstyles{:});
        
        if kk==1
            hold on;
        end
        
    end
    
    switch cAcc
        case 'WORD_ACC', ylabacc = 'Word Acc. (%)';
        case 'PHON_ACC', ylabacc = 'Phone Acc. (%)';
        otherwise, error('Daaaaah');
    end
    
    legend show
    legend('Location', 'northeastoutside')
    xlabel('Hann duration (s)');
    ylabel(ylabacc);
    ylim([0 100]);
    csize = [3.5 3];
    set(f1, 'Paperposition', [0 0 csize]);
    set(f1, 'PaperSize',     csize);
    tit = sprintf('plot_different_ca_%s_%s_acc%s', cr.features, cr.dataset, cAcc(1));
    saveas(f1, fullfile(SPEECHRECOHTK, 'plots', 'plotDifferentCa', [tit '.pdf']));
    %close(f1);
    
    csize = [2.05 3];
    figure(f2);
    set(f2, 'Paperposition', [0 0 csize]);
    set(f2, 'PaperSize',     csize);
    set(gca, 'Xtick', 10.^(-15:2:-10));
    set(gca, 'XTicklabel', {'10^{-15}', '10^{-13}', '10^{-11}'});
    % text(3e-12, -3.5, '...')
    tit2 = sprintf('plot_different_ca_%s_average_%s_acc%s',tit, sprintf('%d',windows_indices_for_averaging(:)), cAcc(1));
    xlabel('[Ca^{2}+]_{thr}');
    ylabel(ylabacc);
    saveas(f2, fullfile(SPEECHRECOHTK, 'plots', 'plotDifferentCa', [tit2 '.pdf']));
    legend show; legend('Location', 'southeastoutside')
    saveas(f2, fullfile(SPEECHRECOHTK, 'plots', 'plotDifferentCa', [tit2 '_leg.pdf']));
    %close(f2)
    
    figure(ftrend_lin);
    csize = [4.5 3];
    set(ftrend_lin, 'Paperposition', [0 0 csize]);
    set(ftrend_lin, 'PaperSize',     csize);
    xlabel('[Ca^{2+}]_{thr}')
    tittrend = sprintf('%s_average_%s_acc%s_trend_lin',tit, sprintf('%d',windows_indices_for_averaging(:)), cAcc(1));
    legend show;
    legend({'a','b','c'},'Location', 'northeastoutside')
    xlim([0 4.95e-11]);
    %saveas(ftrend_lin, fullfile(SPEECHRECOHTK, 'plots', 'plotDifferentCa', [tittrend '.pdf']));
    
    
    figure(ftrend_log);
    csize = [4.5 3];
    set(ftrend_log, 'Paperposition', [0 0 csize]);
    set(ftrend_log, 'PaperSize',     csize);
    xlabel('[Ca^{2+}]_{thr}')
    tittrend = sprintf('%s_average_%s_acc%s_trend_log',tit, sprintf('%d',windows_indices_for_averaging(:)), cAcc(1));
    legend show;
    legend({'a','b','c'},'Location', 'northeastoutside')
    xlim([0 4.95e-11]);
    %saveas(ftrend_log, fullfile(SPEECHRECOHTK, 'plots', 'plotDifferentCa', [tittrend '.pdf']));
end


end

function [mar, col] = get_mar_col()
mar.ca1e15 = '.-';
mar.ca1e14 = '.-';
mar.ca1e13 = '.-' ;
mar.ca1e12 = '.-' ;
mar.ca1e11 = '.-' ;
mar.ca2e11 = '.-';
mar.ca3e11 = '.-' ;
mar.ca4e11 = '-' ;
mar.ca448e11 = '--';
mar.ca5e11 = '.-' ;
mar.ca6e11 = '-';
mar.ca8e11 = '-' ;
mar.ca1e10 = '-' ;
col.ca1e15 = 'r';
col.ca1e14 = 'm';
col.ca1e13 = 'k';
col.ca1e12 = 'g';
col.ca1e11 = 'b';
col.ca2e11 = 'r';
col.ca3e11 = 'g';
col.ca4e11 = 'm';
col.ca448e11 = 'b';
col.ca5e11 = 'k';
col.ca6e11 = 'g';
col.ca8e11 = 'b';
col.ca1e10 = 'r';
end