function results=run_localization_analysis(varargin)
%RUN_LOCALIZATION_ANALYSIS 四分支 2/3/4 站逐级 AOA 与 REV 状态递增定位。

parser=inputParser;
parser.addParameter('Branches',1:4,@(x)isnumeric(x)&&all(ismember(x,1:4)));
parser.addParameter('FrequencyCount',51,@(x)isnumeric(x)&&isscalar(x)&&x>=3);
parser.addParameter('SweepFrequencyCount',21,@(x)isnumeric(x)&&isscalar(x)&&x>=3);
parser.addParameter('AmplitudeExponent',1,@(x)isnumeric(x)&&isscalar(x)&&x>=0&&x<=1);
parser.addParameter('SaveFigures',true,@(x)islogical(x)||(isnumeric(x)&&isscalar(x)));
parser.addParameter('WriteRootOutput',true,@(x)islogical(x)||(isnumeric(x)&&isscalar(x)));
parser.parse(varargin{:}); options=parser.Results;

root=fileparts(mfilename('fullpath')); commonDir=fullfile(root,'common');
addpath(commonDir); pathCleanup=onCleanup(@()rmpath(commonDir));
responseFile=fullfile(fileparts(root),'FourBranchRev','output','four_branch_responses.mat');
if ~isfile(responseFile)
    error('Localization:MissingResponses','请先运行 FourBranchRev/run_four_branch_rev_analysis.m。');
end
loaded=load(responseFile,'bundle'); bundle=loaded.bundle; cfg=bundle.config;
cfg.CoarseDirectionStep=0.025; cfg.FineDirectionStep=0.0025;
cfg.MinValidElements=12; cfg.AmplitudeExponent=options.AmplitudeExponent;
frequencyHz=bundle.frequencyHz(:);
standardFrequencyIndices=select_frequency_indices(frequencyHz,cfg.frequencyRangeHz,options.FrequencyCount);
sweepFrequencyIndices=select_frequency_indices(frequencyHz,cfg.frequencyRangeHz,options.SweepFrequencyCount);
selectedBranches=unique(options.Branches(:).','stable');

fprintf('计算四分支单站 DOA...\n');
doaRows=cell(numel(selectedBranches)*4,13); row=0;
directions=nan(4,3,4);
for branchIndex=selectedBranches
    branch=bundle.branches{branchIndex};
    for locationIndex=1:4
        doa=estimate_broadband_doa(branch.H{locationIndex},branch.valid{locationIndex}, ...
            frequencyHz,standardFrequencyIndices,cfg.localElementPositionsM,cfg);
        directions(locationIndex,:,branchIndex)=doa.direction;
        truth=cfg.trueSourceM-cfg.arrayCentersM(locationIndex,:); truth=truth/norm(truth);
        row=row+1;
        doaRows(row,:)={cfg.branchNames{branchIndex},cfg.branchLabels{branchIndex}, ...
            cfg.locationNames{locationIndex},doa.azimuthDeg,doa.elevationDeg, ...
            doa.direction(1),doa.direction(2),doa.direction(3), ...
            acosd(max(-1,min(1,dot(doa.direction,truth)))),doa.peakScore, ...
            doa.peakToSecondRatio,doa.usedFrequencyCount,doa.meanValidElementFraction};
    end
end
doaTable=cell2table(doaRows(1:row,:),'VariableNames',{'Branch','Method','Location', ...
    'AzimuthDeg','ElevationDeg','Ux','Uy','Uz','AngularErrorDeg','PeakScore', ...
    'PeakToSecondRatio','FrequencyCount','MeanValidElementFraction'});

fprintf('计算每分支 6 个两站、4 个三站、1 个四站组合...\n');
combinationRows=cell(numel(selectedBranches)*11,16); row=0;
for branchIndex=selectedBranches
    for stationCount=2:4
        combinations=nchoosek(1:4,stationCount);
        for combinationIndex=1:size(combinations,1)
            stationIndices=combinations(combinationIndex,:);
            loc=localize_multiray_robust(cfg.arrayCentersM(stationIndices,:), ...
                directions(stationIndices,:,branchIndex));
            errorM=norm(loc.positionM-cfg.trueSourceM);
            row=row+1;
            combinationRows(row,:)={cfg.branchNames{branchIndex},cfg.branchLabels{branchIndex}, ...
                stationCount,station_label(stationIndices),loc.positionM(1),loc.positionM(2), ...
                loc.positionM(3),errorM,loc.rmsRayDistanceM,loc.conditionNumber, ...
                loc.minimumForwardRangeM,loc.allRaysForward,loc.iterations,loc.weightSpread, ...
                min(loc.rayDistancesM),max(loc.rayDistancesM)};
        end
    end
end
combinationTable=cell2table(combinationRows(1:row,:),'VariableNames',{'Branch','Method', ...
    'StationCount','Stations','EstimatedX_M','EstimatedY_M','EstimatedZ_M','ErrorM', ...
    'RmsRayDistanceM','GeometryConditionNumber','MinimumForwardRangeM','AllRaysForward', ...
    'RobustIterations','FinalWeightSpread','MinRayDistanceM','MaxRayDistanceM'});

fprintf('计算 Branch1/Branch4 的 3--9 相移状态定位曲线...\n');
[sweepDoaTable,sweepCombinationTable]=localize_state_sweep(bundle,selectedBranches, ...
    frequencyHz,sweepFrequencyIndices,cfg);

results=struct(); results.config=cfg; results.options=options; results.sourceResponseFile=responseFile;
results.doa=doaTable; results.combinations=combinationTable;
results.stateSweepDoa=sweepDoaTable; results.stateSweepCombinations=sweepCombinationTable;
results.directions=directions;

outputDir=fullfile(root,'output');
if logical(options.WriteRootOutput)
    if ~isfolder(outputDir),mkdir(outputDir);end
    writetable(doaTable,fullfile(outputDir,'doa_results.csv'));
    writetable(combinationTable,fullfile(outputDir,'localization_2_3_4_stations.csv'));
    writetable(sweepDoaTable,fullfile(outputDir,'rev_state_sweep_doa.csv'));
    writetable(sweepCombinationTable,fullfile(outputDir,'rev_state_sweep_localization.csv'));
    save(fullfile(outputDir,'localization_results.mat'),'results','-v7.3');
end
for branchIndex=selectedBranches
    branchOutput=fullfile(root,cfg.branchNames{branchIndex},'output');
    if ~isfolder(branchOutput),mkdir(branchOutput);end
    mask=strcmp(doaTable.Branch,cfg.branchNames{branchIndex});
    writetable(doaTable(mask,:),fullfile(branchOutput,'doa.csv'));
    mask=strcmp(combinationTable.Branch,cfg.branchNames{branchIndex});
    writetable(combinationTable(mask,:),fullfile(branchOutput,'localization_2_3_4_stations.csv'));
    if ismember(branchIndex,[1,4]) && ~isempty(sweepCombinationTable)
        mask=strcmp(sweepCombinationTable.Branch,cfg.branchNames{branchIndex});
        writetable(sweepCombinationTable(mask,:),fullfile(branchOutput,'rev_state_sweep_localization.csv'));
    end
end
if logical(options.WriteRootOutput)
    write_localization_report(fullfile(outputDir,'LOCALIZATION_REPORT.md'),results);
end
if logical(options.SaveFigures) && logical(options.WriteRootOutput)
    plot_localization_progression(fullfile(outputDir,'localization_progression.png'),results);
end
if logical(options.WriteRootOutput)
    fprintf('定位分析完成：%s\n',fullfile(outputDir,'LOCALIZATION_REPORT.md'));
else
    fprintf('分支定位分析完成，结果已写入对应 Branch/output。\n');
end
clear pathCleanup;
end

function indices=select_frequency_indices(frequencyHz,range,count)
band=find(frequencyHz>=range(1)&frequencyHz<=range(2));
pick=unique(round(linspace(1,numel(band),min(count,numel(band)))));
indices=band(pick);
end

function label=station_label(indices)
label=strjoin(compose('L%d',indices),'-');
end

function [doaTable,combinationTable]=localize_state_sweep(bundle,selectedBranches, ...
        frequencyHz,frequencyIndices,cfg)
active=intersect(selectedBranches,[1,4],'stable');
if isempty(active)
    doaTable=table(); combinationTable=table(); return;
end
doaRows=cell(numel(active)*7*4,14); combinationRows=cell(numel(active)*7*11,16);
doaRow=0; combinationRow=0;
for branchIndex=active
    branch=bundle.branches{branchIndex};
    for slot=1:7
        directions=zeros(4,3);
        for locationIndex=1:4
            item=branch.sweep{locationIndex,slot};
            doa=estimate_broadband_doa(item.H,item.valid,frequencyHz,frequencyIndices, ...
                cfg.localElementPositionsM,cfg);
            directions(locationIndex,:)=doa.direction;
            truth=cfg.trueSourceM-cfg.arrayCentersM(locationIndex,:); truth=truth/norm(truth);
            doaRow=doaRow+1;
            doaRows(doaRow,:)={cfg.branchNames{branchIndex},cfg.branchLabels{branchIndex}, ...
                item.estimator,item.stateRole,item.stateCount,item.uniquePhaseCount, ...
                cfg.locationNames{locationIndex}, ...
                doa.azimuthDeg,doa.elevationDeg,doa.direction(1),doa.direction(2), ...
                doa.direction(3),acosd(max(-1,min(1,dot(doa.direction,truth)))),doa.peakScore};
        end
        for stationCount=2:4
            combinations=nchoosek(1:4,stationCount);
            for k=1:size(combinations,1)
                stationIndices=combinations(k,:);
                loc=localize_multiray_robust(cfg.arrayCentersM(stationIndices,:),directions(stationIndices,:));
                combinationRow=combinationRow+1;
                combinationRows(combinationRow,:)={cfg.branchNames{branchIndex}, ...
                    cfg.branchLabels{branchIndex},item.estimator,item.stateRole, ...
                    branch.sweep{1,slot}.stateCount, ...
                    branch.sweep{1,slot}.uniquePhaseCount,stationCount,station_label(stationIndices), ...
                    loc.positionM(1),loc.positionM(2),loc.positionM(3), ...
                    norm(loc.positionM-cfg.trueSourceM),loc.rmsRayDistanceM, ...
                    loc.conditionNumber,loc.minimumForwardRangeM,loc.allRaysForward};
            end
        end
    end
end
doaTable=cell2table(doaRows(1:doaRow,:),'VariableNames',{'Branch','Method','Estimator', ...
    'StateRole','StateCount','UniquePhaseCount','Location','AzimuthDeg','ElevationDeg','Ux','Uy','Uz', ...
    'AngularErrorDeg','PeakScore'});
combinationTable=cell2table(combinationRows(1:combinationRow,:),'VariableNames', ...
    {'Branch','Method','Estimator','StateRole','StateCount','UniquePhaseCount','StationCount','Stations', ...
    'EstimatedX_M','EstimatedY_M','EstimatedZ_M','ErrorM','RmsRayDistanceM', ...
    'GeometryConditionNumber','MinimumForwardRangeM','AllRaysForward'});
end
