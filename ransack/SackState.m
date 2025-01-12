classdef SackState < handle
   properties
      outliers; 
      fit_segs_start = []; 
      fit_segs_end = []; 
      fit_circle_origins = []; 
      fit_circle_radii = [];
      
      % contour plot tool
      mesh_grid_min = -3; 
      mesh_grid_max = 3; 
      mesh_grid_step = 0.05;
      mesh_grid_x = [];
      mesh_grid_y = [];
      mesh_grid_z = [];

      % robot position
      x = 0; 
      y = 0; 
   end
   properties(Constant)
      debug_mode = 1; % whether to Wlot or not while iterating   

      % RANSACK LINE FIT --------------------------------------------------
      line_vertical_thresh = 0.05; % inlier threhold for vertical line fit
      line_horizontal_gap_thresh = 0.05; % inlier threshold for line fit gap
      line_min_pints = 10; % minimum point requirements for line model
      line_num_iters = 1000; % how many times to sample for line fit
      % RANSACK LINE FIT --------------------------------------------------

      % RANSACK CIRCLE FIT --------------------------------------------------
      circle_distance_thresh = 0.05; % inlier threshold for distance to circle model
      circle_min_pints = 5; % minimum point requirements for circle model
      circle_gap_threshold_degrees = 40; % max gap threshold of fit in degrees
      circle_num_iters = 10000; % how many times to sample for circle fit
      % RANSACK CIRCLE FIT --------------------------------------------------

   end
   methods(Static)
       % initialize ransack from polar coords
       function obj = FromPolar(r, theta)
           obj = SackState();
           obj.outliers = [r .* cosd(theta), r .* sind(theta)];
           obj.outliers = filter_by_row(obj.outliers, @(x) (x(1)));
       end
       % initialize ransack from global (x, y) cords
       function obj = FromGlobal(x, y)
           obj = SackState();
           obj.outliers = [x, y];
       end
   end
   methods
      % constructor
      function self = SackState()
         [x, y] = meshgrid(self.mesh_grid_min:self.mesh_grid_step:self.mesh_grid_max,self.mesh_grid_min:self.mesh_grid_step:self.mesh_grid_max);
         self.mesh_grid_x = x;
         self.mesh_grid_y = y;
         self.mesh_grid_z = self.mesh_grid_x*0 + self.mesh_grid_y*0;
      end
      function [model_found] = sack_iter(self)
            [fit_seg_start, fit_seg_end, line_fit_inliers, line_fit_outliers] = sack_line(self.outliers, SackState.line_vertical_thresh, SackState.line_horizontal_gap_thresh, SackState.line_min_pints, SackState.line_num_iters);
            [fit_circle_start, fit_circle_rad, circle_fit_inliers, circle_fit_outliers] = sack_circle(self.outliers, SackState.circle_distance_thresh, SackState.circle_gap_threshold_degrees, SackState.circle_min_pints, SackState.circle_num_iters);
            if(size(line_fit_inliers,1) == 0 && size(circle_fit_inliers,1) == 0)
                % no suitable model left in data
                model_found = 0;
                return;
            end
            if(size(line_fit_inliers,1) >= size(circle_fit_inliers,1))
               % line has a better fit
               self.fit_segs_start = [self.fit_segs_start; fit_seg_start(1) fit_seg_start(2)];
               self.fit_segs_end = [self.fit_segs_end; fit_seg_end(1) fit_seg_end(2)];
               self.outliers = line_fit_outliers;
               
               % visualize output fit to plot if in debug mode
               if(self.debug_mode)
                   color = [rand,rand,rand];
                   add_source_line(self, fit_seg_start, fit_seg_end);
                   scatter(line_fit_inliers(:,1), line_fit_inliers(:,2), 'MarkerFaceColor', color, 'MarkerEdgeColor', color);
                   plot([fit_seg_start(1), fit_seg_end(1)], [fit_seg_start(2), fit_seg_end(2)], 'Color', color);
               end
            else
               % circle has a better fit
               self.fit_circle_origins = [self.fit_circle_origins; fit_circle_start(1) fit_circle_start(2)];
               self.fit_circle_radii = [self.fit_circle_radii; fit_circle_rad];
               self.outliers = circle_fit_outliers;

               % visualize output fit to plot if in debug mode
               if(self.debug_mode)
                   color = [rand,rand,rand];
                   scatter(circle_fit_inliers(:,1), circle_fit_inliers(:,2), 'MarkerFaceColor', color, 'MarkerEdgeColor', color);
                   plot_circle(fit_circle_start(1), fit_circle_start(2), fit_circle_rad, color);
               end
            end
            % some model was found
            model_found = 1;
      end
      % marks a point in the gauntlet as a place to avoid
      function [] = add_source(self, x, y)
            self.mesh_grid_z = self.mesh_grid_z + log(sqrt(((self.mesh_grid_x) - x).^2+ ((self.mesh_grid_y) - y).^2));
      end
      % marks a point in the gauntlet as a place to seek
      function [] = add_sink(self, x, y)
            self.mesh_grid_z = self.mesh_grid_z - 100*log(sqrt(((self.mesh_grid_x) - x).^2+ ((self.mesh_grid_y) - y).^2));
      end
      function [] = add_source_line(self, line_start, line_end)
          resolution = ceil(norm(line_end - line_start) * 100);
          for iter=1:resolution
              intermediate = line_start + (((line_end - line_start) ./ resolution) * iter)
              add_source(self, intermediate(1), intermediate(2));
          end
      end
      function [] = move_neato(self) 
         [Dx, Dy] = gradient(self.mesh_grid_z);

         mesh_grid_x_index = ceil(self.mesh_grid_max/self.mesh_grid_step + (self.x / self.mesh_grid_step));
         mesh_grid_y_index = ceil(self.mesh_grid_max/self.mesh_grid_step + (self.y / self.mesh_grid_step));

         % prevent from going out of bounds
         if(mesh_grid_x_index > size(self.mesh_grid_z,1))
             mesh_grid_x_index = min(mesh_grid_x_index, size(self.mesh_grid_z,1) - 10);
         end
         if(mesh_grid_y_index > size(self.mesh_grid_z,1))
             mesh_grid_y_index = min(mesh_grid_y_index, size(self.mesh_grid_z,1) - 10);
         end

         mesh_grid_x_index
         mesh_grid_y_index

         if(isnan(mesh_grid_x_index) || isnan(mesh_grid_y_index))
             disp("foo");
         end
         

         move_direction = [Dx(mesh_grid_y_index, mesh_grid_x_index); Dy(mesh_grid_y_index, mesh_grid_x_index)]; 
         move_direction = move_direction ./ norm(move_direction);
         move_direction = move_direction ./ 1;

         % move the actual neato

         % stop moving the neato

         % update our position where we think we are
         self.x = self.x + move_direction(1);
         self.y = self.y + move_direction(2);

      end
      function [] = goal(self)
          for iter=1:500
              scatter([self.x], [self.y], 'magenta');
              move_neato(self);
          end
      end
      % run iterative RANSACK with multiple models
      function [] = sack_multi(self)
          % visualize output fit to plot if in debug mode
          if(self.debug_mode)
              figure(); hold on; axis equal; shading interp;
          end
          % resolve iteratively
          while(sack_iter(self))
          end
          % plot out contour if in debug mode
          if(self.debug_mode)
              add_sink(self,-2,2);
              %goal(self);

              contourf(self.mesh_grid_x,self.mesh_grid_y, self.mesh_grid_z, 1000, 'edgecolor','none');
              colormap('hot');
              % send contour plot to background by flipping plot elements
              % https://www.mathworks.com/matlabcentral/answers/30212-how-to-bring-a-plot-to-the-front-or-back-among-multiple-plots
              h = get(gca,'Children');
              set(gca,'Children',flip(h))

              [Dx, Dy] = gradient(self.mesh_grid_z);
              quiver(self.mesh_grid_x, self.mesh_grid_y, Dx, Dy)

          end
      end

   end
end