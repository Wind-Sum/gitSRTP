%% 4x8 DUT 阵列到 Horn 的 Hadamard 信道测量
% 控制 Anritsu MS46322B 和 1->32 发射 APM，依次发送
% Hadamard(32) 码字，采集 S21 复数扫频数据，并解算 32 路有效链路响应。
%
% 射频连接：
%   VNA Port 1 -> TX APM 公共端 -> 4x8 DUT 阵列
%   RX Horn -> VNA Port 2
% 本脚本仅控制 TX APM，不使用 RX APM。
%
% 阵列端口映射：4 列 x 8 行，每列从下到上编号；第一列 1:8，第二列
% 9:16，第三列 17:24，第四列 25:32。

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
cfg.vna.spanFrequencyHz = 1e9;     % 4.5 至 5.5 GHz
cfg.vna.pointCount = 2001;
cfg.vna.ifBandwidthHz = 5e3;
cfg.vna.powerLevel = 'LOW';        % MS46322B：HIGH 或 LOW

cfg.txApm.ipAddress = '192.168.0.251';
cfg.txApm.port = 28888;
cfg.txApm.name = 'TX APM (1->32)';
cfg.apmTimeoutSeconds = 5;
cfg.apmExpectedFrequencyMHz = 5000;
cfg.apmFrequencyToleranceMHz = 0.5;
cfg.apmSettleSeconds = 1.0;
cfg.apmCommandRetries = 2;
cfg.apmReadbackAttToleranceDb = 0.125001;   % 半个 0.25 dB 步进
cfg.apmReadbackPhaseToleranceDeg = 0.703126; % 半个 1.40625° 步进

cfg.allPorts = 1:32;
cfg.onAttenuationDb = 0;
cfg.offAttenuationDb = 90;         % 关断隔离状态
cfg.onPhaseDeg = 0;
cfg.positiveCodePhaseDeg = 0;      % Hadamard +1
cfg.negativeCodePhaseDeg = 180;    % Hadamard -1

% 诊断用的全通道公共衰减。正常测量保持 0 dB；若怀疑多通道同时开启
% 造成 Horn 接收链路/VNA 压缩，可在基准和偏置两次测试中都改为 10~15 dB。
cfg.txCommonAttenuationDb = 0;

% TX 固定幅相偏置。衰减采用硬件正衰减定义：1 dB 表示额外降低约 1 dB。
% enabled=false 可进行无偏置基准测试；ports/attenuationDb/phaseDeg 必须等长。
cfg.txExtra.enabled = false;
cfg.txExtra.ports = [5, 10, 20];
cfg.txExtra.attenuationDb = [2, 4, 6];
cfg.txExtra.phaseDeg = [20, 40, 60];

cfg.numRepeats = 1;                % 每个码字的复数扫频重复次数
cfg.showFigure = true;

% 结果始终保存到本脚本真实所在文件夹的 results 子文件夹。
scriptDirectory = resolveScriptDirectory('Hadamard_Localization_Test.m');
cfg.outputRoot = fullfile(scriptDirectory, 'results');

%% 执行测量
cfg = validateConfig(cfg);
codebook = hadamard(32);
validateCodebook(codebook);
[txAttenuationCommandsDb, txPhaseCommandsDeg, ...
    txExtraAttenuationByPortDb, txExtraPhaseByPortDeg] = ...
    buildTxCommandMatrices(codebook, cfg);
phaseCommandsDeg = txPhaseCommandsDeg; % 保留旧字段名，便于兼容原始结果文件
portMap = buildPortMap();

timestamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss_SSS'));
runDirectory = fullfile(cfg.outputRoot, ['Hadamard_Localization_', timestamp]);
ensureDirectory(runDirectory);

files.checkpoint = fullfile(runDirectory, 'Hadamard_Localization_Checkpoint.mat');
files.mat = fullfile(runDirectory, 'Hadamard_Localization_Result.mat');
files.csv = fullfile(runDirectory, 'Hadamard_Channel_Response.csv');
files.png = fullfile(runDirectory, 'Hadamard_Channel_CenterFrequency.png');

fprintf('\n========== 4x8 Hadamard 阵列链路测试 ==========\n');
fprintf('VNA：%s:%d，%.3f 至 %.3f GHz，%d 点，%s\n', ...
    cfg.vna.ipAddress, cfg.vna.port, ...
    (cfg.vna.centerFrequencyHz - cfg.vna.spanFrequencyHz / 2) / 1e9, ...
    (cfg.vna.centerFrequencyHz + cfg.vna.spanFrequencyHz / 2) / 1e9, ...
    cfg.vna.pointCount, cfg.vna.sParameter);
fprintf('TX APM：%s:%d\n', cfg.txApm.ipAddress, cfg.txApm.port);
fprintf('RX：Horn 直接连接 VNA Port 2\n');
if cfg.txExtra.enabled
    fprintf('TX 额外偏置：端口 %s，衰减 %s dB，相移 %s deg\n', ...
        mat2str(cfg.txExtra.ports), mat2str(cfg.txExtra.attenuationDb), ...
        mat2str(cfg.txExtra.phaseDeg));
else
    fprintf('TX 额外偏置：关闭（基准测试）\n');
end
fprintf('TX 全通道公共衰减：%.2f dB\n', cfg.txCommonAttenuationDb);
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
YRepeats = complex(nan(32, cfg.vna.pointCount, cfg.numRepeats));
YPattern = complex(nan(32, cfg.vna.pointCount));
completedPatterns = 0;
vnaActual = struct();
apmFrequencyMHz = struct();
apmReadback = struct();
apmReadback.txInitialAllOff = struct();
apmReadback.txPatternAttenuationDb = nan(32, 32);
apmReadback.txPatternPhaseDeg = nan(32, 32);
apmReadback.txPatternRawReply = strings(32, 1);
measurementStart = datetime('now');

try
    apmFrequencyMHz = queryApmFrequency(txApm);
    validateApmFrequency(apmFrequencyMHz, cfg, cfg.txApm.name);
    fprintf('TX APM 当前校准频点：%.3f MHz。\n', apmFrequencyMHz);

    configureVna(vna, cfg.vna);
    checkVnaErrors(vna, 'VNA 参数设置');
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

    for patternIndex = 1:32
        fprintf('Hadamard 码字 %02d/32：设置 TX APM ... ', patternIndex);
        txAttenuationDb = txAttenuationCommandsDb(patternIndex, :);
        txPhaseDeg = txPhaseCommandsDeg(patternIndex, :);
        [actualAttenuationDb, actualPhaseDeg, rawReadbackReply] = ...
            sendApmState(txApm, cfg.allPorts, txAttenuationDb, ...
            txPhaseDeg, cfg, sprintf('TX Hadamard pattern %d', patternIndex));
        apmReadback.txPatternAttenuationDb(patternIndex, :) = ...
            actualAttenuationDb;
        apmReadback.txPatternPhaseDeg(patternIndex, :) = actualPhaseDeg;
        apmReadback.txPatternRawReply(patternIndex) = rawReadbackReply;
        pause(cfg.apmSettleSeconds);
        fprintf('采集');

        for repeatIndex = 1:cfg.numRepeats
            [currentFrequencyHz, currentSweep] = acquireVnaSweep(vna, cfg.vna);
            if isempty(frequencyHz)
                frequencyHz = currentFrequencyHz;
            else
                validateFrequencyAxis(frequencyHz, currentFrequencyHz);
            end

            if numel(currentSweep) ~= size(YRepeats, 2)
                error('HadamardArray:PointCountMismatch', ...
                    '码字 %d、第 %d 次采集返回 %d 点，期望 %d 点。', ...
                    patternIndex, repeatIndex, numel(currentSweep), size(YRepeats, 2));
            end
            YRepeats(patternIndex, :, repeatIndex) = currentSweep(:).';
            fprintf('.');
        end

        YPattern(patternIndex, :) = mean( ...
            YRepeats(patternIndex, :, :), 3, 'omitnan');
        completedPatterns = patternIndex;
        checkVnaErrors(vna, sprintf('Hadamard 码字 %d 采集', patternIndex));

        saveCheckpoint(files.checkpoint, 'measuring', cfg, timestamp, ...
            deviceInfo, vnaActual, apmFrequencyMHz, portMap, codebook, ...
            phaseCommandsDeg, txAttenuationCommandsDb, apmReadback, ...
            frequencyHz, YRepeats, YPattern, ...
            completedPatterns, []);

        centerIndex = findCenterIndex(frequencyHz, cfg.vna.centerFrequencyHz);
        centerValue = YPattern(patternIndex, centerIndex);
        elapsedSeconds = seconds(datetime('now') - measurementStart);
        estimatedRemainingSeconds = elapsedSeconds / patternIndex * (32 - patternIndex);
        fprintf(' 完成，中心点 %.3e ∠ %.1f°，预计剩余 %.1f min。\n', ...
            abs(centerValue), angle(centerValue) * 180 / pi, ...
            estimatedRemainingSeconds / 60);
    end

    HElement = (codebook.' * YPattern) / 32;
    completedPatterns = 32;

    result = struct();
    result.status = 'complete';
    result.method = 'hadamard';
    result.timestamp = timestamp;
    result.completedPatterns = completedPatterns;
    result.config = cfg;
    result.deviceInfo = deviceInfo;
    result.vnaActualSettings = vnaActual;
    result.apmFrequencyMHz = apmFrequencyMHz;
    result.portMap = portMap;
    result.codebook = codebook;
    result.phaseCommandsDeg = phaseCommandsDeg;
    result.txAttenuationCommandsDb = txAttenuationCommandsDb;
    result.txPhaseCommandsDeg = txPhaseCommandsDeg;
    result.txExtraAttenuationByPortDb = txExtraAttenuationByPortDb;
    result.txExtraPhaseByPortDeg = txExtraPhaseByPortDeg;
    result.apmReadback = apmReadback;
    result.frequencyHz = frequencyHz;
    result.YRepeats = YRepeats;
    result.YPattern = YPattern;
    result.HElement = HElement;
    result.HChannel = HElement;
    result.files = files;
    result.measurementStart = char(measurementStart);
    result.measurementEnd = char(datetime('now'));
    result.notes = ['HChannel/HElement 为 DUT TX 阵元到 RX Horn 的有效复数信道；' ...
        '未进行通道校准或自由空间去嵌。'];

    save(files.mat, 'result', '-v7.3');
    writeDecodedCsv(files.csv, result);
    createQualityFigure(files.png, result);
    saveCheckpoint(files.checkpoint, 'complete', cfg, timestamp, ...
        deviceInfo, vnaActual, apmFrequencyMHz, portMap, codebook, ...
        phaseCommandsDeg, txAttenuationCommandsDb, apmReadback, ...
        frequencyHz, YRepeats, YPattern, ...
        completedPatterns, []);

    fprintf('\nHadamard 解码完成。\n');
    fprintf('MAT：%s\n', files.mat);
    fprintf('CSV：%s\n', files.csv);
    fprintf('PNG：%s\n', files.png);
    fprintf('检查点：%s\n', files.checkpoint);
catch exception
    failure = exceptionToStruct(exception);
    try
        saveCheckpoint(files.checkpoint, 'failed', cfg, timestamp, ...
            getVariableOrDefault('deviceInfo', struct()), vnaActual, ...
            apmFrequencyMHz, portMap, codebook, phaseCommandsDeg, ...
            txAttenuationCommandsDb, apmReadback, frequencyHz, YRepeats, ...
            YPattern, completedPatterns, failure);
    catch checkpointException
        warning('HadamardArray:CheckpointSaveFailed', ...
            '故障检查点保存失败：%s', checkpointException.message);
    end
    fprintf(2, '\n测量在完成 %d/32 个码字后失败；已保存检查点：%s\n', ...
        completedPatterns, files.checkpoint);
    clear systemCleanup; % 脚本变量留在基础工作区，异常时必须显式触发清理
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

error('HadamardArray:ScriptLocationUnknown', ...
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
validateattributes(cfg.positiveCodePhaseDeg, {'numeric'}, ...
    {'scalar', 'real', 'finite'});
validateattributes(cfg.negativeCodePhaseDeg, {'numeric'}, ...
    {'scalar', 'real', 'finite'});
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
cfg.txExtra.ports = cfg.txExtra.ports(:).';
cfg.txExtra.attenuationDb = cfg.txExtra.attenuationDb(:).';
cfg.txExtra.phaseDeg = cfg.txExtra.phaseDeg(:).';
cfg.outputRoot = validateNonemptyText(cfg.outputRoot, '输出根目录');

extraLengths = [numel(cfg.txExtra.ports), ...
    numel(cfg.txExtra.attenuationDb), numel(cfg.txExtra.phaseDeg)];
if numel(unique(extraLengths)) ~= 1
    error('HadamardArray:TxExtraLengthMismatch', ...
        'cfg.txExtra.ports、attenuationDb 和 phaseDeg 必须等长。');
end
if numel(unique(cfg.txExtra.ports)) ~= numel(cfg.txExtra.ports)
    error('HadamardArray:DuplicateTxExtraPort', ...
        'cfg.txExtra.ports 不能包含重复端口。');
end
if any(cfg.onAttenuationDb + cfg.txCommonAttenuationDb + ...
        cfg.txExtra.attenuationDb > 25)
    error('HadamardArray:TxExtraAttenuationOutOfRange', ...
        '基础开启衰减、公共衰减与端口额外衰减之和不能超过 25 dB。');
end

if cfg.vna.centerFrequencyHz - cfg.vna.spanFrequencyHz / 2 < 3e9 || ...
        cfg.vna.centerFrequencyHz + cfg.vna.spanFrequencyHz / 2 > 8.5e9
    error('HadamardArray:FrequencyOutsideApmRange', ...
        'VNA 扫频范围必须位于 APM 的 3.0 至 8.5 GHz 工作频段内。');
end
if ~isequal(cfg.allPorts(:).', 1:32)
    error('HadamardArray:InvalidPortList', ...
        'cfg.allPorts 必须严格为 1:32。');
end
end

function textValue = validateNonemptyText(value, label)
%VALIDATENONEMPTYTEXT 规范化非空文本配置。

textValue = char(strtrim(string(value)));
if isempty(textValue)
    error('HadamardArray:EmptyConfigText', '%s 不能为空。', label);
end
end

function validateCodebook(codebook)
%VALIDATECODEBOOK 验证 Hadamard(32) 正交性和取值。

if ~isequal(size(codebook), [32, 32]) || ...
        ~all(ismember(codebook(:), [-1, 1])) || ...
        ~isequal(codebook * codebook.', 32 * eye(32))
    error('HadamardArray:InvalidCodebook', ...
        'hadamard(32) 未生成有效的 32x32 正交 +/-1 码本。');
end
end

function [attenuationCommandsDb, phaseCommandsDeg, ...
        extraAttenuationByPortDb, extraPhaseByPortDeg] = ...
        buildTxCommandMatrices(codebook, cfg)
%BUILDTXCOMMANDMATRICES 生成每个码字实际下发的 32 路衰减和相位。

extraAttenuationByPortDb = zeros(1, 32);
extraPhaseByPortDeg = zeros(1, 32);
if cfg.txExtra.enabled
    extraAttenuationByPortDb(cfg.txExtra.ports) = ...
        cfg.txExtra.attenuationDb;
    extraPhaseByPortDeg(cfg.txExtra.ports) = cfg.txExtra.phaseDeg;
end

basePhaseDeg = repmat(cfg.positiveCodePhaseDeg, size(codebook));
basePhaseDeg(codebook < 0) = cfg.negativeCodePhaseDeg;
attenuationCommandsDb = repmat( ...
    cfg.onAttenuationDb + cfg.txCommonAttenuationDb + ...
    extraAttenuationByPortDb, size(codebook, 1), 1);
phaseCommandsDeg = mod(basePhaseDeg + ...
    repmat(extraPhaseByPortDeg, size(codebook, 1), 1), 360);
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
        error('HadamardArray:UnexpectedVna', ...
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
    error('HadamardArray:ApmConnectionFailed', ...
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
    error('HadamardArray:EmptyApmIdentity', '%s 返回了空 IDN。', name);
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
    error('HadamardArray:InvalidApmFrequencyReply', ...
        '无法解析 APM 频点回复：%s', reply);
end
frequencyMHz = str2double(token{1});
if ~isfinite(frequencyMHz) || frequencyMHz <= 0
    error('HadamardArray:InvalidApmFrequency', ...
        'APM 返回了无效校准频点：%s', reply);
end
end

function validateApmFrequency(actualMHz, cfg, name)
%VALIDATEAPMFREQUENCY 要求 APM 当前频点与 5.0 GHz 中心匹配。

if abs(actualMHz - cfg.apmExpectedFrequencyMHz) > ...
        cfg.apmFrequencyToleranceMHz
    error('HadamardArray:ApmFrequencyMismatch', ...
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
    error('HadamardArray:VnaConnectionFailed', ...
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
    error('HadamardArray:InvalidVnaPointCount', ...
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
            error('HadamardArray:ApmSetFailed', ...
                'APM 对“%s”返回失败：%s', tag, reply);
        end
        error('HadamardArray:UnexpectedApmReply', ...
            'APM 对“%s”返回无法识别的回复：%s', tag, reply);
    catch exception
        lastException = exception;
        if attempt < cfg.apmCommandRetries
            pause(0.1);
        end
    end
end

error('HadamardArray:ApmCommandFailed', ...
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
    error('HadamardArray:ApmReadbackFailed', ...
        'APM 对“%s”的状态回读失败：%s', tag, reply);
end

numberPattern = '([-+]?(?:\d+\.?\d*|\.\d+)(?:[Ee][-+]?\d+)?)';
entryPattern = ['A(\d+)B1\s*,\s*', numberPattern, ...
    '\s*,\s*', numberPattern];
tokens = regexp(reply, entryPattern, 'tokens', 'ignorecase');
if numel(tokens) ~= numel(ports)
    error('HadamardArray:ApmReadbackCountMismatch', ...
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
        error('HadamardArray:ApmReadbackUnexpectedPort', ...
            'APM 对“%s”返回了意外或重复的端口 A%dB1。', tag, port);
    end
    attenuationDb(portPosition) = str2double(tokens{tokenIndex}{2});
    phaseDeg(portPosition) = str2double(tokens{tokenIndex}{3});
    seen(portPosition) = true;
end

if ~all(seen) || any(~isfinite(attenuationDb)) || any(~isfinite(phaseDeg))
    error('HadamardArray:ApmReadbackInvalidValue', ...
        'APM 对“%s”的回读包含缺失或无效数值。原始回复：%s', tag, reply);
end
end

function validateApmReadback(commandAttenuationDb, commandPhaseDeg, ...
        actualAttenuationDb, actualPhaseDeg, cfg, tag)
%VALIDATEAPMREADBACK 校验实际状态与命令在半个硬件步进内一致。

attenuationErrorDb = abs(actualAttenuationDb - commandAttenuationDb);
phaseErrorDeg = abs(mod(actualPhaseDeg - commandPhaseDeg + 180, 360) - 180);
if any(attenuationErrorDb > cfg.apmReadbackAttToleranceDb)
    error('HadamardArray:ApmReadbackAttenuationMismatch', ...
        'APM 对“%s”的最大衰减回读误差为 %.6g dB。', ...
        tag, max(attenuationErrorDb));
end
if any(phaseErrorDeg > cfg.apmReadbackPhaseToleranceDeg)
    error('HadamardArray:ApmReadbackPhaseMismatch', ...
        'APM 对“%s”的最大相位回读误差为 %.6g°。', ...
        tag, max(phaseErrorDeg));
end
end

function command = buildApmSetMCommand(ports, attenuationDb, phaseDeg)
%BUILDAPMSETMCOMMAND 生成无内部换行的 32 路 SETM 命令。

if numel(ports) ~= numel(attenuationDb) || ...
        numel(ports) ~= numel(phaseDeg)
    error('HadamardArray:ApmCommandLengthMismatch', ...
        '端口、衰减和相位数组长度必须一致。');
end

groups = strings(1, numel(ports));
for index = 1:numel(ports)
    groups(index) = sprintf('A%dB1,%.6f,%.6f', ...
        ports(index), attenuationDb(index), phaseDeg(index));
end
command = char("SETM:" + strjoin(groups, ';'));

if contains(command, newline) || contains(command, sprintf('\r'))
    error('HadamardArray:ApmCommandContainsNewline', ...
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
    error('HadamardArray:VnaConfiguredPointMismatch', ...
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
    error('HadamardArray:UnknownFrequencyUnit', ...
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
    error('HadamardArray:FrequencyAxisChanged', ...
        '不同码字的 VNA 频率轴不一致。');
end
end

function payload = readScpiBlock(vna)
%READSCPIBLOCK 读取 IEEE 488.2 任意长度数据块。

header = readExactly(vna, 2);
if header(1) ~= uint8('#')
    error('HadamardArray:InvalidBlockHeader', ...
        'VNA 数据块未以 # 开始。');
end

digitCount = str2double(char(header(2)));
if ~isfinite(digitCount) || digitCount < 0 || digitCount > 9 || ...
        digitCount ~= fix(digitCount)
    error('HadamardArray:InvalidBlockHeader', ...
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
    error('HadamardArray:InvalidBlockLength', ...
        'VNA 数据块长度无效：%s。', lengthText);
end

payload = readExactly(vna, payloadLength);
terminator = readExactly(vna, 1);
if terminator == uint8(13)
    terminator = readExactly(vna, 1);
end
if terminator ~= uint8(10)
    error('HadamardArray:InvalidBlockTerminator', ...
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
        error('HadamardArray:IncompleteRead', ...
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
    error('HadamardArray:InvalidTraceXml', ...
        'VNA XML 中没有找到 Point_n 数据。');
end

pointCount = numel(pointTokens);
frequencyValues = zeros(pointCount, 1);
realPart = zeros(pointCount, 1);
imaginaryPart = zeros(pointCount, 1);
for pointIndex = 1:pointCount
    values = sscanf(pointTokens{pointIndex}{1}, '%f;%f;%f');
    if numel(values) ~= 3 || any(~isfinite(values))
        error('HadamardArray:InvalidTracePoint', ...
            'VNA 第 %d 个点不是有效的“频率;实部;虚部”格式。', pointIndex);
    end
    frequencyValues(pointIndex) = values(1);
    realPart(pointIndex) = values(2);
    imaginaryPart(pointIndex) = values(3);
end

if pointCount > 1 && any(diff(frequencyValues) <= 0)
    error('HadamardArray:NonMonotonicFrequency', ...
        'VNA 返回的频率轴不是严格递增序列。');
end
complexData = complex(realPart, imaginaryPart);
end

function saveCheckpoint(fileName, status, cfg, timestamp, deviceInfo, ...
        vnaActual, apmFrequencyMHz, portMap, codebook, phaseCommandsDeg, ...
        txAttenuationCommandsDb, apmReadback, frequencyHz, YRepeats, ...
        YPattern, completedPatterns, failure)
%SAVECHECKPOINT 保存当前测量进度，保留中途故障前的数据。

checkpoint = struct();
checkpoint.status = status;
checkpoint.timestamp = timestamp;
checkpoint.savedAt = char(datetime('now'));
checkpoint.completedPatterns = completedPatterns;
checkpoint.config = cfg;
checkpoint.deviceInfo = deviceInfo;
checkpoint.vnaActualSettings = vnaActual;
checkpoint.apmFrequencyMHz = apmFrequencyMHz;
checkpoint.portMap = portMap;
checkpoint.codebook = codebook;
checkpoint.phaseCommandsDeg = phaseCommandsDeg;
checkpoint.txAttenuationCommandsDb = txAttenuationCommandsDb;
checkpoint.txPhaseCommandsDeg = phaseCommandsDeg;
checkpoint.apmReadback = apmReadback;
checkpoint.frequencyHz = frequencyHz;
checkpoint.YRepeats = YRepeats;
checkpoint.YPattern = YPattern;
checkpoint.failure = failure;
save(fileName, 'checkpoint', '-v7.3');
end

function writeDecodedCsv(fileName, result)
%WRITEDECODEDCSV 以端口为主序导出长表解码结果。

frequencyHz = result.frequencyHz(:);
pointCount = numel(frequencyHz);
decodedByPort = result.HElement.';
decodedVector = decodedByPort(:);

Port = repelem(result.portMap.port, pointCount);
Column = repelem(result.portMap.column, pointCount);
RowFromBottom = repelem(result.portMap.rowFromBottom, pointCount);
TxExtraAttenuation_dB = repelem( ...
    result.txExtraAttenuationByPortDb(:), pointCount);
TxExtraPhase_deg = repelem(result.txExtraPhaseByPortDeg(:), pointCount);
Freq_Hz = repmat(frequencyHz, 32, 1);
Real = real(decodedVector);
Imag = imag(decodedVector);
Mag_dB = 20 .* log10(abs(decodedVector));
Phase_deg = angle(decodedVector) .* (180 / pi);

decodedTable = table(Port, Column, RowFromBottom, ...
    TxExtraAttenuation_dB, TxExtraPhase_deg, Freq_Hz, ...
    Real, Imag, Mag_dB, Phase_deg);
writetable(decodedTable, fileName);
end

function createQualityFigure(fileName, result)
%CREATEQUALITYFIGURE 绘制中心频点的端口曲线和 8x4 空间热图。

centerIndex = findCenterIndex( ...
    result.frequencyHz, result.config.vna.centerFrequencyHz);
centerFrequencyHz = result.frequencyHz(centerIndex);
centerResponse = result.HElement(:, centerIndex);
magnitudeDb = 20 .* log10(abs(centerResponse));
phaseDeg = angle(centerResponse) .* (180 / pi);
magnitudeMap = reshape(magnitudeDb, 8, 4);
phaseMap = reshape(phaseDeg, 8, 4);

if result.config.showFigure
    visibility = 'on';
else
    visibility = 'off';
end
figureHandle = figure('Name', 'Hadamard Decoded Link Responses', ...
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
title(magnitudeAxes, 'Decoded link magnitude', 'Interpreter', 'none');
xlim(magnitudeAxes, [1, 32]);

phaseAxes = nexttile(layout);
plot(phaseAxes, 1:32, phaseDeg, 'o-', ...
    'LineWidth', 1.2, 'MarkerSize', 4);
grid(phaseAxes, 'on');
xlabel(phaseAxes, 'APM Port', 'Interpreter', 'none');
ylabel(phaseAxes, 'Phase (deg)', 'Interpreter', 'none');
title(phaseAxes, 'Decoded link phase', 'Interpreter', 'none');
xlim(phaseAxes, [1, 32]);
ylim(phaseAxes, [-180, 180]);

magnitudeMapAxes = nexttile(layout);
imagesc(magnitudeMapAxes, 1:4, 1:8, magnitudeMap);
set(magnitudeMapAxes, 'YDir', 'normal');
axis(magnitudeMapAxes, 'image');
magnitudeColorbar = colorbar(magnitudeMapAxes);
xlabel(magnitudeMapAxes, 'Array column (left to right)', 'Interpreter', 'none');
ylabel(magnitudeMapAxes, 'Row from bottom', 'Interpreter', 'none');
title(magnitudeMapAxes, '8x4 magnitude map (dB)', 'Interpreter', 'none');
xticks(magnitudeMapAxes, 1:4);
yticks(magnitudeMapAxes, 1:8);

phaseMapAxes = nexttile(layout);
imagesc(phaseMapAxes, 1:4, 1:8, phaseMap, [-180, 180]);
set(phaseMapAxes, 'YDir', 'normal');
axis(phaseMapAxes, 'image');
phaseColorbar = colorbar(phaseMapAxes);
xlabel(phaseMapAxes, 'Array column (left to right)', 'Interpreter', 'none');
ylabel(phaseMapAxes, 'Row from bottom', 'Interpreter', 'none');
title(phaseMapAxes, '8x4 phase map (deg)', 'Interpreter', 'none');
xticks(phaseMapAxes, 1:4);
yticks(phaseMapAxes, 1:8);

axesHandles = [magnitudeAxes, phaseAxes, magnitudeMapAxes, phaseMapAxes];
set(axesHandles, 'TickLabelInterpreter', 'none');
set([magnitudeColorbar, phaseColorbar], 'TickLabelInterpreter', 'none');
for axesIndex = 1:numel(axesHandles)
    axesHandles(axesIndex).Toolbar.Visible = 'off';
end
sgtitle(layout, sprintf( ...
    'Hadamard channel responses at %.6f GHz | RX Horn', centerFrequencyHz / 1e9), ...
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
    error('HadamardArray:EmptyVnaResponse', ...
        'VNA 查询 %s 返回了空响应。', command);
end
end

function value = queryVnaNumber(vna, command)
%QUERYVNANUMBER 查询一个有限数值。

response = queryVna(vna, command);
value = str2double(response);
if ~isfinite(value)
    error('HadamardArray:InvalidVnaNumber', ...
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
    error('HadamardArray:InvalidVnaErrorCount', ...
        'VNA 错误计数不是整数：%.15g。', errorCount);
end

messages = strings(errorCount, 1);
for index = 1:errorCount
    messages(index) = string(queryVna(vna, ':SYST:ERR?'));
end
error('HadamardArray:VnaScpiError', ...
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
    warning('HadamardArray:VnaHoldCleanupFailed', ...
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
    error('HadamardArray:CreateDirectoryFailed', ...
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
