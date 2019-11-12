function [stimulus, fs] = audioread_at_given_dB(pathToWavFile_or_stimulus, level_dB_SPL)
% Read file from path or provided array and renormalise (removing silences) it to given dB
% Outputs same output as audioread up to a renormalisation of the stimulus

switch class(pathToWavFile_or_stimulus)
    case {'char', 'string'}
        if exist(pathToWavFile_or_stimulus, 'file') ~= 2
            error('audioread_at_given_dB expects the path to a wav file as first argument')
        end
        [stimulus,fs] = audioread(pathToWavFile_or_stimulus);
    case 'double'
        stimulus = pathToWavFile_or_stimulus;
        fs = 1e5;  % assumed for simplicity
    otherwise
        error(class(pathToWavFile_or_stimulus))
end
   

shorten_stimulus = false; % true; % false;

% Required fs for the model to work
compulsoryFs = 1e5;

% We need to resample to give the model the sample frequency it uses 
% SignalProcessing toolbox required
assert(contains(which('resample'),'toolbox/signal/'), '"resample" function from signal processing package required')
stimulus = resample(stimulus, compulsoryFs, fs)';
fs = compulsoryFs;

% Give the model a sound level of 'level_dB_SPL' db, using the equation
% soundLevel = 20*log10(rms/20), we renormalise
% level_dB_SPL = 70; normally
newRms = 20*10^(level_dB_SPL/20);

% rms of stimulus (whole stimulus fine if not too much silence, 
% hence use getHighEnergySamples)
highEnergySample = getHighEnergySamples(stimulus, fs);
initRms = rms(highEnergySample); %initRms = rms(stimulus);

% Renormalise
stimulus = (newRms/initRms).*stimulus;

if shorten_stimulus == true
    shorten_to_n_seconds = 0.15;  % at 0.1 or less, may rate break
    stimulus = stimulus(1:round(fs*shorten_to_n_seconds)); 
    warning('audioread_at_given_dB -> Stimulus shortened!!');
end

end

function [highEnergySample, convabs] = getHighEnergySamples(stimulus, fs)
% Subsample the high-energy samples of waveform stimulus, selected by 
% convabs >(max(convabs)/7); 
% used to calculate speech rms despite long silences.
%
% Usage: getHighEnergySamples(stimulus, fs)
% input: waveform and frequency (outputs of audioread)
% output: Subsample of waveform at high-energies

timebin = 160e-3; % seconds (after testing, a wide range gave good result)
nbBin = floor(timebin*fs); % number of bins to integrate over

convabs = conv(abs(stimulus), hann(nbBin), 'same'); % convolve absolute stimulus with Hann window
%convabs = circshift(convabs, [-floor(nbBin/2),0]);  % shift to recenter
highEnergyPositions = convabs >(max(convabs)/7);    % find high-energy samples 
highEnergySample = stimulus(highEnergyPositions);   % extract samples
end