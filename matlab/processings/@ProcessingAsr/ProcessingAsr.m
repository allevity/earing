classdef ProcessingAsr < Processing
    
    % Contains post-processing functions. Applies a succession of features
    % as described by a string such as 'g_d_dd'
    % See 'run_single_features' method to add processing methods
    
    properties
        % features: Processing cell of strings describing the steps
        window function_handle = @hann
        fs = 1e5  % Hz; assumed frequency of input, but may be changed
        rate_time_step       = 10e-3 % s
        rate_window_duration = 30e-3 % s
        inhomogeneous_window = 50e-3 % s
        dct_num_coeff = 13
        deltadelta_delta  = 2
        deltadelta_ddelta = 2
        avg_n_features = 31
        log_threshold_value = -5
        lengthAbsRefractory = 0.75e-3; % refractory period: uniform btween 0.75 and 1.5ms
        input_type {mustBeMember(input_type,{'SPIKE','PROB'})} = 'SPIKE'
    end
    
    methods
        function obj = ProcessingAsr(processing_params)
            obj = obj@Processing(processing_params);
            obj.input_type = processing_params.features{1}{1};
            obj.change_parameters(processing_params);
            obj.parameters2name()
        end
        
        function processed_data = run(obj, data)
            processed_data = data;
            features = obj.features{1};  
            % k= 1 is SPIKE or PROB
            for k = 2:length(features)
                f = features{k};
                processed_data = obj.run_single_features(f, processed_data);
            end
        end
        
        function data = run_single_features(obj, feature, data)
            switch feature
                case ''
                    % Chill, nothing to do
                    
                case {'d','dct'}
                    % Based on Marc-Rene's 'mfcc.m' (followed by 'dd/deltaDelta')
                    data = dct(data);
                    data = data(1:obj.dct_num_coeff,:);
                    
                case {'dd', 'delta_delta'}
                    % Append delta-delta coefficients.
                    % Based on Marc-Rene's 'mfcc.m' (preceded by 'd/dct')
                    context = obj.deltadelta_delta + obj.deltadelta_ddelta;
                    if context > 0 % Temporally pad log Mel-spectrogram by repeating first and last frames
                        data = [repmat(data(:,1),1,context) data repmat(data(:,end),1,context)];
                    end
                    mfccs = data; % (1:num_coeff,:);
                    delta_filter  = linspace(-1, 1, 2.* obj.deltadelta_delta  + 1);
                    ddelta_filter = linspace(-1, 1, 2.* obj.deltadelta_ddelta + 1);
                    deltas  = conv2(mfccs,  delta_filter,  'same');
                    ddeltas = conv2(deltas, ddelta_filter, 'same');
                    data = [mfccs; deltas; ddeltas];
                    if context > 0 % Remove padded context
                        data = data(:,(1+context):(end-context));
                    end
                    
                case {'e', 'energy'}
                    % Append energy (if log performed after appending)
                    E = sum(data.^2,1);
                    data = [E; data];
                    
                case {'el', 'logenergy'}
                    % Append log energy
                    E = log10(1 + sum(data.^2,1));
                    data = [E; data];
                    
                case {'f','fr','sfr','avgneigh'}
                    % Simple feature reduction: Reducing the vertical size to 31 (to use gbfb,
                    % typicaly), by averaging n neighbours. Assumes trains are ordered.
                    
                    % ADD function that defines the number of channels to have ! per
                    % ERB between Rangemin and rangemax
                    data = averagingNeighbours(data, obj.avg_n_features);
                    
                case {'g','gbfb'}
                    data = gbfb(full(data));
                    
                case {'ga', 'gaussianization', 'batchNormalisation'}
                    % Gaussianisation of all features (mean 0, variance 1)
                    a    = bsxfun(@minus, data, mean(data,2))';
                    data = bsxfun(@times, a, var(a).^(-1/2))';
                
                case {'ISI'}
                    % Calculate the ISI matrix (column-wise)
                    data = calculateISI(data);
                    
                case {'l','l0', 'log10'}
                    data = log10(1+data);
                    
                case {'l3', 'log1000'}
                    data = log10(1+1000*data);
                    
                case {'lu'}
                    % Logarithm and uplifting. -5 chosen by sight
                    data = log10(full(data)); % may crash when feats is sparse
                    data(data < obj.log_threshold_value) = obj.log_threshold_value;
                    data = data - obj.log_threshold_value;
                    
                case {'lsp'}
                    % log_spectrogram to the input (should be a speech waveform)
                    data = log_mel_spectrogram(data, obj.fs);
                    
                case {'m', 'mfcc'}
                    % Adapted from https://uk.mathworks.com/matlabcentral/fileexchange/32849-htk-mfcc-matlab
                    % 'feats' should be a spectro-temporal representation, not logged
                    hz2mel = @( hz )( 1127*log(1+hz/700) );     % Hertz to mel warping function
                    mel2hz = @( mel )( 700*exp(mel/1127)-700 ); % mel to Hertz warping function
                    
                    % Type III DCT matrix routine (see Eq. (5.14) on p.77 of [1])
                    dctm = @( N, M )( sqrt(2.0/M) * cos( repmat((0:N-1).',1,M) ...
                        .* repmat(pi*((1:M)-0.5)/M,N,1) ) );
                    
                    % Cepstral lifter routine (see Eq. (5.12) on p.75 of [1])
                    ceplifter = @( N, L )( 1+0.5*L*sin(pi*(0:N-1)/L) );
                    
                    % Set parameters
                    R = [ 300 3700 ];  % frequency range to consider
                    M = 20;            % number of filterbank channels
                    N = 13;            % number of cepstral coefficients
                    L = 22;            % cepstral sine lifter parameter
                    K = size(data,1); % Length of unique part of FFT
                    fs_ = SRoND_SAMPFREQ/2; % Hz, because our BFs are expected to go up to 8kHz.
                    
                    % Triangular filterbank with uniformly spaced filters on mel scale
                    H = trifbank( M, K, R, fs_, hz2mel, mel2hz ); % size of H is M x K
                    
                    % Replace the FFT magnitude by current input (abs(fft()) in original code)
                    % so shouldn't be logged already.
                    MAG = data;
                    
                    % Filterbank application to unique part of the magnitude spectrum
                    FBE = H * MAG(1:K,:); % FBE( FBE<1.0 ) = 1.0; % apply mel floor
                    
                    % DCT matrix computation
                    DCT = dctm( N, M );
                    
                    % Conversion of logFBEs to cepstral coefficients through DCT
                    % Adding 0.01 because our model can give 0s, becoming NaNs after log.
                    CC =  DCT * log( 0.01 + FBE );
                    
                    % Cepstral lifter computation
                    lifter = ceplifter( N, L );
                    
                    % Cepstral liftering gives liftered cepstral coefficients
                    CC = diag( lifter ) * CC; % ~ HTK's MFCCs
                    data = CC; 
                    
                case {'p2p','proba2probawithrefractoriness'}
                    data = MAP_addRefractoriness(data, obj.lengthAbsRefractory);
                    
                case {'p2i', 'proba2inhomogenousrate'}
                    % Assuming an inhomogenous poisson process with very small time-steps
                    proba2inhomorate = @(proba_matrix, fs)(fs/2) * (1 - sqrt(1-4*proba_matrix) );
                    data = proba2inhomorate(data, obj.fs);
                    
                case {'i2f', 'inhomogenousrate2firingrate'}
                    % Extracting the mean by integrating lambda by a sliding window
                    window_fs = obj.inhomogeneous_window * obj.fs; % ms
                    data = conv2(data',ones(window_fs,1)/(window_fs), 'same' )';
                    
                case {'r', 'rate'}
                    % Calculate the rate; uses global variables
                    data = calculateRate(data, obj.fs, obj.window, obj.rate_window_duration, obj.rate_time_step);
                    
                case {'ri', 'RI', 'rateInverse'}
                    data = 1./calculateISI(data);
                    
                case {'s', 'sgbfb'}
                    data = sgbfb(data);
                    
                case {'wh','whitening', 'zca'}
                    % Gaussianisation with decorrelation
                    a = bsxfun(@minus, data, mean(data,2))'; % Mean to 0
                    A = a'*a;
                    [V,D] = eig(A);
                    a = a*V*diag(1./(diag(D)+0.001).^(1/2))*V'; % Decorrelation & renormalise
                    data = a';
                    
                case {'z'}
                    % Cepstral Mean Normalisation
                    % http://dsp.stackexchange.com/questions/19564/cepstral-mean-normalization
                    data = bsxfun(@minus,data, mean(data,2));
                    
                otherwise
                    error(feature);
            end
            
        end
    end

end

function featsISI = calculateISI(feats)
% calculate ISI matrix
hSp = full(feats)';
count = zeros(size(hSp));
spikes2ISI(hSp, count);
featsISI = count';
end

function feats = averagingNeighbours(feats, nbFeat, comp)
% Averaging neighbour rows to have nbFeat rows. 
% The mex file is slower than the Matlab one. 
% Final feature contains all remaining rows (the other being the average 
% of fixed number).

if ~exist('comp', 'var')
    % Default calculation: with Matlab file (faster)
    comp = 'matlab';
end
switch comp
    
    case 'matlab'
        
        % Default number of rows to avarage (except for last)
        n = floor(size(feats,1)/nbFeat);
        
        % Get the indices of rows to average together
        cx = @(kk)getIndicesToAverageTogether(kk, n, nbFeat, size(feats,1));
        
        % Function to apply the mean to those rows
        avgInd = @(kk) mean(feats(cx(kk),:),1);
        
        % Do the calculations
        cf    = arrayfun(avgInd, 1:nbFeat, 'uni', false)';
        feats = cell2mat(cf);
        
        assert(~any(any(isnan(feats))),'There should be no NaN.');
        
    case 'mex'
        
        warning('averageChannels.c is slower than the equivalent Matlab code');
        
        try
            % Might break if feats was a fat logical sparse matrix, so we
            % cut the matrix in blocks
            nbFeatCut = nbFeat;
            n2 = floor(size(feats,2)/nbFeatCut);
            cfeats = zeros(nbFeatCut, size(feats,2));
            for kk=1:nbFeatCut
                if kk < nbFeatCut
                    ind = (kk-1)*n2 + 1:kk*n2;
                else
                    ind = (kk-1)*n2 + 1:size(feats,2);
                end
                cf  = feats(:,ind);
                % Reduces the number of rows by averaging. Last one
                % contains remaining channels
                cfeats(:,ind) = averageChannels(full(double(cf)),nbFeat);
            end
            feats = cfeats;
        catch ME
            if ~exist('averageChannels', 'file')
                warning('averageChannels not found');
            end
            disp(ME);
            error('averagingNeighbours failed; use the Matlab code');
        end
        
end
end

function cx = getIndicesToAverageTogether(kk, n, nbFeat, totalLength)
if kk < nbFeat
    cx = 1+(kk-1)*n:min(kk*n, totalLength);
else
    cx = 1+(kk-1)*n:totalLength;
end
end

function nfeats = batchRate(feats, window, beginInd, nbSamp)
% window = @hann for example
% Calculate a rate. Done for batch calculations
%beginInd = 1:floor(time_step*freq):floor(nbCol-nbSamp);

if isempty(beginInd)
    % Too small sample, neglect
    nfeats = [];
    return;
end

if ~exist(['rateSpikeTrain.' mexext], 'file')
    try
        mex 'rateSpikeTrain.c';
    catch
        % Without mex file. You may
        fprintf('speechreco_extractFeatures.m < batchRate: Couldn''t mex file for rate\n');
        nbCol = size(feats, 2);
        movingHann = @(b)[ zeros(1,b-1) window(nbSamp)' zeros(1,1+nbCol-(b+nbSamp)) ];
        hannWindows_spkTr_rate = cell2mat(arrayfun(movingHann, beginInd, 'uni', false)');
        nfeats = feats*hannWindows_spkTr_rate';
        return;
    end
end
% with mex file
cfeat = double(full(feats'));
% tranpose to concatenate later
w = window(nbSamp);
nfeats = rateSpikeTrain(cfeat, beginInd, w)'/sum(w);
end

function nfeats = calculateRate(feats, fs, window, time_slice, time_step)
% time_step: sliding window by steps of 10ms
nbSamp = floor(fs*time_slice); % Number of samples per time frame
% Since it breaks for very long inputs, we do some batches
nbCol = size(feats,2);
assert(nbSamp<nbCol, sprintf('size(feats)=%d,%d, slice=%f, nbSamp=%d, nbCol=%d',...
    size(feats), time_slice, nbSamp, nbCol))

% Indices at which we convolve a Hann window
beginInd = 1:floor(time_step*fs):floor(nbCol-nbSamp);

% Allocate and loop if too big
if numel(feats) < 1e9
    nfeats = batchRate(feats, window, beginInd, nbSamp);
else
    nfeats = zeros(size(feats,1),length(beginInd));
    for kk=1:size(nfeats,1)
        cfeats = feats(kk,:);
        nfeats(kk,:) = batchRate(cfeats, window, beginInd, nbSamp);
    end
end

end