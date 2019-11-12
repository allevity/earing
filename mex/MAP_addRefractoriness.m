function probref = MAP_addRefractoriness(prob, refPer, dt)
% Calculates probability of firing with refractoriness using the corrected
% equation (3) of Meddis & Hewitt 1991 (replace W(t-T) by W(T))
% Usage: probref = MAP_addRefractoriness(prob, refPer, dt)
%      - prob a double array; each row is a probabilty of firing
%      - refPer is the absolute refractory period (in seconds)
%      - dt in seconds is the inverse of the sampling rate (1e5 by default)
%      - probref double array of size(prob), using a chosen refractory function
%
% Written by Alban, Friday, January 20th 2017

if ~exist('dt', 'var')
    fs = 1e5;
    dt = 1/fs;
end

% Maximal number of bins affected by refractoriness
horiz = 2*refPer; % seconds
maxNbBinRefrac = floor(horiz/dt);  % number of bins
Wfull = 1-arrayfun(@(tt)refract1(tt*dt, refPer), 1:maxNbBinRefrac);

if 1 == 0
    probref = MAP_applyRefractoriness(prob, Wfull, dt, horiz);
else
    probref = MAP_applyRefractoriness_mex(prob, Wfull, dt, horiz);
end

end

function compareSpeedWithWithoutMex(prob, Wfull, dt, horiz)
listBins = [1e2 1e3 1e4 1e5 1e6];
tim = zeros(2, length(listBins));
nor = zeros(1, length(listBins));
for kk = 1:length(listBins)
    prob = repmat ( (sin(linspace(0,5,listBins(kk))/2)).^2, 50, 1);
    t1 = tic;
    probref = MAP_applyRefractoriness(prob, Wfull, dt, horiz);
    tim(1,kk) = toc(t1);
    t2 = tic;
    probref2 = MAP_applyRefractoriness_mex(prob, Wfull, dt, horiz);
    tim(2,kk) = toc(t2);
    nor ( kk ) = norm (probref - probref2);
end
figure ; title('Times');
for kk =1:2
    loglog(listBins, tim(kk,:))
    if kk==1
        hold on;
    end
end
xlabel('# bins'); ylabel ('Times (s)');
% saveas(gcf, fullfile(tmpfolder, 'plots','comparisonSpeedMAP_add_refractorinessMex.pdf'));
figure ; plot(nor); title('Norms'); xlabel('# bins'); ylabel ('norm (p1-p2)');
end

function probref = MAP_applyRefractoriness(prob, Wfull, dt, horiz)
% For loop to calculate all values of probref, using formula
probref = zeros(size(prob));
probref(:,1) = prob(:,1);
maxNbBinRefrac = floor(horiz/dt);  % number of bins
staticTimeW = 1:maxNbBinRefrac;
for tt=1:length(prob)-1
    
    if tt*dt < horiz
        timeP = tt:-1:1;
        timeW = 1:tt;
    else
        timeP = tt - staticTimeW + 1;
        timeW = staticTimeW;
    end
    W = Wfull(timeW);
    probPast = probref(:,timeP);
    ct = bsxfun(@times, probPast, W);
    probref(:,tt+1) = prob(:,tt+1) .* (  1 - sum( ct, 2)  );
    
end
end

function w = refract1(t,T)
% a refractory function with linear relative refractory period between T & 2T
assert(T>0, 'Refractory period T should be positive');
if t <= T,          w = 0;
elseif t > 2*T,     w = 1;
else                w = (t - T)/T;
end
end


function w = refract2(t,T)
% a Heaviside refractory function 
if t < T,           w = 0;
elseif t >= T,      w = 1;
end
end


% Maximal horizon of the refractoriness
%horiz = floor(2*refPer/dt);
% Wfull = 1-arrayfun(@(tt)refract1(tt*dt, refPer), timeW);
% for tt=1:length(prob)-1
%     
%     if tt*dt < horiz
%         timeW = tt:-1:1;
%         timeP = 1:tt;
%     else
%         timeW = tt:-1:tt-horiz;
%         timeP = tt-horiz:tt;
%     end
%     W = Wfull(?,?):
%     probPast = probref(:,timeP);
%     probref(:,tt+1) = prob(:,tt+1) .* (  1 - sum( bsxfun(@times, probPast, W) , 2)  );
%     
% end