function [Final_vars,counter] = HARAM(LOC,PPE,UQ,PB)

%% HIGHLY ADAPTIVE RISK ASSESSMENT MODEL [HARAM]
% Version 1.3 - 10/30/2023. Brief description: This model is
% used to conduct a retrospective risk analysis of different PPE strategies
% on infection dynamics of a specific location.

%% INITIALIZING MODEL

filename = string(LOC.str)+"_data";  % Sets the data file name

% Loading real-world/raw time series data
load(filename,"-mat","Delta","M","Tact","alpha","tact");
% Loads the input dataset for a specific scenario. Dataset includes:
% alpha (peak infection), Delta (peak infeciton time - initial infection
% time), M (exponential growth rate upto lockdown), tact (dimensionless
% time series), Tact (dimensionless dS/dt)

MitData = PPE.PPE_data;
nMit = numel(MitData);
Ns = UQ.N;

if PPE.PPE_bool
    % assumes a "mitigation stratgy" in the input data, allows for a
    % proper comparison of a different (improved) mitigation strategy
    % mask compliance is derived from the FE

    FE = PPE.BL_FE;  % baseline filtration efficiency
    pf_source = 1/(1-FE);    % source protection factor
    T_source = 1/pf_source; % source transmission factor
    epsk = PPE.BL_epsk;   % amount of decrease in delta due to decrease in droplet production
end

for idx1 = 1:UQ.HardLimit
    if PB.CancelRequested
        error("HARAM:Canceled","HARAM Model Was Canceled")
    end

    if UQ.bool

        R0_gamma = LHS([UQ.R0,UQ.mu*Delta],[UQ.R0std,UQ.muStd*Delta],Ns,false);
        R0_uq = R0_gamma(:,1); 
        gamma_uq = R0_gamma(:,2);
    
        % This is the number of R0 and gamma samples used in the input parameter
        % UQ. This is also equal to the number of simulations the code needs to run
    else
        
        Ns = 1;
        % Sets the number of R0 and gamma samples to 1
        % R0 and Gamma (From Mu) Inputs
        R0_uq = UQ.R0; 
        gamma_uq = UQ.mu*Delta;
    end

    % Mesh size
    % This is used in case the number of raw t vs T data points are very small
    % (e.g., < 10)
 
    n=height(tact);
    dt=(tact(end)-tact(1))/(1*n-1);
    N=((tact(end)-tact(1))/dt)+1;

    % Initial conditions (Not UQ Dependant)
    t=(tact(1):dt:tact(end))';
    T0 = Tact(1);

    [OP_T,OP_I,OP_delta] =  deal(nan(N,Ns,nMit+1));
    % Preallocate OP arrays
    % D1: # of Input Samples (n or N)
    % D2: # Number of Non Singularity Outputs from UQ (count+count_op==Ns)
    % D3: # of Mitation Effectivnesss (e.g. 3 FEs testing + baseline)
    counter = false(1,Ns);

    for u = 1:Ns

        % Initial conditions (UQ Dependant)
        R0 = R0_uq(u); % Sets the R0 value of the u^th sample
        gamma = gamma_uq(u); % Sets the gamma value of the u^th sample

        % Computes the RHS of the condition to satisfy such that lambda is positive
        lambda = M*(M+gamma)/((R0*gamma)-gamma-M);
        I0 = -T0/(M+gamma);
        delta0 = R0*lambda*gamma;

        %% COMPUTING BASELINE INFECTION DYNAMICS USING MODEL ODEs FOR T , I, AND delta
        % In the code T is U in Paper 2
        if R0>(1+(M/gamma)) % Determines if a singularity will be reached

            % Step 1: Fit an nth order polynomial to the actual (real-world) T vs t
            pT = polyfit(tact,Tact,10);
            

            % Step 2: Compute baseline I by using baseline T in the ODE for I
            [tf,If] = ode45(@(t,y)fnI(t,y,pT,gamma),t,I0);   % If = fn(f, gamma)
            pI = polyfit(tf,If,10);
            % Fits an nth order polynomial to the baseline I vs t

            % Step 3: Compute baseline delta by using baseline T and I in the
            % ODE for delta
            [tdelta,delta] = ode45(@(t,y)fndelta1(t,y,pT,pI,lambda),t,delta0);  %delta = fn(f, gamma, M, R0)
            pD = polyfit(tdelta,delta,14); % Fits a nth order polynomial to the baseline delta vs t.

            % Step 4: Compute (final) baseline T using baseline I and baseline delta
            % in the ODE for T
            [~,Tf] = ode45(@(t,y)fnT(t,y,pI,pD,lambda),t,T0);  %Tf = fn(f, gamma, M, R0)

            % Outputting Baseline Data (in dimensional form)
            OP_T(:,u,1) = -Tf(:,1)*alpha;
            OP_I(:,u,1) = If(:,1)*alpha*Delta;
            OP_delta(:,u,1) = delta(:,1)/delta0;

            %% EVALUATING PPE STRATEGIES

            if PPE.PPE_bool && LOC.str~="HC"

                % Initlize Output
                [delta_new,T_new,I_new]=deal(zeros(N,nMit));


                % Effect of mask filtration efficiency (FE)
                switch PPE.str
                    case "Mask FE"

                        fi = (1-(delta/delta0).^epsk)/FE; % Computes baseline mask compliance at all time points

                        for idx=1:nMit
                            delta_new_temp = delta.*((1-(fi*MitData(idx)))./(1-(fi*FE))); % Computes new delta corresponding to new FE
                            delta_new(:,idx)=delta_new_temp(:,1);  % Stores values at all FEs (columnwise)
                            pD_new = polyfit(t,delta_new_temp,14); % Fits a 7th order polynomial to the new delta vs t

                            % Next 7 Lines are the same for every senerio
                            [~,ysol] = ode45(@(t,y)fnTI(t,y,pD_new,lambda,gamma),t,[T0 I0]); % Computes new T and I corresponding to the new delta (or FE)
                            T_new(:,idx) = ysol(:,1);  % Stores values at all FEs (columnwise)
                            I_new(:,idx) = ysol(:,2);  % Stores values at all FEs (columnwise)
                            clear ysol; clear pD_new; clear delta_new_temp;

                            % Outputting PPE Data (in dimensional form)
                            OP_T(:,u,idx+1) = -T_new(:,idx)*alpha;
                            OP_I(:,u,idx+1) = I_new(:,idx)*alpha*Delta;
                            OP_delta(:,u,idx+1) = delta_new(:,idx)/delta0;
                        end % for

                        % Effect of mask compliance
                    case "Mask Compliance"

                        fi = (1-(delta/delta0).^epsk)/FE; % Computes baseline mask compliance at all time points
                        xx=zeros(1,nMit);
                        for idx=1:nMit
                            xx(idx)=(MitData(idx)./fi(N,1))-1;  % Computes the desired variation between the baseline and new mask compliance values at peak infection
                            delta_new_temp = delta.*(((T_source*(xx(idx)+1)*fi)+1-(xx(idx)+1)*fi)./((T_source*fi)+1-fi)); % Computes new delta corresponding to new compliance
                            delta_new(:,idx)=delta_new_temp(:,1); % Stores values at all compliance values (columnwise)
                            pD_new = polyfit(t,delta_new_temp,14);  % Fits a 7th order polynomial to the new delta vs t

                            [~,ysol] = ode45(@(t,y)fnTI(t,y,pD_new,lambda,gamma),t,[T0 I0]); % Computes new T and I corresponding to the new delta (or compliance)
                            T_new(:,idx) = ysol(:,1);  % Stores values at all compliance values (columnwise)
                            I_new(:,idx) = ysol(:,2);  % Stores values at all compliance values (columnwise)
                            clear ysol; clear pD_new; clear delta_new_temp;

                            % Outputting PPE Data (in dimensional form)
                            OP_T(:,u,idx+1) = -T_new(:,idx)*alpha;
                            OP_I(:,u,idx+1) = I_new(:,idx)*alpha*Delta;
                            OP_delta(:,u,idx+1) = delta_new(:,idx)/delta0;
                        end % for

                        % Effect of social distancing
                    case "Social Distancing"

                        for idx=1:nMit
                            ysd = log(((1-MitData(idx))*delta(N))/delta0)/log(delta(N)/delta0);  % Solves for the power term at the final time point where delta_new/delta_old = 1-sd
                            delta_new_temp = delta0*(delta/delta0).^ysd;  % Computes new delta corresponding to new level of social distancing
                            delta_new(:,idx)=delta_new_temp(:,1); % Stores values at all social dist values (columnwise)
                            pD_new = polyfit(t,delta_new_temp,14); % Fits a 7th order polynomial to the new delta vs t

                            [~,ysol] = ode45(@(t,y)fnTI(t,y,pD_new,lambda,gamma),t,[T0 I0]); % Computes new T and I corresponding to the new delta (or soc dist)
                            T_new(:,idx) = ysol(:,1); % Stores values at all social dist values (columnwise)
                            I_new(:,idx) = ysol(:,2); % Stores values at all social dist values (columnwise)
                            clear ysol; clear pD_new; clear delta_new_temp; clear ysd;

                            % Outputting PPE Data (in dimensional form)
                            OP_T(:,u,idx+1) = -T_new(:,idx)*alpha;
                            OP_I(:,u,idx+1) = I_new(:,idx)*alpha*Delta;
                            OP_delta(:,u,idx+1) = delta_new(:,idx)/delta0;
                        end % for
                end % switch

            elseif PPE.PPE_bool && LOC.str=="HC"
                % HC SCENARIO
                n1 = 67;
                n2 = 93;
                % Nhc = (n2-n1)+1;
                deltahc = delta(n1:n2);
                delta0hc = delta(n1);
                thc = t(n1:n2);
                T0hc = Tact(n1);
                I0hc = If(n1);
                fi = (1-(delta/delta0).^epsk)/FE; % Computes baseline mask compliance at all time points
                fihc = fi(n1:n2);
                Deltahc = n2-n1;

                warning('off','MATLAB:polyfit:RepeatedPointsOrRescale')

                % Effect of mask filtration efficiency (FE)
                switch PPE.str
                    case "Mask FE"
                        delta_new=nan(N,nMit);
                        T_new=nan(N,nMit);
                        I_new=nan(N,nMit);
                        for idx=1:nMit
                            delta_new_temp = deltahc.*((1-(fihc*MitData(idx)))./(1-(fihc*FE))); % Computes new delta corresponding to new FE
                            delta_new(n1:n2,idx)=delta_new_temp(:,1);  % Stores values at all FEs (columnwise)
                            pD_new = polyfit(thc,delta_new_temp,14); % Fits a 7th order polynomial to the new delta vs t

                            [~,ysol] = ode45(@(thc,y)fnTI(thc,y,pD_new,lambda,gamma),thc,[T0hc I0hc]); % Computes new T and I corresponding to the new delta (or FE)
                            T_new(n1:n2,idx) = ysol(:,1);  % Stores values at all FEs (columnwise)
                            I_new(n1:n2,idx) = ysol(:,2);  % Stores values at all FEs (columnwise)
                            clear ysol; clear pD_new; clear delta_new_temp;

                            % Outputting PPE Data (in dimensional form)
                            OP_T(:,u,idx+1) = -T_new(:,idx)*alpha;
                            OP_I(:,u,idx+1) = I_new(:,idx)*alpha*Deltahc;
                            OP_delta(:,u,idx+1) = delta_new(:,idx)/delta0hc;
                        end

                        % Effect of mask compliance
                    case "Mask Compliance"
                        delta_new=nan(N,nMit);
                        T_new=nan(N,nMit);
                        I_new=nan(N,nMit);
                        xx=zeros(1,nMit);
                        for idx=1:nMit
                            xx(idx)=(MitData(idx)./fi(N,1))-1;  % Computes the desired variation between the baseline and new mask compliance values at peak infection
                            delta_new_temp = deltahc.*(((T_source*(xx(idx)+1)*fihc)+1-(xx(idx)+1)*fihc)./((T_source*fihc)+1-fihc)); % Computes new delta corresponding to new compliance
                            delta_new(n1:n2,idx)=delta_new_temp(:,1); % Stores values at all compliance values (columnwise)
                            pD_new = polyfit(thc,delta_new_temp,14);  % Fits a 7th order polynomial to the new delta vs t

                            [~,ysol] = ode45(@(thc,y)fnTI(thc,y,pD_new,lambda,gamma),thc,[T0hc I0hc]); % Computes new T and I corresponding to the new delta (or compliance)
                            T_new(n1:n2,idx) = ysol(:,1);  % Stores values at all compliance values (columnwise)
                            I_new(n1:n2,idx) = ysol(:,2);  % Stores values at all compliance values (columnwise)
                            clear ysol; clear pD_new; clear delta_new_temp;

                            % Outputting PPE Data (in dimensional form)
                            OP_T(:,u,idx+1) = -T_new(:,idx)*alpha;
                            OP_I(:,u,idx+1) = I_new(:,idx)*alpha*Deltahc;
                            OP_delta(:,u,idx+1) = delta_new(:,idx)/delta0hc;
                        end

                        % Effect of social distancing
                    case "Social Distancing"
                        delta_new=nan(N,nMit);
                        T_new=nan(N,nMit);
                        I_new=nan(N,nMit);
                        for idx=1:nMit
                            ysd = log(((1-MitData(idx))*delta(N))/delta0hc)/log(delta(N)/delta0hc);  % Solves for the power term at the final time point where delta_new/delta_old = 1-sd
                            delta_new_temp = delta0hc*(deltahc/delta0hc).^ysd;  % Computes new delta corresponding to new level of social distancing
                            delta_new(n1:n2,idx)=delta_new_temp(:,1); % Stores values at all social dist values (columnwise)
                            pD_new = polyfit(thc,delta_new_temp,14); % Fits a 7th order polynomial to the new delta vs t
                            
                            [~,ysol] = ode45(@(thc,y)fnTI(thc,y,pD_new,lambda,gamma),thc,[T0hc I0hc]); % Computes new T and I corresponding to the new delta (or soc dist)
                            T_new(n1:n2,idx) = ysol(:,1); % Stores values at all social dist values (columnwise)
                            I_new(n1:n2,idx) = ysol(:,2); % Stores values at all social dist values (columnwise)
                            clear ysol; clear pD_new; clear delta_new_temp; clear ysd;

                            % Outputting PPE Data (in dimensional form)
                            OP_T(:,u,idx+1) = -T_new(:,idx)*alpha;
                            OP_I(:,u,idx+1) = I_new(:,idx)*alpha*Deltahc;
                            OP_delta(:,u,idx+1) = delta_new(:,idx)/delta0hc;
                        end
                end
                warning('on','MATLAB:polyfit:RepeatedPointsOrRescale')
            end
        else
            counter(u)=true; % Array storing the missed sample run # (Index corresponds to run #)
        end

        clearvars -except Delta FE LOC M MitData N Ns OP_I OP_T OP_delta PPE R0_uq T_source Tact UQ alpha counter dt epsk gamma_uq n nMit pf_source tact u t T0 PB idx1
        close all;

    if PB.CancelRequested
        error("HARAM:Canceled","HARAM Model Was Canceled")
    end

    end

    if ~UQ.bool || nnz(~counter) >= UQ.SigLim
        break
    elseif idx1 == UQ.HardLimit
        error("HARAM:SigLimitUnreach","Unable to Converge on a Solution.\n Please Increase N to above %d and/or Change the Infection Charateristics",...
            Ns)
    else
        Ns = Ns + UQ.Ninc;
    end
end % for idx1 = 1:UQ.HardLimit

%% COMPUTING THE MEAN AND UNCERTAINTY BOUNDS FOR MODEL OUTPUTS

% Removes Singularity Data from preallocated OP arrays
OP_T=OP_T(:,~counter,:);
OP_I=OP_I(:,~counter,:);
OP_delta=OP_delta(:,~counter,:);

Final_vars = cell(1,3);
[Final_vars{:}] = HARAM_out(OP_T, OP_I, OP_delta, PPE);

end % function HARAM
% ---- END OF HARAM FUNCTION ----
% ---- Local Functions ----

function [T_out, I_out, d_out] = HARAM_out(T_in, I_in, d_in,PPE)
% HARAM_OUT takes the output arrays from solving the ODEs to an output
% table. It also adds a 95% Confidence Interval (Upper and Lower)
%
% Inputs:
% T_in: Change in Susceptible Population Array 
% I_in: Infected Population Array
% d_in: Dynamic Spread Function Array
% PPE: PPE Structure Inputed into the Main HARAM Function 
arguments
    T_in (:,:,:) double {mustBeReal}
    I_in (:,:,:) double {mustBeReal}
    d_in (:,:,:) double {mustBeReal,mustBeEqualSize(T_in,I_in,d_in)}
    PPE struct {validPPEstruct(PPE)}
end

% Mean values
M_T = mean(T_in,2);
M_I = mean(I_in,2);
M_delta = mean(d_in,2);

% Uncertainty values
U_T = sqrt(var(T_in,0,2));
U_I = sqrt(var(I_in,0,2));
U_delta = sqrt(var(d_in,0,2));

% Uncertainty bounds [95% CI]
Lb_T = M_T(:,:,:)-(1.96.*U_T(:,:,:)); % Lb: Lower bound
Ub_T = M_T(:,:,:)+(1.96.*U_T(:,:,:)); % Ub: Upper bound

Lb_I = M_I(:,:,:)-(1.96.*U_I(:,:,:));
Ub_I = M_I(:,:,:)+(1.96.*U_I(:,:,:));

Lb_delta = M_delta(:,:,:)-(1.96.*U_delta(:,:,:));
Ub_delta = M_delta(:,:,:)+(1.96.*U_delta(:,:,:));


%% STORING FINAL OUTPUT DATA
[T_out,I_out,d_out]=deal(zeros(size(T_in,1,3).*[1 3]));

for idx=1:size(T_in,3)

    T_out(:,(idx-1)*3+1) = M_T(:,:,idx);
    T_out(:,(idx-1)*3+2) = Lb_T(:,:,idx);
    T_out(:,(idx-1)*3+3) = Ub_T(:,:,idx);

    I_out(:,(idx-1)*3+1) = M_I(:,:,idx);
    I_out(:,(idx-1)*3+2) = Lb_I(:,:,idx);
    I_out(:,(idx-1)*3+3) = Ub_I(:,:,idx);

    d_out(:,(idx-1)*3+1) = M_delta(:,:,idx);
    d_out(:,(idx-1)*3+2) = Lb_delta(:,:,idx);
    d_out(:,(idx-1)*3+3) = Ub_delta(:,:,idx);

end % for

VarNames = repelem("BL",3);
if PPE.str_abv ~= ""
    VarNames = [VarNames,... % [VarNames+"_"+PPE.str_abv,...
    repelem(string(PPE.PPE_data*100)',3)+"_"+PPE.str_abv]; 
end
VarNames = join([VarNames;repmat(["mean","Lb","Ub"],[1 size(T_in,3)])]',"_")';

T_out = array2table(T_out,"VariableNames",VarNames);
T_out = addprop(T_out,{'PlotVar','Handles','mainAxes'},{'table','table','table'});
T_out.Properties.CustomProperties.PlotVar = "T";

I_out = array2table(I_out,"VariableNames",VarNames);
I_out = addprop(I_out,{'PlotVar','Handles','mainAxes'},{'table','table','table'});
I_out.Properties.CustomProperties.PlotVar = "I";

d_out = array2table(d_out,"VariableNames",VarNames);
d_out = addprop(d_out,{'PlotVar','Handles','mainAxes'},{'table','table','table'});
d_out.Properties.CustomProperties.PlotVar = "delta";


end % function HARAM_out

%% Local input validation functions
function mustBeEqualSize(a,b,c)
    % Test for equal size
    if ~isequal(size(a),size(b),size(c))
        eid = 'Size:notEqual';
        msg = 'Size of all arrays must be the same.';
        throwAsCaller(MException(eid,msg))
    end
end % function mustBeEqualSize(a,b,c)

function validPPEstruct(PPE)
    if ~all(isfield(PPE,["BL_FE","PPE_data","str_abv"]))
        eid = 'validPPEstruct:missingFields';
        msg = 'PPE Struct is missing required fields.';
        throwAsCaller(MException(eid,msg))
    end
    mustBeTextScalar(PPE.str_abv)
    mustBeNonnegative(PPE.BL_FE)
    mustBeLessThanOrEqual(PPE.BL_FE,1)
    mustBeNonnegative(PPE.PPE_data)
    mustBeLessThanOrEqual(PPE.PPE_data,1)
end % function validPPEstruct(PPE)