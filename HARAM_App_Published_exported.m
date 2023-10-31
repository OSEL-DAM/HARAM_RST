classdef HARAM_App_Published_exported < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        HARAMUIFigure                   matlab.ui.Figure
        GridLayout                      matlab.ui.container.GridLayout
        Inputs                          matlab.ui.container.Panel
        InputsGrid                      matlab.ui.container.GridLayout
        StrategiesTabs                  matlab.ui.container.TabGroup
        BaselineTab                     matlab.ui.container.Tab
        BaselineGrid                    matlab.ui.container.GridLayout
        EpsilonKSpinner                 matlab.ui.control.Spinner
        BaselineMitSpinner              matlab.ui.control.Spinner
        EpsilonKSpinnerLabel            matlab.ui.control.Label
        BaselineMitSpinnerLabel         matlab.ui.control.Label
        MitigationTab                   matlab.ui.container.Tab
        MitigationGrid                  matlab.ui.container.GridLayout
        RemoveRowButton                 matlab.ui.control.Button
        SortButton                      matlab.ui.control.Button
        AddRowButton                    matlab.ui.control.Button
        MitigationTable                 matlab.ui.control.Table
        InfectionCharacteristicsPanel   matlab.ui.container.Panel
        ICGrid                          matlab.ui.container.GridLayout
        IterationsSpinnerLabel          matlab.ui.control.Label
        R0StdSpinnerLabel               matlab.ui.control.Label
        GammaStdSpinnerLabel            matlab.ui.control.Label
        MuLabel                         matlab.ui.control.Label
        IterationsSpinner               matlab.ui.control.Spinner
        MuStdSpinner                    matlab.ui.control.Spinner
        InfectionRecoveryRateMuSpinner  matlab.ui.control.Spinner
        R0StdSpinner                    matlab.ui.control.Spinner
        RepoductionNumberR0Spinner      matlab.ui.control.Spinner
        RepoductionNumberR0SpinnerLabel  matlab.ui.control.Label
        Scenario                        matlab.ui.container.Panel
        ScenarioGrid                    matlab.ui.container.GridLayout
        InterventionStrategyDropDown    matlab.ui.control.DropDown
        ScenarioDropDown                matlab.ui.control.DropDown
        InterventionStrategyLabel       matlab.ui.control.Label
        ScenarioLabel                   matlab.ui.control.Label
        Outputs                         matlab.ui.container.Panel
        OutputGrid                      matlab.ui.container.GridLayout
        ULbSliderLabel                  matlab.ui.control.Label
        RunScenerioButton               matlab.ui.control.Button
        ExportDataButton                matlab.ui.control.Button
        ULbSlider                       matlab.ui.control.Slider
        BoundsPlotOptionsButtonGroup    matlab.ui.container.ButtonGroup
        NoneButton                      matlab.ui.control.RadioButton
        ErrorBarsButton                 matlab.ui.control.RadioButton
        WedgeButton                     matlab.ui.control.RadioButton
        PlotTabGroup                    matlab.ui.container.TabGroup
        NewCasesTab                     matlab.ui.container.Tab
        NewCasesGrid                    matlab.ui.container.GridLayout
        TAxes                           matlab.ui.control.UIAxes
        ActiveCasesTab                  matlab.ui.container.Tab
        ActiveCaseGrid                  matlab.ui.container.GridLayout
        IAxes                           matlab.ui.control.UIAxes
        SpreadTab                       matlab.ui.container.Tab
        SpreadGrid                      matlab.ui.container.GridLayout
        deltaAxes                       matlab.ui.control.UIAxes
    end

    % Properties that correspond to apps with auto-reflow
    properties (Access = private)
        onePanelWidth = 576;
    end

    
    properties (Access = public)
        Scenerios = ["New York City, New York", "New York State", "Harris County, Texas", "Diamond Princess Cruise"];
        ScenerioData = ["NYC","NYState","HC","DP"];
        HARAM_out = struct;
    end % properties public
    
    properties (Access = private)
        CustomScenerio = false;
        PPE_bool = true;
        PPE_FH = [];
        PPE_str_abv = "";
        UQ_bool = true;
        UQ_SingularityLimit = 200;
        UQ_LoopLimit = 20; 
        UQ_Nincrement=50; 
        ExportedData=false
        HARAM_ran=false;
        UQ_warning=false;
        InputsChngd=false;
        HARAM_PlotData = struct;
    end % properties private
    
    methods (Access = private)
            
        function PlotHARAM(app,PlotData,DataVar)
                    % Plots HARAM Data After Running it and Saves the Handles
                    % to HARAM_PlotData.

                    % Sets Delta Plot Specific Options
                    % Hides mitigation data from Spread Function Plots
                    if DataVar =="delta"
                        legLoc = "northeast";
                        findVar = "BL_mean";
                    else
                        legLoc = "northwest";
                        findVar = "mean";
                    end
                    
                    % Gets Handle Names from Input Datatable
                    PD_CP = PlotData.Properties.CustomProperties;
                    HandleStruct = PD_CP.Handles;
                    app.HARAM_PlotData.(HandleStruct)=struct;
                    app.HARAM_PlotData.(HandleStruct).mainAxes = app.(PD_CP.mainAxes);
                    VarNames = string(PlotData.Properties.VariableNames);
                    meanVars = contains(VarNames,findVar);

        
                    % Set Legend Text and Location
                    legStr = extractBefore(VarNames(meanVars),"_");
                    legStr(contains(VarNames(meanVars),"BL"))="Baseline";
                    legStr(contains(VarNames(meanVars),digitsPattern))=legStr(contains(VarNames(meanVars),digitsPattern))+"% "+app.PPE_str_abv;

                    
                    % app.HARAM_PlotData.(HandleStruct).mainAxes is a UIAxes Handle
                    % Despite Warnings, Plots Data to Proper Axes
                    app.HARAM_PlotData.(HandleStruct).AvgLine = plot(app.HARAM_PlotData.(HandleStruct).mainAxes,...
                        PlotData{:,meanVars});
                    app.HARAM_PlotData.(HandleStruct).LineLegend = legend(app.HARAM_PlotData.(HandleStruct).mainAxes,...
                        legStr,"Location",legLoc,"AutoUpdate",false);
                    ytext = string(app.HARAM_PlotData.(HandleStruct).mainAxes.Parent.Parent.Title);
                    xlabel(app.HARAM_PlotData.(HandleStruct).mainAxes,"Days into Scenerio")
                    ylabel(app.HARAM_PlotData.(HandleStruct).mainAxes,ytext)
                    title(app.HARAM_PlotData.(HandleStruct).mainAxes,ytext+" Over Time")
                    app.HARAM_PlotData.(HandleStruct).BoundsPlot = gobjects;
        
                    % Gets Current Bound Plot Options and Plot them
                    BoundsOpt = app.BoundsPlotOptionsButtonGroup.SelectedObject;
                    SliderValue = app.ULbSlider.Value;
                    DataHandle = table(PD_CP.PlotVar,HandleStruct,'VariableNames',["DataVar","Handle"]);
                    switch BoundsOpt.Text
                        case "Wedge"
                            app.PlotWedge(DataHandle,SliderValue)
                        case "Error Bars"
                            app.PlotEB(DataHandle,SliderValue)   
                    end % switch BoundsOpt.Text
        end % function PlotHARAM

        function PlotWedge(app,DataHandles,SliderValue)
        % Plots Bound Wedge, Needed for the following
        % - Inital Plot (PlotHARAM)
        % - Chnaging Bound Type (BGSelectionChnged)

            for idx = 1:height(DataHandles)
                % Sets Bound Plot Data
                HandleData = app.HARAM_PlotData.(DataHandles.Handle(idx));
                PlotData = app.HARAM_out.(DataHandles.DataVar(idx));
                VarNames = string(PlotData.Properties.VariableNames);

                % Hides mitigation data from Spread Function Plots
                if DataHandles.DataVar(idx) == "delta"
                    findVarU = "BL_Ub";
                    findVarL = "BL_Lb";
                else
                    findVarU = "Ub";
                    findVarL = "Lb";
                end

                LbData = fillmissing(PlotData{:,contains(VarNames,findVarL)},'constant',0);
                UbData = fillmissing(PlotData{:,contains(VarNames,findVarU)},'constant',0);
                fillY = [LbData;flipud(UbData)];
                fillX = repmat([1:size(LbData,1),size(LbData,1):-1:1]',[1 size(LbData,2)]);
                fillC = permute(lines(width(LbData)),[1,3,2]);
                fillAlpha = SliderValue/abs(diff(app.ULbSlider.Limits));
                if app.HARAM_ran
                    % Deletes Prior Bound Plot
                    delete(HandleData.BoundsPlot)
                end % if app.HARAM_ran
                
                % app.HARAM_PlotData.(HandleStruct).mainAxes is a UIAxes Handle
                % Despite Warnings, Plots Data to Proper Axes
                hold(HandleData.mainAxes,"on")
                app.HARAM_PlotData.(DataHandles.Handle(idx)).BoundsPlot = patch(HandleData.mainAxes,...
                    fillX,fillY,fillC,'EdgeColor','none','FaceAlpha',fillAlpha);
                hold(HandleData.mainAxes,"off")
            end % for idx = 1:height(DataHandles)
        end % function PlotWedge

        function PlotEB(app,DataHandles,SliderValue)
        %  Plots Error Bars, Needed for the following
        % - Inital Plot (PlotHARAM)
        % - Updated Number of Bars (ULbSliderValueChanging)
        % - Chnaging Bound Type (BGSelectionChnged)

            for idx = 1:height(DataHandles)
                % Sets Error Bar Plot Data
                HandleData = app.HARAM_PlotData.(DataHandles.Handle(idx));
                PlotData = app.HARAM_out.(DataHandles.DataVar(idx));
                VarNames = string(PlotData.Properties.VariableNames);

                % Hides mitigation data from Spread Function Plots
                if DataHandles.DataVar(idx) == "delta"
                    findVarM = "BL_mean";
                    findVarU = "BL_Ub";
                    findVarL = "BL_Lb";
                else
                    findVarM = "mean";
                    findVarU = "Ub";
                    findVarL = "Lb";
                end

                meanVars = contains(VarNames,findVarM);
                LbVars = contains(VarNames,findVarL);
                UbVars = contains(VarNames,findVarU);
                LbData = PlotData{:,LbVars};
                UbData = PlotData{:,UbVars};
                barsIdx = round(linspace(1,height(PlotData),round(SliderValue)));
                ebY = PlotData{barsIdx,meanVars};
                ebNeg = ebY-LbData(barsIdx,:);
                ebPos = UbData(barsIdx,:)-ebY;
                if app.HARAM_ran
                    % Delete Prior Bounds Plot
                    delete(HandleData.BoundsPlot)
                end % if app.HARAM_ran

                colororder(HandleData.mainAxes,lines(width(ebY)))
                % app.HARAM_PlotData.(HandleStruct).mainAxes is a UIAxes Handle
                % Despite Warnings, Plots Data to Proper Axes
                hold(HandleData.mainAxes,"on")
                app.HARAM_PlotData.(DataHandles.Handle(idx)).BoundsPlot = errorbar(HandleData.mainAxes,...
                    repmat(barsIdx',[1 width(ebY)]),ebY,ebNeg,ebPos,"LineStyle","none");
                hold(HandleData.mainAxes,"off") 
            end % for idx = 1:height(DataHandles)
            app.ULbSlider.Limits = [1 height(PlotData)];
            app.ULbSlider.MajorTicksMode = 'manual';
            app.ULbSlider.MajorTicks = floor(linspace(1,height(PlotData),11));
        end % function PlotEB
        
        function ChangedData(app)
            % Changes Apperance of Run Scenerio Button
            app.RunScenerioButton.FontWeight = 'bold';
        end
        
    end % methods private

    % Callbacks that handle component events
    methods (Access = private)

        % Code that executes after component creation
        function startupFcn(app)
            clc;
            % Set Startup Defaults
            app.ScenarioDropDown.Items=app.Scenerios;
            app.ScenarioDropDown.ItemsData=app.ScenerioData;
            
            app.ScenarioDropDown.Value = "NYC";
            app.InterventionStrategyDropDown.Value = "Mask FE";
            app.CustomScenerio = false;
            app.PPE_str_abv = "FE";
            app.PPE_bool = true;
            app.PPE_FH = @PPE_FE;
            app.IterationsSpinner.Value = 500;
            app.UQ_bool = true;
            app.RepoductionNumberR0Spinner.Value= 3.95;
            app.R0StdSpinner.Value = 1.025;
            app.InfectionRecoveryRateMuSpinner.Value = 0.3; % 6;
            app.MuStdSpinner.Value = 0.1; % 2;

            app.MitigationTable.ColumnName = {'Filtration Efficiency [%]'};
            app.MitigationTable.Data = [0.75;0.80;0.90];

            app.BoundsPlotOptionsButtonGroup.SelectedObject=app.WedgeButton;
            app.ULbSlider.Limits = [0,100];
            app.ULbSliderLabel.Text = "% Transparency";
            app.ULbSlider.Tooltip = "Adjust the transparency of the wedge plot";
            app.ULbSlider.Limits = [0,100];
            app.ULbSlider.Value = 100;
            
            MitTblStl = uistyle("HorizontalAlignment","center","FontWeight","bold");
            addStyle(app.MitigationTable,MitTblStl)
            app.ExportDataButton.Enable=false;
            app.ExportDataButton.Tooltip = "Run the model to enable the exporting of data.";
            app.RunScenerioButton.FontWeight = 'normal';
            app.HARAM_ran=false;
        end

        % Button pushed function: RunScenerioButton
        function RunScenarioButtonPushed(app, event)
            %% RUN HARAM MODEL
            clc;
            uiPB = uiprogressdlg(app.HARAMUIFigure,"Title","HARAM App","Message","Running Model",...
        'Indeterminate','on',"Cancelable","on");

            app.ExportDataButton.Enable = false;


            % Assign GUI Inputs to Structures to be passed to the model
            LOC.str = app.ScenarioDropDown.Value;
            LOC.CustomScenerio = app.CustomScenerio;

            PPE.str = app.InterventionStrategyDropDown.Value;
            PPE.str_abv = app.PPE_str_abv;
            PPE.BL_FE = app.BaselineMitSpinner.Value;
            PPE.BL_epsk = app.EpsilonKSpinner.Value;
            PPE.PPE_bool = app.PPE_bool;
            PPE.PPE_data = app.MitigationTable.Data;
            PPE.PPE_FH = app.PPE_FH;


            UQ.bool = app.UQ_bool;
            UQ.R0 = app.RepoductionNumberR0Spinner.Value;
            UQ.R0std = app.R0StdSpinner.Value;
            UQ.mu = app.InfectionRecoveryRateMuSpinner.Value;
            UQ.muStd = app.MuStdSpinner.Value;
            UQ.N = app.IterationsSpinner.Value;
            UQ.Ninc = app.UQ_Nincrement;
            UQ.SigLim = app.UQ_SingularityLimit;
            UQ.HardLimit = app.UQ_LoopLimit;
            
            try
                excp = false;
                % Runs the Model in an External Function
                [PlotData,counter] = HARAM(LOC,PPE,UQ,uiPB);
            catch ME
                % Catches Exceptions that Occurred in the model
                excp = true;
                switch ME.identifier
                    case 'HARAM:Canceled'
                        % Model Computation Was Canceled via User
                        report = ME.message;
                        icon = "warning";
                    case 'HARAM:SigLimitUnreach'
                        % Model Was Unable to Converge to the Signularity
                        % Limit
                        report = ME.message;
                        icon = "error";
                    otherwise
                        % Generates Report of Exception that Occured
                        report = getReport(ME);
                        icon = "error";
                end % switch ME.identifier

                % Closes the Progress Bar and Report Error to User
                close(uiPB)
                uialert(app.HARAMUIFigure,report,"HARAM App","Interpreter","html","Icon",icon,"CloseFcn",@(~,~)uiresume(app.HARAMUIFigure))
                uiwait(app.HARAMUIFigure)
                
            end % try
            if ~excp

                % Plot T, I, delta, delta/delta0 (first element in delta)
                % all as individual plots (need a tab group)
                % Line is mean (always ploted)
                % ub & lb should have the option of an error bar at the
                % end or throuout (add a slider), highlighted patch, or not plotted at all
                % T: # of Daily New Infection
                % I: Active Cases (Infected)
                % delta: Normalized Spread Function

                % Model was sucessfully ran, sets graphic handles, plots
                % the model outputs and save them to a struct
                DataVar = strings(size(PlotData))';
                for idx = 1:numel(PlotData)
                    DataTable = PlotData{idx};
                    DataVar(idx) = DataTable.Properties.CustomProperties.PlotVar;
                    DataTable.Properties.CustomProperties.Handles = DataVar(idx) + "_Handles";
                    DataTable.Properties.CustomProperties.mainAxes = DataVar(idx) + "Axes";
                    app.HARAM_out.(DataVar(idx)) = DataTable;
                    app.PlotHARAM(DataTable,DataVar(idx));
                    
                    if uiPB.CancelRequested
                        % Model Was Canceled during the Ploting Phase
                        close(uiPB)
                        uialert(app.HARAMUIFigure,"Model Simulation Was Canceled","HARAM App","Interpreter",...
                            "html","Icon","warning","CloseFcn",@(~,~)uiresume(app.HARAMUIFigure))
                        uiwait(app.HARAMUIFigure)
                        return
                    end % if
                end % for          

                % Adds Extra Data to Output Structure
                app.HARAM_out.SigCount = counter;
                InputParams=[struct2table(PPE,"AsArray",true),struct2table(UQ,"AsArray",true)];
                InputParams=removevars(InputParams,["str_abv","PPE_FH","bool","Ninc","SigLim","HardLimit"]);
                InputParams=addvars(InputParams,LOC.str,'Before',1,'NewVariableNames','Scenario');
                InputParams.Properties.VariableNames = replace(InputParams.Properties.VariableNames,["str","PPE"],"Int");
                app.HARAM_out.Inputs = InputParams;


                % Create Table of Handle and Data Locations for updating
                % plots
                if app.HARAM_ran
                    % Clears Previous Data Handles from Plot Data
                    app.HARAM_PlotData = rmfield(app.HARAM_PlotData,"DataHandles");
                end % if app.HARAM_ran
                Handle = string(fieldnames(app.HARAM_PlotData));
                app.HARAM_PlotData.DataHandles = table(DataVar,Handle);
                
                % Sets/Resets Flags after running the model
                app.ExportDataButton.Enable = true;
                app.ExportDataButton.Tooltip = "Export the analyzed data as either a text, CSV or Excel file. (Ctrl+S)";
                app.ExportedData = false;
                app.InputsChngd = false;
                app.RunScenerioButton.FontWeight = 'normal';
                app.HARAM_ran=true;
                close(uiPB)
                uialert(app.HARAMUIFigure,"Done","HARAM App","Icon","success","CloseFcn",@(~,~)uiresume(app.HARAMUIFigure));
                uiwait(app.HARAMUIFigure)
            end % if ~excp
        end

        % Value changed function: InterventionStrategyDropDown
        function InterventionStrategyDropDownValueChanged(app, event)
            % Sets Default Mitgation Measure Values after being selected 
            PPE = app.InterventionStrategyDropDown.Value;
            switch PPE
                case "Mask FE"
                    app.RemoveRowButton.Enable = true;
                    app.AddRowButton.Enable = true;
                    app.SortButton.Enable = true;
                    app.BaselineMitSpinner.Enable = true;
                    app.EpsilonKSpinner.Enable = true;
                    app.MitigationTable.ColumnName = {'Filtration Efficiency [%]'};
                    app.MitigationTable.Data = [0.75;0.80;0.90];
                    app.PPE_bool=true;
                    app.PPE_FH = @PPE_FEpf;
                    app.PPE_str_abv = "FE";
                    app.BaselineMitSpinner.Value = 0.67;
                    app.EpsilonKSpinner.Value = 0.2;
                    TT = "filtration efficiencies (FE) of masks used to be compared to the baseline FE.";
                case "Mask Compliance"
                    app.RemoveRowButton.Enable = true;
                    app.AddRowButton.Enable = true;
                    app.SortButton.Enable = true;
                    app.BaselineMitSpinner.Enable = true;
                    app.EpsilonKSpinner.Enable = true;
                    app.MitigationTable.ColumnName = {'Mask Compliance [%]'};
                    app.MitigationTable.Data = [0.5;0.6;0.7];
                    app.PPE_bool=true;
                    app.PPE_FH = @PPE_MCpf;
                    app.PPE_str_abv = "MC";
                    app.BaselineMitSpinner.Value = 0.67;
                    app.EpsilonKSpinner.Value = 0.2;
                    TT = "the percent of people are mask compliant at peak infection compared to the baseline.";
                case "Social Distancing"
                    app.RemoveRowButton.Enable = true;
                    app.AddRowButton.Enable = true;
                    app.SortButton.Enable = true;
                    app.BaselineMitSpinner.Enable = false;
                    app.EpsilonKSpinner.Enable = false;
                    app.MitigationTable.ColumnName = {'Change in SD [%]'};
                    app.MitigationTable.Data = [0.1;0.2;0.3];
                    app.PPE_bool=true;
                    app.PPE_FH = @PPE_SDpf;
                    app.PPE_str_abv = "SD";
                    TT = "the percent increase of people who social distance compared to the baseline.";
                    app.StrategiesTabs.SelectedTab = app.StrategiesTabs.Children(2);
                otherwise
                    app.MitigationTable.ColumnName = {''};
                    app.MitigationTable.Data = [];
                    app.RemoveRowButton.Enable = false;
                    app.AddRowButton.Enable = false;
                    app.SortButton.Enable = false;
                    app.BaselineMitSpinner.Enable = false;
                    app.EpsilonKSpinner.Enable = false;
                    app.PPE_bool=false;
                    app.PPE_FH = [];
                    app.PPE_str_abv = "";
                    app.BaselineMitSpinner.Value = 0.67;
                    app.EpsilonKSpinner.Value = 0.2;
                    TT = "Table of mitigation values to evaluated compared to the baseline.";
            end % switch PPE
            app.MitigationTable.Tooltip = "Table of "+TT;

            if app.HARAM_ran
                app.InputsChngd = true;
                ChangedData(app)
            end % if app.HARAM_ran
        end

        % Value changed function: ScenarioDropDown
        function ScenarioDropDownValueChanged(app, event)
            % Sets Scenerio Default Values for the UQ
            value = app.ScenarioDropDown.Value;
            switch value
                case "NYC"
                    app.RepoductionNumberR0Spinner.Value= 3.95;
                    app.R0StdSpinner.Value = 1.025;
                    app.InfectionRecoveryRateMuSpinner.Value = 0.3; % 6;
                    app.MuStdSpinner.Value = 0.1; % 2;
                    app.CustomScenerio = false;
                case "NYState"
                    app.RepoductionNumberR0Spinner.Value= 6.4;
                    app.R0StdSpinner.Value = 1.05;
                    app.InfectionRecoveryRateMuSpinner.Value = 0.3; % 4.5;
                    app.MuStdSpinner.Value = 0.1; % 1.5;
                    app.CustomScenerio = false;
                case "HC"
                    app.RepoductionNumberR0Spinner.Value= 2.66;
                    app.R0StdSpinner.Value = 0.32;
                    app.InfectionRecoveryRateMuSpinner.Value = 0.3; % 27.6;
                    app.MuStdSpinner.Value = 0.1; % 9.2;
                    app.CustomScenerio = false;
                case "DP"
                    app.RepoductionNumberR0Spinner.Value= 2.72;
                    app.R0StdSpinner.Value = 0.665;
                    app.InfectionRecoveryRateMuSpinner.Value = 0.3; % 3.6;
                    app.MuStdSpinner.Value = 0.1; % 1.2;
                    app.CustomScenerio = false;
                otherwise
                    app.RepoductionNumberR0Spinner.Value= 0;
                    app.R0StdSpinner.Value = 0;
                    app.InfectionRecoveryRateMuSpinner.Value = 0;
                    app.MuStdSpinner.Value = 0;
                    app.CustomScenerio = true;
            end % switch value   


            if app.HARAM_ran
                app.InputsChngd = true;
                ChangedData(app)
            end % if app.HARAM_ran
        end

        % Value changed function: BaselineMitSpinner, EpsilonKSpinner, 
        % ...and 4 other components
        function BaselineMitSpinnerValueChanged(app, event)
            if app.HARAM_ran
                app.InputsChngd = true;
                ChangedData(app)
            end % if app.HARAM_ran
        end

        % Value changed function: IterationsSpinner
        function IterationsSpinnerValueChanged(app, event)
            % Check N Value box and if it is greater than 1 but below the
            % set Sigulatory Limit (In Properties) then set N to 1 (i.e.
            % does not do uncertainty quantification
            value = app.IterationsSpinner.Value;
            if value >= 1 && value < app.UQ_SingularityLimit
                app.IterationsSpinner.Value = 1;
                app.R0StdSpinner.Enable = false;
                app.MuStdSpinner.Enable = false;
                app.UQ_bool = false;
            elseif value >= app.UQ_SingularityLimit
                app.R0StdSpinner.Enable = true;
                app.MuStdSpinner.Enable = true;
                app.UQ_bool = true;
            end % if value >= 1 ...

            if app.HARAM_ran
                app.InputsChngd = true;
                ChangedData(app)
            end % if app.HARAM_ran
        end

        % Button pushed function: AddRowButton
        function AddRowButtonPushed(app, event)
            % Adds a Blank Row the the Mitigation Table
            app.MitigationTable.Data = [app.MitigationTable.Data; NaN];

            % Enables the remove row button
            app.RemoveRowButton.Enable = true;

            if app.HARAM_ran
                app.InputsChngd = true;
                ChangedData(app)
            end % if app.HARAM_ran
        end

        % Button pushed function: RemoveRowButton
        function RemoveRowButtonPushed(app, event)
            % Removes Row from Table
            app.MitigationTable.Data = app.MitigationTable.Data(1:end-1);

            % If there is only one row remaining, disable remove row button
            if height(app.MitigationTable.Data)==1
                app.RemoveRowButton.Enable = false;
            end % if height...

            if app.HARAM_ran
                app.InputsChngd = true;
                ChangedData(app)
            end % if app.HARAM_ran
        end

        % Cell edit callback: MitigationTable
        function MitigationTableCellEdit(app, event)
            indices = event.Indices;
            newData = event.NewData;
            Lidx = sub2ind(size(app.MitigationTable.Data),indices(1),indices(2));
            % Set Entered Mitigation to be a Percentages between 0 and 1 if
            % data entered was outside of that range
            if newData > 1
                app.MitigationTable.Data(Lidx)=1;
            elseif newData < 0
                app.MitigationTable.Data(Lidx)=0;
            else % if input is not a number, Table will auto set it to NaN
                app.MitigationTable.Data(Lidx)=real(newData);
            end % if newData > 1

            if app.HARAM_ran
                app.InputsChngd = true;
                ChangedData(app)
            end % if app.HARAM_ran
        end

        % Selection changed function: BoundsPlotOptionsButtonGroup
        function BoundsPlotOptionsButtonGroupSelectionChanged(app, event)
            selectedButton = app.BoundsPlotOptionsButtonGroup.SelectedObject;
            
            %Change Slider Based on Bound Plot Option Selected
            switch selectedButton.Text
                case "Wedge"
                    % Sets Slider to be a range of 0 to 100 when Wedge is
                    % selected, updates labels, and ticks.
                    app.ULbSlider.Enable = true;
                    app.ULbSlider.MajorTicksMode = 'auto';
                    %app.ULbSlider.MinorTicksMode = 'auto';
                    if app.ULbSlider.Value > 100
                        app.ULbSlider.Value = 100;
                    end % if app.ULbSlider.Value > 100
                    app.ULbSlider.Limits = [0,100];
                    app.ULbSliderLabel.Text = "% Transparency";
                    app.ULbSlider.Tooltip = "Adjust the transparency of the wedge plot";

                    if ~app.HARAM_ran
                        return
                        % Stop App from updating plot if model wasn't run
                    end % if ~app.HARAM_ran
                    
                    % Plots Wedge Bound Plot
                    DataHandles = app.HARAM_PlotData.DataHandles;
                    app.PlotWedge(DataHandles,app.ULbSlider.Value)

                case "Error Bars"
                    % If model has not run, sets the slider limit to be 2
                    % else it sets the upper slider limit to the number of
                    % datapoint between day 0 and when mitigation measure
                    % starts
                    app.ULbSlider.Enable = true;
                    if ~app.HARAM_ran
                        UpperSliderLimit = 2;
                    else
                        UpperSliderLimit =  height(app.HARAM_out.(app.PlotTabGroup.SelectedTab.Tag));
                    end % if ~app.HARAM_ran
                    
                    if app.ULbSlider.Value > UpperSliderLimit
                        app.ULbSlider.Value = UpperSliderLimit;
                    elseif app.ULbSlider.Value == 0
                        app.ULbSlider.Value = 1;
                    end % if app.ULbSlider.Value ...

                    % Set Slider Limit from 1 to the Upper Limit Calculated
                    % Above 
                    app.ULbSlider.Limits = [1,UpperSliderLimit];
                    app.ULbSliderLabel.Text = "# of Error Bars";
                    app.ULbSlider.Tooltip = "Change the number of error bars visable";
                    
                    app.ULbSlider.MajorTicksMode = 'manual';
                    app.ULbSlider.MajorTicks = floor(linspace(1,UpperSliderLimit,11));

                    if ~app.HARAM_ran
                        return
                        % Stop App from updating plot if model wasn't run
                    end % if ~app.HARAM_ran

                    % Plots Error Bar Plot
                    DataHandles = app.HARAM_PlotData.DataHandles;
                    app.PlotEB(DataHandles,app.ULbSlider.Value)

                otherwise
                    % Option is set to None, Removes Slider Label as well 
                    % as disabling the slider.
                    app.ULbSlider.Enable = false;
                    app.ULbSliderLabel.Text = "";
                    app.ULbSlider.Tooltip = "Show either a wedge plot or error bars to enable the slider";
                    
                    if ~app.HARAM_ran
                        return
                        % Stop App from updating plot if model wasn't run
                    end % if ~app.HARAM_ran

                    % Removes the Bound Plots
                    DataHandles = app.HARAM_PlotData.DataHandles;
                    for idx = 1:height(DataHandles)
                        delete(app.HARAM_PlotData.(DataHandles.Handle(idx)).BoundsPlot)
                    end % for idx = 1:height(DataHandles)
            end % switch selectedButton.Text
        end

        % Value changing function: ULbSlider
        function ULbSliderValueChanging(app, event)
            changingValue = event.Value;
            selectedButton = app.BoundsPlotOptionsButtonGroup.SelectedObject;
            if ~app.HARAM_ran
                return
                % Stop App from updating plot if model wasn't run
            end % if ~app.HARAM_ran
            DataHandles = app.HARAM_PlotData.DataHandles;
            switch selectedButton.Text
                case "Wedge"
                    % If Current Bound plot is a wedge, slider changes the
                    % transparcy
                    for idx1 = 1:height(DataHandles)
                        app.HARAM_PlotData.(DataHandles.Handle(idx1)).BoundsPlot.FaceAlpha = changingValue/abs(diff(app.ULbSlider.Limits));
                    end % for idx1 ...
                case "Error Bars"
                    % If current Bound plot is error bars, slider changes
                    % the number of error bars, which requires reploting
                    % them
                    app.PlotEB(DataHandles,changingValue)
            end % switch selectedButton.Text
        end

        % Value changed function: ULbSlider
        function ULbSliderValueChanged(app, event)
            selectedButton = app.BoundsPlotOptionsButtonGroup.SelectedObject;
            % Sets final value of slider to be an integer if Error Bars is
            % current bound plot option
            if string(selectedButton.Text)=="Error Bars" 
                app.ULbSlider.Value = round(app.ULbSlider.Value);
            end % if string    
        end

        % Button pushed function: ExportDataButton
        function ExportDataButtonPushed(app, event)
            if app.InputsChngd
                selection = uiconfirm(app.HARAMUIFigure,["Data inputs have changed since model was run and do not match displayed output data";...
                    "Do you still want to export data?"],"HARAM App",'Options',["Yes","No"],"Icon","warning");
                if selection == "No"
                    return
                end % if selection == "No"

            end
            
            % Inializes Options and Opens a UIPUTFILE Dialog 
            expTypes = ["CSV","XLSX","MAT"];
            expDesc = ["Comma Seperated Values", "Excel Spreadsheet", "MATLAB Data"];
            filter = ["*."+lower(expTypes)',expDesc'];
            dFN = ["HARAM",app.ScenarioDropDown.Value,app.PPE_str_abv,string(datetime('now',"Format","MMddyyHHmmSS"))];
            dFN = strjoin(dFN,"_");
            StructOut = app.HARAM_out;
            [expFile,expPath,idx]=uiputfile(filter,"Export Data",dFN);
            % Switches Export format based on Index of the filter
            switch idx
                case 1 % CSV
                    % Exports a CSV file for every variable in HARAM_out
                    StructOut.SigCount = table((1:numel(StructOut.SigCount))',StructOut.SigCount',...
                        'VariableNames',["UQ_Run#","Singularity Reached"]);
                    FldNs = fieldnames(StructOut);
                    for FldN = FldNs'
                        NexpFile = strrep(expFile,'.csv',strcat('_',FldN{:},'.csv'));
                        writetable(StructOut.(FldN{:}),fullfile(expPath,NexpFile))
                    end % for FldN = FldNs'
                    expMsg = "Successfully Exported Data to "+string(numel(FldNs))+" CSV Files";
                case 2 % XLSX
                    % Exports an Excel Spreadsheet with a sheet for each
                    % variable in HARAM_out
                    StructOut.SigCount = table((1:numel(StructOut.SigCount))',StructOut.SigCount',...
                        'VariableNames',["UQ_Run#","Singularity Reached"]);
                    FldNs = fieldnames(StructOut);
                    for FldN = FldNs'
                        writetable(StructOut.(FldN{:}),fullfile(expPath,expFile),'Sheet',FldN{:})
                    end % for FldN = FldNs'
                    expMsg = "Successfully Exported Data to XLSX File";
                case 3 % MAT
                    % Save a MAT File containing the variables in HARAM_out
                    StructOut.Inputs=table2struct(StructOut.Inputs,"ToScalar",true);
                    save(fullfile(expPath,expFile),"-struct","StructOut")
                    expMsg = "Successfully Exported Data to MAT File";
                otherwise
                    % Exits Dialog with no export if canceled
                    return
            end % switch idx
            app.ExportedData = true; % Set Exported Data Flag to True
            uialert(app.HARAMUIFigure,expMsg,"HARAM App","Icon","success","CloseFcn",@(~,~)uiresume(app.HARAMUIFigure));
            uiwait(app.HARAMUIFigure)
        end

        % Close request function: HARAMUIFigure
        function HARAMUIFigureCloseRequest(app, event)
            % Adds unexported data warning to UIALERT if data was not
            % exported and model was run
            if ~app.HARAM_ran || app.ExportedData 
                promptSuffix = "";
                icon = "question";
            else
                promptSuffix = "Any Unexported Data Will Be Lost";
                icon = "warning";
            end % if ~app.HARAM_ran || app.ExportedData 

            selection = uiconfirm(app.HARAMUIFigure,["Close HARAM App?";promptSuffix],"HARAM App",'Options',["Yes","No"],"Icon",icon);
            if selection == "Yes"
                % Closes HARAM App
                delete(app)
            else
                return
            end % if selection == "Yes"
        end

        % Window key press function: HARAMUIFigure
        function HARAMUIFigureWindowKeyPress(app, event)
            if isequal(event.Modifier, "control")
                switch event.Key
                    case 'b'
                        app.StrategiesTabs.SelectedTab = app.StrategiesTabs.Children(1);
                    case 'm'
                        app.StrategiesTabs.SelectedTab = app.StrategiesTabs.Children(2);
                    case 't'
                        app.PlotTabGroup.SelectedTab = app.PlotTabGroup.Children(1);
                    case 'i'
                        app.PlotTabGroup.SelectedTab = app.PlotTabGroup.Children(2);
                    case 'd'
                        app.PlotTabGroup.SelectedTab = app.PlotTabGroup.Children(3);
                    case 's'
                        if ~app.ExportDataButton.Enable
                            % Cancels Keyboard Command if Export button is
                            % not enabled
                            return
                        end
                        ExportDataButtonPushed(app,event)
                    otherwise
                        return
                end % switch event.Key
            elseif isequal(event.Key, 'f5')
                RunScenarioButtonPushed(app, event)
            end % if isequal(event.Modifier, "control")

        end

        % Button pushed function: SortButton
        function SortButtonPushed(app, event)
            app.MitigationTable.Data = sort(app.MitigationTable.Data);
        end

        % Changes arrangement of the app based on UIFigure width
        function updateAppLayout(app, event)
            currentFigureWidth = app.HARAMUIFigure.Position(3);
            if(currentFigureWidth <= app.onePanelWidth)
                % Change to a 2x1 grid
                app.GridLayout.RowHeight = {517, 517};
                app.GridLayout.ColumnWidth = {'1x'};
                app.Outputs.Layout.Row = 2;
                app.Outputs.Layout.Column = 1;
            else
                % Change to a 1x2 grid
                app.GridLayout.RowHeight = {'1x'};
                app.GridLayout.ColumnWidth = {340, '1x'};
                app.Outputs.Layout.Row = 1;
                app.Outputs.Layout.Column = 2;
            end
        end
    end

    % Component initialization
    methods (Access = private)

        % Create UIFigure and components
        function createComponents(app)

            % Create HARAMUIFigure and hide until all components are created
            app.HARAMUIFigure = uifigure('Visible', 'off');
            app.HARAMUIFigure.AutoResizeChildren = 'off';
            app.HARAMUIFigure.Position = [100 100 810 517];
            app.HARAMUIFigure.Name = 'HARAM';
            app.HARAMUIFigure.CloseRequestFcn = createCallbackFcn(app, @HARAMUIFigureCloseRequest, true);
            app.HARAMUIFigure.SizeChangedFcn = createCallbackFcn(app, @updateAppLayout, true);
            app.HARAMUIFigure.WindowKeyPressFcn = createCallbackFcn(app, @HARAMUIFigureWindowKeyPress, true);

            % Create GridLayout
            app.GridLayout = uigridlayout(app.HARAMUIFigure);
            app.GridLayout.ColumnWidth = {340, '1x'};
            app.GridLayout.RowHeight = {'1x'};
            app.GridLayout.ColumnSpacing = 0;
            app.GridLayout.RowSpacing = 0;
            app.GridLayout.Padding = [0 0 0 0];
            app.GridLayout.Scrollable = 'on';

            % Create Inputs
            app.Inputs = uipanel(app.GridLayout);
            app.Inputs.Layout.Row = 1;
            app.Inputs.Layout.Column = 1;

            % Create InputsGrid
            app.InputsGrid = uigridlayout(app.Inputs);
            app.InputsGrid.ColumnWidth = {'1x'};
            app.InputsGrid.RowHeight = {'0.75x', '1x', '1.4x'};
            app.InputsGrid.RowSpacing = 8.5;
            app.InputsGrid.Padding = [4.5 8.5 4.5 8.5];

            % Create Scenario
            app.Scenario = uipanel(app.InputsGrid);
            app.Scenario.Title = 'Scenerio';
            app.Scenario.Layout.Row = 1;
            app.Scenario.Layout.Column = 1;

            % Create ScenarioGrid
            app.ScenarioGrid = uigridlayout(app.Scenario);
            app.ScenarioGrid.ColumnWidth = {78, '1x', '3.27x'};
            app.ScenarioGrid.ColumnSpacing = 5.5;
            app.ScenarioGrid.Padding = [5.5 10 5.5 10];

            % Create ScenarioLabel
            app.ScenarioLabel = uilabel(app.ScenarioGrid);
            app.ScenarioLabel.HorizontalAlignment = 'right';
            app.ScenarioLabel.Layout.Row = 1;
            app.ScenarioLabel.Layout.Column = 1;
            app.ScenarioLabel.Text = 'Scenario ';

            % Create InterventionStrategyLabel
            app.InterventionStrategyLabel = uilabel(app.ScenarioGrid);
            app.InterventionStrategyLabel.HorizontalAlignment = 'right';
            app.InterventionStrategyLabel.WordWrap = 'on';
            app.InterventionStrategyLabel.Layout.Row = 2;
            app.InterventionStrategyLabel.Layout.Column = 1;
            app.InterventionStrategyLabel.Text = 'Intervention Strategy ';

            % Create ScenarioDropDown
            app.ScenarioDropDown = uidropdown(app.ScenarioGrid);
            app.ScenarioDropDown.Items = {'New York City, New York', 'New York State', 'Harris County, Texas', 'Diamond Princess Cruise'};
            app.ScenarioDropDown.ItemsData = {'NYC', 'NYState', 'HC', 'DP'};
            app.ScenarioDropDown.ValueChangedFcn = createCallbackFcn(app, @ScenarioDropDownValueChanged, true);
            app.ScenarioDropDown.Tooltip = {'Select which scenario to run the model'};
            app.ScenarioDropDown.Layout.Row = 1;
            app.ScenarioDropDown.Layout.Column = [2 3];
            app.ScenarioDropDown.Value = 'NYC';

            % Create InterventionStrategyDropDown
            app.InterventionStrategyDropDown = uidropdown(app.ScenarioGrid);
            app.InterventionStrategyDropDown.Items = {'None', 'Mask Filtration Efficiency (FE)', 'Mask Compliance (MC)', 'Social Distancing (SD)'};
            app.InterventionStrategyDropDown.ItemsData = {'None', 'Mask FE', 'Mask Compliance', 'Social Distancing'};
            app.InterventionStrategyDropDown.ValueChangedFcn = createCallbackFcn(app, @InterventionStrategyDropDownValueChanged, true);
            app.InterventionStrategyDropDown.Tooltip = {'Select the intervention strategy for the model'};
            app.InterventionStrategyDropDown.Layout.Row = 2;
            app.InterventionStrategyDropDown.Layout.Column = [2 3];
            app.InterventionStrategyDropDown.Value = 'None';

            % Create InfectionCharacteristicsPanel
            app.InfectionCharacteristicsPanel = uipanel(app.InputsGrid);
            app.InfectionCharacteristicsPanel.Title = 'Infection Characteristics';
            app.InfectionCharacteristicsPanel.Layout.Row = 2;
            app.InfectionCharacteristicsPanel.Layout.Column = 1;

            % Create ICGrid
            app.ICGrid = uigridlayout(app.InfectionCharacteristicsPanel);
            app.ICGrid.ColumnWidth = {'0.8x', '0.8x', '0.4x', '0.4x', '0.4x', '0.5x', '0.4x', '0.4x', '0.4x'};
            app.ICGrid.RowHeight = {'0.5x', '0.5x', '0.5x'};
            app.ICGrid.ColumnSpacing = 6.5;
            app.ICGrid.Padding = [6.5 10 6.5 10];

            % Create RepoductionNumberR0SpinnerLabel
            app.RepoductionNumberR0SpinnerLabel = uilabel(app.ICGrid);
            app.RepoductionNumberR0SpinnerLabel.HorizontalAlignment = 'center';
            app.RepoductionNumberR0SpinnerLabel.WordWrap = 'on';
            app.RepoductionNumberR0SpinnerLabel.Layout.Row = 1;
            app.RepoductionNumberR0SpinnerLabel.Layout.Column = [1 2];
            app.RepoductionNumberR0SpinnerLabel.Text = 'Repoduction Number (R0)';

            % Create RepoductionNumberR0Spinner
            app.RepoductionNumberR0Spinner = uispinner(app.ICGrid);
            app.RepoductionNumberR0Spinner.Limits = [0 Inf];
            app.RepoductionNumberR0Spinner.ValueChangedFcn = createCallbackFcn(app, @BaselineMitSpinnerValueChanged, true);
            app.RepoductionNumberR0Spinner.Tooltip = {'Reproduction Number of the Infection'};
            app.RepoductionNumberR0Spinner.Layout.Row = 1;
            app.RepoductionNumberR0Spinner.Layout.Column = [3 5];

            % Create R0StdSpinner
            app.R0StdSpinner = uispinner(app.ICGrid);
            app.R0StdSpinner.Limits = [0 Inf];
            app.R0StdSpinner.ValueChangedFcn = createCallbackFcn(app, @BaselineMitSpinnerValueChanged, true);
            app.R0StdSpinner.Tooltip = {'Standard deviation of R0, the infection repoduction number.'};
            app.R0StdSpinner.Layout.Row = 1;
            app.R0StdSpinner.Layout.Column = [7 9];

            % Create InfectionRecoveryRateMuSpinner
            app.InfectionRecoveryRateMuSpinner = uispinner(app.ICGrid);
            app.InfectionRecoveryRateMuSpinner.Limits = [0 Inf];
            app.InfectionRecoveryRateMuSpinner.ValueChangedFcn = createCallbackFcn(app, @BaselineMitSpinnerValueChanged, true);
            app.InfectionRecoveryRateMuSpinner.Tooltip = {'Infection recovery rate'};
            app.InfectionRecoveryRateMuSpinner.Layout.Row = 2;
            app.InfectionRecoveryRateMuSpinner.Layout.Column = [3 5];

            % Create MuStdSpinner
            app.MuStdSpinner = uispinner(app.ICGrid);
            app.MuStdSpinner.Limits = [0 Inf];
            app.MuStdSpinner.ValueChangedFcn = createCallbackFcn(app, @BaselineMitSpinnerValueChanged, true);
            app.MuStdSpinner.Tooltip = {'Standard deviation of Mu, the infection recovery rate.'};
            app.MuStdSpinner.Layout.Row = 2;
            app.MuStdSpinner.Layout.Column = [7 9];

            % Create IterationsSpinner
            app.IterationsSpinner = uispinner(app.ICGrid);
            app.IterationsSpinner.Limits = [1 10000];
            app.IterationsSpinner.RoundFractionalValues = 'on';
            app.IterationsSpinner.ValueDisplayFormat = '%.0f';
            app.IterationsSpinner.ValueChangedFcn = createCallbackFcn(app, @IterationsSpinnerValueChanged, true);
            app.IterationsSpinner.Tooltip = {'Number of uncertainy samples to perform. Must be greater than 200. Change to 1 if no uncertany analysis is desired.'};
            app.IterationsSpinner.Layout.Row = 3;
            app.IterationsSpinner.Layout.Column = [4 7];
            app.IterationsSpinner.Value = 500;

            % Create MuLabel
            app.MuLabel = uilabel(app.ICGrid);
            app.MuLabel.HorizontalAlignment = 'center';
            app.MuLabel.WordWrap = 'on';
            app.MuLabel.Layout.Row = 2;
            app.MuLabel.Layout.Column = [1 2];
            app.MuLabel.Text = 'Infection Recovery Rate (Mu)';

            % Create GammaStdSpinnerLabel
            app.GammaStdSpinnerLabel = uilabel(app.ICGrid);
            app.GammaStdSpinnerLabel.HorizontalAlignment = 'right';
            app.GammaStdSpinnerLabel.WordWrap = 'on';
            app.GammaStdSpinnerLabel.Layout.Row = 2;
            app.GammaStdSpinnerLabel.Layout.Column = 6;
            app.GammaStdSpinnerLabel.Text = 'Std. Dev.';

            % Create R0StdSpinnerLabel
            app.R0StdSpinnerLabel = uilabel(app.ICGrid);
            app.R0StdSpinnerLabel.HorizontalAlignment = 'right';
            app.R0StdSpinnerLabel.WordWrap = 'on';
            app.R0StdSpinnerLabel.Layout.Row = 1;
            app.R0StdSpinnerLabel.Layout.Column = 6;
            app.R0StdSpinnerLabel.Text = 'Std. Dev.';

            % Create IterationsSpinnerLabel
            app.IterationsSpinnerLabel = uilabel(app.ICGrid);
            app.IterationsSpinnerLabel.HorizontalAlignment = 'right';
            app.IterationsSpinnerLabel.Layout.Row = 3;
            app.IterationsSpinnerLabel.Layout.Column = [2 3];
            app.IterationsSpinnerLabel.Text = 'Iterations';

            % Create StrategiesTabs
            app.StrategiesTabs = uitabgroup(app.InputsGrid);
            app.StrategiesTabs.Layout.Row = 3;
            app.StrategiesTabs.Layout.Column = 1;

            % Create BaselineTab
            app.BaselineTab = uitab(app.StrategiesTabs);
            app.BaselineTab.Tooltip = {'Show the baseline model inputs for the model. (Ctrl+B)'};
            app.BaselineTab.Title = 'Baseline';

            % Create BaselineGrid
            app.BaselineGrid = uigridlayout(app.BaselineTab);
            app.BaselineGrid.ColumnWidth = {'0.5x', '2.5x', '2.5x', '0.5x'};
            app.BaselineGrid.RowHeight = {'1x', '2x', '1x', '2x', '1x'};

            % Create BaselineMitSpinnerLabel
            app.BaselineMitSpinnerLabel = uilabel(app.BaselineGrid);
            app.BaselineMitSpinnerLabel.HorizontalAlignment = 'right';
            app.BaselineMitSpinnerLabel.WordWrap = 'on';
            app.BaselineMitSpinnerLabel.Layout.Row = 2;
            app.BaselineMitSpinnerLabel.Layout.Column = 2;
            app.BaselineMitSpinnerLabel.Text = 'Baseline Filtration Efficiency (FE)';

            % Create EpsilonKSpinnerLabel
            app.EpsilonKSpinnerLabel = uilabel(app.BaselineGrid);
            app.EpsilonKSpinnerLabel.HorizontalAlignment = 'right';
            app.EpsilonKSpinnerLabel.Layout.Row = 4;
            app.EpsilonKSpinnerLabel.Layout.Column = 2;
            app.EpsilonKSpinnerLabel.Text = 'Epsilon K';

            % Create BaselineMitSpinner
            app.BaselineMitSpinner = uispinner(app.BaselineGrid);
            app.BaselineMitSpinner.Step = 0.05;
            app.BaselineMitSpinner.Limits = [0 1];
            app.BaselineMitSpinner.ValueChangedFcn = createCallbackFcn(app, @BaselineMitSpinnerValueChanged, true);
            app.BaselineMitSpinner.Tooltip = {'Baseline filtration efficiency for the mask used in the intervention strategies. Not used for Social Distancing.'};
            app.BaselineMitSpinner.Layout.Row = 2;
            app.BaselineMitSpinner.Layout.Column = 3;
            app.BaselineMitSpinner.Value = 0.67;

            % Create EpsilonKSpinner
            app.EpsilonKSpinner = uispinner(app.BaselineGrid);
            app.EpsilonKSpinner.Step = 0.05;
            app.EpsilonKSpinner.Limits = [0 1];
            app.EpsilonKSpinner.ValueChangedFcn = createCallbackFcn(app, @BaselineMitSpinnerValueChanged, true);
            app.EpsilonKSpinner.Tooltip = {'Fraction of variation in spread function due to reduction in droplet production resulting from the use of masks. Not used for Social Distancing.'};
            app.EpsilonKSpinner.Layout.Row = 4;
            app.EpsilonKSpinner.Layout.Column = 3;
            app.EpsilonKSpinner.Value = 0.2;

            % Create MitigationTab
            app.MitigationTab = uitab(app.StrategiesTabs);
            app.MitigationTab.Tooltip = {'Show the mitigation inputs for the model. (Ctrl+M)'};
            app.MitigationTab.Title = 'Mitigation';

            % Create MitigationGrid
            app.MitigationGrid = uigridlayout(app.MitigationTab);
            app.MitigationGrid.ColumnWidth = {'4x', '1x'};
            app.MitigationGrid.RowHeight = {'0.5x', '1.5x', '1x', '1.5x', '0.5x'};
            app.MitigationGrid.ColumnSpacing = 15;

            % Create MitigationTable
            app.MitigationTable = uitable(app.MitigationGrid);
            app.MitigationTable.ColumnName = {'Filtration Efficiency [%]'};
            app.MitigationTable.ColumnSortable = true;
            app.MitigationTable.ColumnEditable = true;
            app.MitigationTable.CellEditCallback = createCallbackFcn(app, @MitigationTableCellEdit, true);
            app.MitigationTable.Tooltip = {'Table of mitigation values to evaluation compared to the baseline.'};
            app.MitigationTable.Layout.Row = [1 5];
            app.MitigationTable.Layout.Column = 1;

            % Create AddRowButton
            app.AddRowButton = uibutton(app.MitigationGrid, 'push');
            app.AddRowButton.ButtonPushedFcn = createCallbackFcn(app, @AddRowButtonPushed, true);
            app.AddRowButton.FontSize = 20;
            app.AddRowButton.FontWeight = 'bold';
            app.AddRowButton.Tooltip = {'add a mitigation value to the mitigation table'};
            app.AddRowButton.Layout.Row = 2;
            app.AddRowButton.Layout.Column = 2;
            app.AddRowButton.Text = '+';

            % Create SortButton
            app.SortButton = uibutton(app.MitigationGrid, 'push');
            app.SortButton.ButtonPushedFcn = createCallbackFcn(app, @SortButtonPushed, true);
            app.SortButton.Tooltip = {'sort the data in the mitigation table in asscending order'};
            app.SortButton.Layout.Row = 3;
            app.SortButton.Layout.Column = 2;
            app.SortButton.Text = 'Sort';

            % Create RemoveRowButton
            app.RemoveRowButton = uibutton(app.MitigationGrid, 'push');
            app.RemoveRowButton.ButtonPushedFcn = createCallbackFcn(app, @RemoveRowButtonPushed, true);
            app.RemoveRowButton.FontSize = 20;
            app.RemoveRowButton.FontWeight = 'bold';
            app.RemoveRowButton.Tooltip = {'remove the last mitigation value from the mitigation table'};
            app.RemoveRowButton.Layout.Row = 4;
            app.RemoveRowButton.Layout.Column = 2;
            app.RemoveRowButton.Text = '-';

            % Create Outputs
            app.Outputs = uipanel(app.GridLayout);
            app.Outputs.Layout.Row = 1;
            app.Outputs.Layout.Column = 2;

            % Create OutputGrid
            app.OutputGrid = uigridlayout(app.Outputs);
            app.OutputGrid.ColumnWidth = {'100x', '100x'};
            app.OutputGrid.RowHeight = {'8.45x', '2.85x', '1x', 22};

            % Create PlotTabGroup
            app.PlotTabGroup = uitabgroup(app.OutputGrid);
            app.PlotTabGroup.Layout.Row = 1;
            app.PlotTabGroup.Layout.Column = [1 2];

            % Create NewCasesTab
            app.NewCasesTab = uitab(app.PlotTabGroup);
            app.NewCasesTab.Tooltip = {'Show the new cases plot. Variable: T. (Ctrl+T)'};
            app.NewCasesTab.Title = 'New Cases';
            app.NewCasesTab.Tag = 'T';

            % Create NewCasesGrid
            app.NewCasesGrid = uigridlayout(app.NewCasesTab);
            app.NewCasesGrid.ColumnWidth = {'2.5x'};
            app.NewCasesGrid.RowHeight = {'9.5x'};

            % Create TAxes
            app.TAxes = uiaxes(app.NewCasesGrid);
            app.TAxes.Layout.Row = 1;
            app.TAxes.Layout.Column = 1;
            app.TAxes.Tag = 'TAxes';

            % Create ActiveCasesTab
            app.ActiveCasesTab = uitab(app.PlotTabGroup);
            app.ActiveCasesTab.Tooltip = {'Show the active cases plot. Variable: I.(Ctrl+I)'};
            app.ActiveCasesTab.Title = 'Active Cases';
            app.ActiveCasesTab.Tag = 'I';

            % Create ActiveCaseGrid
            app.ActiveCaseGrid = uigridlayout(app.ActiveCasesTab);
            app.ActiveCaseGrid.ColumnWidth = {'2.5x'};
            app.ActiveCaseGrid.RowHeight = {'9.5x'};

            % Create IAxes
            app.IAxes = uiaxes(app.ActiveCaseGrid);
            app.IAxes.Layout.Row = 1;
            app.IAxes.Layout.Column = 1;
            app.IAxes.Tag = 'IAxes';

            % Create SpreadTab
            app.SpreadTab = uitab(app.PlotTabGroup);
            app.SpreadTab.Tooltip = {'Show the normalized spread function plot. Variable: delta.(Ctrl+D)'};
            app.SpreadTab.Title = 'Normalized Spread Function';
            app.SpreadTab.Tag = 'delta';

            % Create SpreadGrid
            app.SpreadGrid = uigridlayout(app.SpreadTab);
            app.SpreadGrid.ColumnWidth = {'2.5x'};
            app.SpreadGrid.RowHeight = {'9.5x'};

            % Create deltaAxes
            app.deltaAxes = uiaxes(app.SpreadGrid);
            app.deltaAxes.Layout.Row = 1;
            app.deltaAxes.Layout.Column = 1;
            app.deltaAxes.Tag = 'SpreadAxes';

            % Create BoundsPlotOptionsButtonGroup
            app.BoundsPlotOptionsButtonGroup = uibuttongroup(app.OutputGrid);
            app.BoundsPlotOptionsButtonGroup.SelectionChangedFcn = createCallbackFcn(app, @BoundsPlotOptionsButtonGroupSelectionChanged, true);
            app.BoundsPlotOptionsButtonGroup.Title = 'Bounds Plot Options';
            app.BoundsPlotOptionsButtonGroup.Layout.Row = [2 3];
            app.BoundsPlotOptionsButtonGroup.Layout.Column = 1;

            % Create WedgeButton
            app.WedgeButton = uiradiobutton(app.BoundsPlotOptionsButtonGroup);
            app.WedgeButton.Tooltip = {'Show wedge bound plot for the analyzed mitigation strategies'};
            app.WedgeButton.Text = 'Wedge';
            app.WedgeButton.Position = [11 82 60 22];
            app.WedgeButton.Value = true;

            % Create ErrorBarsButton
            app.ErrorBarsButton = uiradiobutton(app.BoundsPlotOptionsButtonGroup);
            app.ErrorBarsButton.Tooltip = {'Show error bars highlighting the upper and lower bounds for the analyzed mitigation strategies'};
            app.ErrorBarsButton.Text = 'Error Bars';
            app.ErrorBarsButton.Position = [11 60 77 22];

            % Create NoneButton
            app.NoneButton = uiradiobutton(app.BoundsPlotOptionsButtonGroup);
            app.NoneButton.Tooltip = {'Hide the bound plot from the analyzed mitigation strategies'};
            app.NoneButton.Text = 'None';
            app.NoneButton.Position = [11 38 65 22];

            % Create ULbSlider
            app.ULbSlider = uislider(app.OutputGrid);
            app.ULbSlider.ValueChangedFcn = createCallbackFcn(app, @ULbSliderValueChanged, true);
            app.ULbSlider.ValueChangingFcn = createCallbackFcn(app, @ULbSliderValueChanging, true);
            app.ULbSlider.Layout.Row = 2;
            app.ULbSlider.Layout.Column = 2;
            app.ULbSlider.Value = 5;

            % Create ExportDataButton
            app.ExportDataButton = uibutton(app.OutputGrid, 'push');
            app.ExportDataButton.ButtonPushedFcn = createCallbackFcn(app, @ExportDataButtonPushed, true);
            app.ExportDataButton.Tooltip = {'Export the analyzed data as either a text, CSV or Excel file.'};
            app.ExportDataButton.Layout.Row = 4;
            app.ExportDataButton.Layout.Column = 1;
            app.ExportDataButton.Text = 'Export Data';

            % Create RunScenerioButton
            app.RunScenerioButton = uibutton(app.OutputGrid, 'push');
            app.RunScenerioButton.ButtonPushedFcn = createCallbackFcn(app, @RunScenarioButtonPushed, true);
            app.RunScenerioButton.Interruptible = 'off';
            app.RunScenerioButton.FontWeight = 'bold';
            app.RunScenerioButton.Tooltip = {'Run the model with the provided inputs (F5).'};
            app.RunScenerioButton.Layout.Row = 4;
            app.RunScenerioButton.Layout.Column = 2;
            app.RunScenerioButton.Text = 'Run Scenerio';

            % Create ULbSliderLabel
            app.ULbSliderLabel = uilabel(app.OutputGrid);
            app.ULbSliderLabel.HorizontalAlignment = 'center';
            app.ULbSliderLabel.VerticalAlignment = 'top';
            app.ULbSliderLabel.WordWrap = 'on';
            app.ULbSliderLabel.Layout.Row = 3;
            app.ULbSliderLabel.Layout.Column = 2;
            app.ULbSliderLabel.Text = '# of Error Bars';

            % Show the figure after all components are created
            app.HARAMUIFigure.Visible = 'on';
        end
    end

    % App creation and deletion
    methods (Access = public)

        % Construct app
        function app = HARAM_App_Published_exported

            % Create UIFigure and components
            createComponents(app)

            % Register the app with App Designer
            registerApp(app, app.HARAMUIFigure)

            % Execute the startup function
            runStartupFcn(app, @startupFcn)

            if nargout == 0
                clear app
            end
        end

        % Code that executes before app deletion
        function delete(app)

            % Delete UIFigure when app is deleted
            delete(app.HARAMUIFigure)
        end
    end
end