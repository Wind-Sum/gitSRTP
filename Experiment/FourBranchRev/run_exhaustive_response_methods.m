function cache=run_exhaustive_response_methods(varargin)
%RUN_EXHAUSTIVE_RESPONSE_METHODS 枚举Branch4全部3--9观测子集并恢复复响应。

parser=inputParser;
parser.addParameter('FrequencyCount',21,@(x)isnumeric(x)&&isscalar(x)&&x>=3);
parser.parse(varargin{:}); options=parser.Results;

root=fileparts(mfilename('fullpath'));
commonDir=fullfile(root,'common');
branchDirs=arrayfun(@(k)fullfile(root,sprintf('Branch%d',k)),1:4,'UniformOutput',false);
addpath(commonDir,branchDirs{:});
pathCleanup=onCleanup(@()rmpath(commonDir,branchDirs{:}));

cfg=four_branch_config;
resultsRoot=fullfile(fileparts(root),'Real_test','results');
measurements=load_experiment_measurements(resultsRoot,cfg);
phaseDeg=measurements(1).rev.config.rev.phaseDeg(:).';
if numel(phaseDeg)~=9
    error('ExhaustiveREV:ExpectedNineObservations','穷举要求恰好9次REV观测，当前为%d次。',numel(phaseDeg));
end
schedule=build_rev_state_schedule(phaseDeg,cfg.stateAdditionOrderDeg);
referenceBranches={compute_branch1(measurements,schedule),compute_branch2(measurements), ...
    compute_branch3(measurements),compute_branch4(measurements,schedule)};

frequencyHz=measurements(1).frequencyHz(:);
frequencyIndices=select_frequency_indices(frequencyHz,cfg.frequencyRangeHz,options.FrequencyCount);
selectedFrequencyHz=frequencyHz(frequencyIndices);
subsetList=enumerate_subsets(9,3:9);
branch4Count=numel(subsetList);
methodCount=3+branch4Count;
fprintf('复响应方法总数：3个参考分支 + %d个Branch4子集 = %d。\n',branch4Count,methodCount);

elementCount=size(measurements(1).rev.ZRev,1);
frequencyCount=numel(frequencyIndices);
locationCount=4;
responses=complex(nan(elementCount,frequencyCount,locationCount,methodCount));
valid=false(elementCount,frequencyCount,locationCount,methodCount);
trainFitNmseDb=nan(methodCount,locationCount);
heldOutFitNmseDb=nan(methodCount,locationCount);
validFraction=nan(methodCount,locationCount);
methodRows=cell(methodCount,13);

referenceIds={'B1_DFT8','B2_ONOFF','B3_HADAMARD'};
for methodIndex=1:3
    branch=referenceBranches{methodIndex};
    for locationIndex=1:locationCount
        responses(:,:,locationIndex,methodIndex)=branch.H{locationIndex}(:,frequencyIndices);
        valid(:,:,locationIndex,methodIndex)=branch.valid{locationIndex}(:,frequencyIndices);
        validFraction(methodIndex,locationIndex)=mean(valid(:,:,locationIndex,methodIndex),'all');
    end
    if methodIndex==1
        stateCount=8; uniquePhaseCount=8; observationIndices='1/2/3/4/5/6/7/8';
        phaseSet='0/45/90/135/180/225/270/315';
    else
        stateCount=NaN; uniquePhaseCount=NaN; observationIndices=''; phaseSet='';
    end
    methodRows(methodIndex,:)={methodIndex,referenceIds{methodIndex},cfg.branchNames{methodIndex}, ...
        cfg.branchLabels{methodIndex},stateCount,uniquePhaseCount,observationIndices,phaseSet, ...
        NaN,NaN,true,methodIndex==1,''};
end

for subsetIndex=1:branch4Count
    methodIndex=3+subsetIndex;
    observationIndices=subsetList{subsetIndex};
    selectedPhaseDeg=phaseDeg(observationIndices);
    design=[ones(numel(observationIndices),1),2*cosd(selectedPhaseDeg(:)), ...
        -2*sind(selectedPhaseDeg(:))];
    designRank=rank(design,1e-10);
    if designRank==3, designCondition=cond(design); else, designCondition=Inf; end
    recoverable=designRank==3;
    canonical=numel(observationIndices)==8 && isequal(observationIndices,1:8);
    methodId=sprintf('B4_K%02d_I%s',numel(observationIndices), ...
        strjoin(compose('%02d',observationIndices),'-'));
    if recoverable, failureReason=''; else, failureReason='PowerDesignRankBelow3'; end
    methodRows(methodIndex,:)={methodIndex,methodId,'Branch4','PowerREV', ...
        numel(observationIndices),numel(unique(mod(selectedPhaseDeg,360))), ...
        strjoin(compose('%d',observationIndices),'/'), ...
        strjoin(compose('%g',selectedPhaseDeg),'/'),designRank,designCondition, ...
        recoverable,canonical,failureReason};
    if ~recoverable, continue; end

    heldOut=setdiff(1:9,observationIndices,'stable');
    for locationIndex=1:locationCount
        rev=measurements(locationIndex).rev;
        powerData=abs(rev.ZRev(:,frequencyIndices,:)).^2;
        [h,v,diagnostics]=recover_power_rev_ls(powerData(:,:,observationIndices), ...
            deg2rad(selectedPhaseDeg),rev.config.rev.minBackgroundMagnitude, ...
            powerData(:,:,heldOut),deg2rad(phaseDeg(heldOut)));
        responses(:,:,locationIndex,methodIndex)=h;
        valid(:,:,locationIndex,methodIndex)=v;
        trainFitNmseDb(methodIndex,locationIndex)=diagnostics.trainNmseDb;
        heldOutFitNmseDb(methodIndex,locationIndex)=diagnostics.evaluationNmseDb;
        validFraction(methodIndex,locationIndex)=diagnostics.validFraction;
    end
    if mod(subsetIndex,50)==0 || subsetIndex==branch4Count
        fprintf('已恢复Branch4子集 %d/%d。\n',subsetIndex,branch4Count);
    end
end

methodTable=cell2table(methodRows,'VariableNames',{'MethodIndex','MethodId','Branch', ...
    'Estimator','StateCount','UniquePhaseCount','ObservationIndices','PhaseSetDeg', ...
    'PowerDesignRank','PowerDesignCondition','Recoverable','Canonical','FailureReason'});
canonicalB4Index=methodTable.MethodIndex(strcmp(methodTable.Branch,'Branch4')&methodTable.Canonical);
if numel(canonicalB4Index)~=1
    error('ExhaustiveREV:CanonicalCount','应且仅应存在一个Branch4八相位正式基准。');
end

referenceMethodIndices=[1,2,3,canonicalB4Index];
referenceNames={'Branch1','Branch2','Branch3','Branch4Canonical'};
agreementRows=cell(methodCount*locationCount*numel(referenceMethodIndices),13);
row=0;
for methodIndex=1:methodCount
    for locationIndex=1:locationCount
        for referenceIndex=1:numel(referenceMethodIndices)
            row=row+1;
            referenceMethodIndex=referenceMethodIndices(referenceIndex);
            metrics=complex_response_metrics(responses(:,:,locationIndex,referenceMethodIndex), ...
                responses(:,:,locationIndex,methodIndex),1:frequencyCount,12);
            agreementRows(row,:)={methodIndex,methodTable.MethodId{methodIndex}, ...
                methodTable.Branch{methodIndex},locationIndex,cfg.locationNames{locationIndex}, ...
                referenceNames{referenceIndex},metrics.medianCoherence, ...
                metrics.medianPhaseRmseDeg,metrics.medianComplexNmseDb, ...
                metrics.medianMagnitudeNrmse,metrics.medianMagnitudeCorrelation, ...
                metrics.frequencyCount,validFraction(methodIndex,locationIndex)};
        end
    end
end
responseAgreement=cell2table(agreementRows,'VariableNames',{'MethodIndex','MethodId','Branch', ...
    'LocationIndex','Location','Reference','MedianCoherence','MedianPhaseRmseDeg', ...
    'MedianComplexNmseDb','MedianMagnitudeNrmse','MedianMagnitudeCorrelation', ...
    'ComparedFrequencyCount','ValidFraction'});

summary=build_method_summary(methodTable,responseAgreement,validFraction, ...
    trainFitNmseDb,heldOutFitNmseDb);
cache=struct('config',cfg,'options',options,'frequencyHz',selectedFrequencyHz, ...
    'sourceFrequencyIndices',frequencyIndices,'phaseDeg',phaseDeg, ...
    'methodTable',methodTable,'responses',responses,'valid',valid, ...
    'trainFitNmseDb',trainFitNmseDb,'heldOutFitNmseDb',heldOutFitNmseDb, ...
    'validFraction',validFraction,'responseAgreement',responseAgreement, ...
    'methodSummary',summary,'canonicalB4MethodIndex',canonicalB4Index, ...
    'sourceFiles',{arrayfun(@(m)m.files,measurements,'UniformOutput',false)});

outputDir=fullfile(root,'output'); if ~isfolder(outputDir),mkdir(outputDir);end
save(fullfile(outputDir,'exhaustive_response_cache.mat'),'cache','-v7.3');
writetable(methodTable,fullfile(outputDir,'exhaustive_response_methods.csv'));
writetable(responseAgreement,fullfile(outputDir,'exhaustive_response_agreement.csv'));
writetable(summary,fullfile(outputDir,'exhaustive_response_summary.csv'));
for branchIndex=1:4
    branchOutput=fullfile(root,cfg.branchNames{branchIndex},'output');
    if ~isfolder(branchOutput),mkdir(branchOutput);end
    methodMask=strcmp(methodTable.Branch,cfg.branchNames{branchIndex});
    methodIndices=methodTable.MethodIndex(methodMask);
    writetable(methodTable(methodMask,:),fullfile(branchOutput,'exhaustive_response_methods.csv'));
    writetable(summary(methodMask,:),fullfile(branchOutput,'exhaustive_response_summary.csv'));
    agreementMask=ismember(responseAgreement.MethodIndex,methodIndices);
    writetable(responseAgreement(agreementMask,:), ...
        fullfile(branchOutput,'exhaustive_response_agreement.csv'));
end
write_exhaustive_response_report(fullfile(outputDir,'EXHAUSTIVE_RESPONSE_REPORT.md'),cache);
fprintf('穷举复响应完成：%s\n',fullfile(outputDir,'EXHAUSTIVE_RESPONSE_REPORT.md'));
clear pathCleanup;
end

function indices=select_frequency_indices(frequencyHz,range,count)
band=find(frequencyHz>=range(1)&frequencyHz<=range(2));
pick=unique(round(linspace(1,numel(band),min(count,numel(band)))));
indices=band(pick);
end

function subsets=enumerate_subsets(observationCount,stateCounts)
subsets=cell(sum(arrayfun(@(k)nchoosek(observationCount,k),stateCounts)),1);
row=0;
for stateCount=stateCounts
    combinations=nchoosek(1:observationCount,stateCount);
    for index=1:size(combinations,1)
        row=row+1; subsets{row}=combinations(index,:);
    end
end
end

function summary=build_method_summary(methodTable,agreement,validFraction,trainFit,heldOutFit)
methodCount=height(methodTable);
rows=cell(methodCount,28);
references={'Branch1','Branch2','Branch3','Branch4Canonical'};
for methodIndex=1:methodCount
    values={};
    for referenceIndex=1:numel(references)
        mask=agreement.MethodIndex==methodIndex&strcmp(agreement.Reference,references{referenceIndex});
        values=[values,{median(agreement.MedianCoherence(mask),'omitnan'), ...
            median(agreement.MedianPhaseRmseDeg(mask),'omitnan'), ...
            median(agreement.MedianComplexNmseDb(mask),'omitnan'), ...
            median(agreement.MedianMagnitudeNrmse(mask),'omitnan')}]; %#ok<AGROW>
    end
    rows(methodIndex,:)=[table2cell(methodTable(methodIndex,1:3)), ...
        {methodTable.StateCount(methodIndex),methodTable.UniquePhaseCount(methodIndex), ...
        methodTable.PowerDesignRank(methodIndex),methodTable.PowerDesignCondition(methodIndex), ...
        methodTable.Recoverable(methodIndex),methodTable.Canonical(methodIndex), ...
        median(validFraction(methodIndex,:),'omitnan'),median(trainFit(methodIndex,:),'omitnan'), ...
        median(heldOutFit(methodIndex,:),'omitnan')},values];
end
names={'MethodIndex','MethodId','Branch','StateCount','UniquePhaseCount','PowerDesignRank', ...
    'PowerDesignCondition','Recoverable','Canonical','MedianValidFraction', ...
    'MedianTrainingFitNmseDb','MedianHeldOutFitNmseDb'};
for referenceIndex=1:numel(references)
    prefix=references{referenceIndex};
    names=[names,{[prefix,'Coherence'],[prefix,'PhaseRmseDeg'], ...
        [prefix,'ComplexNmseDb'],[prefix,'MagnitudeNrmse']}]; %#ok<AGROW>
end
summary=cell2table(rows,'VariableNames',names);
end
