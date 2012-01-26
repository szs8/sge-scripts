#!/usr/bin/env ruby

# == Synopsis 
#   Not Available
#
# == Examples
# ./accounting.rb -i /opt/gridengine/default/common/accounting -o testofile -u pavgi -s 3d
# ./accounting.rb -ipfile /opt/gridengine/default/common/accounting -opfile testofile --user pavgi --since 3d  
#
# == Usage 
#   accounting.rb [options]
#   For help use: accounting.rb -h
#   See Examples ^^
# 
# == Author
#   Shantanu Pavgi, knowshantanu@gmail.com  
# == Credits
#   Useful post for writing command-line application skeleton - http://blog.toddwerth.com/entries/5 
# == Depenedcies - included as standard Ruby lib; no external gems/lib required:  
#   'optparse'
#   'ostruct'
# == TODO
#   Improve skeleton and instance variable usage 
#   Setting stdout as a default during initialization  
# 
# Example line from accounting file which needs to be parsed: 
# compute.q:compute-0-6.local:pavgi:pavgi:galaxy_2503.sh:8070699:sge:0:1311868550:1311868559:1311875460:100:138:6901:0.000000:0.001999:0.000000:0:0:0:0:574:0:0:0.000000:0:0:0:0:43:2:NONE:defaultdepartment:NONE:1:0:6888.600000:511.570799:9.135190:-u pavgi -l h_rt=7200,h_vmem=2G,s_rt=6900,virtual_free=2G:0.000000:NONE:145149952.000000:0:0

# 0 : queue
# 1 : compute node
# 2 : group
# 3 : user
# 4 : job script name
# 5 : job number
# 6 : account sge
# 7 : priority
# 8 : submission time
# 9 : start time
# 10: end time
# 11: failed - for sge killed run-time jobs 100, sge killed memory limit jobs 100, job fails for some reason1 non-zero
# 12: exit-status - for sge killed run-time jobs 138, sge killed memory limit jobs 137, job fails for some reason1 19
# 13
# ..
# ..

require 'optparse'
require 'ostruct'


class JobSearch
  VERSION="1.0.0"

  # Initialize/instantiate new JobSearch object 
  attr_reader :options
  def initialize(arguments)
    @arguments = arguments
    # set default options 
    @options = OpenStruct.new
    @options.help = false
    @options.ipfile = "#{ENV['SGE_ROOT']}/#{ENV['SGE_CELL']}/common/accounting"
    @options.user = ENV['USER']
  end

  def run
    # parsed_options 
    if parsed_options? 
      # process_options # should process_option be called here or from parsed_options??
      # output_options
      # process_command performs the real job - parsing SGE accounting file
      process_command
    else
      puts "Unknown Error..."
      exit 99
    end
  end
  
  protected 
  def parsed_options?
    # define options
    since_regex = /\d+[m|h|d]/
    @optionparser_obj = OptionParser.new do |opts|
      opts.banner = "#{$0} OPTIONS"
      opts.on('-v', '--verbose', "Verbose Output") { @options.verbose = true }
      opts.on('-h', '--help', "Display help") { @options.help = true }
      opts.on('-i', '--ipfile IFILE', "SGE Accounting file") { |a| @options.ipfile = a }
      opts.on('-o', '--opfile OFILE', "Output file") { |a| @options.opfile = a }
      opts.on('-u', '--user USER', "Job user") { |a| @options.user = a }
      opts.on('-s', '--since SINCE', since_regex, "Go back in history until N[m|h|d]") { |a| @options.since = a }
      opts.separator ""
    end
    # Parse @options passed 
    begin 
      @optionparser_obj.parse!(@arguments)
    rescue OptionParser::InvalidOption => e
      puts e
      exit 1
    rescue OptionParser::MissingArgument => e
      puts e 
      exit 1
    rescue OptionParser::InvalidArgument => e
      puts e 
      exit 1
    end
    process_options
    true
  end
  
  # print output options 
  def output_options
    @options.marshal_dump.each do |name,value|
      puts "#{name} = #{value} "
    end
  end
  
  # Process options and assign them to specific variables as needed
  def process_options
    output_help if @options.help
    @afilename = @options.ipfile 
    @ofilename = @options.opfile 
    @user = @options.user
    # convert 'since' time to seconds
    since = @options.since 
    case since
    when /\d+m/
      @seconds = since.to_i * 60
    when /\d+h/
      @seconds = since.to_i * 60 * 60
    when /\d+d/
      @seconds = since.to_i * 24 * 60 * 60   
    else
      puts "Unexpected pattern!"
      @seconds = 0
    end
  end
  
  # Real command - where accounting file is parsed 
  def process_command
    puts "# #{$0} #{@options.to_s}"
    # Get current time in epochs
    time = Time.now
    epochs = time.gmtime.to_i
    # Subtract seconds(obtained from minutes user ip) to go back in accounting file
    epochs = epochs - @seconds.to_i
    # Output file  - set to STDOUT if @options.opfile not specified
    if @ofilename 
      ofile = File.open(@ofilename, "w") 
    else
      ofile = STDOUT
    end
    ofile << "# Failed jobs for user #{@user} since last #{@options.since}\n"
    ofile << "# SGE Job ID, Job script name\n"
    File.foreach(@afilename) do |aline| 
        # Select lines that match following criteria: 
        ## specified-username
        ## && (completed/end-time in last n minutes #{epochs})
        ## && (failed status is non-zero || exit status is non-zero)
        if aline !~ /#/
            aarray = aline.split(":")
            wallclock = aarray[10].to_i - aarray[9].to_i
        	if aarray[3]== @user && (aarray[10].to_i>=epochs) && (aarray[11]!='0' || aarray[12]!='0')
            	#ofile << "#{aarray[5]} #{epochs} #{aarray[10]} #{time}\n"
            	ofile << "#{aarray[5]}, #{aarray[4]}\n"
        	end
        end
    end
    ofile.close
    # Close output file 
  end
  
  def output_help
    puts "HELP:"
    puts @optionparser_obj
    exit
  end
end

job = JobSearch.new(ARGV)
job.run