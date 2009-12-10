% This class defines a graph of measures between sensor data and a trajectory
classdef measure < sensor
  
  properties (Constant=true,GetAccess=public)
    baseClass='measure';
  end
  
  methods (Access=protected)
    % Construct a measure given a sensor
    %
    % INPUT
    % u = sensor instance
    %
    % NOTES
    % A subclass constructor must pass identical arguments to this 
    %   constructor using the syntax this=this@measure(u);
    % Does not modify sensor lock state
    function this=measure(u)
      assert(isa(u,'sensor'));
    end
  end
  
  methods (Abstract=true)
    % Set the trajectory that will be used to compute costs
    %
    % INPUT
    % x = trajectory instance
    %
    % NOTES
    % This trajectory represents the motion of the body frame relative to a 
    %   world frame. If the sensor frame is not coincident with the body 
    %   frame, then the sensor frame offset may need to be kinematically 
    %   composed with the body frame to locate the sensor.
    % Does not modify sensor lock state
    setTrajectory(this,x);
    
    % Check whether the adjacency matrix of the graph is diagonal
    %
    % OUTPUT
    % flag = true if no edges span more than one node, logical scalar
    %
    % NOTES
    % Does not modify sensor lock state
    flag=isDiagonal(this);
    
    % Find all edges in the graph
    %
    % OUTPUT
    % ka = lower node index for each edge, uint32 N-by-1
    % kb = upper node index for each edge, uint32 N-by-1
    %
    % NOTES
    % Indices must be sorted in ascending order, first by a then by b
    % If graph is diagonal, then a and b are identical
    % Does not modify sensor lock state
    [ka,kb]=findEdges(this);
    
    % Evaluate an edge
    %
    % INPUT
    % ka = lower node index, uint32 scalar
    % kb = upper node index, uint32 scalar
    %
    % OUTPUT
    % cost = non-negative measure in the interval [0,1], double scalar
    %
    % NOTES
    % For diagonal graphs the upper node index may be empty
    % Does not modify sensor lock state
    cost=computeEdgeCost(this,ka,kb);
  end
  
end
