classdef Flock < handle
    properties (GetAccess = public, SetAccess = public)
        boids
        arena
        radiusRep
        radiusOri
        radiusAtr
        wallRepRadius
        senseGoalRadius
        foundGoalRadius
        senseObstacleRadius
        communicationRadius
        goal
        initPos
        obstacles
        numObstacles
        nTop
        model
        fileID
        blindspot
        locations
        barrierCert
        unibarrierCert
        si2uni
        positionCont
    end
    
    methods
        % Constructor
        function this = Flock(r, numBoids)
            this.arena = r;
            for i = 1:numBoids
                this.boids = [this.boids; Boid(this,  i)];
            end
        end
        
        function updateLocations(this)
            this.locations = this.arena.get_poses();
        end
        
        function goalReached = check_goal(this)
            N = length(this.boids);
            for i = 1:N
                goaldist = norm(this.locations(1:2, i) - this.goal);
                if goaldist < this.foundGoalRadius
                    this.boids(i,1).atGoal = true;
                end
            end
            x = this.locations;
            x = x(1:2,:);
            if norm(this.goal-x,1)<0.275
                goalReached = 1;
                for i = 1:N
                    this.boids(i,1).atGoal = true;
                end
                disp('GOAL REACHED!')
            else
                goalReached = 0;
            end
        end
        
        function this = goToStart(this)
            flag = 0;
            N = length(this.boids);
            while ~flag
                x = this.arena.get_poses();
                x_temp = x(1:2,:);
                x_goal = this.initPos;

                %% Algorithm
                % Let's make sure we're close enough the the goals
                if norm(x_goal-x_temp,1)<0.08
                     flag = 1;
                end
                dx = this.positionCont(x(1:2, :), x_goal);
                % Normalization of controls.
                dxmax = 0.1;
                for i = 1:N
                    if norm(dx(:,i)) > dxmax
                        dx(:,i) = dx(:,i)/norm(dx(:,i))*dxmax;
                    end
                end

                %% Apply barrier certs. and map to unicycle dynamics
                dx = this.barrierCert(dx, x);
                dx = this.si2uni(dx, x);    
                this.arena.set_velocities(1:N, dx);
                this.arena.step();
            end
        end
        
        function this = resetBoids(this)
             for i = 1:size(this.boids)
                currentBoid = this.boids(i, 1);
                currentBoid.knowsGoal = false;
                currentBoid.foundGoal = false;
                delete(currentBoid.lines);
             end
        end
        
        function this = visualizeNeighbors(this, currentBoid)
            delete(currentBoid.lines);
            for j = 1:length(currentBoid.neighbors)
                nbr_id = currentBoid.neighbors(j);
                nbr = this.boids(nbr_id, 1);
                x1 = this.locations(1, currentBoid.id);
                x2 = this.locations(1, nbr.id);
                y1 = this.locations(2, currentBoid.id);
                y2 = this.locations(2, nbr.id);
                currentBoid.lines(j) = line([x1 x2], [y1 y2],'Color', 'r');
            end
        end
        
        function this = run(this)
            N = length(this.boids);
            dxu = zeros(2, N);
            % For each agent
            for i = 1:size(this.boids)
                currentBoid = this.boids(i, 1);
                currentBoid.getCommNeighbors(this);
                this.visualizeNeighbors(currentBoid);
                % Inform your neighbors if you can sense the goal
                if currentBoid.sensesGoal(this.goal, this.senseGoalRadius)
                    for j = currentBoid.neighbors
                        this.boids(j, 1).knowsGoal = true;
                    end
                end
                dxu(:,currentBoid.id) = this.boids(i, 1).run(this);
            end
            
            % Get ids of goal knowing agents
            xi = this.locations;
            ids = [];
            for i = 1:length(this.boids)
                currentBoid = this.boids(i, 1);
                if currentBoid.knowsGoal
                    ids = [ids currentBoid.id];
                end
            end
            
            % Update their goal to a ring around the goal center, use SI
            subset_xi = this.locations(:,ids);
            % theta = 0:2*pi/N:2*pi;
            % r = N * 0.0175;
            % goals = [r*sin(theta); r*cos(theta)];
            
            subset_dxi = this.goal - this.locations(1:2, ids); % + goals(1:2, ids);
            subset_dxu = this.si2uni(subset_dxi, subset_xi);
            for i = 1:length(ids)
                dxu(1:2,ids(i)) = subset_dxu(1:2,i);
            end
            
            % Go slowly if swarming
            for i = 1:length(this.boids)
                currentBoid = this.boids(i, 1);
                if ~currentBoid.knowsGoal
                    dxu(1:2, i) = dxu(1:2, i)*0.05;
                end
            end
            
            % Utilize barrier certs, and send velocities
            dxu = this.unibarrierCert(dxu, xi);
            this.arena.set_velocities(1:N, dxu);
            this.arena.step();
        end
    end
end


