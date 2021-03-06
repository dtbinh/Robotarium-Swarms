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
        goals
        goalMarks
        goalVisits
        initPos
        obstacles
        numObstacles
        nTop
        model
        fileID
        blindspot
        vdist
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
        
        function updateGoals(this)
            global GOAL_TOLERANCE
            N = length(this.boids);
%             this.goals;
%             this.locations;
            for i = 1:N
                for j = 1:length(this.goals)
                    goaldist = norm(this.locations(1:2, i)' - this.goals(j, :));
                    
                    if goaldist < GOAL_TOLERANCE
                        this.goalMarks(j) = 1;
                        this.goalVisits(i,j) = 1;
                    end
                end
            end
        end
        
        function this = goToStart(this)
            global START_TOLERANCE
            flag = 0;
            N = length(this.boids);
            while ~flag
                x = this.arena.get_poses();
                x_temp = x(1:2,:);
                x_goal = this.initPos;

                % Make sure we're close enough the the goals
                %norm(x_goal-x_temp,1);
                if norm(x_goal-x_temp,1)< START_TOLERANCE
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
                % Apply barrier certs. and map to unicycle dynamics
                dx = this.barrierCert(dx, x);
                dx = this.si2uni(dx, x);    
                this.arena.set_velocities(1:N, dx);
                this.arena.step();
            end
        end
        
        function this = resetBoids(this)
             for i = 1:size(this.boids)
                currentBoid = this.boids(i, 1);
                delete(currentBoid.lines(:));
             end
             this.goalMarks(:) = 0;
             this.goalVisits(:) = 0;
        end
        
        function this = visualizeNeighbors(this, currentBoid)
            delete(currentBoid.lines);
            x1 = this.locations(1, currentBoid.id);
            y1 = this.locations(2, currentBoid.id);
            for j = 1:length(currentBoid.neighbors)
                nbr_id = currentBoid.neighbors(j);
                nbr = this.boids(nbr_id, 1);
                x2 = this.locations(1, nbr.id);
                y2 = this.locations(2, nbr.id);
                currentBoid.lines(j) = line([x1 x2], [y1 y2],'Color', 'r');
            end
        end
        
        function this = visualizeRadii(this, currentBoid)
           delete(currentBoid.circles(2:3));
           currentBoid.circles(2) = viscircles([this.locations(1:2,currentBoid.id)'], this.radiusOri, 'LineStyle', '-.', 'Color', [0.4 0.8 0.4], 'LineWidth', 0.1);
           currentBoid.circles(3) = viscircles([this.locations(1:2,currentBoid.id)'], this.radiusAtr, 'LineStyle', '-.', 'Color', [0.4 0.4 0.8], 'LineWidth', 0.1);
        end
        
        function this = run(this)
            global ENABLE_ROBOT_LBL ENABLE_NBOR_VIS ENABLE_RADII_VIS SWARM_SPEED
            N = length(this.boids);
            dxu = zeros(2, N);
            xi = this.locations;
            
            if ENABLE_ROBOT_LBL       
                for i = 1:size(this.boids)
                    currentBoid = this.boids(i, 1);
                    delete(currentBoid.text)
                    x1 = this.locations(1, currentBoid.id);
                    y1 = this.locations(2, currentBoid.id);
                    currentBoid.text = text(x1,y1,['     R' num2str(currentBoid.id)]);
                end
            end
            
            for i = 1:size(this.boids)
                currentBoid = this.boids(i, 1);

 
                currentBoid.getCommNeighbors(this);
                if ENABLE_NBOR_VIS
                    this.visualizeNeighbors(currentBoid);
                end
                if ENABLE_RADII_VIS
                    this.visualizeRadii(currentBoid);
                end
                dxu(:,currentBoid.id) = this.boids(i, 1).run(this);
            end
            
            % Go slowly if swarming
            for i = 1:length(this.boids)
                dxu(1:2, i) = dxu(1:2, i)*SWARM_SPEED;
            end
            
            % Utilize barrier certs, and send velocities
            dxu = this.unibarrierCert(dxu, xi);
            this.arena.set_velocities(1:N, dxu);
            this.arena.step();
        end
    end
end


