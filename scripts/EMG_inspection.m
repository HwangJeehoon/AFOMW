% EMG_inspection.m
% Inspects subj3_assist1~3 CSVs from 260609/EMG:
%   (1) Data integrity  – NaN, flatline, timestamp gaps
%   (2) Cross-trial scale comparison – RMS per channel × trial
%   (3) SNR per channel × trial

clear; clc; close all;

%% ── Configuration ──────────────────────────────────────────────────────────
data_dir     = fullfile(fileparts(fileparts(mfilename('fullpath'))), '260609', 'EMG');
trial_files  = {'subj3_assist1.csv', 'subj3_assist2.csv', 'subj3_assist3.csv'};
trial_labels = {'Trial 1', 'Trial 2', 'Trial 3'};

N_HEADER   = 8;       % rows to skip before numeric data
N_SENSORS  = 8;       % sensors → 16 columns (time, emg, time, emg, ...)

% Flatline detection
FLAT_WIN   = 500;     % sliding window width (samples)  ~0.23 s at 2148 Hz
FLAT_VAR   = 1e-7;    % variance threshold (mV²) below which = flatline
FLAT_MIN_S = 0.5;     % minimum flatline duration to report (seconds)

% Timestamp gap
GAP_FACTOR = 3;       % flag if dt > GAP_FACTOR × median(dt)

% SNR noise estimation
SNR_WIN_S  = 0.5;     % window size for windowed-RMS noise floor (seconds)
SNR_PCT    = 5;       % use bottom N-th percentile of windowed RMS as noise floor

sensor_names = { ...
    'Avanti3(63660)', 'Avanti2(63168)', 'Mini5(59499)',  'Avanti4(63404)', ...
    'Mini7(59434)',   'Mini8(60403)',   'Avanti1(63629)', 'Mini6(59521)' };

%% ── Load data ───────────────────────────────────────────────────────────────
fprintf('=== Loading EMG data ===\n');
T = struct('name', {}, 'time', {}, 'emg', {}, 'fs', {});
for k = 1:numel(trial_files)
    fpath = fullfile(data_dir, trial_files{k});
    fprintf('  Loading %-30s', trial_files{k});
    raw = readmatrix(fpath, 'NumHeaderLines', N_HEADER);
    % odd columns = time, even columns = emg
    time_mat = raw(:, 1:2:2*N_SENSORS-1);   % [N × 8]
    emg_mat  = raw(:, 2:2:2*N_SENSORS);     % [N × 8]
    t_vec    = time_mat(:, 1);
    fs       = 1 / median(diff(t_vec), 'omitnan');
    T(k).name = trial_files{k};
    T(k).time = t_vec;
    T(k).emg  = emg_mat;
    T(k).fs   = fs;
    fprintf('→ %d samples, fs = %.1f Hz, dur = %.1f s\n', ...
        size(emg_mat,1), fs, t_vec(end)-t_vec(1));
end
n_trials = numel(T);

%% ═══════════════════════════════════════════════════════════════════════════
%  1.  DATA INTEGRITY
%% ═══════════════════════════════════════════════════════════════════════════
fprintf('\n=== 1. Data Integrity ===\n');

all_ok = true;
for k = 1:n_trials
    emg  = T(k).emg;
    t    = T(k).time;
    fs   = T(k).fs;
    N    = size(emg, 1);
    fprintf('\n[%s]\n', T(k).name);

    % ── NaN check ──────────────────────────────────────────────────────────
    nan_cnt = sum(isnan(emg), 1);
    if any(nan_cnt > 0)
        all_ok = false;
        for ch = find(nan_cnt > 0)
            fprintf('  [!] NaN   Ch%d %-18s : %d samples\n', ch, sensor_names{ch}, nan_cnt(ch));
        end
    else
        fprintf('  [OK] NaN check: no missing values\n');
    end

    % ── Flatline detection (movvar) ────────────────────────────────────────
    flat_found = false;
    flat_min_samp = round(FLAT_MIN_S * fs);
    for ch = 1:N_SENSORS
        sig = emg(:, ch);
        v   = movvar(sig, FLAT_WIN);          % vectorised – fast even for 700 k rows
        v(isnan(v)) = Inf;
        is_flat = v < FLAT_VAR;

        % find contiguous runs
        d = diff([false; is_flat; false]);
        starts = find(d == 1);
        ends   = find(d == -1) - 1;
        durations = ends - starts + 1;

        long = durations >= flat_min_samp;
        if any(long)
            all_ok    = false;
            flat_found = true;
            for s = find(long)'
                fprintf('  [!] FLAT  Ch%d %-18s : %.2f – %.2f s  (%.2f s)\n', ...
                    ch, sensor_names{ch}, t(starts(s)), t(ends(s)), ...
                    t(ends(s)) - t(starts(s)));
            end
        end
    end
    if ~flat_found
        fprintf('  [OK] Flatline check: no dead zones\n');
    end

    % ── Timestamp gap check ────────────────────────────────────────────────
    dt       = diff(t);
    med_dt   = median(dt);
    gap_idx  = find(dt > GAP_FACTOR * med_dt);
    if ~isempty(gap_idx)
        all_ok = false;
        for g = gap_idx'
            fprintf('  [!] GAP   at t = %.3f s  (dt = %.4f s, expected %.4f s)\n', ...
                t(g), dt(g), med_dt);
        end
    else
        fprintf('  [OK] Timestamp gap check: no gaps (med dt = %.5f s)\n', med_dt);
    end
end

if all_ok
    fprintf('\n  >> All integrity checks PASSED\n');
else
    fprintf('\n  >> WARNING: integrity issues found (see [!] above)\n');
end

%% ── Figure 1: Raw signals ───────────────────────────────────────────────
fig1 = figure('Name', 'Raw EMG – All Trials', 'NumberTitle', 'off', ...
              'Position', [50, 50, 1600, 960]);
for ch = 1:N_SENSORS
    for k = 1:n_trials
        ax = subplot(N_SENSORS, n_trials, (ch-1)*n_trials + k);
        plot(T(k).time, T(k).emg(:, ch), 'LineWidth', 0.2, 'Color', [0.2 0.4 0.8]);
        if ch == 1,      title(trial_labels{k}, 'FontWeight', 'bold'); end
        if k == 1,       ylabel(sensor_names{ch}, 'FontSize', 7, 'Interpreter', 'none'); end
        if ch == N_SENSORS, xlabel('Time (s)', 'FontSize', 7); end
        xlim([T(k).time(1), T(k).time(end)]);
        set(ax, 'FontSize', 6);
        box off;
    end
end
sgtitle('Raw EMG Signals – Integrity Overview', 'FontWeight', 'bold');

%% ═══════════════════════════════════════════════════════════════════════════
%  2.  CROSS-TRIAL SCALE COMPARISON
%% ═══════════════════════════════════════════════════════════════════════════
fprintf('\n=== 2. Cross-trial Scale Comparison (RMS, mV) ===\n');

rms_vals = zeros(N_SENSORS, n_trials);
for k = 1:n_trials
    for ch = 1:N_SENSORS
        rms_vals(ch, k) = rms(T(k).emg(:, ch), 'omitnan');
    end
end

% Print table
hdr = sprintf('  %-20s', 'Channel');
for k = 1:n_trials; hdr = [hdr, sprintf(' %10s', trial_labels{k})]; end %#ok<AGROW>
hdr = [hdr, sprintf('  %8s', 'CV (%)')];
fprintf('%s\n', hdr);
fprintf('  %s\n', repmat('-', 1, 65));

cv_vals = std(rms_vals, 0, 2) ./ mean(rms_vals, 2) * 100;
for ch = 1:N_SENSORS
    row = sprintf('  %-20s', sensor_names{ch});
    for k = 1:n_trials; row = [row, sprintf(' %10.5f', rms_vals(ch,k))]; end %#ok<AGROW>
    flag = '';
    if cv_vals(ch) > 30, flag = '  <-- HIGH VAR'; end
    row = [row, sprintf('  %7.1f%%%s', cv_vals(ch), flag)];
    fprintf('%s\n', row);
end

%% ── Figure 2: Cross-trial RMS comparison ────────────────────────────────
fig2 = figure('Name', 'Cross-trial RMS Comparison', 'NumberTitle', 'off', ...
              'Position', [50, 50, 960, 520]);
b = bar(rms_vals');
set(gca, 'XTick', 1:n_trials, 'XTickLabel', trial_labels);
legend(sensor_names, 'Location', 'northeastoutside', 'FontSize', 8, 'Interpreter', 'none');
xlabel('Trial');  ylabel('RMS (mV)');
title('Cross-trial EMG RMS (higher = stronger signal)');
grid on;  box off;

%% ── Figure 3: CV across trials ───────────────────────────────────────────
fig3 = figure('Name', 'Cross-trial CV', 'NumberTitle', 'off', ...
              'Position', [50, 50, 700, 420]);
barh(cv_vals, 'FaceColor', [0.3 0.6 0.9]);
set(gca, 'YTick', 1:N_SENSORS, 'YTickLabel', sensor_names);
xline(30, 'r--', 'CV=30%', 'LabelVerticalAlignment', 'bottom');
xlabel('Coefficient of Variation (%)');
title('Cross-trial RMS Variability per Channel');
grid on;  box off;

%% ═══════════════════════════════════════════════════════════════════════════
%  3.  SIGNAL-TO-NOISE RATIO
%% ═══════════════════════════════════════════════════════════════════════════
% Noise floor = SNR_PCT-th percentile of windowed RMS (quietest segments)
% Signal RMS  = overall RMS of full recording
% SNR (dB)    = 20*log10(signal_rms / noise_floor_rms)
fprintf('\n=== 3. SNR (dB) ===\n');
fprintf('  Method: noise floor = %d-th pct of %.1f-s windowed RMS\n', SNR_PCT, SNR_WIN_S);

snr_vals = zeros(N_SENSORS, n_trials);
for k = 1:n_trials
    win_samp = round(SNR_WIN_S * T(k).fs);
    for ch = 1:N_SENSORS
        sig      = T(k).emg(:, ch);
        sig_rms  = rms(sig, 'omitnan');

        % windowed RMS using movmean on sig.^2
        win_rms  = sqrt(movmean(sig.^2, win_samp, 'omitnan'));
        noise_rms = prctile(win_rms, SNR_PCT);

        if noise_rms > 0
            snr_vals(ch, k) = 20 * log10(sig_rms / noise_rms);
        else
            snr_vals(ch, k) = NaN;
        end
    end
end

% Print table
hdr = sprintf('  %-20s', 'Channel');
for k = 1:n_trials; hdr = [hdr, sprintf(' %12s', trial_labels{k})]; end %#ok<AGROW>
fprintf('%s\n', hdr);
fprintf('  %s\n', repmat('-', 1, 60));
for ch = 1:N_SENSORS
    row = sprintf('  %-20s', sensor_names{ch});
    for k = 1:n_trials
        val = snr_vals(ch, k);
        if isnan(val)
            row = [row, sprintf(' %10s dB', 'NaN')]; %#ok<AGROW>
        else
            flag = '';
            if val < 6, flag = '(!)'; end
            row = [row, sprintf(' %8.2f dB%s', val, flag)]; %#ok<AGROW>
        end
    end
    fprintf('%s\n', row);
end
fprintf('  (!) = SNR < 6 dB (signal likely dominated by noise)\n');

%% ── Figure 4: SNR comparison ─────────────────────────────────────────────
fig4 = figure('Name', 'SNR per Channel × Trial', 'NumberTitle', 'off', ...
              'Position', [50, 50, 960, 520]);
bar(snr_vals');
set(gca, 'XTick', 1:n_trials, 'XTickLabel', trial_labels);
legend(sensor_names, 'Location', 'northeastoutside', 'FontSize', 8, 'Interpreter', 'none');
yline(6,  'r--', '6 dB',  'LabelVerticalAlignment', 'bottom');
yline(20, 'g--', '20 dB', 'LabelVerticalAlignment', 'bottom');
xlabel('Trial');  ylabel('SNR (dB)');
title(sprintf('EMG SNR  (noise = %d-th pct of %.1f-s windowed RMS)', SNR_PCT, SNR_WIN_S));
grid on;  box off;

%% ── Figure 5: Windowed RMS traces per trial ──────────────────────────────
colors = lines(N_SENSORS);
for k = 1:n_trials
    fig = figure('Name', sprintf('Windowed RMS – %s', trial_labels{k}), ...
                 'NumberTitle', 'off', 'Position', [50+k*30, 50+k*30, 1200, 600]);
    win_samp = round(SNR_WIN_S * T(k).fs);
    hold on;
    for ch = 1:N_SENSORS
        sig     = T(k).emg(:, ch);
        wr      = sqrt(movmean(sig.^2, win_samp, 'omitnan'));
        ds      = max(1, round(numel(wr)/4000));  % downsample for plotting speed
        plot(T(k).time(1:ds:end), wr(1:ds:end), ...
             'Color', colors(ch,:), 'LineWidth', 0.8, 'DisplayName', sensor_names{ch});
    end
    hold off;
    legend('Location', 'northeastoutside', 'FontSize', 7, 'Interpreter', 'none');
    xlabel('Time (s)');  ylabel('Windowed RMS (mV)');
    title(sprintf('Windowed RMS – %s  (win = %.1f s)', trial_labels{k}, SNR_WIN_S));
    grid on;  box off;
end

fprintf('\n=== Inspection Complete ===\n');
