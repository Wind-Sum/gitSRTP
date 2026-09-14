%% Anritsu MS46322B B2B S21 测量
% 运行后，MATLAB 工作区直接保留：
%   frequencyHz   - N×1 真实扫频频率，单位 Hz
%   S21           - N×1 复数 S21
%   S21MagnitudeDb、S21PhaseDeg、calibrationStatus、B2B
%
% 本脚本不执行 *RST、不重新校准，也不改变当前校准/修正状态。

clearvars;
clc;

%% 用户配置
cfg.ipAddress = '192.168.0.10';
cfg.port = 5001;
cfg.timeoutSeconds = 120;

cfg.channel = 1;
cfg.trace = 1;
cfg.centerFrequencyHz = 5.0e9;
cfg.spanFrequencyHz = 1.0e9;
cfg.pointCount = 2001;
cfg.ifBandwidthHz = 5e3;
cfg.powerLevel = 'LOW';            % MS46322B 仅支持 HIGH / LOW

% 诊断选项：直接用电缆连接 Port 1 和 Port 2 时建议设为 true。
cfg.expectDirectThru = false;
cfg.maxExpectedDirectThruLossDb = 5;

cfg.saveResult = true;
cfg.plotResult = true;
scriptDirectory = resolveScriptDirectory( ...
    'MS46322B_B2B_S21_Measurement.m');
cfg.outputDirectory = fullfile(scriptDirectory, 'results', 'B2B');

%% 连接、设置和测量
cfg = validateConfig(cfg);
vna = [];
try
    fprintf('连接 VNA：%s:%d ...\n', cfg.ipAddress, cfg.port);
    vna = tcpclient(cfg.ipAddress, cfg.port, ...
        'Timeout', cfg.timeoutSeconds);
    configureTerminator(vna, "LF");
    flush(vna);
catch exception
    safeDelete(vna);
    error('MS46322B_B2B:ConnectionFailed', ...
        '无法连接 VNA %s:%d。原始错误：%s', ...
        cfg.ipAddress, cfg.port, exception.message);
end
connectionCleanup = onCleanup(@() cleanupVna(vna, cfg));

instrumentIdentity = queryLine(vna, '*IDN?');
identityUpper = upper(instrumentIdentity);
if ~contains(identityUpper, 'ANRITSU') || ...
        ~contains(identityUpper, 'MS46322')
    error('MS46322B_B2B:UnexpectedInstrument', ...
        '连接的设备不是 Anritsu MS46322 系列：%s', instrumentIdentity);
end
fprintf('已连接：%s\n', instrumentIdentity);

writeLine(vna, ':SYST:ERR:CLE');
calibrationStatus.beforeConfiguration = readCalibrationStatus(vna, cfg);
configureS21(vna, cfg);
checkScpiErrors(vna, '参数设置');
actualSettings = readBackSettings(vna, cfg);
calibrationStatus.afterConfiguration = readCalibrationStatus(vna, cfg);
printInstrumentDiagnostics(calibrationStatus, actualSettings);

fprintf(['单次扫频：%.6f 至 %.6f GHz，%d 点，IFBW %.0f Hz，' ...
    '功率 %s ...\n'], ...
    actualSettings.startFrequencyHz / 1e9, ...
    actualSettings.stopFrequencyHz / 1e9, ...
    actualSettings.pointCount, actualSettings.ifBandwidthHz, ...
    actualSettings.powerLevel);

% PLINCOMP 确保 TDATA:SDAT? 返回复数实部/虚部。
writeLine(vna, sprintf(':CALC%d:PAR%d:SEL', cfg.channel, cfg.trace));
writeLine(vna, sprintf(':CALC%d:PAR%d:FORM PLINCOMP', ...
    cfg.channel, cfg.trace));
writeLine(vna, ':TRIG:SING');

[frequencyValues, S21] = readComplexTrace(vna, cfg);
frequencyHz = normalizeFrequencyAxisToHz(frequencyValues, cfg);
frequencyHz = frequencyHz(:);
S21 = S21(:);

if numel(S21) ~= actualSettings.pointCount
    error('MS46322B_B2B:PointCountMismatch', ...
        'VNA 实际设置为 %d 点，但返回了 %d 点。', ...
        actualSettings.pointCount, numel(S21));
end
if numel(frequencyHz) ~= numel(S21)
    error('MS46322B_B2B:DataLengthMismatch', ...
        '频率点数 %d 与 S21 点数 %d 不一致。', ...
        numel(frequencyHz), numel(S21));
end

S21MagnitudeDb = 20 * log10(abs(S21));
S21PhaseDeg = rad2deg(angle(S21));
measurementDiagnostics = analyzeMeasurement(S21MagnitudeDb, cfg);
timestamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss_SSS'));

B2B = struct();
B2B.timestamp = timestamp;
B2B.instrumentIdentity = instrumentIdentity;
B2B.config = cfg;
B2B.actualSettings = actualSettings;
B2B.calibrationStatus = calibrationStatus;
B2B.measurementDiagnostics = measurementDiagnostics;
B2B.frequencyHz = frequencyHz;
B2B.S21 = S21;
B2B.magnitudeDb = S21MagnitudeDb;
B2B.phaseDeg = S21PhaseDeg;
B2B.files = struct('mat', '', 'csv', '');

if cfg.saveResult
    if ~isfolder(cfg.outputDirectory)
        mkdir(cfg.outputDirectory);
    end
    fileStem = sprintf('B2B_S21_%s_%.3f-%.3fGHz_%dpts', ...
        timestamp, frequencyHz(1) / 1e9, frequencyHz(end) / 1e9, ...
        numel(frequencyHz));
    B2B.files.mat = fullfile(cfg.outputDirectory, [fileStem, '.mat']);
    B2B.files.csv = fullfile(cfg.outputDirectory, [fileStem, '.csv']);

    save(B2B.files.mat, 'frequencyHz', 'S21', ...
        'S21MagnitudeDb', 'S21PhaseDeg', 'calibrationStatus', ...
        'measurementDiagnostics', 'B2B');
    outputTable = table(frequencyHz, frequencyHz / 1e9, ...
        real(S21), imag(S21), S21MagnitudeDb, S21PhaseDeg, ...
        'VariableNames', {'Freq_Hz', 'Freq_GHz', 'Real', 'Imag', ...
        'Mag_dB', 'Phase_deg'});
    writetable(outputTable, B2B.files.csv);
end

if cfg.plotResult
    figureHandle = figure('Color', 'white', ...
        'Name', 'MS46322B B2B S21', 'NumberTitle', 'off');
    tiledlayout(figureHandle, 2, 1, ...
        'TileSpacing', 'compact', 'Padding', 'compact');
    magnitudeAxes = nexttile;
    plot(magnitudeAxes, frequencyHz / 1e9, S21MagnitudeDb, ...
        'LineWidth', 1.2);
    grid(magnitudeAxes, 'on');
    xlabel(magnitudeAxes, 'Frequency (GHz)', 'Interpreter', 'none');
    ylabel(magnitudeAxes, '|S21| (dB)', 'Interpreter', 'none');
    title(magnitudeAxes, 'B2B S21 magnitude', 'Interpreter', 'none');

    phaseAxes = nexttile;
    plot(phaseAxes, frequencyHz / 1e9, S21PhaseDeg, ...
        'LineWidth', 1.2);
    grid(phaseAxes, 'on');
    xlabel(phaseAxes, 'Frequency (GHz)', 'Interpreter', 'none');
    ylabel(phaseAxes, 'Phase (deg)', 'Interpreter', 'none');
    title(phaseAxes, 'B2B S21 phase', 'Interpreter', 'none');
    try
        axtoolbar(magnitudeAxes, {});
        axtoolbar(phaseAxes, {});
    catch
    end
end

% 恢复 Log Magnitude 显示并保持 HOLD；clear 会立即执行 onCleanup。
clear connectionCleanup;

fprintf('\nB2B 测量完成：%d 点。\n', numel(S21));
fprintf(['工作区变量：frequencyHz、S21、S21MagnitudeDb、S21PhaseDeg、' ...
    'calibrationStatus、measurementDiagnostics、B2B\n']);
if cfg.saveResult
    fprintf('MAT：%s\n', B2B.files.mat);
    fprintf('CSV：%s\n', B2B.files.csv);
end

%% 局部函数
function cfg = validateConfig(cfg)
%VALIDATECONFIG 检查用户配置。

cfg.ipAddress = char(strtrim(string(cfg.ipAddress)));
if isempty(cfg.ipAddress)
    error('MS46322B_B2B:EmptyIpAddress', 'VNA IP 地址不能为空。');
end
validateattributes(cfg.port, {'numeric'}, ...
    {'scalar', 'integer', '>=', 1, '<=', 65535});
validateattributes(cfg.timeoutSeconds, {'numeric'}, ...
    {'scalar', 'real', 'finite', 'positive'});
validateattributes(cfg.channel, {'numeric'}, ...
    {'scalar', 'integer', '>=', 1, '<=', 16});
validateattributes(cfg.trace, {'numeric'}, ...
    {'scalar', 'integer', '>=', 1, '<=', 16});
validateattributes(cfg.centerFrequencyHz, {'numeric'}, ...
    {'scalar', 'real', 'finite', 'positive'});
validateattributes(cfg.spanFrequencyHz, {'numeric'}, ...
    {'scalar', 'real', 'finite', '>=', 20});
validateattributes(cfg.pointCount, {'numeric'}, ...
    {'scalar', 'integer', '>=', 2, '<=', 20001});
validateattributes(cfg.ifBandwidthHz, {'numeric'}, ...
    {'scalar', 'real', 'finite', 'positive'});
validateattributes(cfg.saveResult, {'logical', 'numeric'}, {'scalar'});
validateattributes(cfg.plotResult, {'logical', 'numeric'}, {'scalar'});
validateattributes(cfg.expectDirectThru, {'logical', 'numeric'}, {'scalar'});
validateattributes(cfg.maxExpectedDirectThruLossDb, {'numeric'}, ...
    {'scalar', 'real', 'finite', 'nonnegative'});
if cfg.centerFrequencyHz - cfg.spanFrequencyHz / 2 <= 0
    error('MS46322B_B2B:InvalidFrequencyRange', ...
        '扫频起始频率必须大于 0 Hz。');
end
cfg.powerLevel = validatestring(upper(string(cfg.powerLevel)), ...
    {'HIGH', 'LOW'});
cfg.saveResult = logical(cfg.saveResult);
cfg.plotResult = logical(cfg.plotResult);
cfg.expectDirectThru = logical(cfg.expectDirectThru);
end

function configureS21(vna, cfg)
%CONFIGURES21 配置线性扫频和 S21，不改变已有校准状态。

channel = cfg.channel;
trace = cfg.trace;
writeLine(vna, sprintf(':SENS%d:HOLD:FUNC HOLD', channel));
writeLine(vna, sprintf(':SENS%d:SWE:TYPE LIN', channel));
writeLine(vna, sprintf(':SENS%d:FREQ:CENT %.15g', ...
    channel, cfg.centerFrequencyHz));
writeLine(vna, sprintf(':SENS%d:FREQ:SPAN %.15g', ...
    channel, cfg.spanFrequencyHz));
writeLine(vna, sprintf(':SENS%d:SWE:POIN %d', ...
    channel, cfg.pointCount));
writeLine(vna, sprintf(':SENS%d:BWID %.15g', ...
    channel, cfg.ifBandwidthHz));
writeLine(vna, sprintf(':SOUR%d:POW %s', channel, cfg.powerLevel));
writeLine(vna, sprintf(':CALC%d:PAR%d:DEF S21', channel, trace));
writeLine(vna, sprintf(':CALC%d:PAR%d:SEL', channel, trace));
end

function actual = readBackSettings(vna, cfg)
%READBACKSETTINGS 回读仪器实际设置。

channel = cfg.channel;
actual.centerFrequencyHz = queryNumber(vna, ...
    sprintf(':SENS%d:FREQ:CENT?', channel));
actual.spanFrequencyHz = queryNumber(vna, ...
    sprintf(':SENS%d:FREQ:SPAN?', channel));
actual.startFrequencyHz = actual.centerFrequencyHz - ...
    actual.spanFrequencyHz / 2;
actual.stopFrequencyHz = actual.centerFrequencyHz + ...
    actual.spanFrequencyHz / 2;
actual.pointCount = queryNumber(vna, ...
    sprintf(':SENS%d:SWE:POIN?', channel));
actual.ifBandwidthHz = queryNumber(vna, ...
    sprintf(':SENS%d:BWID?', channel));
actual.powerLevel = queryLine(vna, sprintf(':SOUR%d:POW?', channel));
actual.effectivePort1PowerDbm = queryNumber(vna, ...
    sprintf(':SOUR%d:EFF:POW:PORT1?', channel));
actual.effectivePort2PowerDbm = queryNumber(vna, ...
    sprintf(':SOUR%d:EFF:POW:PORT2?', channel));
actual.sParameter = queryLine(vna, ...
    sprintf(':CALC%d:PAR%d:DEF?', channel, cfg.trace));
actual.pointCount = round(actual.pointCount);
end

function status = readCalibrationStatus(vna, cfg)
%READCALIBRATIONSTATUS 回读当前通道的 RF 校准修正和插值状态。

channel = cfg.channel;
status.rfCorrectionRaw = queryLine(vna, ...
    sprintf(':SENS%d:CORR:STAT?', channel));
status.rfCorrectionEnabled = parseOnOffResponse( ...
    status.rfCorrectionRaw, ':SENS:CORR:STAT?');
status.interpolationRaw = queryLine(vna, ...
    sprintf(':SENS%d:CORR:INT:STAT?', channel));
status.interpolationEnabled = parseOnOffResponse( ...
    status.interpolationRaw, ':SENS:CORR:INT:STAT?');
end

function enabled = parseOnOffResponse(response, commandName)
%PARSEONOFFRESPONSE 将 0/1 或 OFF/ON 回复转换为 logical。

normalized = upper(strtrim(string(response)));
if any(normalized == ["1", "ON"])
    enabled = true;
elseif any(normalized == ["0", "OFF"])
    enabled = false;
else
    error('MS46322B_B2B:InvalidOnOffResponse', ...
        'SCPI 查询 %s 返回无法识别的状态：%s。', ...
        commandName, char(normalized));
end
end

function printInstrumentDiagnostics(calibrationStatus, actual)
%PRINTINSTRUMENTDIAGNOSTICS 显示校准和功率诊断信息。

before = calibrationStatus.beforeConfiguration;
after = calibrationStatus.afterConfiguration;
fprintf('\n--- VNA 状态诊断 ---\n');
fprintf('配置前 RF 校准修正：%s；插值：%s\n', ...
    onOffText(before.rfCorrectionEnabled), ...
    onOffText(before.interpolationEnabled));
fprintf('配置后 RF 校准修正：%s；插值：%s\n', ...
    onOffText(after.rfCorrectionEnabled), ...
    onOffText(after.interpolationEnabled));
fprintf('当前 Trace 参数：%s\n', actual.sParameter);
fprintf('功率档：%s；Port 1 有效功率：%.3f dBm；Port 2 有效功率：%.3f dBm\n', ...
    actual.powerLevel, actual.effectivePort1PowerDbm, ...
    actual.effectivePort2PowerDbm);

if before.rfCorrectionEnabled && ~after.rfCorrectionEnabled
    warning('MS46322B_B2B:CorrectionDisabledByConfiguration', ...
        ['脚本配置频率、点数、IFBW或功率后，RF 校准修正由 ON 变为 OFF。' ...
         '当前测量未使用原校准。']);
elseif after.rfCorrectionEnabled
    fprintf(['RF 校准修正当前为 ON。必须保证校准与测量使用相同的频率、' ...
        '点数、IFBW和功率档。\n']);
else
    fprintf('RF 校准修正当前为 OFF；本次结果是未校准测量。\n');
end
fprintf('--------------------\n\n');
end

function textValue = onOffText(enabled)
%ONOFFTEXT 返回便于显示的 ON/OFF 文本。
if enabled
    textValue = 'ON';
else
    textValue = 'OFF';
end
end

function diagnostics = analyzeMeasurement(magnitudeDb, cfg)
%ANALYZEMEASUREMENT 给出直通连接下的基本幅度合理性检查。

diagnostics.medianMagnitudeDb = median(magnitudeDb, 'omitnan');
diagnostics.minimumMagnitudeDb = min(magnitudeDb, [], 'omitnan');
diagnostics.maximumMagnitudeDb = max(magnitudeDb, [], 'omitnan');
diagnostics.peakToPeakRippleDb = diagnostics.maximumMagnitudeDb - ...
    diagnostics.minimumMagnitudeDb;
fprintf(['幅度诊断：中值 %.3f dB，范围 %.3f 至 %.3f dB，' ...
    '峰峰纹波 %.3f dB。\n'], diagnostics.medianMagnitudeDb, ...
    diagnostics.minimumMagnitudeDb, diagnostics.maximumMagnitudeDb, ...
    diagnostics.peakToPeakRippleDb);

if cfg.expectDirectThru && diagnostics.medianMagnitudeDb < ...
        -cfg.maxExpectedDirectThruLossDb
    warning('MS46322B_B2B:UnexpectedDirectThruLoss', ...
        ['当前声明为 Port 1-Port 2 直通，但 S21 中值为 %.3f dB，' ...
         '超过允许损耗 %.3f dB。请对照 VNA 前面板的 S21：若前面板接近 ' ...
         '0 dB 而 MATLAB 不是，则需继续检查远程数据读取；若两者一致，' ...
         '则问题在仪器状态、连接或接收机归一化。'], ...
        diagnostics.medianMagnitudeDb, cfg.maxExpectedDirectThruLossDb);
end
end

function [frequencyValues, complexData] = readComplexTrace(vna, cfg)
%READCOMPLEXTRACE 读取带 IEEE 488.2 块头的 XML 复数 Trace。

flush(vna, "input");
writeLine(vna, sprintf(':CALC%d:PAR%d:SEL', cfg.channel, cfg.trace));
writeLine(vna, sprintf(':CALC%d:TDATA:SDAT?', cfg.channel));
xmlBytes = readScpiBlock(vna);
xmlText = native2unicode(xmlBytes(:).', 'UTF-8');
[frequencyValues, complexData] = parseTraceXml(xmlText);
end

function payload = readScpiBlock(vna)
%READSCPIBLOCK 读取 IEEE 488.2 数据块。

header = readExactly(vna, 2);
if header(1) ~= uint8('#')
    error('MS46322B_B2B:InvalidBlockHeader', ...
        'VNA 数据块没有以 # 开始。');
end
digitCount = str2double(char(header(2)));
if ~isfinite(digitCount) || digitCount < 0 || digitCount > 9 || ...
        digitCount ~= fix(digitCount)
    error('MS46322B_B2B:InvalidBlockHeader', ...
        '数据块长度字段位数无效。');
end
if digitCount == 0
    payload = uint8(char(readline(vna)));
    return;
end
lengthText = char(readExactly(vna, digitCount));
payloadLength = str2double(lengthText);
if ~isfinite(payloadLength) || payloadLength < 0 || ...
        payloadLength ~= fix(payloadLength)
    error('MS46322B_B2B:InvalidBlockLength', ...
        '数据块长度字段无效：%s。', lengthText);
end
payload = readExactly(vna, payloadLength);
terminator = readExactly(vna, 1);
if terminator == uint8(13)
    terminator = readExactly(vna, 1);
end
if terminator ~= uint8(10)
    error('MS46322B_B2B:InvalidBlockTerminator', ...
        'VNA 数据块末尾不是 LF。');
end
end

function bytes = readExactly(vna, byteCount)
%READEXACTLY 完整读取指定字节数。

bytes = zeros(1, byteCount, 'uint8');
offset = 0;
while offset < byteCount
    chunk = read(vna, byteCount - offset, 'uint8');
    if isempty(chunk)
        error('MS46322B_B2B:IncompleteRead', ...
            'TCP 数据提前结束，期望 %d 字节，实际 %d 字节。', ...
            byteCount, offset);
    end
    nextOffset = offset + numel(chunk);
    bytes(offset + 1:nextOffset) = chunk(:).';
    offset = nextOffset;
end
end

function [frequencyValues, complexData] = parseTraceXml(xmlText)
%PARSETRACEXML 解析 Point_n 中的频率、实部和虚部。

tokens = regexp(xmlText, ...
    '<Point_\d+>\s*([^<]+?)\s*</Point_\d+>', 'tokens');
if isempty(tokens)
    error('MS46322B_B2B:InvalidTraceXml', ...
        'VNA XML 中没有找到 Point_n 数据。');
end
pointCount = numel(tokens);
frequencyValues = zeros(pointCount, 1);
realPart = zeros(pointCount, 1);
imaginaryPart = zeros(pointCount, 1);
for pointIndex = 1:pointCount
    values = sscanf(tokens{pointIndex}{1}, '%f;%f;%f');
    if numel(values) ~= 3 || any(~isfinite(values))
        error('MS46322B_B2B:InvalidTracePoint', ...
            '第 %d 个 Point_n 数据无效。', pointIndex);
    end
    frequencyValues(pointIndex) = values(1);
    realPart(pointIndex) = values(2);
    imaginaryPart(pointIndex) = values(3);
end
if pointCount > 1 && any(diff(frequencyValues) <= 0)
    error('MS46322B_B2B:NonMonotonicFrequency', ...
        'VNA 返回的频率轴不是严格递增序列。');
end
complexData = complex(realPart, imaginaryPart);
end

function frequencyHz = normalizeFrequencyAxisToHz(frequencyValues, cfg)
%NORMALIZEFREQUENCYAXISTOHZ 将 Hz/kHz/MHz/GHz 横轴统一成 Hz。

frequencyValues = frequencyValues(:);
expectedEndpointsHz = [cfg.centerFrequencyHz - cfg.spanFrequencyHz / 2, ...
    cfg.centerFrequencyHz + cfg.spanFrequencyHz / 2];
candidateScales = [1, 1e3, 1e6, 1e9];
candidateErrorsHz = zeros(size(candidateScales));
for scaleIndex = 1:numel(candidateScales)
    endpointsHz = [frequencyValues(1), frequencyValues(end)] .* ...
        candidateScales(scaleIndex);
    candidateErrorsHz(scaleIndex) = max(abs( ...
        endpointsHz - expectedEndpointsHz));
end
[bestErrorHz, bestIndex] = min(candidateErrorsHz);
toleranceHz = max(1, cfg.spanFrequencyHz * 1e-6);
if bestErrorHz > toleranceHz
    error('MS46322B_B2B:UnknownFrequencyUnit', ...
        ['无法把 VNA 返回的 %.12g 至 %.12g 转换为配置的频率范围；' ...
         '最小端点误差为 %.6g Hz。'], ...
        frequencyValues(1), frequencyValues(end), bestErrorHz);
end
frequencyHz = frequencyValues .* candidateScales(bestIndex);
end

function checkScpiErrors(vna, stage)
%CHECKSCPIERRORS 读取并报告 SCPI 错误队列。

errorCount = queryNumber(vna, ':SYST:ERR:COUN?');
if errorCount <= 0
    return;
end
messages = strings(round(errorCount), 1);
for index = 1:numel(messages)
    messages(index) = string(queryLine(vna, ':SYST:ERR?'));
end
error('MS46322B_B2B:ScpiError', ...
    '%s后 VNA 报告 SCPI 错误：%s', stage, strjoin(messages, newline));
end

function writeLine(vna, command)
%WRITELINE 写入一条以 LF 结束的 SCPI 命令。
writeline(vna, command);
end

function response = queryLine(vna, command)
%QUERYLINE 查询一行文本。
writeLine(vna, command);
response = strtrim(char(readline(vna)));
if isempty(response)
    error('MS46322B_B2B:EmptyResponse', ...
        'SCPI 查询 %s 返回空响应。', command);
end
end

function value = queryNumber(vna, command)
%QUERYNUMBER 查询有限数值。
response = queryLine(vna, command);
value = str2double(response);
if ~isfinite(value)
    error('MS46322B_B2B:InvalidNumericResponse', ...
        'SCPI 查询 %s 返回无效数值：%s。', command, response);
end
end

function cleanupVna(vna, cfg)
%CLEANUPVNA 恢复显示、HOLD并释放TCP连接。

if isempty(vna) || ~isvalid(vna)
    return;
end
try
    writeline(vna, sprintf(':CALC%d:PAR%d:FORM MLOG', ...
        cfg.channel, cfg.trace));
catch
end
try
    writeline(vna, sprintf(':SENS%d:HOLD:FUNC HOLD', cfg.channel));
catch
end
safeDelete(vna);
end

function safeDelete(client)
%SAFEDELETE 安全释放 tcpclient。

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

function directory = resolveScriptDirectory(expectedFileName)
%RESOLVESCRIPTDIRECTORY 确定脚本真实目录，避免保存到编辑器临时目录。

try
    activeFile = char(matlab.desktop.editor.getActiveFilename);
catch
    activeFile = '';
end
if isfile(activeFile)
    [~, name, extension] = fileparts(activeFile);
    if strcmpi([name, extension], expectedFileName)
        directory = fileparts(activeFile);
        return;
    end
end
fullName = mfilename('fullpath');
if ~isempty(fullName) && isfile([fullName, '.m'])
    directory = fileparts([fullName, '.m']);
    return;
end
locatedFile = which(expectedFileName);
if ~isempty(locatedFile) && isfile(locatedFile)
    directory = fileparts(locatedFile);
    return;
end
error('MS46322B_B2B:ScriptLocationUnknown', ...
    '请先把脚本保存为 %s，再运行完整脚本。', expectedFileName);
end
