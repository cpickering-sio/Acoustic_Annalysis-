
clear          % Clear all variables from the workspace
close all      % Close all open figure windows

%addpath '/Users/corinnepickering/Desktop/Thode_lab/Ulysses/source/deps'; % Add path to compute_directional_metrics.m function
addpath .

base_dir = '/Users/corinnepickering/Desktop/Thode_lab/Acoustic_Analysis/R3D_reefense_annalysis/DASAR_R3D_Annalysis/Fish_calls'; % Root directory containing fish call subdirectories
%base_dir ='/Users/thode/Projects/VectorSensors.dir/Pulse_Detector_Vector_Sensor.dir/Fish_calls';
% Save the current working directory so we can return to it at the end
current_dir = pwd;
cd(base_dir); % Navigate into the fish calls directory


% ---- Spectrogram Parameters ----
nfft = 256/2;            % Number of FFT points (128); controls frequency resolution
window = hamming(nfft);  % Apply a Hamming window to each FFT frame to reduce spectral leakage
noverlap = nfft/2;       % Number of samples overlapping between consecutive FFT frames (50% overlap)

% ---- Azimuth Display & Peak Detection Parameters ----
edges = 0:15:360;                    % Bin edges for azimuth histograms (degrees)
thresh=(2^16)*0.2;                   % FastPeakFind threshold: 0.1 percent of bandwidth (.15?)
filt=fspecial('gaussian', 3,1);      % Smoothing filter applied to image before peak detection
alg=1;                               % Peak detection algorithm: 1 = fast/simple, 2 = robust/slower (blob detection)

% ---- Directional Metrics Parameters ----
metric_type{1} = 'Azimuth';    % First metric to compute: azimuth (compass bearing) of sound source
metric_type{2} = 'ItoERatio';  % Second metric: intensity-to-energy ratio (a measure of signal directionality)

param.sec_avg = '0';                     % No time-averaging of directional output
param.climm = '[0 360]';                 % Color axis limits for azimuth plot (full compass, 0–360 degrees)
param.brefa = '0';                       % Bearing reference angle (0 = north/forward)
param.phase_calibration = 'Arctic5G_2014'; % Phase calibration file to correct for sensor phase offsets

% Define the three DASAR sensor channels used for directional analysis
param.instrument{1} = 'DASAR_DASAR-omnisensor'; % Channel 1: omnidirectional pressure sensor
param.instrument{2} = 'DASAR_DASAR-Xsensor';    % Channel 2: X-axis velocity sensor
param.instrument{3} = 'DASAR_DASAR-Ysensor';    % Channel 3: Y-axis velocity sensor
%     '_VS-209-omnisensor'; needs to start with '_' and end with 'sensor'
%           Each channel needs its own string.


% ---- Loop Over Subdirectories ----
dir_files = dir('*00'); % Find all subdirectories ending in '00' (one per recording station/deployment)

for I = 1:length(dir_files)        % Loop over each subdirectory
    %for I = 9:9 % New Moon July 17th
    %for I = 12:12 %example with no peaks
    %for I = 4:4

    cd(dir_files(I).name)           % Navigate into the subdirectory
    mat_name = dir('*.mat');        % List all .mat files (individual fish call recordings) in this subdirectory

    for J = 1:length(mat_name)     % Loop over each .mat file
        figure                     % Open a new figure window for this recording

        % ---- ANALYSIS: Load data and compute spectrogram ----
        fname = mat_name(J).name;  % Get the filename of the current .mat file
        data = load(fname);        % Load the .mat file; expects fields 'x' (signal) and 'Fs' (sample rate)
        x = data.x;                % Extract the multi-channel signal matrix (rows = samples, columns = channels)

        [s,f,t] = spectrogram(x(:,1), window, noverlap, nfft, data.Fs);
        % Compute the spectrogram of channel 1 (omnidirectional)
        % Returns: s = complex STFT matrix, f = frequency vector (Hz), t = time vector (s)

        Pdb = 10 * log10(abs(s));  % Convert spectrogram magnitude to decibels (dB re 1)

        % ---- PLOTTING: Spectrogram ----
        ax1 = subplot(2,2,1);              % Top panel of a 2-panel figure
        imagesc(t, f, Pdb);          % Plot spectrogram as a color image (time on x-axis, frequency on y-axis)
        axis xy                      % Flip y-axis so low frequencies are at bottom (default imagesc is flipped)
        xlabel("time (seconds)");    % Label x-axis
        ylabel("Hz");                % Label y-axis
        colorbar                     % Add color scale bar showing dB values
        colormap(ax1,"jet")              % Use jet color scheme (blue=low, red=high)
        title(sprintf("Spectrogram of %s", dir_files(I).name)); % Title with subdirectory name

        % ---- ANALYSIS: Compute directional metrics (azigram) ----
        [TT, FF, output_array, PdB] = compute_directional_metrics(x', metric_type, ...
            data.Fs, nfft, 0.5, param);
        % Compute azimuth and ItoE ratio across time and frequency using all 3 channels
        % x' transposes so channels are rows (required by function)
        % 0.5 = 50% overlap between analysis windows
        % Returns: TT = time vector, FF = frequency vector,
        %          output_array{1} = azimuth matrix, output_array{2} = ItoE matrix, PdB = power in dB

        % ---- PLOTTING: Azigram ----
        ax2 = subplot(2,2,3);               % Bottom panel of the same 2-panel figure
        imagesc(FF,TT, output_array{1}'); % Plot azimuth as a color image (azigram)
        %axis xy                      % Flip y-axis so low frequencies are at bottom
        ylabel("time (seconds)");    % Label x-axis
        xlabel("Hz");                % Label y-axis
        colorbar                     % Add color scale bar showing azimuth in degrees (0–360)
        colormap(ax2,"hsv")              % Use hsv color scheme
        title("Azigram of the Signal"); % Title

        % ---- PLOTTING: Azimuth distribution and scatter ----

        % %subplot(2,2,1)
        % %histogram(output_array{1}(:), 36); % Histogram of all azimuth values (36 bins = 10-degree resolution)
        % % output_array{1}(:) flattens the 2D azimuth matrix into a single vector
        % xlabel("Heading") %Heading axis spans full compass
        % ylabel("Points")  %double check this
        % title(sprintf("Histogram of %s", dir_files(I).name));

        
        % plot(output_array{1}(:), Pdb(:), ".") % Scatter plot: azimuth (x) vs. power in dB (y)
        % % Each point is one time-frequency bin; shows whether certain headings are louder
        % ylabel("dB");
        % xlabel("Heading");
        % xlim([0 360]);  % Heading axis spans full compass
        % ylim([50 70]);  % dB axis range
        % grid on
        % title(sprintf("Scatter Plot of %s", dir_files(I).name));


        % ---- Making Histograms for each individual frequency ----
        ax3 = subplot(2,2,2);
     
        %%Frequency Azimuth Display subplot

        %%Corrine, this is the problem
        Ncounts_fraz=zeros(length(FF),length(edges)-1); %allocating memory 
        for Ifreq = 1:length(FF)
            aziline = output_array{1}(Ifreq,:);

            [Ncounts_fraz(Ifreq,:),edges] = histcounts(aziline,edges);

        end

        Ncounts_fraz=Ncounts_fraz/length(TT);

        midpoint = 0.5*(edges(2:end)+edges(1:(end-1)));
        subplot(2,2,2)
        imagesc(midpoint, FF, Ncounts_fraz);
        axis xy
        ylabel("Frequency (Hz)");
        xlabel("Heading (Degrees)");
        title("Frequency Azimuth Display")
        xticks(0:30:360)
        grid on %make white
        colorbar;
        colormap(ax3,"parula")

        %%Time Azimuth Display subplot 
        ax4 = subplot(2,2,4);

        %%Corrine, this is the problem
        Ncounts_taz=zeros(length(edges)-1,length(TT));
        for Itime = 1:length(TT)
            aziline = output_array{1}(:,Itime);

            [Ncounts_taz(:,Itime),edges] = histcounts(aziline,edges);

        end
        Ncounts_taz=Ncounts_taz/length(FF);

        midpoint = 0.5*(edges(2:end)+edges(1:(end-1)));
        imagesc(midpoint, TT, Ncounts_taz');
        %axis xy
        xlabel("Heading (Degrees)");
        ylabel("Time (s)");
        title("Time Azimuth Display")
        xticks(0:30:360)
        grid on %make white
        colorbar
        colormap(ax4,"parula");
        clim([0 0.3]);

    end %matfile
    cd ..  % Move back up one directory level after processing all files in this subdirectory

    %%%%Search for peaks
    
    edge=2;
    
    myfig=gcf;
    [cent, cm]=FastPeakFind(Ncounts_taz', thresh, filt,edge,alg );
    azi_pick=midpoint(round(cent(1:2:end)));
    t_pick=TT(round(cent(2:2:end)));
    %figure;
    figure(myfig)
    %imagesc(cm);colorbar;hold on;
    hold on
    plot(azi_pick,t_pick,'ro','MarkerFaceColor','r');
    
    pause;
    close(100)
end %directory

cd(current_dir); % Return to the original working directory
