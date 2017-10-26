function res = main_exp(P)

% MAIN_EXP Run coalitional PD experiments, Angus & Newton (2017).
%    RES = MAIN_EXP(P) conducts a single experimental condition of the 
%    Coalitional PD model, with input parameter structure P and producing 
%    output structure RES.
%
%    if P.R = 1 (single replicate):
%       RES has following structure,
%          res.XT           .. the pop-fraction of D-players t \in 1..T
%          res.more_res.G   .. the Graph (adjacency matrix), G
%          res.more_res.fX  .. the strategy profile for players 1..n for each 
%          of the final R1_nper_store periods.
%    elseif P.R > 1 (multiple replicates):
%       RES has a more simple structure,
%          res.XT   .. as above, but per replicate.
%
%    Examples (from main code directory):
%
%       % Set up a parallel session
%       parpool              % start parallel pool with default cluster
%
%       % Run a single set of parameters,
%       setup; cd test/      % ensure everything on path
%       params_example       % provides 'P'
%       res = main_exp(P);
%
%       % Run a multiple parameter study, single replicate, rich output,
%       setup; cd test/      % ensure everything on path
%       SimRunner('main_exp', 'runfile_example_R1.txt', 'test_R1');
%
%       % Run a multiple parameter study, many replicates, simple output,
%       setup; cd test/      % ensure everything on path
%       SimRunner('main_exp', 'runfile_example_R2.txt', 'test_R2');
%
%    Functions
%    ---------
%    During experiments:
%     choose_one     A fast version of RANDSAMPLE, returning only 1 item.
%     game_table     Provides a game table, PI.
%     GetKpdf        Obtain a discrete binomial probability distribution.
%     InitStrats     Initialise strategies with given fraction of C.
%     LogUpdates     Provide detailed 'story' information to a log-file.
%     UpdatePayoffs  Calculate total payoffs to each agent in the game.
%     ApplyBetterResponse        Return a vector of better-response strategies.
%     ChooseCoalition_Binomial   Choose a coalition from the library.
%
%    To create a coalitional library:
%     MakeNetLib     Build a coalition library for fast run-time simulation.
%     MakeGraph      Make a graph from a menu of types.
%     GetAllCoalitions_k     Find all possible coalitions, given G and K.
%
%    Visualisation:
%     viz_contours   Make all panels of avg C contour plot in (p,e) space.
%     viz_networks   Write a .dot graph file for networks, nodes shaded by %C.
%     viz_timeseries
%
% See also GAME_TABLE GETKPDF RANDSTREAM

% Author: SA, 25 Oct 2017

% History
%  2012-09-27: Pseudo code
%  2012-10-16: Initial coding
%  2017-09-06: Update for SIxPD work.
%  2017-10-25: Update for deployment.

% -------------------------------------------------------- %
% Note on strategy encoding
%   We assume strat 0:C and 1:D throughout
% -------------------------------------------------------- %

% // Initialise inputs and outputs
P.PI = game_table(P.b, P.c);     % build game table
P.prob_k = GetKpdf(P.k, P.p);    % prob. distro over k=1:P.k
more_out_G = cell(1,1);
more_out_fX = cell(1,1);

% .. obtain graph and coalition options from library
load(P.coalitional_library_fname);      % --> provides 'Glib'

% .. now find the index of Glib which matches given e and p (note rounding to ensure match)
g_ix = find(round([Glib.e],3)==round(P.e,3));
thisG = Glib(g_ix);

% // For all replicates 1..R (i.e. for each graph 1..R in the sub-set of the library)
% use 'for' in place of 'parfor' if no parallel toolbox
parfor r = 1:P.R

	% // Initalise replicate
	% .. random stream is reproducible, the seed is the replicate #
	s1 = RandStream.create('mt19937ar','seed',r);
    RandStream.setGlobalStream(s1);

    % .. get graph, and coalitions
    G = full(thisG.lib(r).G);
    M = thisG.lib(r).M;
    sM = thisG.lib(r).sM;

    % .. initialise strats
    x = InitStrats(P.ini.n, P.ini.fB);
    x1 = zeros(P.ini.n,1);
    xt = zeros(P.T,1);
	pi = UpdatePayoffs(G,x,P);
    fX = logical(zeros(P.ini.n, P.R1_nper_store));

	% // Main Loop
	t = 1;
    c1 = 1;
    xt(1) = mean(x);
    while (t < P.T)
	
        % .. an update
        S = ChooseCoalition_Binomial(M,sM,P.k,P.ini.n, P.prob_k);
        x1 = ApplyBetterResponse(G,x,S,P,pi);
        pi = UpdatePayoffs(G,x1,P);
        xt(t+1) = mean(x1);

        % .. extra reporting if required
        if P.R==1 & (t >= (P.T - P.R1_nper_store + 1))
            fX(:,c1) = x1;
            LogUpdates(S,x,x1,P,t,c1)
            c1 = c1+1;
        end

        % .. prep for next update
        t = t + 1;
        x = x1;
	
	end % (while t)

	% .. prepare for reporting
	XT(r).xt = xt(1:t);
    if P.R==1
        more_out_G{r} = G;
        more_out_fX{r} = fX;
    end


end % (parfor r)

% // Output
res.XT = XT;
if P.R==1
    res.more_res.G = more_out_G{1};
    res.more_res.fX = more_out_fX{1};
end