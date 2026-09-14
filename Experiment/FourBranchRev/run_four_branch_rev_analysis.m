function bundle=run_four_branch_rev_analysis(varargin)
%RUN_FOUR_BRANCH_REV_ANALYSIS 四分支复响应恢复、相移级数扫描与响应级验证。

parser=inputParser;
parser.addParameter('MetricFrequencyCount',51,@(x)isnumeric(x)&&isscalar(x)&&x>=3);
parser.parse(varargin{:}); options=parser.Results;
root=fileparts(mfilename('fullpath'));
commonDir=fullfile(root,'common');
branchDirs=arrayfun(@(k)fullfile(root,sprintf('Branch%d',k)),1:4,'UniformOutput',false);
addpath(commonDir,branchDirs{:});
pathCleanup=onCleanup(@()rmpath(commonDir,branchDirs{:}));

cfg=four_branch_config;
cfg.metricFrequencyCount=options.MetricFrequencyCount;
resultsRoot=fullfile(fileparts(root),'Real_test','results');
measurements=load_experiment_measurements(resultsRoot,cfg);
schedule=build_rev_state_schedule(measurements(1).rev.config.rev.phaseDeg, ...
    cfg.stateAdditionOrderDeg);

fprintf('计算 Branch1--4 规范复响应...\n');
branches=cell(4,1);
branches{1}=compute_branch1(measurements,schedule);
branches{2}=compute_branch2(measurements);
branches{3}=compute_branch3(measurements);
branches{4}=compute_branch4(measurements,schedule);
frequencyHz=measurements(1).frequencyHz;
band=find(frequencyHz>=cfg.frequencyRangeHz(1)&frequencyHz<=cfg.frequencyRangeHz(2));
pick=unique(round(linspace(1,numel(band),min(cfg.metricFrequencyCount,numel(band)))));
frequencyIndices=band(pick);

pairRows=cell(24,11); row=0; pairs=nchoosek(1:4,2);
for locationIndex=1:4
    for pairIndex=1:size(pairs,1)
        a=pairs(pairIndex,1); b=pairs(pairIndex,2);
        m=complex_response_metrics(branches{a}.H{locationIndex}, ...
            branches{b}.H{locationIndex},frequencyIndices,12);
        row=row+1;
        pairRows(row,:)={cfg.locationNames{locationIndex},cfg.branchNames{a}, ...
            cfg.branchLabels{a},cfg.branchNames{b},cfg.branchLabels{b}, ...
            m.medianCoherence,m.medianPhaseRmseDeg,m.medianComplexNmseDb, ...
            m.medianMagnitudeNrmse,m.medianMagnitudeCorrelation,m.frequencyCount};
    end
end
pairMetrics=cell2table(pairRows,'VariableNames',{'Location','BranchA','MethodA', ...
    'BranchB','MethodB','MedianCoherence','MedianPhaseRmseDeg','MedianComplexNmseDb', ...
    'MedianMagnitudeNrmse','MedianMagnitudeCorrelation','FrequencyCount'});

sweepRows=cell(4*7*2,19); row=0;
for methodIndex=[1,4]
    for locationIndex=1:4
        for slot=1:7
            item=branches{methodIndex}.sweep{locationIndex,slot};
            against=cell(3,1);
            against{1}=complex_response_metrics(branches{1}.H{locationIndex},item.H,frequencyIndices,12);
            against{2}=complex_response_metrics(branches{2}.H{locationIndex},item.H,frequencyIndices,12);
            against{3}=complex_response_metrics(branches{3}.H{locationIndex},item.H,frequencyIndices,12);
            row=row+1;
            sweepRows(row,:)={cfg.branchNames{methodIndex},cfg.branchLabels{methodIndex}, ...
                item.estimator,item.stateRole,cfg.locationNames{locationIndex}, ...
                item.stateCount,item.uniquePhaseCount, ...
                strjoin(compose('%g',item.phaseDeg),'/'),mean(item.valid,'all'), ...
                item.diagnostics.trainNmseDb,item.diagnostics.evaluationNmseDb, ...
                against{1}.medianCoherence,against{1}.medianComplexNmseDb, ...
                against{2}.medianCoherence,against{2}.medianComplexNmseDb, ...
                against{3}.medianCoherence,against{3}.medianComplexNmseDb, ...
                against{1}.medianPhaseRmseDeg,against{1}.medianMagnitudeNrmse};
        end
    end
end
sweepMetrics=cell2table(sweepRows,'VariableNames',{'Branch','Method','Estimator','StateRole', ...
    'Location','StateCount','UniquePhaseCount','PhaseSetDeg','ValidFraction','TrainingFitNmseDb', ...
    'HeldOutFitNmseDb','VsBranch1Coherence','VsBranch1ComplexNmseDb', ...
    'VsBranch2Coherence','VsBranch2ComplexNmseDb','VsBranch3Coherence', ...
    'VsBranch3ComplexNmseDb','VsBranch1PhaseRmseDeg','VsBranch1MagnitudeNrmse'});

bundle=struct(); bundle.config=cfg; bundle.schedule=schedule;
bundle.frequencyHz=frequencyHz; bundle.metricFrequencyIndices=frequencyIndices;
bundle.branches=branches; bundle.pairMetrics=pairMetrics; bundle.sweepMetrics=sweepMetrics;
bundle.sourceFiles={measurements.files};

outputDir=fullfile(root,'output'); if ~isfolder(outputDir),mkdir(outputDir);end
save(fullfile(outputDir,'four_branch_responses.mat'),'bundle','-v7.3');
writetable(pairMetrics,fullfile(outputDir,'response_pair_metrics.csv'));
writetable(sweepMetrics,fullfile(outputDir,'rev_state_sweep_metrics.csv'));
for branchIndex=1:4
    branch=branches{branchIndex};
    branchOutput=fullfile(root,cfg.branchNames{branchIndex},'output');
    if ~isfolder(branchOutput),mkdir(branchOutput);end
    save(fullfile(branchOutput,sprintf('%s_Response.mat',cfg.branchNames{branchIndex})), ...
        'branch','-v7.3');
    clear branch;
    involved=strcmp(pairMetrics.BranchA,cfg.branchNames{branchIndex})| ...
        strcmp(pairMetrics.BranchB,cfg.branchNames{branchIndex});
    writetable(pairMetrics(involved,:),fullfile(branchOutput,'response_agreement.csv'));
    if ismember(branchIndex,[1,4])
        ownSweep=strcmp(sweepMetrics.Branch,cfg.branchNames{branchIndex});
        writetable(sweepMetrics(ownSweep,:),fullfile(branchOutput,'state_sweep_metrics.csv'));
    end
end
write_rev_analysis_report(fullfile(outputDir,'FOUR_BRANCH_RESPONSE_REPORT.md'),bundle);
plot_response_progression(fullfile(outputDir,'response_state_progression.png'),bundle);
fprintf('复响应分析完成：%s\n',fullfile(outputDir,'FOUR_BRANCH_RESPONSE_REPORT.md'));
clear pathCleanup;
end
