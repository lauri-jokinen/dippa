classdef resultsAnalysis
    %UNTITLED Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        res = {}
        % res{run}{# of objects} = steps required for solution
        % negative values indicate stopping to a local min,
        % which is not a solution
        problem = containers.Map % "shapes", "box" : [x,y], "methods"
        name
    end
    
    methods
        function obj = save(obj)
            save(join([obj.name, ".mat"],""))
        end
        function obj = load(obj, name)
            loaded = load(join([name, ".mat"], ""), "obj");
            obj = loaded.obj;
        end
        function obj = initialize(obj)
            box = shape;
            box.height = 1350 / 100;
            box.width = 1400 / 100;
            box.type = "rectangle";
            obj.problem("box") = box;
            
            obj.problem("shapesType") = "doubleType";
            s = capsRect;
            s.capsule.height = 275 / 100;
            s.capsule.width = 455 / 100;
            s.capsule.type = "capsule";
            s.rectangle.height = 275 * 0.8 / 100;
            s.rectangle.width = 455 * 0.8 / 100;
            s.rectangle.type = "rectangle";
            %s = shape;
            %s.height = 4.4/1.4;
            %s.width = 6.4/1.4;
            %s.type = "rectangle";
            obj.problem("shape1") = s;
            obj.problem("shape2") = s.capsule;
            
            r = shape;
            r.type = "rectangle";
            r.theta = 0;
            r.static = true;
            r.width = 63/10; r.height = 118/10;
            r.position = [obj.problem("box").width/2  -  r.width/2,...
                         -obj.problem("box").height/2 + r.height/2];
            obj.problem("staticShape") = r;
            
            obj.problem("methodType") = "twinType";
            obj.problem("method1") = @(P,p)P.optimizeCyclic("triangleSubGrad",p);
            obj.problem("method2") = @(P,p)P.optimizeCyclic("Matlab",p);
            %obj.problem("method2") = @(P,p)P.optimizeBFGS(p);
            %obj.problem("method2") = @(P,p)P.findZeroGrad(p);
            obj.problem("changeIter") = 0; % change at changeIter*n
            obj.problem("solutionLimit") = 1e-3;
            obj.problem("squared") = "no";
            obj.problem("linesearchLimit") = .5;
            obj.problem("randomTrials") = 1;
            obj.problem("accelerationProbability") = .3;
            obj.problem("h2Step") = "diminishing";
            obj.problem("allowDist") = "allowDistances";
        end
        function obj = initializeFullGradient(obj)
            box = shape;
            box.height = 9;
            box.width = 13;
            box.type = "rectangle";
            obj.problem("box") = box;
            
            obj.problem("shapesType") = "sigleType";
            s = shape;
            s.height = 4.4;
            s.width = 6.4;
            s.type = "rectangle";
            obj.problem("shape") = s;
            
            obj.problem("methodType") = "twinType";
            obj.problem("method1") = @(P)P.optimizeFullSubGradient();
            obj.problem("method2") = @(P)P.optimizeFullGradient();
            obj.problem("changeIter") = 15; % change at changeIter*n
        end
        function obj = simulate(obj, runs, video)
            calculationLimit = 1e8;
            box = obj.problem("box");
            objProblem = obj.problem;
            resTmp = obj.res;
            L = length(resTmp);
            if video == "video"
                runs = 1;
                videoFile = VideoWriter('elokuva.mp4','MPEG-4');
                videoFile.FrameRate = 18;
                open(videoFile);
            else
                videoFile = NaN;
            end
            parfor r = 1:runs % use non-parallel for-loop for video!!
                P = elevatorProblem;
                P = P.addShape(objProblem("staticShape"));
                P.box = box;
                resTmp{L+r} = {};
                currentObjectiveValue = 0;
                n = 0;
                firstMethodInUse = true;
                
                % Loop, where we add capsules until no solution can be found
                while currentObjectiveValue == 0
                    
                    if n ~= 0 && video == "plot"
                        close all
                        close all hidden
                        P.drawProblem(true);
                        axis([-P.box.width P.box.width -P.box.height P.box.height]*0.8)
                        saveas(gcf, [num2str(n), '.jpg'])
                    end
                    
                    if video == "returnP"
                        Ptemp = P;
                        if r == 1
                            Pmax = P;
                        end
                    end
                    
                    % Add an object to the problem
                    if objProblem("shapesType") == "sigleType"
                        P = P.addShape(objProblem("shape"));
                    elseif objProblem("shapesType") == "doubleType"
                        if mod(n,2)==0
                            P = P.addShape(objProblem("shape1"));
                        else
                            P = P.addShape(objProblem("shape2"));
                        end
                    end
                    
                    n = n+1;
                    
                    if isa(P.shapes{end},"shape")
                    	P.shapes{end}.theta = rand()*2*pi;
                        %P.shapes{end}.position = [(2*rand()-1), (2*rand()-1)];
                    	P.shapes{end}.position = [(2*rand()-1) * P.box.width/2, P.box.height/2];
                    elseif isa(P.shapes{end},"capsRect")
                    	P.shapes{end}.capsule.theta = rand()*2*pi;
                    	P.shapes{end}.capsule.position = [(2*rand()-1) * P.box.width/2, P.box.height/2];
                    end
                    
                    % Check if problem is impossible
                    if P.impossible()
                        disp("Impossible problem")
                        resTmp{L+r}{n} = -P.calculations;
                        break;
                    end
                    
                    iter = 0;
                    previousMinFunValue = Inf;
                    objFunValue = Inf;
                    currentObjectiveValue = Inf;
                    flagOne = false;
                    P = P.randomizeShapeIndices;
                    
                    %P.drawProblem(false);
                    %return
                    %P.objectiveFunctionAll(NaN, false, objProblem)
                    
                    % Iterate until a solution / a local minimum is found
                    while P.calculations < calculationLimit && currentObjectiveValue ~= 0
                        if video == "video" && (n < 5 || mod(iter,n-3) == 0)
                            close all
                            close all hidden
                            P.drawProblem(true);
                            axis([-P.box.width P.box.width -P.box.height P.box.height]*0.8)
                            set(gca,'nextplot','replacechildren');
                            frame = getframe(gcf);
                            writeVideo(videoFile,frame);
                        end
                        
                        % Check if the objective is descending
                        if mod(iter, 5*n) == 0 && ~firstMethodInUse
                            if objFunValue > previousMinFunValue*0.995
                                if flagOne
                                    disp("Objective is not descending");
                                    break
                                end
                                flagOne = true;
                            else
                                flagOne = false;
                            end
                            previousMinFunValue = objFunValue;
                            objFunValue = Inf;
                        end
                        
                        % Iterate, 'fun' is an optimization method
                        if objProblem("methodType") == "singleType"
                            fun = objProblem("method");
                            P = fun(P, objProblem);
                            firstMethodInUse = false;
                        elseif objProblem("methodType") == "twinType"
                            if iter / n < objProblem("changeIter")
                                fun = objProblem("method1");
                                P = fun(P, objProblem);
                                firstMethodInUse = true;
                                %disp('M1')
                            else
                                fun = objProblem("method2");
                                P = fun(P, objProblem);
                                firstMethodInUse = false;
                                %disp('M2')
                            end
                        else
                            disp("Method not found")
                            break
                        end
                        
                        iter = iter+1;
                        % Check feasibility only fraction of the time
                        if mod(iter,4) == 0
                            currentObjectiveValue = P.objectiveFunctionAll(NaN, false, objProblem);
                        end
                        objFunValue = min([objFunValue, currentObjectiveValue]);
                    end
                    
                    % If a solution is found, put a positive value in
                    % otherwise negative and escape
                    if currentObjectiveValue == 0
                        resTmp{L+r}{n} = P.calculations;
                    else
                        resTmp{L+r}{n} = -P.calculations;
                        break
                    end
                end
                if video == "returnP" && length(Ptemp.shapes) > length(Pmax.shapes)
                    Pmax = Ptemp;
                end
            end
            obj.res = resTmp;
            if video == "video"
                close(videoFile);
            end
            if video == "returnP"
            	obj = Pmax;
            end
        end
        
        function res2 = res2matrix(obj)
            lenRes = length(obj.res);
            maxN = 0;
            for q = 1:lenRes
                maxN = max(maxN, length(obj.res{q}));
            end
            res2 = zeros(lenRes, maxN)*NaN;
            for q = 1:lenRes
                lenR = length(obj.res{q});
                for w = 1:lenR
                    res2(q,w) = obj.res{q}{w};
                end
            end
            res2 = res2.';
        end
        
        function expArray = expectedCalculations(obj)
            res2 = obj.res2matrix();
            maxN = length(res2(:,1));
            lenRes = length(res2(1,:));
            expArray = zeros(maxN,1);
            for p = 1:maxN
                positive = res2(p, res2(p,:) >= 0);
                probP = length(positive) / lenRes;
                stepsP = mean(positive);
                [stepsQ, indices] = min(res2);
                stepsQ = stepsQ(((indices <= p) .* (stepsQ < 0)) == 1);
                stepsQ = mean(-stepsQ);
                if probP == 1
                    expArray(p) = stepsP;
                elseif probP == 0
                    expArray(p) = Inf;
                else
                    expArray(p) = stepsQ / probP + stepsP - stepsQ;
                end
            end
        end
        
        function [] = plot(obj,title1,save)
            res2 = obj.res2matrix();
            maxN = length(res2(:,1));
            expArray = obj.expectedCalculations();
            figure;
            hold on
            for p = 1:maxN
                positive = res2(p, res2(p,:) >= 0);
                negative = res2(p, res2(p,:) < 0);
                if ~isempty(positive)
                    pSucces = plot(p*ones(1,length(positive)) + 0.5*(rand(1,length(positive)) - 0.5), positive, '*', 'Color', [0 0.4470 0.7410]);
                end
                if ~isempty(negative)
                    pFail = plot(p*ones(1,length(negative)) + 0.5*(rand(1,length(negative)) - 0.5), -negative,'*', 'Color', [0.8500 0.3250 0.0980]);
                end
                pExp = plot(p + [-0.4, 0.4], ones(2,1)*expArray(p), 'LineWidth', 1, 'Color', 'k');
            end
            xlabel("# of objects in the box")
            ylabel("Time (# of area evaluations)")
            legend([pSucces pFail pExp],...
            ["Feasible solution found", ...
             "Algorithm stopped; no solution found", ...
             "Expected time for finding a solution"],...
            'Location',...
            'northwest');
            set(gca, 'YScale', 'log')
            title(obj.name);
            if save
                figuresize(14, 9, 'cm')
                saveas(gcf, [title1, '.pdf'])
            end
        end
        
        function [] = plotTwo(obj1,obj2,obj3,title1,title2,save)
            res2 = obj1.res2matrix();
            maxN1 = length(res2(:,1));
            res2 = obj2.res2matrix();
            maxN2 = length(res2(:,1));
            res2 = obj3.res2matrix();
            maxN3 = length(res2(:,1));
            expArray1 = obj1.expectedCalculations();
            expArray2 = obj2.expectedCalculations();
            expArray3 = obj3.expectedCalculations();
            figure; hold on;
            for p = 1:maxN1
                pExp1 = plot(p + [-0.4, 0.4], ones(2,1)*expArray1(p), 'LineWidth', 1.5, 'Color', 'r');
            end
            for p = 1:maxN2
                pExp2 = plot(p + [-0.4, 0.4], ones(2,1)*expArray2(p), 'LineWidth', 1.5, 'Color', 'b');
            end
            for p = 1:maxN3
                pExp3 = plot(p + [-0.4, 0.4], ones(2,1)*expArray3(p), 'LineWidth', 1.5, 'Color', 'k');
            end
            
            xlabel("# of objects in the box")
            ylabel("Time (# of area evaluations)")
            title(title1);
            legend([pExp1 pExp2, pExp3],...
            [obj1.name, ...
             obj2.name,...
             obj3.name],...
            'Location',...
            'northwest');
            %set(gca, 'YScale', 'log')
            
            if save
                figuresize(14, 9, 'cm')
                saveas(gcf, [title1, '.pdf'])
            end
            
            figure; hold on;
            for p = 1:min(maxN1, maxN2)
                pExp1 = plot(p + [-0.4, 0.4], ones(2,1)*expArray1(p) / expArray2(p), 'LineWidth', 1, 'Color', 'b');
            end
            
            if maxN1 < maxN2
                for p = (min(maxN1, maxN2)+1):maxN2
                    pExp1 = plot(p + [-0.4, 0.4], zeros(2,1), 'LineWidth', 1, 'Color', 'b');
                end
                disp('Inf encountered')
            elseif maxN1 > maxN2
                for p = (min(maxN1, maxN2)+1):maxN1
                    if ~isinf(expArray1(p))
                        pExp1 = plot(p + [-0.4, 0.4], zeros(2,1), 'LineWidth', 1, 'Color', 'b');
                    end
                end
            end
            
            xlabel("# of objects in the box")
            %ylabel("Time (# of area evaluations)")
            legend([pExp1],...
            join([obj1.name, ' / ', obj2.name]),...
            'Location',...
            'northwest');
            title(title2);
            %set(gca, 'YScale', 'log')
            
            %if save
            %    figuresize(19.5, 11.96, 'cm')
            %    saveas(gcf, [title2, '.pdf'])
            %end
        end
    end
end


