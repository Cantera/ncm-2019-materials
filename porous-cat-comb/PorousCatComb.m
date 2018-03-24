%Catalytic combustion over a Pt catalyst embedded into a porous monolith
%   reactor.
%
%...Developed by S. DeCaluwe (Colorado School of Mines, Mech. Eng.) in
%       conjunction with the National Combustion Meeting, University of
%       Maryland, College Park.  April 23, 2017.
%
%...This script solves a catalytic combustion problem.  A 1-D plug flow 
%       through a porous foam reactor at 900 K loaded with Pt catalyst. The
%       lean, premixed methane/air mixture enters at ~ 6 cm/s (0.06 
%       kg/m2/s), and burns catalytically on the platinum surface. 
%       Gas-phase chemistry is also included.
%
help PorousCatComb
disp('Press any key to start the simulation');
pause

clear all;
cleanup;

t0 = cputime; %...Record the starting time.

%%%%%%%%%%%%%%%  BEGIN INPUT PARAMETER LIST  %%%%%%%%%%%%%%%%%%%%%%
p = oneatm;                     % pressure (Pa)
T_reactor = 900;                % uniform reactor temperature (K)
mdot = 0.06;                    % mass flow rate (kg/m2/s)
transport = 'Mix';              % Mixture-averaged transport model
L_reactor = 8e-3;               % Length of the reactor (m)
n_grid = 1;                     % Number of discretized grid points
phi_g = 0.55;                   % Porosity of the foam
tau_g = 1.7;                    % Tortuosity of the foam
a_surf = 1020;                  % specific surface area of catalyst (1/m)
%
%...Composition of the inlet premixed gas for the methane/air case
comp1 =   'CH4:0.095, O2:0.21, N2:0.78, AR:0.01';

t_final = 2e-1;                 % Total time to integrate (s)    

%...Numerical parameters:
tol_ts    = [1.0e-4 1.0e-9];    % [rtol atol] for time stepping

%%%%%%%%%%%%%%%  END INPUT PARAMETER LIST  %%%%%%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%%%%% create the gas object %%%%%%%%%%%%%%%%%%%%%%%%
%
% This object will be used to evaluate all thermodynamic, kinetic,
% and transport properties
%
% The gas phase will be taken from the definition of phase 'gas' in
% input file 'ptcombust.cti,' which is a stripped-down version of
% GRI-Mech 3.0.
gas = Solution('ptcombust.cti','gas');
set(gas,'T',T_reactor,'P',p,'X',comp1)
disp('This is a printout of inlet state of the gas.')
disp('Press any key to continue')
pause

%%%%%%%%%%%%%%%% create the interface object %%%%%%%%%%%%%%%%%%
%
% This object will be used to evaluate all surface chemical production
% rates. It will be created from the interface definition 'Pt_surf'
% in input file 'ptcombust.cti,' which implements the reaction
% mechanism of Deutschmann et al., 1995 for catalytic combustion on
% platinum.
%
disp('Initial state of the surface phase (as defined in cti file)')
surf_phase = importInterface('ptcombust.cti','Pt_surf',gas)
setTemperature(surf_phase, T_reactor);

% integrate the coverage equations in time for 0.01 s, holding the gas
% composition fixed to generate a good starting estimate for the
% coverages.
advanceCoverages(surf_phase, 0.01);
disp('After integrating surface coverages')
%...Display the current state of the surface phase:
surf_phase
disp('Press any key to continue')
pause

%...The two objects we just created are independent of the problem
%   type -- they are useful in zero-D simulations, 1-D simulations,
%   etc. Now we turn to creating the objects that are specifically
%   for 1-D simulations. These will be 'stacked' together to create
%   the complete simulation.
%
%...Let's store some information about our gas and surface objects.  We use
%       Matlab's structured arrays for convenience's sake: easier to pass
%       to our integration function.
params.nsp_gas = nSpecies(gas);         % number of species in the gas obj
params.nsp_surf = nSpecies(surf_phase); % number of species in the surf obj
params.Xg_inlet = moleFractions(gas);   % mole fractions at the gas inlet
%
%...Load some of the previously defined parameters:
params.T_reactor = T_reactor;           
params.p = p;
params.phi_g = phi_g;
params.tau_g = tau_g;
params.dyInv = n_grid/L_reactor;
params.n_grid = n_grid;
params.a_surf = a_surf;
%
%...Load gas and surface into a structured array:
phases.gas = gas;
phases.surf = surf_phase;
%
%...Now we create a solution vector which stores the state (gas and surface
%       conditions at each of our grid points):
%
%...First create some pointers that tell us the order of our variables:
ptr.T_gas = 1;
ptr.X_gas = 2:1+params.nsp_gas;
ptr.theta_surf = ptr.X_gas(end)+1:ptr.X_gas(end)+params.nsp_surf;
%
params.nVars = ptr.theta_surf(end);     % how many variables for each node?
%
%...Initialize our solution vector:
SV_0 = zeros(params.nVars*n_grid,1);

for i=1:n_grid
    offset = (i-1)*params.nVars;
    SV_0(offset+ptr.T_gas) = T_reactor;
    SV_0(offset+ptr.X_gas) = params.Xg_inlet;
    SV_0(offset+ptr.theta_surf) = coverages(surf_phase);
end
%
%...Integrator options:
options = odeset('RelTol',tol_ts(1),'AbsTol',tol_ts(2));%,'OutputFcn', @odeplot);
t_span = [0, t_final];                   % integration time (s)
%
%...Integrate:
[t,SV] = ode15s(@(t,SV) PorousCatComb_func(t,SV,params,phases,ptr),t_span,SV_0,options);
%
%...Plot some results:
%
%...Gas phase reactant and product mole fractions:
%       Identify key species indices:
i_O2 = speciesIndex(gas,'O2');
i_CH4 = speciesIndex(gas,'CH4');
i_H2O = speciesIndex(gas,'H2O');
i_CO2 = speciesIndex(gas,'CO2');
figure
plot(t,SV(:,ptr.X_gas([i_O2,i_CH4,i_H2O,i_CO2])));
legend('O2','CH4','H2O','CO2')
%
%...Plot surface species coverages:
i_Pt = speciesIndex(surf_phase,'PT(S)');
i_O = speciesIndex(surf_phase,'O(S)');
i_OH = speciesIndex(surf_phase,'OH(S)');
figure
plot(t,SV(:,ptr.theta_surf([i_Pt,i_O,i_OH])));
legend('Pt(s)','O(s)','OH(s)');
%...Print out the elapsed time:
elapsed_time = cputime - t0
