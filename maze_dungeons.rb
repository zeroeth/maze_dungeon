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

require 'rubygems'

puts 'Load path:'
  $LOAD_PATH.each { |dir| puts "*** (#{dir})" }
puts '----=-=-=-=-=----'
puts "((#{Gem.path}))"

require 'theseus'
puts "!"*20
puts Theseus::Maze.instance_methods(false).inspect
puts "^"*20

maze = Theseus::OrthogonalMaze.new height: 10, width: 10
maze.generate!

# TODO
#   - include thesus and maze as a jar together
#   - make easy way to define the maze 'tube' shape. from profile.. using text or
#     bitmap? corners will be hard.
#   - maybe a series of slices like a sprite sheet from bottom to top
#   - make tubes and intersections or make wall sections..
#     ie - | + L   vs || = etc.
#
#   - death star
#   - glass floors
#   - hillside slant.. bowl
#   - ladders w multi height
#   - bridge on top of walls 2nd maze. (not hard.. just make a new maze and if
#     there's a wall below use that else draw a bridge, i dont think it needs
#     to be contstrained to the maze beneath it.
#   - real '3d' maze
#   - crazy sphere like the clear ball greg has
#   - 'torus' maze.

class MazeDungeonsPlugin
  include Purugin::Plugin
  description 'Maze Dungeon Generator', 0.1

  def on_enable
    public_command('mazed', 'create a maze', '/maze {width} {levels}') do |me, *args|
      $me = me
      error? args[0].to_i > 0, "width must be an integer larger than 0"
      width = args[0].to_i || 5

      error? args[1].to_i > 0, "levels must be an integer larger than 0"
      levels = args[1].to_i || 1


      origin_block = me.target_block
      origin_block = origin_block.block_at(:down, 4) # spawn in the floor

      levels.times do
        generator = MazeDungeons::OrthoGenerator.new
        generator.height = generator.width = width

        renderer = MazeDungeons::OrthoRenderer.new(generator.maze)
        renderer.draw_at origin_block

        origin_block = origin_block.block_at(:down, renderer.block_size)
      end

    end

    public_command('typed', 'set the block type', '/typed {type}') do |me, *args|
      me.target_block.change_type args[0].to_sym
    end

    public_command('inspect', 'inspect target block', '/inspect') do |me, *args|
      me.msg me.target_block.to_s
      me.msg me.target_block.inspect
    end

    public_command('eval', 'woo', '/eval {stuff}') do |me, *args|
      eval(args.join(" "))
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
  N, S, E, W, U, D = 1, 2, 4, 8, 16, 32
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
    attr_accessor :block_size
    attr_accessor :maze

    def initialize(maze)
      self.maze = maze
      self.block_size = 5
    end

    def draw_at(target_block)
      self.block_grid   = Array.new(maze.height*block_size){ Array.new(maze.width*block_size){ Array.new(block_size, :air) } }
      rasterize_grid
      blockit(target_block)
    end

    def rasterize_grid
      maze.grid.each_with_index do |row, cell_y|
        row.each_with_index do |col, cell_x|
          center_y = cell_y*block_size + 2
          center_x = cell_x*block_size + 2
          center_z = 2

          # FIXME use the direction constants with a multiplier
          west = center_x - 2
          east = center_x + 2

          north = center_y - 2
          south = center_y + 2

          top = 4
          bottom = 0

          fill(west, north, bottom, west, north, top)
          fill(west, south, bottom, west, south, top)
          fill(east, north, bottom, east, north, top)
          fill(east, south, bottom, east, south, top)

          if !maze.passage?(cell_x,cell_y, U)
            fill(west, north, top, east, south, top, :glass)
          end

          if !maze.passage?(cell_x,cell_y, D)
            fill(west, north, bottom, east, south, bottom, :glass)
          end

          if !maze.passage?(cell_x,cell_y, N)
            fill(west, north, bottom, east, north, top, :wool)
            # FIXME use directional constants
            set(center_x, north+1, center_z, :torch)
          end

          if !maze.passage?(cell_x,cell_y, S)
            fill(west, south, bottom, east, south, top, :brick)
            set(center_x, south-1, center_z, :torch)
          end

          if !maze.passage?(cell_x,cell_y, E)
            fill(east, north, bottom, east, south, top, :wood)
            set(east-1, center_y, center_z, :torch)
          end

          if !maze.passage?(cell_x,cell_y, W)
            fill(west, north, bottom, west, south, top, :sandstone)
            set(west+1, center_y, center_z, :torch)
          end
        end
      end
    end

    # fill a cube region
    def fill(sx,sy,sz,ex,ey,ez, material = :mossy_cobblestone)
      (sy..ey).each do |y|
        (sx..ex).each do |x|
          (sz..ez).each do |z|
            self.block_grid[y][x][z] = material
          end
        end
      end
    end

    def set(x,y,z, material)
      self.block_grid[y][x][z] = material
    end

    # render the grid at a specific orientation
    def blockit(target_block)
      start_x = target_block.x
      start_y = target_block.y
      start_z = target_block.z
      world = target_block.world

      block_grid.each_with_index do |row, cell_y|
        row.each_with_index do |col, cell_x|
          col.each_with_index do |cell, cell_z|
            # Convert to minecraft coords
            # local X = minecraft Z
            # local Y = minecraft X
            # local Z = minecraft Y

            x = start_z-cell_x # west is inverse
            y = start_x+cell_y
            z = start_y+cell_z

            block = world.block_at(y,z,x)

            # TODO make smarter to set material based on world neighbors
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
      self.generated = false
    end

    def maze
      @maze || generate_maze
    end

    def create_entrance
    end

    def braid_dead_ends
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

