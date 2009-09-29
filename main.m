close all;
clear classes;
drawnow;

DISPLAY_OUTPUT=false;

this=tommas(tommasConfig);

while(true)

  [this,xEstimate,cost,costPotential]=step(this);
  
  fprintf('\n');
  fprintf('\ncostPotential: %f',costPotential);
  fprintf('\ncost:');
  fprintf('\n%f',cost);
  fprintf('\n');
  
  if(DISPLAY_OUTPUT)
    figure;
    px=exp(-9*(cost.*cost));
    px=px/norm(px);
    display(xEstimate,'alpha',px');
    axis('on');
    xlabel('North');
    ylabel('East');
    zlabel('Down');
  end

end