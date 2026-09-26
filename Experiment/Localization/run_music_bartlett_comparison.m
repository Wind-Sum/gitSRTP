function comparison = run_music_bartlett_comparison(varargin)
%RUN_MUSIC_BARTLETT_COMPARISON 以同一实测复响应比较两种测向谱与5159条定位链。
% MUSIC 是每频点单个复响应向量构成的秩一协方差版本，不代表多快拍实验。

parser = inputParser;
parser.addParameter('UseParallel', true, @(x)islogical(x)||(isnumeric(x)&&isscalar(x)));
parser.addParameter('ParallelWorkers', 4, @(x)isnumeric(x)&&isscalar(x)&&x>=1);
parser.parse(varargin{:}); options = parser.Results;

root = fileparts(mfilename('fullpath'));
commonDir = fullfile(root,'common');
addpath(commonDir); pathCleanup = onCleanup(@()rmpath(commonDir));
cacheFile = fullfile(fileparts(root),'FourBranchRev','output','exhaustive_response_cache.mat');
baselineFile = fullfile(root,'output','exhaustive_localization_results.mat');
if ~isfile(cacheFile) || ~isfile(baselineFile)
    error('MusicComparison:MissingInputs', ...
        '需要先运行469种复响应恢复及既有Bartlett穷举定位。');
end
loadedCache = load(cacheFile,'cache'); cache = loadedCache.cache;
loadedBaseline = load(baselineFile,'results'); baseline = loadedBaseline.results;
cfg = cache.config;
cfg.CoarseDirectionStep = 0.025;
cfg.FineDirectionStep = 0.0025;
cfg.MinValidElements = 12;
cfg.AmplitudeExponent = 1;
methodCount = height(cache.methodTable);
if height(baseline.methodTable) ~= methodCount || ...
        ~isequal(baseline.methodTable.MethodId, cache.methodTable.MethodId) || ...
        ~isequal(baseline.frequencyHz, cache.frequencyHz)
    error('MusicComparison:CacheMismatch', ...
        'Bartlett定位结果与当前复响应缓存的方法或频点不一致。');
end

doaCells = cell(methodCount,1);
localizationCells = cell(methodCount,1);
useParallel = logical(options.UseParallel) && license('test','Distrib_Computing_Toolbox');
if useParallel
    pool = gcp('nocreate');
    if isempty(pool), pool = parpool('local',min(options.ParallelWorkers,methodCount)); end
    fprintf('MUSIC对照使用%d个并行进程处理%d种方法。\n',pool.NumWorkers,methodCount);
    parfor methodIndex = 1:methodCount
        [doaCells{methodIndex},localizationCells{methodIndex}] = ...
            process_music_method(methodIndex,cache,cfg);
    end
else
    for methodIndex = 1:methodCount
        [doaCells{methodIndex},localizationCells{methodIndex}] = ...
            process_music_method(methodIndex,cache,cfg);
        if mod(methodIndex,25)==0 || methodIndex==methodCount
            fprintf('MUSIC已完成%d/%d种方法。\n',methodIndex,methodCount);
        end
    end
end

doaRows = vertcat(doaCells{:});
localizationRows = vertcat(localizationCells{:});
musicDoa = cell2table(doaRows,'VariableNames',{'MethodIndex','MethodId','Branch', ...
    'StateCount','LocationIndex','Location','DoaValid','FailureReason', ...
    'AzimuthDeg','ElevationDeg','Ux','Uy','Uz','AngularErrorDeg','FrequencyCount'});
musicLocalization = cell2table(localizationRows,'VariableNames',{'MethodIndex', ...
    'MethodId','Branch','StateCount','StationCount','Stations', ...
    'LocalizationValid','FailureReason','ErrorM','EstimatedX_M','EstimatedY_M', ...
    'EstimatedZ_M','RmsRayDistanceM','AllRaysForward'});
if height(musicDoa)~=methodCount*4 || height(musicLocalization)~=methodCount*11
    error('MusicComparison:WrongRowCount','MUSIC DOA或定位组合数不正确。');
end

bfDoa = baseline.doa;
bf = baseline.localizations;
if ~isequal(musicDoa.MethodIndex,bfDoa.MethodIndex) || ...
        ~isequal(musicDoa.LocationIndex,bfDoa.LocationIndex) || ...
        ~isequal(musicLocalization.MethodIndex,bf.MethodIndex) || ...
        ~isequal(musicLocalization.StationCount,bf.StationCount) || ...
        ~isequal(musicLocalization.Stations,bf.Stations)
    error('MusicComparison:PairingMismatch','MUSIC与Bartlett记录无法逐行配对。');
end

angleDifference = acosd(max(-1,min(1, ...
    musicDoa.Ux.*bfDoa.Ux + musicDoa.Uy.*bfDoa.Uy + musicDoa.Uz.*bfDoa.Uz)));
doaPair = table(bfDoa.MethodIndex,bfDoa.MethodId,bfDoa.Branch, ...
    bfDoa.StateCount,bfDoa.LocationIndex,bfDoa.Location, ...
    bfDoa.DoaValid,musicDoa.DoaValid,bfDoa.AngularErrorDeg, ...
    musicDoa.AngularErrorDeg,angleDifference,bfDoa.Ux,bfDoa.Uy,bfDoa.Uz, ...
    musicDoa.Ux,musicDoa.Uy,musicDoa.Uz, ...
    'VariableNames',{'MethodIndex','MethodId','Branch','StateCount', ...
    'LocationIndex','Location','BartlettValid','MusicValid', ...
    'BartlettAngularErrorDeg','MusicAngularErrorDeg','DirectionDifferenceDeg', ...
    'BartlettUx','BartlettUy','BartlettUz','MusicUx','MusicUy','MusicUz'});
pipelinePair = table(bf.MethodIndex,bf.MethodId,bf.Branch,bf.StateCount, ...
    bf.StationCount,bf.Stations,bf.ResponseRecoverable, ...
    bf.LocalizationValid,musicLocalization.LocalizationValid, ...
    bf.ErrorM,musicLocalization.ErrorM,musicLocalization.ErrorM-bf.ErrorM, ...
    bf.RmsRayDistanceM,musicLocalization.RmsRayDistanceM, ...
    bf.AllRaysForward,musicLocalization.AllRaysForward, ...
    bf.EstimatedX_M,bf.EstimatedY_M,bf.EstimatedZ_M, ...
    musicLocalization.EstimatedX_M,musicLocalization.EstimatedY_M, ...
    musicLocalization.EstimatedZ_M, ...
    'VariableNames',{'MethodIndex','MethodId','Branch','StateCount', ...
    'StationCount','Stations','ResponseRecoverable','BartlettValid','MusicValid', ...
    'BartlettErrorM','MusicErrorM','MusicMinusBartlettErrorM', ...
    'BartlettRayRmsM','MusicRayRmsM','BartlettAllRaysForward', ...
    'MusicAllRaysForward','BartlettX_M','BartlettY_M','BartlettZ_M', ...
    'MusicX_M','MusicY_M','MusicZ_M'});
groupSummary = summarize_groups(pipelinePair,doaPair);

comparison = struct('options',options,'sourceResponseFile',cacheFile, ...
    'sourceBartlettFile',baselineFile,'frequencyHz',cache.frequencyHz, ...
    'musicDoa',musicDoa,'musicLocalization',musicLocalization, ...
    'doaPair',doaPair,'pipelinePair',pipelinePair,'groupSummary',groupSummary);
outputDir = fullfile(root,'output');
writetable(musicDoa,fullfile(outputDir,'music_exhaustive_doa.csv'));
writetable(musicLocalization,fullfile(outputDir,'music_exhaustive_localization.csv'));
writetable(doaPair,fullfile(outputDir,'music_vs_bartlett_doa.csv'));
writetable(pipelinePair,fullfile(outputDir,'music_vs_bartlett_pipeline.csv'));
writetable(groupSummary,fullfile(outputDir,'music_vs_bartlett_group_summary.csv'));
save(fullfile(outputDir,'music_bartlett_comparison.mat'),'comparison','-v7.3');
for branchIndex=1:4
    branchName=sprintf('Branch%d',branchIndex);
    branchDir=fullfile(root,branchName,'output');
    methodMask=strcmp(musicDoa.Branch,branchName);
    writetable(musicDoa(methodMask,:),fullfile(branchDir,'music_exhaustive_doa.csv'));
    methodMask=strcmp(musicLocalization.Branch,branchName);
    writetable(musicLocalization(methodMask,:), ...
        fullfile(branchDir,'music_exhaustive_localization.csv'));
    methodMask=strcmp(pipelinePair.Branch,branchName);
    writetable(pipelinePair(methodMask,:), ...
        fullfile(branchDir,'music_vs_bartlett_pipeline.csv'));
end
write_music_bartlett_report(fullfile(outputDir,'MUSIC_BARTLETT_COMPARISON_REPORT.md'),comparison);
fprintf('MUSIC/Bartlett对照完成：%d条DOA、%d条定位配对。\n', ...
    height(doaPair),height(pipelinePair));
clear pathCleanup;
end

function [doaRows,localizationRows]=process_music_method(methodIndex,cache,cfg)
method=cache.methodTable(methodIndex,:);
doaRows=cell(4,15);
directions=nan(4,3); doaValid=false(4,1);
for locationIndex=1:4
    failure=''; direction=[NaN,NaN,NaN]; azimuth=NaN; elevation=NaN;
    angularError=NaN; usedCount=0;
    if method.Recoverable
        try
            doa=estimate_broadband_doa(cache.responses(:,:,locationIndex,methodIndex), ...
                cache.valid(:,:,locationIndex,methodIndex),cache.frequencyHz, ...
                1:numel(cache.frequencyHz),cfg.localElementPositionsM,cfg,'Music');
            direction=doa.direction; azimuth=doa.azimuthDeg;
            elevation=doa.elevationDeg; usedCount=doa.usedFrequencyCount;
            directions(locationIndex,:)=direction; doaValid(locationIndex)=true;
            truth=cfg.trueSourceM-cfg.arrayCentersM(locationIndex,:);
            truth=truth/norm(truth);
            angularError=acosd(max(-1,min(1,dot(direction,truth))));
        catch exception
            failure=[exception.identifier,': ',exception.message];
        end
    else
        failure=method.FailureReason{1};
    end
    doaRows(locationIndex,:)={methodIndex,method.MethodId{1},method.Branch{1}, ...
        method.StateCount,locationIndex,cfg.locationNames{locationIndex}, ...
        doaValid(locationIndex),failure,azimuth,elevation,direction(1), ...
        direction(2),direction(3),angularError,usedCount};
end

localizationRows=cell(11,14); row=0;
for stationCount=2:4
    combinations=nchoosek(1:4,stationCount);
    for combinationIndex=1:size(combinations,1)
        row=row+1; stationIndices=combinations(combinationIndex,:);
        valid=false; failure=''; position=[NaN,NaN,NaN];
        errorM=NaN; rayRms=NaN; forward=false;
        if all(doaValid(stationIndices))
            try
                loc=localize_multiray_robust(cfg.arrayCentersM(stationIndices,:), ...
                    directions(stationIndices,:));
                position=loc.positionM; valid=all(isfinite(position));
                if valid
                    errorM=norm(position-cfg.trueSourceM);
                    rayRms=loc.rmsRayDistanceM;
                    forward=loc.allRaysForward;
                else
                    failure='NonfiniteLocalization';
                end
            catch exception
                failure=[exception.identifier,': ',exception.message];
            end
        else
            failure='OneOrMoreStationsHaveInvalidDOA';
        end
        localizationRows(row,:)={methodIndex,method.MethodId{1},method.Branch{1}, ...
            method.StateCount,stationCount,station_label(stationIndices),valid, ...
            failure,errorM,position(1),position(2),position(3),rayRms,forward};
    end
end
end

function label=station_label(indices)
label=strjoin(compose('L%d',indices),'-');
end

function summary=summarize_groups(pipelinePair,doaPair)
rows=cell(30,11); row=0;
for branchIndex=1:4
    if branchIndex==4, stateCounts=3:9; else, stateCounts=NaN; end
    for stateCount=stateCounts
        branch=sprintf('Branch%d',branchIndex);
        branchMask=strcmp(pipelinePair.Branch,branch);
        doaMask=strcmp(doaPair.Branch,branch);
        if branchIndex==4
            branchMask=branchMask & pipelinePair.StateCount==stateCount;
            doaMask=doaMask & doaPair.StateCount==stateCount;
        end
        for stationCount=2:4
            row=row+1;
            p=pipelinePair(branchMask & pipelinePair.StationCount==stationCount,:);
            d=doaPair(doaMask,:);
            pairValid=p.BartlettValid & p.MusicValid;
            rows(row,:)={branch,stateCount,stationCount,height(p),nnz(pairValid), ...
                median(p.BartlettErrorM(pairValid),'omitnan'), ...
                median(p.MusicErrorM(pairValid),'omitnan'), ...
                median(p.MusicMinusBartlettErrorM(pairValid),'omitnan'), ...
                nnz(pairValid & abs(p.MusicMinusBartlettErrorM)<1e-10), ...
                median(d.DirectionDifferenceDeg,'omitnan'), ...
                nnz(p.MusicValid & ~p.MusicAllRaysForward)};
        end
    end
end
summary=cell2table(rows(1:row,:),'VariableNames',{'Branch','StateCount', ...
    'StationCount','PipelineCount','PairedValidCount','BartlettMedianErrorM', ...
    'MusicMedianErrorM','MedianMusicMinusBartlettErrorM', ...
    'ExactlyEqualErrorCount','MedianDoaDifferenceDeg','MusicNonForwardCount'});
end
