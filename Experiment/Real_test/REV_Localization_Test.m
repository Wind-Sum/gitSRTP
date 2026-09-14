%% 4x8 DUT 阵列到 Horn 的 REV 信道测量
% 其他31路保持全开，仅旋转当前TX阵元相位。
% 0:45:315用于复数DFT和功率REV解算，360°仅用于闭合重复性检查。

clearvars;
clc;

%% 用户配置
cfg.vna.ipAddress = '192.168.0.10';
cfg.vna.port = 5001;
cfg.vna.timeoutSeconds = 120;
cfg.vna.channel = 1;
cfg.vna.trace = 1;
cfg.vna.sParameter = 'S21';
cfg.vna.centerFrequencyHz = 5.0e9;
cfg.vna.spanFrequencyHz = 1e9;
cfg.vna.pointCount = 2001;
cfg.vna.ifBandwidthHz = 5e3;
cfg.vna.powerLevel = 'LOW';

cfg.txApm.ipAddress = '192.168.0.251';
cfg.txApm.port = 28888;
cfg.txApm.name = 'TX APM (1->32)';
cfg.apmTimeoutSeconds = 5;
cfg.apmExpectedFrequencyMHz = 5000;
cfg.apmFrequencyToleranceMHz = 0.5;
cfg.apmSettleSeconds = 1.0;
cfg.apmCommandRetries = 2;
cfg.apmReadbackAttToleranceDb = 0.125001;
cfg.apmReadbackPhaseToleranceDeg = 0.703126;

cfg.allPorts = 1:32;
cfg.onAttenuationDb = 0;
cfg.offAttenuationDb = 90;
cfg.onPhaseDeg = 0;
cfg.txCommonAttenuationDb = 0;

cfg.txExtra.enabled = false;
cfg.txExtra.ports = [5, 10, 20];
cfg.txExtra.attenuationDb = [2, 4, 6];
cfg.txExtra.phaseDeg = [20, 40, 60];

cfg.rev.phaseDeg = 0:45:360;
cfg.rev.minBackgroundMagnitude = 1e-12;
cfg.numRepeats = 1;
cfg.showFigure = true;

scriptDirectory = resolveScriptDirectory('REV_Localization_Test.m');
cfg.outputRoot = fullfile(scriptDirectory, 'results');

%% 执行测量
cfg = validateConfig(cfg);
[txAttenuationCommandsDb, txPhaseCommandsDeg, ...
    txExtraAttenuationByPortDb, txExtraPhaseByPortDeg] = ...
    buildRevCommandMatrices(cfg);
portMap = buildPortMap();
phaseCount = numel(cfg.rev.phaseDeg);
totalStates = 32 * phaseCount;

timestamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss_SSS'));
runDirectory = fullfile(cfg.outputRoot, ['REV_Localization_', timestamp]);
ensureDirectory(runDirectory);
files.checkpoint = fullfile(runDirectory, 'REV_Localization_Checkpoint.mat');
files.mat = fullfile(runDirectory, 'REV_Localization_Result.mat');
files.csv = fullfile(runDirectory, 'REV_Channel_Response.csv');
files.png = fullfile(runDirectory, 'REV_Channel_CenterFrequency.png');

fprintf('\n========== REV 阵元信道测量 ==========\n');
fprintf('VNA：%s:%d，4–6 GHz，%d点，功率%s\n', ...
    cfg.vna.ipAddress, cfg.vna.port, cfg.vna.pointCount, cfg.vna.powerLevel);
fprintf('REV相位：%s deg；总状态数%d\n', ...
    mat2str(cfg.rev.phaseDeg), totalStates);
fprintf('TX APM：%s:%d；RX Horn直连VNA Port 2\n', ...
    cfg.txApm.ipAddress, cfg.txApm.port);
fprintf('结果目录：%s\n\n', runDirectory);

vna = [];
txApm = [];
try
    [vna, txApm, deviceInfo] = connectSystem(cfg);
catch exception
    safeDeleteClient(vna);
    safeDeleteClient(txApm);
    rethrow(exception);
end
systemCleanup = onCleanup(@() shutdownSystem(vna, txApm, cfg));

frequencyHz = [];
ZRevRepeats = complex(nan(32, cfg.vna.pointCount, ...
    phaseCount, cfg.numRepeats));
ZRev = complex(nan(32, cfg.vna.pointCount, phaseCount));
completedElements = 0;
completedStates = 0;
vnaActual = struct();
apmFrequencyMHz = struct();
apmReadback = struct();
apmReadback.txInitialAllOff = struct();
apmReadback.txStateAttenuationDb = nan(32, phaseCount, 32);
apmReadback.txStatePhaseDeg = nan(32, phaseCount, 32);
apmReadback.txStateRawReply = strings(32, phaseCount);
measurementStart = datetime('now');

try
    apmFrequencyMHz = queryApmFrequency(txApm);
    validateApmFrequency(apmFrequencyMHz, cfg, cfg.txApm.name);
    configureVna(vna, cfg.vna);
    checkVnaErrors(vna, 'VNA参数设置');
    vnaActual = readBackVnaSettings(vna, cfg.vna);
    displayVnaSettings(vnaActual);

    apmReadback.txInitialAllOff = ...
        setApmAllOff(txApm, cfg, 'TX initial all-off');
    pause(cfg.apmSettleSeconds);
    writeVna(vna, sprintf(':SENS%d:HOLD:FUNC HOLD', cfg.vna.channel));
    writeVna(vna, sprintf(':CALC%d:PAR%d:SEL', ...
        cfg.vna.channel, cfg.vna.trace));
    writeVna(vna, sprintf(':CALC%d:PAR%d:FORM PLINCOMP', ...
        cfg.vna.channel, cfg.vna.trace));

    for elementIndex = 1:32
        fprintf('REV阵元%02d/32\n', elementIndex);
        for phaseIndex = 1:phaseCount
            phaseValueDeg = cfg.rev.phaseDeg(phaseIndex);
            fprintf('  相位%6.1f°：设置 ... ', phaseValueDeg);
            txAttenuationDb = reshape( ...
                txAttenuationCommandsDb(elementIndex, phaseIndex, :), 1, []);
            txPhaseDeg = reshape( ...
                txPhaseCommandsDeg(elementIndex, phaseIndex, :), 1, []);
            [actualAttenuationDb, actualPhaseDeg, rawReadbackReply] = ...
                sendApmState(txApm, cfg.allPorts, txAttenuationDb, ...
                txPhaseDeg, cfg, sprintf('REV element %d phase %.1f', ...
                elementIndex, phaseValueDeg));
            apmReadback.txStateAttenuationDb(elementIndex, phaseIndex, :) = ...
                reshape(actualAttenuationDb, 1, 1, []);
            apmReadback.txStatePhaseDeg(elementIndex, phaseIndex, :) = ...
                reshape(actualPhaseDeg, 1, 1, []);
            apmReadback.txStateRawReply(elementIndex, phaseIndex) = ...
                rawReadbackReply;
            pause(cfg.apmSettleSeconds);
            fprintf('采集');

            for repeatIndex = 1:cfg.numRepeats
                [currentFrequencyHz, currentSweep] = ...
                    acquireVnaSweep(vna, cfg.vna);
                if isempty(frequencyHz)
                    frequencyHz = currentFrequencyHz;
                else
                    validateFrequencyAxis(frequencyHz, currentFrequencyHz);
                end
                ZRevRepeats(elementIndex, :, phaseIndex, repeatIndex) = ...
                    currentSweep(:).';
                fprintf('.');
            end
            ZRev(elementIndex, :, phaseIndex) = mean( ...
                ZRevRepeats(elementIndex, :, phaseIndex, :), 4, 'omitnan');
            completedStates = completedStates + 1;
            checkVnaErrors(vna, sprintf('REV阵元%d相位%.1f°采集', ...
                elementIndex, phaseValueDeg));

            elapsedSeconds = seconds(datetime('now') - measurementStart);
            remainingSeconds = elapsedSeconds / completedStates * ...
                (totalStates - completedStates);
            fprintf(' 完成，预计剩余%.1f min。\n', remainingSeconds / 60);
        end
        completedElements = elementIndex;
        saveCheckpoint(files.checkpoint, 'measuring', cfg, timestamp, ...
            deviceInfo, vnaActual, apmFrequencyMHz, portMap, ...
            txAttenuationCommandsDb, txPhaseCommandsDeg, apmReadback, ...
            frequencyHz, ZRevRepeats, ZRev, completedElements, ...
            completedStates, []);
    end

    revDiagnostics = solveRevChannels(ZRev, cfg.rev);
    HRevComplex = revDiagnostics.HComplex;
    HRevPower = revDiagnostics.HPower;
    HChannel = HRevComplex;
    weakBackgroundCount = nnz(~revDiagnostics.powerBackgroundStrong);
    ambiguousRootCount = nnz(~revDiagnostics.powerRootSeparated);
    if weakBackgroundCount > 0 || ambiguousRootCount > 0
        warning('REVArray:PowerRevInvalidPoints', ...
            ['功率REV有%d个频点背景过弱、%d个频点两根区分不足；' ...
             '这些点的HRevPower已标为NaN，请使用powerValid定位。'], ...
            weakBackgroundCount, ambiguousRootCount);
    end

    result = struct();
    result.status = 'complete';
    result.method = 'rev';
    result.timestamp = timestamp;
    result.completedElements = completedElements;
    result.completedStates = completedStates;
    result.config = cfg;
    result.deviceInfo = deviceInfo;
    result.vnaActualSettings = vnaActual;
    result.apmFrequencyMHz = apmFrequencyMHz;
    result.portMap = portMap;
    result.txAttenuationCommandsDb = txAttenuationCommandsDb;
    result.txPhaseCommandsDeg = txPhaseCommandsDeg;
    result.txExtraAttenuationByPortDb = txExtraAttenuationByPortDb;
    result.txExtraPhaseByPortDeg = txExtraPhaseByPortDeg;
    result.apmReadback = apmReadback;
    result.frequencyHz = frequencyHz;
    result.ZRevRepeats = ZRevRepeats;
    result.ZRev = ZRev;
    result.HRevComplex = HRevComplex;
    result.HRevPower = HRevPower;
    result.HChannel = HChannel;
    result.revDiagnostics = revDiagnostics;
    result.files = files;
    result.measurementStart = char(measurementStart);
    result.measurementEnd = char(datetime('now'));
    result.notes = ['HChannel采用复数DFT结果；HRevPower为严格仅由功率恢复的H/T，' ...
        '不使用VNA复数背景相位。360°状态只用于0°/360°闭合校验。'];

    save(files.mat, 'result', '-v7.3');
    writeRevCsv(files.csv, result);
    createQualityFigure(files.png, result);
    saveCheckpoint(files.checkpoint, 'complete', cfg, timestamp, ...
        deviceInfo, vnaActual, apmFrequencyMHz, portMap, ...
        txAttenuationCommandsDb, txPhaseCommandsDeg, apmReadback, ...
        frequencyHz, ZRevRepeats, ZRev, completedElements, ...
        completedStates, []);

    fprintf('\nREV测量与解算完成。功率REV有效点比例：%.2f%%\n', ...
        100 * mean(revDiagnostics.powerValid, 'all'));
    fprintf('MAT：%s\nCSV：%s\nPNG：%s\n', ...
        files.mat, files.csv, files.png);
catch exception
    failure = exceptionToStruct(exception);
    try
        saveCheckpoint(files.checkpoint, 'failed', cfg, timestamp, ...
            getVariableOrDefault('deviceInfo', struct()), vnaActual, ...
            apmFrequencyMHz, portMap, txAttenuationCommandsDb, ...
            txPhaseCommandsDeg, apmReadback, frequencyHz, ...
            ZRevRepeats, ZRev, completedElements, completedStates, failure);
    catch checkpointException
        warning('REVArray:CheckpointSaveFailed', ...
            '故障检查点保存失败：%s', checkpointException.message);
    end
    fprintf(2, '\nREV在完成%d/%d个状态后失败；检查点：%s\n', ...
        completedStates, totalStates, files.checkpoint);
    clear systemCleanup;
    rethrow(exception);
end

clear systemCleanup;

%% 局部函数
function directory = resolveScriptDirectory(expectedFileName)
%RESOLVESCRIPTDIRECTORY 定位编辑器中的原始脚本，拒绝临时执行副本。

try
    activeFile = char(matlab.desktop.editor.getActiveFilename);
catch
    activeFile = '';
end
if isfile(activeFile)
    [~, activeName, activeExtension] = fileparts(activeFile);
    if strcmpi([activeName, activeExtension], expectedFileName)
        directory = fileparts(activeFile);
        return;
    end
end

locatedFile = which(expectedFileName);
if ~isempty(locatedFile) && isfile(locatedFile)
    directory = fileparts(locatedFile);
    return;
end

error('REVArray:ScriptLocationUnknown', ...
    ['无法确定脚本的真实保存位置。请先将脚本保存为 %s，' ...
     '然后从 MATLAB 编辑器运行完整脚本。'], expectedFileName);
end

function cfg = validateConfig(cfg)
%VALIDATECONFIG 检查用户配置和实验约束。

validateattributes(cfg.vna.port, {'numeric'}, ...
    {'scalar', 'integer', '>=', 1, '<=', 65535});
validateattributes(cfg.vna.timeoutSeconds, {'numeric'}, ...
    {'scalar', 'real', 'finite', 'positive'});
validateattributes(cfg.vna.channel, {'numeric'}, ...
    {'scalar', 'integer', '>=', 1, '<=', 16});
validateattributes(cfg.vna.trace, {'numeric'}, ...
    {'scalar', 'integer', '>=', 1, '<=', 16});
validateattributes(cfg.vna.centerFrequencyHz, {'numeric'}, ...
    {'scalar', 'real', 'finite', 'positive'});
validateattributes(cfg.vna.spanFrequencyHz, {'numeric'}, ...
    {'scalar', 'real', 'finite', '>=', 20, '<=', 5.5e9});
validateattributes(cfg.vna.pointCount, {'numeric'}, ...
    {'scalar', 'integer', '>=', 2, '<=', 20001});
validateattributes(cfg.vna.ifBandwidthHz, {'numeric'}, ...
    {'scalar', 'real', 'finite', 'positive'});
validateattributes(cfg.apmTimeoutSeconds, {'numeric'}, ...
    {'scalar', 'real', 'finite', 'positive'});
validateattributes(cfg.apmExpectedFrequencyMHz, {'numeric'}, ...
    {'scalar', 'real', 'finite', 'positive'});
validateattributes(cfg.apmFrequencyToleranceMHz, {'numeric'}, ...
    {'scalar', 'real', 'finite', 'nonnegative'});
validateattributes(cfg.apmSettleSeconds, {'numeric'}, ...
    {'scalar', 'real', 'finite', 'nonnegative'});
validateattributes(cfg.apmCommandRetries, {'numeric'}, ...
    {'scalar', 'integer', '>=', 1});
validateattributes(cfg.apmReadbackAttToleranceDb, {'numeric'}, ...
    {'scalar', 'real', 'finite', 'nonnegative'});
validateattributes(cfg.apmReadbackPhaseToleranceDeg, {'numeric'}, ...
    {'scalar', 'real', 'finite', 'nonnegative'});
validateattributes(cfg.numRepeats, {'numeric'}, ...
    {'scalar', 'integer', '>=', 1});
validateattributes(cfg.showFigure, {'logical', 'numeric'}, {'scalar'});
validateattributes(cfg.onAttenuationDb, {'numeric'}, ...
    {'scalar', 'real', 'finite', '>=', 0, '<=', 90});
validateattributes(cfg.offAttenuationDb, {'numeric'}, ...
    {'scalar', 'real', 'finite', '>=', 0, '<=', 90});
validateattributes(cfg.onPhaseDeg, {'numeric'}, {'scalar', 'real', 'finite'});
validateattributes(cfg.rev.phaseDeg, {'numeric'}, ...
    {'vector', 'real', 'finite'});
validateattributes(cfg.rev.minBackgroundMagnitude, {'numeric'}, ...
    {'scalar', 'real', 'finite', 'nonnegative'});
validateattributes(cfg.txCommonAttenuationDb, {'numeric'}, ...
    {'scalar', 'real', 'finite', '>=', 0, '<=', 25});
validateattributes(cfg.txExtra.enabled, {'logical', 'numeric'}, {'scalar'});
validateattributes(cfg.txExtra.ports, {'numeric'}, ...
    {'vector', 'integer', '>=', 1, '<=', 32});
validateattributes(cfg.txExtra.attenuationDb, {'numeric'}, ...
    {'vector', 'real', 'finite', 'nonnegative'});
validateattributes(cfg.txExtra.phaseDeg, {'numeric'}, ...
    {'vector', 'real', 'finite'});

cfg.vna.ipAddress = validateNonemptyText(cfg.vna.ipAddress, 'VNA IP');
cfg.txApm.ipAddress = validateNonemptyText(cfg.txApm.ipAddress, 'TX APM IP');
cfg.vna.sParameter = validatestring(upper(string(cfg.vna.sParameter)), ...
    {'S11', 'S12', 'S21', 'S22'});
cfg.vna.powerLevel = validatestring(upper(string(cfg.vna.powerLevel)), ...
    {'HIGH', 'LOW'});
cfg.showFigure = logical(cfg.showFigure);
cfg.txExtra.enabled = logical(cfg.txExtra.enabled);
cfg.rev.phaseDeg = cfg.rev.phaseDeg(:).';
cfg.txExtra.ports = cfg.txExtra.ports(:).';
cfg.txExtra.attenuationDb = cfg.txExtra.attenuationDb(:).';
cfg.txExtra.phaseDeg = cfg.txExtra.phaseDeg(:).';
cfg.outputRoot = validateNonemptyText(cfg.outputRoot, '输出根目录');

if numel(cfg.rev.phaseDeg) < 4 || cfg.rev.phaseDeg(1) ~= 0 || ...
        cfg.rev.phaseDeg(end) ~= 360
    error('REVArray:InvalidPhaseGrid', ...
        'cfg.rev.phaseDeg 必须从0°开始、以360°结束，并至少包含4个点。');
end
solvePhaseDeg = cfg.rev.phaseDeg(1:end-1);
if numel(unique(mod(solvePhaseDeg, 360))) ~= numel(solvePhaseDeg)
    error('REVArray:DuplicateSolvePhase', ...
        '除末尾360°外，REV解算相位不能重复。');
end
phaseStepDeg = diff(solvePhaseDeg);
expectedStepDeg = 360 / numel(solvePhaseDeg);
if any(abs(phaseStepDeg - expectedStepDeg) > 1e-9) || ...
        abs(solvePhaseDeg(end) - (360 - expectedStepDeg)) > 1e-9
    error('REVArray:NonuniformPhaseGrid', ...
        'REV解算相位必须在0至360°内均匀覆盖一个周期。');
end

extraLengths = [numel(cfg.txExtra.ports), ...
    numel(cfg.txExtra.attenuationDb), numel(cfg.txExtra.phaseDeg)];
if numel(unique(extraLengths)) ~= 1
    error('REVArray:TxExtraLengthMismatch', ...
        'cfg.txExtra.ports、attenuationDb 和 phaseDeg 必须等长。');
end
if numel(unique(cfg.txExtra.ports)) ~= numel(cfg.txExtra.ports)
    error('REVArray:DuplicateTxExtraPort', ...
        'cfg.txExtra.ports 不能包含重复端口。');
end
if any(cfg.onAttenuationDb + cfg.txCommonAttenuationDb + ...
        cfg.txExtra.attenuationDb > 25)
    error('REVArray:TxExtraAttenuationOutOfRange', ...
        '基础开启衰减、公共衰减与端口额外衰减之和不能超过 25 dB。');
end

if cfg.vna.centerFrequencyHz - cfg.vna.spanFrequencyHz / 2 < 3e9 || ...
        cfg.vna.centerFrequencyHz + cfg.vna.spanFrequencyHz / 2 > 8.5e9
    error('REVArray:FrequencyOutsideApmRange', ...
        'VNA 扫频范围必须位于 APM 的 3.0 至 8.5 GHz 工作频段内。');
end
if ~isequal(cfg.allPorts(:).', 1:32)
    error('REVArray:InvalidPortList', ...
        'cfg.allPorts 必须严格为 1:32。');
end
end

function textValue = validateNonemptyText(value, label)
%VALIDATENONEMPTYTEXT 规范化非空文本配置。

textValue = char(strtrim(string(value)));
if isempty(textValue)
    error('REVArray:EmptyConfigText', '%s 不能为空。', label);
end
end

function [attenuationCommandsDb, phaseCommandsDeg, ...
        extraAttenuationByPortDb, extraPhaseByPortDeg] = ...
        buildRevCommandMatrices(cfg)
%BUILDREVCOMMANDMATRICES 生成逐阵元旋转的完整32路状态矩阵。

elementCount = numel(cfg.allPorts);
phaseCount = numel(cfg.rev.phaseDeg);
extraAttenuationByPortDb = zeros(1, elementCount);
extraPhaseByPortDeg = zeros(1, elementCount);
if cfg.txExtra.enabled
    extraAttenuationByPortDb(cfg.txExtra.ports) = cfg.txExtra.attenuationDb;
    extraPhaseByPortDeg(cfg.txExtra.ports) = cfg.txExtra.phaseDeg;
end

baseAttenuationDb = cfg.onAttenuationDb + cfg.txCommonAttenuationDb + ...
    extraAttenuationByPortDb;
basePhaseDeg = mod(cfg.onPhaseDeg + extraPhaseByPortDeg, 360);
attenuationCommandsDb = repmat(reshape(baseAttenuationDb, 1, 1, []), ...
    elementCount, phaseCount, 1);
phaseCommandsDeg = repmat(reshape(basePhaseDeg, 1, 1, []), ...
    elementCount, phaseCount, 1);
for elementIndex = 1:elementCount
    for phaseIndex = 1:phaseCount
        phaseCommandsDeg(elementIndex, phaseIndex, elementIndex) = mod( ...
            basePhaseDeg(elementIndex) + cfg.rev.phaseDeg(phaseIndex), 360);
    end
end
end

function rev = solveRevChannels(ZRev, revConfig)
%SOLVEREVCHANNELS 使用复数DFT和严格纯功率REV解算逐阵元信道。

solvePhaseDeg = revConfig.phaseDeg(1:end-1);
thetaRad = deg2rad(solvePhaseDeg);
phaseCount = numel(thetaRad);
ZSolve = ZRev(:, :, 1:phaseCount);
negativeWeights = reshape(exp(-1j .* thetaRad), 1, 1, []);
positiveWeights = reshape(exp(1j .* thetaRad), 1, 1, []);

rev.background = mean(ZSolve, 3);
rev.HComplex = mean(ZSolve .* negativeWeights, 3);
complexFit = rev.background + rev.HComplex .* positiveWeights;
complexResidualPower = sum(abs(ZSolve - complexFit).^2, 3);
complexDataPower = sum(abs(ZSolve).^2, 3);
rev.complexFitNmseDb = 10 .* log10( ...
    complexResidualPower ./ max(complexDataPower, realmin));

powerData = abs(ZSolve).^2;
powerDc = mean(powerData, 3);
powerFirstHarmonic = mean(powerData .* negativeWeights, 3);
discriminant = powerDc.^2 - 4 .* abs(powerFirstHarmonic).^2;
discriminantTolerance = 1e-10 .* max(powerDc.^2, realmin);
rev.powerDiscriminantValid = discriminant >= -discriminantTolerance;
clampedDiscriminant = max(discriminant, 0);
elementMagnitudeSquared = max( ...
    (powerDc - sqrt(clampedDiscriminant)) ./ 2, 0);
elementMagnitude = sqrt(elementMagnitudeSquared);
relativePhase = angle(powerFirstHarmonic);
    backgroundMagnitude = sqrt(max( ...
        (powerDc + sqrt(clampedDiscriminant)) ./ 2, 0));
    relativeElement = elementMagnitude .* exp(1j .* relativePhase);
    relativeTotal = backgroundMagnitude + relativeElement;
    % powerFirstHarmonic = conj(B)*H。以下恢复 H/(B+H)，它与真实 H
    % 只相差全阵列共有的复标量，保留 DOA 所需信息，且不使用 VNA 相位。
    rev.HPower = relativeElement ./ relativeTotal;
    rev.powerRootSeparation = abs(backgroundMagnitude - elementMagnitude) ./ ...
        max(backgroundMagnitude + elementMagnitude, realmin);
    rev.powerRootSeparated = rev.powerRootSeparation >= 0.01;
    rev.powerBackgroundDominant = backgroundMagnitude >= elementMagnitude;
    rev.powerBackgroundStrong = ...
        backgroundMagnitude > revConfig.minBackgroundMagnitude;
    rev.powerTotalStrong = ...
        abs(relativeTotal) > revConfig.minBackgroundMagnitude;
    rev.powerValid = rev.powerDiscriminantValid & ...
        rev.powerBackgroundDominant & rev.powerBackgroundStrong & ...
        rev.powerTotalStrong & rev.powerRootSeparated;
rev.HPower(~rev.powerValid) = complex(NaN, NaN);

powerFit = powerDc + 2 .* real(powerFirstHarmonic .* positiveWeights);
powerResidual = sum((powerData - powerFit).^2, 3);
powerDataEnergy = sum(powerData.^2, 3);
rev.powerFitNmseDb = 10 .* log10( ...
    powerResidual ./ max(powerDataEnergy, realmin));
rev.powerDc = powerDc;
rev.powerFirstHarmonic = powerFirstHarmonic;

z0 = ZRev(:, :, 1);
z360 = ZRev(:, :, end);
rev.closureComplexError = z360 - z0;
closureRatio = z360 ./ z0;
closureRatio(abs(z0) <= realmin) = complex(NaN, NaN);
rev.closureMagnitudeDb = 20 .* log10(abs(closureRatio));
rev.closurePhaseDeg = angle(closureRatio) .* (180 / pi);
end

function portMap = buildPortMap()
%BUILDPORTMAP 建立端口与 4 列 x 8 行物理位置的映射。

portMap.matrixRowsBottomToTop = reshape(1:32, 8, 4);
portMap.port = (1:32).';
portMap.column = floor((portMap.port - 1) / 8) + 1;
portMap.rowFromBottom = mod(portMap.port - 1, 8) + 1;
end

function [vna, txApm, deviceInfo] = connectSystem(cfg)
%CONNECTSYSTEM 连接并识别 TX APM 和 VNA。

vna = [];
txApm = [];
try
    txApm = connectApm(cfg.txApm, cfg.apmTimeoutSeconds);
    deviceInfo.txApmIdentity = queryApmIdentity(txApm, cfg.txApm.name);
    vna = connectVna(cfg.vna);
    deviceInfo.vnaIdentity = strtrim(queryVna(vna, '*IDN?'));
    if ~contains(upper(deviceInfo.vnaIdentity), 'ANRITSU') || ...
            ~contains(upper(deviceInfo.vnaIdentity), 'MS46322')
        error('REVArray:UnexpectedVna', ...
            'VNA 身份不符合 Anritsu MS46322 系列：%s', ...
            deviceInfo.vnaIdentity);
    end
catch exception
    safeDeleteClient(vna);
    safeDeleteClient(txApm);
    rethrow(exception);
end

fprintf('TX APM 身份：%s\n', deviceInfo.txApmIdentity);
fprintf('VNA 身份：%s\n', deviceInfo.vnaIdentity);
end

function apm = connectApm(apmConfig, timeoutSeconds)
%CONNECTAPM 通过 TCP/IP 连接 APM，命令终止符为 CRLF。

fprintf('连接 %s：%s:%d ...\n', ...
    apmConfig.name, apmConfig.ipAddress, apmConfig.port);
try
    apm = tcpclient(apmConfig.ipAddress, apmConfig.port, ...
        'Timeout', timeoutSeconds);
catch exception
    error('REVArray:ApmConnectionFailed', ...
        '无法连接 %s %s:%d。原始错误：%s', ...
        apmConfig.name, apmConfig.ipAddress, apmConfig.port, exception.message);
end
configureTerminator(apm, "CR/LF");
flush(apm);
end

function identity = queryApmIdentity(apm, name)
%QUERYAPMIDENTITY 查询 APM IDN。

writeline(apm, 'SYSTem:IDN');
identity = strtrim(char(readline(apm)));
if isempty(identity)
    error('REVArray:EmptyApmIdentity', '%s 返回了空 IDN。', name);
end
fprintf('%s IDN：%s\n', name, identity);
end

function frequencyMHz = queryApmFrequency(apm)
%QUERYAPMFREQUENCY 查询 APM 当前使用的校准频点。

flush(apm, "input");
writeline(apm, 'QUERy:FREQuency');
reply = strtrim(char(readline(apm)));
token = regexp(reply, 'QUERy:FREQuency:\s*([-+0-9.]+)', ...
    'tokens', 'once', 'ignorecase');
if isempty(token)
    error('REVArray:InvalidApmFrequencyReply', ...
        '无法解析 APM 频点回复：%s', reply);
end
frequencyMHz = str2double(token{1});
if ~isfinite(frequencyMHz) || frequencyMHz <= 0
    error('REVArray:InvalidApmFrequency', ...
        'APM 返回了无效校准频点：%s', reply);
end
end

function validateApmFrequency(actualMHz, cfg, name)
%VALIDATEAPMFREQUENCY 要求 APM 当前频点与 5.0 GHz 中心匹配。

if abs(actualMHz - cfg.apmExpectedFrequencyMHz) > ...
        cfg.apmFrequencyToleranceMHz
    error('REVArray:ApmFrequencyMismatch', ...
        '%s 当前校准频点为 %.3f MHz，要求 %.3f +/- %.3f MHz。', ...
        name, actualMHz, cfg.apmExpectedFrequencyMHz, ...
        cfg.apmFrequencyToleranceMHz);
end
end

function vna = connectVna(vnaConfig)
%CONNECTVNA 连接 Anritsu MS46322B Raw Socket。

fprintf('连接 VNA：%s:%d ...\n', vnaConfig.ipAddress, vnaConfig.port);
try
    vna = tcpclient(vnaConfig.ipAddress, vnaConfig.port, ...
        'Timeout', vnaConfig.timeoutSeconds);
catch exception
    error('REVArray:VnaConnectionFailed', ...
        '无法连接 VNA %s:%d。原始错误：%s', ...
        vnaConfig.ipAddress, vnaConfig.port, exception.message);
end
configureTerminator(vna, "LF");
flush(vna);
end

function configureVna(vna, config)
%CONFIGUREVNA 设置 VNA 的基本扫频和 Trace 参数。

channel = config.channel;
trace = config.trace;
writeVna(vna, ':SYST:ERR:CLE');
writeVna(vna, sprintf(':SENS%d:HOLD:FUNC HOLD', channel));
writeVna(vna, sprintf(':SENS%d:SWE:TYPE LIN', channel));
writeVna(vna, sprintf(':SENS%d:FREQ:CENT %.15g', ...
    channel, config.centerFrequencyHz));
writeVna(vna, sprintf(':SENS%d:FREQ:SPAN %.15g', ...
    channel, config.spanFrequencyHz));
writeVna(vna, sprintf(':SENS%d:SWE:POIN %d', ...
    channel, config.pointCount));
writeVna(vna, sprintf(':SENS%d:BWID %.15g', ...
    channel, config.ifBandwidthHz));
writeVna(vna, sprintf(':SOUR%d:POW %s', channel, config.powerLevel));
writeVna(vna, sprintf(':CALC%d:PAR%d:DEF %s', ...
    channel, trace, config.sParameter));
writeVna(vna, sprintf(':CALC%d:PAR%d:SEL', channel, trace));
writeVna(vna, sprintf(':CALC%d:PAR%d:FORM MLOG', channel, trace));
end

function actual = readBackVnaSettings(vna, config)
%READBACKVNASETTINGS 读取仪器实际接受的配置。

channel = config.channel;
trace = config.trace;
actual.centerFrequencyHz = queryVnaNumber(vna, ...
    sprintf(':SENS%d:FREQ:CENT?', channel));
actual.spanFrequencyHz = queryVnaNumber(vna, ...
    sprintf(':SENS%d:FREQ:SPAN?', channel));
actual.startFrequencyHz = actual.centerFrequencyHz - actual.spanFrequencyHz / 2;
actual.stopFrequencyHz = actual.centerFrequencyHz + actual.spanFrequencyHz / 2;
actual.pointCount = queryVnaNumber(vna, ...
    sprintf(':SENS%d:SWE:POIN?', channel));
actual.ifBandwidthHz = queryVnaNumber(vna, ...
    sprintf(':SENS%d:BWID?', channel));
actual.powerLevel = queryVna(vna, sprintf(':SOUR%d:POW?', channel));
actual.sParameter = queryVna(vna, ...
    sprintf(':CALC%d:PAR%d:DEF?', channel, trace));
actual.displayFormat = queryVna(vna, ...
    sprintf(':CALC%d:PAR%d:FORM?', channel, trace));

if actual.pointCount ~= fix(actual.pointCount)
    error('REVArray:InvalidVnaPointCount', ...
        'VNA 返回了非整数扫频点数 %.15g。', actual.pointCount);
end
end

function displayVnaSettings(actual)
%DISPLAYVNASETTINGS 显示 VNA 实际参数。

fprintf('\nVNA 实际设置：\n');
fprintf('  频率：%.6f 至 %.6f GHz\n', ...
    actual.startFrequencyHz / 1e9, actual.stopFrequencyHz / 1e9);
fprintf('  点数：%d，IFBW：%.0f Hz，功率：%s，参数：%s\n\n', ...
    actual.pointCount, actual.ifBandwidthHz, ...
    actual.powerLevel, actual.sParameter);
end

function state = setApmAllOff(apm, cfg, tag)
%SETAPMALLOFF 将全部 32 路设置为关断隔离状态。

attenuationDb = repmat(cfg.offAttenuationDb, 1, 32);
phaseDeg = zeros(1, 32);
[actualAttenuationDb, actualPhaseDeg, rawReply] = sendApmState( ...
    apm, cfg.allPorts, attenuationDb, phaseDeg, cfg, tag);
state = struct('attenuationDb', actualAttenuationDb, ...
    'phaseDeg', actualPhaseDeg, 'rawReply', rawReply);
end

function [actualAttenuationDb, actualPhaseDeg, rawReadbackReply] = ...
        sendApmState(apm, ports, attenuationDb, phaseDeg, cfg, tag)
%SENDAPMSTATE 下发 SETM，收到 OK 后回读并校验全部通道状态。

command = buildApmSetMCommand(ports, attenuationDb, phaseDeg);
lastException = [];
for attempt = 1:cfg.apmCommandRetries
    try
        flush(apm, "input");
        writeline(apm, command);
        reply = strtrim(char(readline(apm)));
        replyCompact = regexprep(upper(reply), '\s+', '');
        if contains(replyCompact, 'SETM:OK')
            [actualAttenuationDb, actualPhaseDeg, rawReadbackReply] = ...
                queryApmState(apm, ports, tag);
            validateApmReadback(attenuationDb, phaseDeg, ...
                actualAttenuationDb, actualPhaseDeg, cfg, tag);
            return;
        end
        if contains(replyCompact, 'SETM:FAIL')
            error('REVArray:ApmSetFailed', ...
                'APM 对“%s”返回失败：%s', tag, reply);
        end
        error('REVArray:UnexpectedApmReply', ...
            'APM 对“%s”返回无法识别的回复：%s', tag, reply);
    catch exception
        lastException = exception;
        if attempt < cfg.apmCommandRetries
            pause(0.1);
        end
    end
end

error('REVArray:ApmCommandFailed', ...
    'APM 命令“%s”尝试 %d 次仍失败。最后错误：%s', ...
    tag, cfg.apmCommandRetries, lastException.message);
end

function [attenuationDb, phaseDeg, reply] = queryApmState(apm, ports, tag)
%QUERYAPMSTATE 使用 READm:STATus 回读指定通道的实际衰减和相位。

portNames = "A" + string(ports) + "B1";
command = char("READm:STATus:" + strjoin(portNames, ';'));
flush(apm, "input");
writeline(apm, command);
reply = strtrim(char(readline(apm)));

if contains(regexprep(upper(reply), '\s+', ''), 'READM:STATUS:FAIL')
    error('REVArray:ApmReadbackFailed', ...
        'APM 对“%s”的状态回读失败：%s', tag, reply);
end

numberPattern = '([-+]?(?:\d+\.?\d*|\.\d+)(?:[Ee][-+]?\d+)?)';
entryPattern = ['A(\d+)B1\s*,\s*', numberPattern, ...
    '\s*,\s*', numberPattern];
tokens = regexp(reply, entryPattern, 'tokens', 'ignorecase');
if numel(tokens) ~= numel(ports)
    error('REVArray:ApmReadbackCountMismatch', ...
        'APM 对“%s”回读了 %d 路，期望 %d 路。原始回复：%s', ...
        tag, numel(tokens), numel(ports), reply);
end

attenuationDb = nan(1, numel(ports));
phaseDeg = nan(1, numel(ports));
seen = false(1, numel(ports));
for tokenIndex = 1:numel(tokens)
    port = str2double(tokens{tokenIndex}{1});
    portPosition = find(ports == port, 1);
    if isempty(portPosition) || seen(portPosition)
        error('REVArray:ApmReadbackUnexpectedPort', ...
            'APM 对“%s”返回了意外或重复的端口 A%dB1。', tag, port);
    end
    attenuationDb(portPosition) = str2double(tokens{tokenIndex}{2});
    phaseDeg(portPosition) = str2double(tokens{tokenIndex}{3});
    seen(portPosition) = true;
end

if ~all(seen) || any(~isfinite(attenuationDb)) || any(~isfinite(phaseDeg))
    error('REVArray:ApmReadbackInvalidValue', ...
        'APM 对“%s”的回读包含缺失或无效数值。原始回复：%s', tag, reply);
end
end

function validateApmReadback(commandAttenuationDb, commandPhaseDeg, ...
        actualAttenuationDb, actualPhaseDeg, cfg, tag)
%VALIDATEAPMREADBACK 校验实际状态与命令在半个硬件步进内一致。

attenuationErrorDb = abs(actualAttenuationDb - commandAttenuationDb);
phaseErrorDeg = abs(mod(actualPhaseDeg - commandPhaseDeg + 180, 360) - 180);
if any(attenuationErrorDb > cfg.apmReadbackAttToleranceDb)
    error('REVArray:ApmReadbackAttenuationMismatch', ...
        'APM 对“%s”的最大衰减回读误差为 %.6g dB。', ...
        tag, max(attenuationErrorDb));
end
if any(phaseErrorDeg > cfg.apmReadbackPhaseToleranceDeg)
    error('REVArray:ApmReadbackPhaseMismatch', ...
        'APM 对“%s”的最大相位回读误差为 %.6g°。', ...
        tag, max(phaseErrorDeg));
end
end

function command = buildApmSetMCommand(ports, attenuationDb, phaseDeg)
%BUILDAPMSETMCOMMAND 生成无内部换行的 32 路 SETM 命令。

if numel(ports) ~= numel(attenuationDb) || ...
        numel(ports) ~= numel(phaseDeg)
    error('REVArray:ApmCommandLengthMismatch', ...
        '端口、衰减和相位数组长度必须一致。');
end

groups = strings(1, numel(ports));
for index = 1:numel(ports)
    groups(index) = sprintf('A%dB1,%.6f,%.6f', ...
        ports(index), attenuationDb(index), phaseDeg(index));
end
command = char("SETM:" + strjoin(groups, ';'));

if contains(command, newline) || contains(command, sprintf('\r'))
    error('REVArray:ApmCommandContainsNewline', ...
        'SETM 命令内部不能包含 CR 或 LF。');
end
end

function [frequencyHz, complexData] = acquireVnaSweep(vna, config)
%ACQUIREVNASWEEP 触发单次扫频并读取真实频率轴和复数 S 参数。

flush(vna, "input");
writeVna(vna, ':TRIG:SING');
writeVna(vna, sprintf(':CALC%d:PAR%d:SEL', config.channel, config.trace));
writeVna(vna, sprintf(':CALC%d:TDATA:SDAT?', config.channel));
xmlBytes = readScpiBlock(vna);
xmlText = native2unicode(xmlBytes(:).', 'UTF-8');
[frequencyValues, complexData] = parseTraceXml(xmlText);
frequencyHz = normalizeFrequencyAxisToHz(frequencyValues, config);

if numel(complexData) ~= config.pointCount
    error('REVArray:VnaConfiguredPointMismatch', ...
        'VNA 配置为 %d 点，但返回 %d 点。', ...
        config.pointCount, numel(complexData));
end
end

function frequencyHz = normalizeFrequencyAxisToHz(frequencyValues, config)
%NORMALIZEFREQUENCYAXISTOHZ 将 VNA 当前显示单位的横轴统一转换为 Hz。

frequencyValues = frequencyValues(:);
expectedStartHz = config.centerFrequencyHz - config.spanFrequencyHz / 2;
expectedStopHz = config.centerFrequencyHz + config.spanFrequencyHz / 2;
expectedEndpointsHz = [expectedStartHz, expectedStopHz];
candidateScales = [1, 1e3, 1e6, 1e9];
candidateErrorsHz = zeros(size(candidateScales));
for scaleIndex = 1:numel(candidateScales)
    scaledEndpointsHz = [frequencyValues(1), frequencyValues(end)] .* ...
        candidateScales(scaleIndex);
    candidateErrorsHz(scaleIndex) = max(abs( ...
        scaledEndpointsHz - expectedEndpointsHz));
end

[bestErrorHz, bestIndex] = min(candidateErrorsHz);
toleranceHz = max(1, config.spanFrequencyHz * 1e-6);
if bestErrorHz > toleranceHz
    error('REVArray:UnknownFrequencyUnit', ...
        ['无法将 VNA 返回的频率轴 %.12g 至 %.12g 转换为配置的 ' ...
         '%.12g 至 %.12g Hz。最小端点误差为 %.6g Hz。'], ...
        frequencyValues(1), frequencyValues(end), expectedStartHz, ...
        expectedStopHz, bestErrorHz);
end
frequencyHz = frequencyValues .* candidateScales(bestIndex);
end

function validateFrequencyAxis(referenceHz, currentHz)
%VALIDATEFREQUENCYAXIS 要求全部码字使用完全相同的扫频轴。

if ~isequal(size(referenceHz), size(currentHz)) || ...
        any(abs(referenceHz(:) - currentHz(:)) > 1)
    error('REVArray:FrequencyAxisChanged', ...
        '不同码字的 VNA 频率轴不一致。');
end
end

function payload = readScpiBlock(vna)
%READSCPIBLOCK 读取 IEEE 488.2 任意长度数据块。

header = readExactly(vna, 2);
if header(1) ~= uint8('#')
    error('REVArray:InvalidBlockHeader', ...
        'VNA 数据块未以 # 开始。');
end

digitCount = str2double(char(header(2)));
if ~isfinite(digitCount) || digitCount < 0 || digitCount > 9 || ...
        digitCount ~= fix(digitCount)
    error('REVArray:InvalidBlockHeader', ...
        'VNA 数据块长度字段位数无效：%s。', char(header(2)));
end

if digitCount == 0
    payload = uint8(char(readline(vna)));
    return;
end

lengthText = char(readExactly(vna, digitCount));
payloadLength = str2double(lengthText);
if ~isfinite(payloadLength) || payloadLength < 0 || ...
        payloadLength ~= fix(payloadLength)
    error('REVArray:InvalidBlockLength', ...
        'VNA 数据块长度无效：%s。', lengthText);
end

payload = readExactly(vna, payloadLength);
terminator = readExactly(vna, 1);
if terminator == uint8(13)
    terminator = readExactly(vna, 1);
end
if terminator ~= uint8(10)
    error('REVArray:InvalidBlockTerminator', ...
        'VNA 数据块末尾不是 LF。');
end
end

function bytes = readExactly(client, byteCount)
%READEXACTLY 完整读取指定数量的字节。

bytes = zeros(1, byteCount, 'uint8');
offset = 0;
while offset < byteCount
    chunk = read(client, byteCount - offset, 'uint8');
    if isempty(chunk)
        error('REVArray:IncompleteRead', ...
            'TCP 数据提前结束：期望 %d 字节，实际收到 %d 字节。', ...
            byteCount, offset);
    end
    nextOffset = offset + numel(chunk);
    bytes(offset + 1:nextOffset) = chunk(:).';
    offset = nextOffset;
end
end

function [frequencyValues, complexData] = parseTraceXml(xmlText)
%PARSETRACEXML 解析 <Point_n>频率;实部;虚部</Point_n>。

pointTokens = regexp(xmlText, ...
    '<Point_\d+>\s*([^<]+?)\s*</Point_\d+>', 'tokens');
if isempty(pointTokens)
    error('REVArray:InvalidTraceXml', ...
        'VNA XML 中没有找到 Point_n 数据。');
end

pointCount = numel(pointTokens);
frequencyValues = zeros(pointCount, 1);
realPart = zeros(pointCount, 1);
imaginaryPart = zeros(pointCount, 1);
for pointIndex = 1:pointCount
    values = sscanf(pointTokens{pointIndex}{1}, '%f;%f;%f');
    if numel(values) ~= 3 || any(~isfinite(values))
        error('REVArray:InvalidTracePoint', ...
            'VNA 第 %d 个点不是有效的“频率;实部;虚部”格式。', pointIndex);
    end
    frequencyValues(pointIndex) = values(1);
    realPart(pointIndex) = values(2);
    imaginaryPart(pointIndex) = values(3);
end

if pointCount > 1 && any(diff(frequencyValues) <= 0)
    error('REVArray:NonMonotonicFrequency', ...
        'VNA 返回的频率轴不是严格递增序列。');
end
complexData = complex(realPart, imaginaryPart);
end

function saveCheckpoint(fileName, status, cfg, timestamp, deviceInfo, ...
        vnaActual, apmFrequencyMHz, portMap, txAttenuationCommandsDb, ...
        txPhaseCommandsDeg, apmReadback, frequencyHz, ZRevRepeats, ...
        ZRev, completedElements, completedStates, failure)
%SAVECHECKPOINT 保存REV测量进度和已采集的相位状态。

checkpoint = struct();
checkpoint.status = status;
checkpoint.method = 'rev';
checkpoint.timestamp = timestamp;
checkpoint.savedAt = char(datetime('now'));
checkpoint.completedElements = completedElements;
checkpoint.completedStates = completedStates;
checkpoint.config = cfg;
checkpoint.deviceInfo = deviceInfo;
checkpoint.vnaActualSettings = vnaActual;
checkpoint.apmFrequencyMHz = apmFrequencyMHz;
checkpoint.portMap = portMap;
checkpoint.txAttenuationCommandsDb = txAttenuationCommandsDb;
checkpoint.txPhaseCommandsDeg = txPhaseCommandsDeg;
checkpoint.apmReadback = apmReadback;
checkpoint.frequencyHz = frequencyHz;
checkpoint.ZRevRepeats = ZRevRepeats;
checkpoint.ZRev = ZRev;
checkpoint.failure = failure;
save(fileName, 'checkpoint', '-v7.3');
end

function writeRevCsv(fileName, result)
%WRITEREVCSV 导出复数DFT、功率REV及诊断指标。

frequencyHz = result.frequencyHz(:);
pointCount = numel(frequencyHz);
complexVector = result.HRevComplex.'.';
complexVector = complexVector(:);
powerVector = result.HRevPower.'.';
powerVector = powerVector(:);

Port = repelem(result.portMap.port, pointCount);
Column = repelem(result.portMap.column, pointCount);
RowFromBottom = repelem(result.portMap.rowFromBottom, pointCount);
Freq_Hz = repmat(frequencyHz, 32, 1);
Freq_GHz = Freq_Hz ./ 1e9;
ComplexReal = real(complexVector);
ComplexImag = imag(complexVector);
ComplexMag_dB = 20 .* log10(abs(complexVector));
ComplexPhase_deg = angle(complexVector) .* (180 / pi);
PowerReal = real(powerVector);
PowerImag = imag(powerVector);
PowerMag_dB = 20 .* log10(abs(powerVector));
PowerPhase_deg = angle(powerVector) .* (180 / pi);
PowerValid = result.revDiagnostics.powerValid.'.';
PowerValid = PowerValid(:);
PowerDiscriminantValid = ...
    result.revDiagnostics.powerDiscriminantValid.'.';
PowerDiscriminantValid = PowerDiscriminantValid(:);
PowerBackgroundDominant = ...
    result.revDiagnostics.powerBackgroundDominant.'.';
PowerBackgroundDominant = PowerBackgroundDominant(:);
WeakBackground = ~result.revDiagnostics.powerBackgroundStrong.'.';
WeakBackground = WeakBackground(:);
BackgroundMag_dB = 20 .* log10(abs( ...
    result.revDiagnostics.background.'.'));
BackgroundMag_dB = BackgroundMag_dB(:);
ComplexFitNMSE_dB = result.revDiagnostics.complexFitNmseDb.'.';
ComplexFitNMSE_dB = ComplexFitNMSE_dB(:);
PowerFitNMSE_dB = result.revDiagnostics.powerFitNmseDb.'.';
PowerFitNMSE_dB = PowerFitNMSE_dB(:);
ClosureMag_dB = result.revDiagnostics.closureMagnitudeDb.'.';
ClosureMag_dB = ClosureMag_dB(:);
ClosurePhase_deg = result.revDiagnostics.closurePhaseDeg.'.';
ClosurePhase_deg = ClosurePhase_deg(:);
ClosureErrorReal = real(result.revDiagnostics.closureComplexError.'.');
ClosureErrorReal = ClosureErrorReal(:);
ClosureErrorImag = imag(result.revDiagnostics.closureComplexError.'.');
ClosureErrorImag = ClosureErrorImag(:);

revTable = table(Port, Column, RowFromBottom, Freq_Hz, Freq_GHz, ...
    ComplexReal, ComplexImag, ComplexMag_dB, ComplexPhase_deg, ...
    PowerReal, PowerImag, PowerMag_dB, PowerPhase_deg, PowerValid, ...
    PowerDiscriminantValid, PowerBackgroundDominant, WeakBackground, ...
    BackgroundMag_dB, ComplexFitNMSE_dB, PowerFitNMSE_dB, ...
    ClosureErrorReal, ClosureErrorImag, ClosureMag_dB, ClosurePhase_deg);
writetable(revTable, fileName);
end

function createQualityFigure(fileName, result)
%CREATEQUALITYFIGURE 绘制中心频点的端口曲线和 8x4 空间热图。

centerIndex = findCenterIndex( ...
    result.frequencyHz, result.config.vna.centerFrequencyHz);
centerFrequencyHz = result.frequencyHz(centerIndex);
centerResponse = result.HChannel(:, centerIndex);
magnitudeDb = 20 .* log10(abs(centerResponse));
phaseDeg = angle(centerResponse) .* (180 / pi);
magnitudeMap = reshape(magnitudeDb, 8, 4);
phaseMap = reshape(phaseDeg, 8, 4);

if result.config.showFigure
    visibility = 'on';
else
    visibility = 'off';
end
figureHandle = figure('Name', 'REV Complex-DFT Channel Responses', ...
    'NumberTitle', 'off', 'Color', 'white', 'Visible', visibility, ...
    'MenuBar', 'none', 'ToolBar', 'none', ...
    'Position', [100, 100, 1300, 850]);
if ~result.config.showFigure
    figureCleanup = onCleanup(@() closeIfValid(figureHandle));
end

layout = tiledlayout(figureHandle, 2, 2, ...
    'TileSpacing', 'compact', 'Padding', 'compact');

magnitudeAxes = nexttile(layout);
plot(magnitudeAxes, 1:32, magnitudeDb, 'o-', ...
    'LineWidth', 1.2, 'MarkerSize', 4);
grid(magnitudeAxes, 'on');
xlabel(magnitudeAxes, 'APM Port', 'Interpreter', 'none');
ylabel(magnitudeAxes, 'Magnitude (dB)', 'Interpreter', 'none');
title(magnitudeAxes, 'REV complex-DFT magnitude', 'Interpreter', 'none');
xlim(magnitudeAxes, [1, 32]);

phaseAxes = nexttile(layout);
plot(phaseAxes, 1:32, phaseDeg, 'o-', ...
    'LineWidth', 1.2, 'MarkerSize', 4);
grid(phaseAxes, 'on');
xlabel(phaseAxes, 'APM Port', 'Interpreter', 'none');
ylabel(phaseAxes, 'Phase (deg)', 'Interpreter', 'none');
title(phaseAxes, 'REV complex-DFT phase', 'Interpreter', 'none');
xlim(phaseAxes, [1, 32]);
ylim(phaseAxes, [-180, 180]);

magnitudeMapAxes = nexttile(layout);
imagesc(magnitudeMapAxes, 1:4, 1:8, magnitudeMap);
set(magnitudeMapAxes, 'YDir', 'normal');
axis(magnitudeMapAxes, 'image');
magnitudeColorbar = colorbar(magnitudeMapAxes);
xlabel(magnitudeMapAxes, 'Array column (left to right)', 'Interpreter', 'none');
ylabel(magnitudeMapAxes, 'Row from bottom', 'Interpreter', 'none');
title(magnitudeMapAxes, '8x4 channel magnitude map (dB)', 'Interpreter', 'none');
xticks(magnitudeMapAxes, 1:4);
yticks(magnitudeMapAxes, 1:8);

phaseMapAxes = nexttile(layout);
imagesc(phaseMapAxes, 1:4, 1:8, phaseMap, [-180, 180]);
set(phaseMapAxes, 'YDir', 'normal');
axis(phaseMapAxes, 'image');
phaseColorbar = colorbar(phaseMapAxes);
xlabel(phaseMapAxes, 'Array column (left to right)', 'Interpreter', 'none');
ylabel(phaseMapAxes, 'Row from bottom', 'Interpreter', 'none');
title(phaseMapAxes, '8x4 channel phase map (deg)', 'Interpreter', 'none');
xticks(phaseMapAxes, 1:4);
yticks(phaseMapAxes, 1:8);

axesHandles = [magnitudeAxes, phaseAxes, magnitudeMapAxes, phaseMapAxes];
set(axesHandles, 'TickLabelInterpreter', 'none');
set([magnitudeColorbar, phaseColorbar], 'TickLabelInterpreter', 'none');
for axesIndex = 1:numel(axesHandles)
    axesHandles(axesIndex).Toolbar.Visible = 'off';
end
sgtitle(layout, sprintf( ...
    'REV complex-DFT channel responses at %.6f GHz | RX Horn', centerFrequencyHz / 1e9), ...
    'Interpreter', 'none');

drawnow;
exportgraphics(figureHandle, fileName, 'Resolution', 180);
end

function index = findCenterIndex(frequencyHz, centerFrequencyHz)
%FINDCENTERINDEX 返回最接近配置中心频率的频点索引。

[~, index] = min(abs(frequencyHz(:) - centerFrequencyHz));
end

function writeVna(vna, command)
%WRITEVNA 写入一条 LF 结尾的 SCPI 命令。
writeline(vna, command);
end

function response = queryVna(vna, command)
%QUERYVNA 查询一行 ASCII 响应。

writeVna(vna, command);
response = strtrim(char(readline(vna)));
if isempty(response)
    error('REVArray:EmptyVnaResponse', ...
        'VNA 查询 %s 返回了空响应。', command);
end
end

function value = queryVnaNumber(vna, command)
%QUERYVNANUMBER 查询一个有限数值。

response = queryVna(vna, command);
value = str2double(response);
if ~isfinite(value)
    error('REVArray:InvalidVnaNumber', ...
        'VNA 查询 %s 返回了无效数值：%s。', command, response);
end
end

function checkVnaErrors(vna, stage)
%CHECKVNAERRORS 检查并清空 VNA SCPI 错误队列。

errorCount = queryVnaNumber(vna, ':SYST:ERR:COUN?');
if errorCount <= 0
    return;
end
if errorCount ~= fix(errorCount)
    error('REVArray:InvalidVnaErrorCount', ...
        'VNA 错误计数不是整数：%.15g。', errorCount);
end

messages = strings(errorCount, 1);
for index = 1:errorCount
    messages(index) = string(queryVna(vna, ':SYST:ERR?'));
end
error('REVArray:VnaScpiError', ...
    '%s后 VNA 报告 %d 个 SCPI 错误：\n%s', ...
    stage, errorCount, strjoin(messages, newline));
end

function shutdownSystem(vna, txApm, cfg)
%SHUTDOWNSYSTEM 异常或正常结束时关闭 TX APM 并释放连接。

try
    if ~isempty(vna) && isvalid(vna)
        writeline(vna, sprintf(':SENS%d:HOLD:FUNC HOLD', cfg.vna.channel));
    end
catch exception
    warning('REVArray:VnaHoldCleanupFailed', ...
        '清理时无法将 VNA 置于 HOLD：%s', exception.message);
end

sendApmAllOffNoReply(txApm, cfg);
safeDeleteClient(vna);
safeDeleteClient(txApm);
end

function sendApmAllOffNoReply(apm, cfg)
%SENDAPMALLOFFNOREPLY 清理阶段发送关断命令，不等待回复。

if isempty(apm) || ~isvalid(apm)
    return;
end
try
    attenuationDb = repmat(cfg.offAttenuationDb, 1, 32);
    phaseDeg = zeros(1, 32);
    command = buildApmSetMCommand(cfg.allPorts, attenuationDb, phaseDeg);
    writeline(apm, command);
    pause(0.05);
catch
end
end

function safeDeleteClient(client)
%SAFEDELETECLIENT 安全释放 tcpclient 对象。

if isempty(client)
    return;
end
try
    if isvalid(client)
        delete(client);
    end
catch
end
end

function ensureDirectory(directory)
%ENSUREDIRECTORY 创建结果目录。

if isfolder(directory)
    return;
end
[created, message] = mkdir(directory);
if ~created
    error('REVArray:CreateDirectoryFailed', ...
        '无法创建目录 %s：%s', directory, message);
end
end

function failure = exceptionToStruct(exception)
%EXCEPTIONTOSTRUCT 将 MException 转换为可持久化结构体。

failure.identifier = exception.identifier;
failure.message = exception.message;
failure.stack = exception.stack;
end

function value = getVariableOrDefault(variableName, defaultValue)
%GETVARIABLEORDEFAULT 获取调用方变量；变量不存在时返回默认值。

if evalin('caller', sprintf('exist(''%s'', ''var'')', variableName))
    value = evalin('caller', variableName);
else
    value = defaultValue;
end
end

function closeIfValid(figureHandle)
%CLOSEIFVALID 关闭仍然存在的图窗。

if isgraphics(figureHandle)
    close(figureHandle);
end
end
