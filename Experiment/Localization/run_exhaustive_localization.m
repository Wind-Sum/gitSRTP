function results=run_exhaustive_localization(varargin)
%RUN_EXHAUSTIVE_LOCALIZATION 对全部复响应方法运行6+4+1种多站定位。

parser=inputParser;
parser.addParameter('UseParallel',true,@(x)islogical(x)||(isnumeric(x)&&isscalar(x)));
parser.addParameter('ParallelWorkers',4,@(x)isnumeric(x)&&isscalar(x)&&x>=1);
parser.addParameter('SaveFigure',true,@(x)islogical(x)||(isnumeric(x)&&isscalar(x)));
parser.parse(varargin{:}); options=parser.Results;

root=fileparts(mfilename('fullpath')); commonDir=fullfile(root,'common');
addpath(commonDir); pathCleanup=onCleanup(@()rmpath(commonDir));
cacheFile=fullfile(fileparts(root),'FourBranchRev','output','exhaustive_response_cache.mat');
if ~isfile(cacheFile)
    error('ExhaustiveLocalization:MissingCache', ...
        '请先运行FourBranchRev/run_exhaustive_response_methods.m。');
end
loaded=load(cacheFile,'cache'); cache=loaded.cache; cfg=cache.config;
cfg.CoarseDirectionStep=0.025; cfg.FineDirectionStep=0.0025;
cfg.MinValidElements=12; cfg.AmplitudeExponent=1;
methodCount=height(cache.methodTable);
fprintf('对%d种复响应方法计算4个单站DOA和11种定位。\n',methodCount);

doaCells=cell(methodCount,1); localizationCells=cell(methodCount,1);
useParallel=logical(options.UseParallel)&&license('test','Distrib_Computing_Toolbox');
if useParallel
    pool=gcp('nocreate');
    if isempty(pool)
        pool=parpool('local',min(options.ParallelWorkers,methodCount));
    end
    fprintf('使用%d个并行工作进程。\n',pool.NumWorkers);
    parfor methodIndex=1:methodCount
        [doaCells{methodIndex},localizationCells{methodIndex}]=process_method(methodIndex,cache,cfg);
    end
else
    for methodIndex=1:methodCount
        [doaCells{methodIndex},localizationCells{methodIndex}]=process_method(methodIndex,cache,cfg);
        if mod(methodIndex,25)==0 || methodIndex==methodCount
            fprintf('已完成方法 %d/%d。\n',methodIndex,methodCount);
        end
    end
end

doaRows=vertcat(doaCells{:}); localizationRows=vertcat(localizationCells{:});
doaTable=cell2table(doaRows,'VariableNames',{'MethodIndex','MethodId','Branch','Estimator', ...
    'StateCount','UniquePhaseCount','ObservationIndices','PhaseSetDeg','ResponseRecoverable', ...
    'LocationIndex','Location','DoaValid','FailureReason','AzimuthDeg','ElevationDeg', ...
    'Ux','Uy','Uz','AngularErrorDeg','PeakScore','FrequencyCount','ValidFraction'});
localizationTable=cell2table(localizationRows,'VariableNames',{'MethodIndex','MethodId', ...
    'Branch','Estimator','StateCount','UniquePhaseCount','ObservationIndices','PhaseSetDeg', ...
    'ResponseRecoverable','StationCount','Stations','LocalizationValid','FailureReason', ...
    'EstimatedX_M','EstimatedY_M','EstimatedZ_M','ErrorM','RmsRayDistanceM', ...
    'GeometryConditionNumber','MinimumForwardRangeM','AllRaysForward'});
localizationTable=addvars(localizationTable,(1:height(localizationTable)).', ...
    'Before',1,'NewVariableNames','PipelineIndex');
if height(localizationTable)~=methodCount*11
    error('ExhaustiveLocalization:PipelineCount','应有%d条定位链，实际%d条。', ...
        methodCount*11,height(localizationTable));
end

localSummary=build_localization_summary(cache.methodTable,doaTable,localizationTable);
methodSummary=join(cache.methodSummary,localSummary,'Keys','MethodIndex');
groupSummary=build_group_summary(methodSummary,localizationTable);
results=struct('config',cfg,'options',options,'sourceCacheFile',cacheFile, ...
    'frequencyHz',cache.frequencyHz, ...
    'methodTable',cache.methodTable,'doa',doaTable,'localizations',localizationTable, ...
    'methodSummary',methodSummary,'groupSummary',groupSummary);

outputDir=fullfile(root,'output'); if ~isfolder(outputDir),mkdir(outputDir);end
writetable(doaTable,fullfile(outputDir,'exhaustive_doa.csv'));
writetable(localizationTable,fullfile(outputDir,'exhaustive_full_pipeline.csv'));
writetable(methodSummary,fullfile(outputDir,'exhaustive_method_summary.csv'));
writetable(groupSummary,fullfile(outputDir,'exhaustive_group_summary.csv'));
for branchIndex=1:4
    branchName=sprintf('Branch%d',branchIndex);
    branchOutput=fullfile(root,branchName,'output');
    if ~isfolder(branchOutput),mkdir(branchOutput);end
    methodMask=strcmp(cache.methodTable.Branch,branchName);
    methodIndices=cache.methodTable.MethodIndex(methodMask);
    writetable(doaTable(ismember(doaTable.MethodIndex,methodIndices),:), ...
        fullfile(branchOutput,'exhaustive_doa.csv'));
    writetable(localizationTable(ismember(localizationTable.MethodIndex,methodIndices),:), ...
        fullfile(branchOutput,'exhaustive_full_pipeline.csv'));
    writetable(methodSummary(methodMask,:),fullfile(branchOutput,'exhaustive_method_summary.csv'));
end
save(fullfile(outputDir,'exhaustive_localization_results.mat'),'results','-v7.3');
write_exhaustive_localization_report(fullfile(outputDir,'EXHAUSTIVE_COMPARISON_REPORT.md'),results);
if logical(options.SaveFigure)
    plot_exhaustive_comparison(fullfile(outputDir,'exhaustive_comparison.png'),results);
end
fprintf('穷举定位完成：%s\n',fullfile(outputDir,'EXHAUSTIVE_COMPARISON_REPORT.md'));
clear pathCleanup;
end

function [doaRows,localizationRows]=process_method(methodIndex,cache,cfg)
method=cache.methodTable(methodIndex,:);
doaRows=cell(4,22); directions=nan(4,3); doaValid=false(4,1);
for locationIndex=1:4
    failure=''; doa=empty_doa;
    if method.Recoverable
        try
            doa=estimate_broadband_doa(cache.responses(:,:,locationIndex,methodIndex), ...
                cache.valid(:,:,locationIndex,methodIndex),cache.frequencyHz, ...
                1:numel(cache.frequencyHz),cfg.localElementPositionsM,cfg);
            directions(locationIndex,:)=doa.direction; doaValid(locationIndex)=true;
        catch exception
            failure=[exception.identifier,': ',exception.message];
        end
    else
        failure=method.FailureReason{1};
    end
    truth=cfg.trueSourceM-cfg.arrayCentersM(locationIndex,:); truth=truth/norm(truth);
    if doaValid(locationIndex)
        angularError=acosd(max(-1,min(1,dot(doa.direction,truth))));
    else
        angularError=NaN;
    end
    doaRows(locationIndex,:)={methodIndex,method.MethodId{1},method.Branch{1}, ...
        method.Estimator{1},method.StateCount,method.UniquePhaseCount, ...
        method.ObservationIndices{1},method.PhaseSetDeg{1},method.Recoverable, ...
        locationIndex,cfg.locationNames{locationIndex},doaValid(locationIndex),failure, ...
        doa.azimuthDeg,doa.elevationDeg,doa.direction(1),doa.direction(2),doa.direction(3), ...
        angularError,doa.peakScore,doa.usedFrequencyCount,doa.meanValidElementFraction};
end

localizationRows=cell(11,21); row=0;
for stationCount=2:4
    combinations=nchoosek(1:4,stationCount);
    for combinationIndex=1:size(combinations,1)
        row=row+1; stationIndices=combinations(combinationIndex,:);
        localizationValid=false; failure=''; loc=empty_localization;
        if all(doaValid(stationIndices))
            try
                loc=localize_multiray_robust(cfg.arrayCentersM(stationIndices,:), ...
                    directions(stationIndices,:));
                localizationValid=all(isfinite(loc.positionM));
                if ~localizationValid, failure='NonfiniteLocalization'; end
            catch exception
                failure=[exception.identifier,': ',exception.message];
            end
        else
            failure='OneOrMoreStationsHaveInvalidDOA';
        end
        if localizationValid, errorM=norm(loc.positionM-cfg.trueSourceM); else, errorM=NaN; end
        localizationRows(row,:)={methodIndex,method.MethodId{1},method.Branch{1}, ...
            method.Estimator{1},method.StateCount,method.UniquePhaseCount, ...
            method.ObservationIndices{1},method.PhaseSetDeg{1},method.Recoverable, ...
            stationCount,station_label(stationIndices),localizationValid,failure, ...
            loc.positionM(1),loc.positionM(2),loc.positionM(3),errorM, ...
            loc.rmsRayDistanceM,loc.conditionNumber,loc.minimumForwardRangeM,loc.allRaysForward};
    end
end
end

function doa=empty_doa
doa=struct('azimuthDeg',NaN,'elevationDeg',NaN,'direction',[NaN,NaN,NaN], ...
    'peakScore',NaN,'usedFrequencyCount',0,'meanValidElementFraction',NaN);
end

function loc=empty_localization
loc=struct('positionM',[NaN,NaN,NaN],'rmsRayDistanceM',NaN, ...
    'conditionNumber',NaN,'minimumForwardRangeM',NaN,'allRaysForward',false);
end

function label=station_label(indices)
label=strjoin(compose('L%d',indices),'-');
end

function summary=build_localization_summary(methodTable,doaTable,localizationTable)
methodCount=height(methodTable); rows=cell(methodCount,19);
for methodIndex=1:methodCount
    d=doaTable(doaTable.MethodIndex==methodIndex,:);
    l=localizationTable(localizationTable.MethodIndex==methodIndex,:);
    two=l(l.StationCount==2&l.LocalizationValid,:);
    three=l(l.StationCount==3&l.LocalizationValid,:);
    four=l(l.StationCount==4&l.LocalizationValid,:);
    rows(methodIndex,:)={methodIndex,nnz(d.DoaValid),median(d.AngularErrorDeg,'omitnan'), ...
        nnz(l.LocalizationValid),height(two),median_or_nan(two.ErrorM),min_or_nan(two.ErrorM), ...
        max_or_nan(two.ErrorM),median_or_nan(two.RmsRayDistanceM),height(three), ...
        median_or_nan(three.ErrorM),min_or_nan(three.ErrorM),max_or_nan(three.ErrorM), ...
        median_or_nan(three.RmsRayDistanceM),height(four),first_or_nan(four.ErrorM), ...
        first_or_nan(four.RmsRayDistanceM),first_or_nan(four.EstimatedY_M), ...
        nnz(l.LocalizationValid&l.AllRaysForward)};
end
summary=cell2table(rows,'VariableNames',{'MethodIndex','ValidDoaCount', ...
    'MedianDoaAngularErrorDeg','ValidLocalizationCount','TwoStationValidCount', ...
    'TwoStationMedianErrorM','TwoStationMinErrorM','TwoStationMaxErrorM', ...
    'TwoStationMedianRayRmsM','ThreeStationValidCount','ThreeStationMedianErrorM', ...
    'ThreeStationMinErrorM','ThreeStationMaxErrorM','ThreeStationMedianRayRmsM', ...
    'FourStationValidCount','FourStationErrorM','FourStationRayRmsM', ...
    'FourStationEstimatedY_M','ForwardLocalizationCount'});
end

function summary=build_group_summary(methodSummary,localizationTable)
rows=cell(10,14); row=0;
for branchIndex=1:3
    row=row+1; mask=strcmp(methodSummary.Branch,sprintf('Branch%d',branchIndex));
    rows(row,:)=group_row(sprintf('Branch%d',branchIndex),NaN,methodSummary(mask,:),localizationTable);
end
for stateCount=3:9
    row=row+1; mask=strcmp(methodSummary.Branch,'Branch4')&methodSummary.StateCount==stateCount;
    rows(row,:)=group_row('Branch4',stateCount,methodSummary(mask,:),localizationTable);
end
summary=cell2table(rows,'VariableNames',{'Branch','StateCount','MethodCount', ...
    'RecoverableMethodCount','FullyLocalizedMethodCount','MedianValidFraction', ...
    'MedianBranch1Coherence','MedianBranch1PhaseRmseDeg','MedianDoaErrorDeg', ...
    'MedianTwoStationErrorM','MedianThreeStationErrorM','MedianFourStationErrorM', ...
    'MinFourStationErrorM','MaxFourStationErrorM'});
end

function row=group_row(branch,stateCount,methods,localizationTable)
methodIndices=methods.MethodIndex;
l=localizationTable(ismember(localizationTable.MethodIndex,methodIndices)& ...
    localizationTable.LocalizationValid,:);
two=l.ErrorM(l.StationCount==2); three=l.ErrorM(l.StationCount==3); four=l.ErrorM(l.StationCount==4);
row={branch,stateCount,height(methods),nnz(methods.Recoverable), ...
    nnz(methods.ValidLocalizationCount==11),median(methods.MedianValidFraction,'omitnan'), ...
    median(methods.Branch1Coherence,'omitnan'),median(methods.Branch1PhaseRmseDeg,'omitnan'), ...
    median(methods.MedianDoaAngularErrorDeg,'omitnan'),median_or_nan(two), ...
    median_or_nan(three),median_or_nan(four),min_or_nan(four),max_or_nan(four)};
end

function value=median_or_nan(x)
if isempty(x),value=NaN;else,value=median(x,'omitnan');end
end
function value=min_or_nan(x)
if isempty(x),value=NaN;else,value=min(x,[],'omitnan');end
end
function value=max_or_nan(x)
if isempty(x),value=NaN;else,value=max(x,[],'omitnan');end
end
function value=first_or_nan(x)
if isempty(x),value=NaN;else,value=x(1);end
end
