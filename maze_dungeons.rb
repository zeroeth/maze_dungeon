# Maze / Dungeon generator by Kevin Alford (zeroeth)
# Based on Jamis Buck's wonderful maze algorithms in ruby.
# Be sure to check out:
# * His 'theseus' gem
# * His articles on maze algorithms:
#   http://weblog.jamisbuck.org/2011/2/7/maze-generation-algorithm-recap
# * And his awesome presentation on them
#   http://www.jamisbuck.org/presentations/rubyconf2011/index.html

# TODO
# random coridoor types, fancy 4-way intersections..
# glass if tunnel comes in contact with air.. or water/lava

# "2d" woven maze
# "3d" stacked maze (pick random point as end point to next level
# "3d" true 3d maze?
# "plinko" 2d maze turned sideways (with angles to guide you left/right)

class MazeDungeonsPlugin
  include Purugin::Plugin
  description 'Maze Dungeon Generator', 0.1

  def on_enable
    public_command('mazed', 'create a maze', '/maze {width}') do |me, *args|
      $me = me
      generator = MazeDungeons::OrthoGenerator.new
      maze = generator.maze
      renderer = MazeDungeons::OrthoRenderer.new(maze)
      renderer.draw_at me.target_block 
    end
  end
end


# Usage:
# generator = OrthoGenerator.new
# generator.mode = "newest;oldest" (OPTIONAL)
# maze = generator.generate (can also refer to generator.maze after)
# TODO ^ pass options to new, then maze is create or pass

# renderer = OrthoRenderer.new(maze)
# renderer.render_at(x,y,z)

module MazeDungeons
  N, S, E, W = 1, 2, 4, 8
  DX         = { E => 1, W => -1, N =>  0, S => 0 }
  DY         = { E => 0, W =>  0, N => -1, S => 1 }
  OPPOSITE   = { E => W, W =>  E, N =>  S, S => N }


  class Maze
    attr_accessor :width, :height
    attr_accessor :grid

    def initialize(height,width)
      self.height = height
      self.width  = width
      self.grid   = Array.new(height) { Array.new(width, 0) }
    end

    def carve(x,y,value)
      self.grid[y][x] |= value
    end
    
    def passage?(x,y,dir)
      cell(x,y) & dir != 0
    end

    def cell(x,y)
      self.grid[y][x]
    end
  end

  class MazeCell
  end

  class OrthoRenderer
    attr_accessor :block_grid
    attr_accessor :maze

    def initialize(maze)
      self.maze = maze
    end

    def draw_at(target_block)
      rasterize_grid
      blockit(target_block)
    end

    def rasterize_grid
      
      $me.msg "rasterize_grid"
      # put into 2d/3d grid
      block_size = 5
      self.block_grid   = Array.new(maze.height*block_size){ Array.new(maze.width*block_size){ Array.new(block_size, :air) } }

      maze.grid.each_with_index do |row, cell_y|
        $me.msg "row #{cell_y}"
        row.each_with_index do |col, cell_x|
          $me.msg "col #{cell_x}"
          center_y = cell_y*block_size + 3
          center_x = cell_x*block_size + 3

          if !maze.passage?(cell_x,cell_y, N)
            fill(center_x-2, center_y-2, 0, center_x+2,center_y-2, 4)
          end

          if !maze.passage?(cell_x,cell_y, S)
            fill(center_x-2, center_y+2, 0, center_x+2,center_y+2, 4)
          end

          if !maze.passage?(cell_x,cell_y, E)
            fill(center_x+2, center_y-2, 0, center_x+2,center_y+2, 4)
          end

          if !maze.passage?(cell_x,cell_y, W)
            fill(center_x-2, center_y-2, 0, center_x-2,center_y+2, 4)
          end
        end
      end
    end

    # fill a cube region
    def fill(sx,sy,sz,ex,ey,ez)
      [sy..ey].each do |y|
        [sx..ex].each do |x|
          [sz..ez].each do |z|
            self.block_grid[y][x][z] = :cobblestone
          end
        end
      end
    end

    # render the grid at a specific orientation
    def blockit(target_block)
      $me.msg "block it"
      start_x = target_block.x
      start_y = target_block.y
      start_z = target_block.z
      world = target_block.world

      block_grid.each_with_index do |row, cell_y|
        row.each_with_index do |col, cell_x|
          col.each do |cell, cell_z|
            block = world.block_at(start_x+cell_x, start_y+cell_y, start_z+cell_z)
            block.change_type cell
          end
        end
      end
    end
  end

  class OrthoCellRender
  end

  class OrthoGenerator
    attr_accessor :width, :height
    attr_accessor :mode
    attr_accessor :seed
    attr_accessor :grid
    attr_accessor :generated
    attr_accessor :commands,:current
    attr_accessor :maze

    def initialize
      self.width  = 5
      self.height = width
      self.mode   = "random"
      self.seed   = rand(0xFFFF_FFFF).to_i
      self.seed   = 100
      self.generated = false
    end

    def maze
      @maze || generate_maze
    end

    def generate_maze
      parse_commands
      srand(seed)

      self.maze = Maze.new(height,width)

      cells = []
      x, y = rand(width), rand(height)
      cells << [x, y]

      until cells.empty?
        index = next_index(cells.length)
        x, y = cells[index]
        [N, S, E, W].shuffle.each do |dir|
          nx, ny = x + DX[dir], y + DY[dir]
          if nx >= 0 && ny >= 0 && nx < width && ny < height && maze.cell(nx,ny) == 0
            maze.carve(x,y, dir)
            maze.carve(nx,ny, OPPOSITE[dir])
            cells << [nx, ny]
            index = nil
            break
          end
        end

        cells.delete_at(index) if index
      end

      return maze
    end

    def parse_commands
      self.commands = mode.split(/;/).map { |cmd| parse_command(cmd) }
      self.current = 0
    end

    def parse_command(cmd)
      total_weight = 0
      parts = cmd.split(/,/).map do |element|
        name, weight = element.split(/:/)
        weight ||= 100
        abort "commands must be random, newest, middle, or oldest (was #{name.inspect})" unless %w(random r newest n middle m oldest o).include?(name)
        total_weight += weight.to_i
        { :name => name.to_sym, :weight => total_weight }
      end
      { :total => total_weight, :parts => parts }
    end

    def next_index(ceil)
      command = self.commands[self.current]
      self.current = (self.current + 1) % self.commands.length

      v = rand(command[:total])
      command[:parts].each do |part|
        if v < part[:weight]
          case part[:name]
          when :random, :r then return rand(ceil)
          when :newest, :n then return ceil-1
          when :middle, :m then return ceil/2
          when :oldest, :o then return 0
          end
        end
      end

      abort "[bug] failed to find index (#{v} of #{command.inspect})"
    end
  end
end

