direc = File.dirname(__FILE__)

require 'rubygems'
require 'bacon'
require "#{direc}/../lib/pry"
require "#{direc}/test_helper"

NOT_FOR_RUBY_18 = [/show_doc/, /show_idoc/, /show_method/, /show_imethod/]

puts "Ruby Version #{RUBY_VERSION}"
puts "Testing Pry #{Pry::VERSION}"
puts "With method_source version #{MethodSource::VERSION}"
puts "--"

describe Pry do
  describe "open a Pry session on an object" do
    describe "rep" do
      
      before do
        class Hello
        end
      end

      after do
        Object.send(:remove_const, :Hello)
      end

      it 'should set an ivar on an object' do
        input_string = "@x = 10"
        input = InputTester.new(input_string)
        o = Object.new

        pry_tester = Pry.new(:input => input, :output => Pry::NullOutput.new)
        pry_tester.rep(o)
        o.instance_variable_get(:@x).should == 10
      end

      it 'should make self evaluate to the receiver of the rep session' do
        o = Object.new
        str_output = StringIO.new
        
        pry_tester = Pry.new(:input => InputTester.new("self"), :output => Pry::Output.new(str_output))
        pry_tester.rep(o)
        str_output.string.should =~ /#{o.to_s}/
      end

      it 'should work with multi-line input' do
        o = Object.new
        str_output = StringIO.new
        
        pry_tester = Pry.new(:input => InputTester.new("x = ", "1 + 4"), :output => Pry::Output.new(str_output))
        pry_tester.rep(o)
        str_output.string.should =~ /5/
      end

      it 'should define a nested class under Hello and not on top-level or Pry' do
        pry_tester = Pry.new(:input => InputTester.new("class Nested", "end"), :output => Pry::NullOutput.new)
        pry_tester.rep(Hello)
        Hello.const_defined?(:Nested).should == true
      end
    end

    describe "repl" do
      describe "basic functionality" do
        it 'should set an ivar on an object and exit the repl' do
          input_strings = ["@x = 10", "exit"]
          input = InputTester.new(*input_strings)

          o = Object.new

          pry_tester = Pry.new(:input => input, :output => Pry::NullOutput.new)
          pry_tester.repl(o)

          o.instance_variable_get(:@x).should == 10
        end

        it 'should execute start session and end session hooks' do
          input = InputTester.new("exit")
          str_output = StringIO.new
          o = Object.new
          
          pry_tester = Pry.new(:input => input, :output => Pry::Output.new(str_output))
          pry_tester.repl(o)
          str_output.string.should =~ /Beginning.*#{o}/
          str_output.string.should =~ /Ending.*#{o}/
        end
      end

      describe "nesting" do
        it 'should nest properly' do
          Pry.input = InputTester.new("pry", "pry", "pry", "\"nest:\#\{Pry.nesting.level\}\"", "exit_all")

          str_output = StringIO.new
          Pry.output = Pry::Output.new(str_output)

          o = Object.new

          pry_tester = Pry.new
          pry_tester.repl(o)
          str_output.string.should =~ /nest:3/

          Pry.input = Pry::Input.new
          Pry.output = Pry::Output.new
        end
      end

      describe "commands" do
        it 'should run command1' do
          pry_tester = Pry.new
          pry_tester.commands = CommandTester.new
          pry_tester.input = InputTester.new("command1", "exit_all")
          pry_tester.commands = CommandTester.new

          str_output = StringIO.new
          pry_tester.output = Pry::Output.new(str_output)

          pry_tester.rep

          str_output.string.should =~ /command1/
        end

        it 'should run command2' do
          pry_tester = Pry.new
          pry_tester.commands = CommandTester.new
          pry_tester.input = InputTester.new("command2 horsey", "exit_all")
          pry_tester.commands = CommandTester.new

          str_output = StringIO.new
          pry_tester.output = Pry::Output.new(str_output)

          pry_tester.rep

          str_output.string.should =~ /horsey/
        end
      end

      describe "test Pry defaults" do
        it 'should set the input default, and the default should be overridable' do
          Pry.input = InputTester.new("5")

          str_output = StringIO.new
          Pry.output = Pry::Output.new(str_output)
          Pry.new.rep
          str_output.string.should =~ /5/

          Pry.new(:input => InputTester.new("6")).rep
          str_output.string.should =~ /6/

          Pry.reset_defaults
        end

        it 'should set the output default, and the default should be overridable' do
          Pry.input = InputTester.new("5", "6", "7")
          
          str_output = StringIO.new
          Pry.output = Pry::Output.new(str_output)
          
          Pry.new.rep
          str_output.string.should =~ /5/

          Pry.new.rep
          str_output.string.should =~ /5\n.*6/

          str_output2 = StringIO.new
          Pry.new(:output => Pry::Output.new(str_output2)).rep
          str_output2.string.should.not =~ /5\n.*6/
          str_output2.string.should =~ /7/

          Pry.reset_defaults
        end

        it 'should set the commands default, and the default should be overridable' do
          Pry.reset_defaults
          
          commands = {
            "hello" => proc { |opts| opts[:output].puts "hello world"; opts[:val].clear }
          }

          def commands.commands() self end

          Pry.commands = commands

          str_output = StringIO.new
          Pry.new(:input => InputTester.new("hello"), :output => Pry::Output.new(str_output)).rep
          str_output.string.should =~ /hello world/

          commands = {
            "goodbye" => proc { |opts| opts[:output].puts "goodbye world"; opts[:val].clear }
          }

          def commands.commands() self end
          str_output = StringIO.new
          
          Pry.new(:input => InputTester.new("goodbye"), :output => Pry::Output.new(str_output), :commands => commands).rep
          str_output.string.should =~ /goodbye world/

          Pry.reset_defaults
        end


        it "should set the print default, and the default should be overridable" do
          new_print = proc { |out, value| out.puts value }
          Pry.print =  new_print

          Pry.new.print.should == Pry.print
          str_output = StringIO.new
          Pry.new(:input => InputTester.new("\"test\""), :output => str_output).rep
          str_output.string.should == "test\n"

          str_output = StringIO.new
          Pry.new(:input => InputTester.new("\"test\""), :output => str_output,
                  :print => proc { |out, value| out.puts value.reverse }).rep
          str_output.string.should == "tset\n"
          
          Pry.new.print.should == Pry.print
          str_output = StringIO.new
          Pry.new(:input => InputTester.new("\"test\""), :output => str_output).rep
          str_output.string.should == "test\n"

          Pry.reset_defaults
        end
        
        describe "prompts" do
          it 'should set the prompt default, and the default should be overridable (single prompt)' do
            new_prompt = proc { "test prompt> " }
            Pry.prompt =  new_prompt

            Pry.new.prompt.should == Pry.prompt
            Pry.new.get_prompt(true, 0).should == "test prompt> "
            Pry.new.get_prompt(false, 0).should == "test prompt> "

            new_prompt = proc { "A" }
            pry_tester = Pry.new(:prompt => new_prompt)
            pry_tester.prompt.should == new_prompt
            pry_tester.get_prompt(true, 0).should == "A"
            pry_tester.get_prompt(false, 0).should == "A"
                                 
            Pry.new.prompt.should == Pry.prompt
            Pry.new.get_prompt(true, 0).should == "test prompt> "
            Pry.new.get_prompt(false, 0).should == "test prompt> "
          end

          it 'should set the prompt default, and the default should be overridable (multi prompt)' do
            new_prompt = [proc { "test prompt> " }, proc { "test prompt* " }]
            Pry.prompt =  new_prompt

            Pry.new.prompt.should == Pry.prompt
            Pry.new.get_prompt(true, 0).should == "test prompt> "
            Pry.new.get_prompt(false, 0).should == "test prompt* "

            new_prompt = [proc { "A" }, proc { "B" }]
            pry_tester = Pry.new(:prompt => new_prompt)
            pry_tester.prompt.should == new_prompt
            pry_tester.get_prompt(true, 0).should == "A"
            pry_tester.get_prompt(false, 0).should == "B"
                                 
            Pry.new.prompt.should == Pry.prompt
            Pry.new.get_prompt(true, 0).should == "test prompt> "
            Pry.new.get_prompt(false, 0).should == "test prompt* "
          end
        end

        it 'should set the hooks default, and the default should be overridable' do
          Pry.input = InputTester.new("exit")
          Pry.hooks = {
            :before_session => proc { |out| out.puts "HELLO" },
            :after_session => proc { |out| out.puts "BYE" }
          }
          
          str_output = StringIO.new
          Pry.new(:output => Pry::Output.new(str_output)).repl
          str_output.string.should =~ /HELLO/
          str_output.string.should =~ /BYE/
          
          Pry.input.rewind

          str_output = StringIO.new
          Pry.new(:output => Pry::Output.new(str_output),
                  :hooks => {
                    :before_session => proc { |out| out.puts "MORNING" },
                    :after_session => proc { |out| out.puts "EVENING" }
                  }
                  ).repl

          str_output.string.should =~ /MORNING/
          str_output.string.should =~ /EVENING/

          # try below with just defining one hook
          Pry.input.rewind
          str_output = StringIO.new
          Pry.new(:output => Pry::Output.new(str_output),
                  :hooks => {
                    :before_session => proc { |out| out.puts "OPEN" }
                  }
                  ).repl
          
          str_output.string.should =~ /OPEN/

          Pry.input.rewind
          str_output = StringIO.new
          Pry.new(:output => Pry::Output.new(str_output),
                  :hooks => {
                    :after_session => proc { |out| out.puts "CLOSE" }
                  }
                  ).repl

          str_output.string.should =~ /CLOSE/

          Pry.reset_defaults
        end

        
        
      end

      #     commands = {
      #       "!" => "refresh",
      #       "help" => "show_help",
      #       "nesting" => "show_nesting",
      #       "status" => "show_status",
      #       "cat dummy" => "cat",
      #       "cd 3" => "cd",
      #       "ls" => "ls",
      #       "jump_to 0" => "jump_to",
      #       "show_method test_method" => "show_method",
      #       "show_imethod test_method" => "show_method",
      #       "show_doc test_method" => "show_doc",
      #       "show_idoc test_method" => "show_doc"
      #     }
      
      #     commands.each do |command, meth|

      #       if RUBY_VERSION =~ /1.8/ && NOT_FOR_RUBY_18.any? { |v| v =~ command }
      #         next
      #       end

      #       eval %{
      #         it "should invoke output##{meth} when #{command} command entered" do
      #           input_strings = ["#{command}", "exit"]
      #           input = InputTester.new(*input_strings)
      #           output = OutputTester.new
      #           o = Class.new
      
      #           pry_tester = Pry.new(:input => input, :output => output)
      #           pry_tester.repl(o)

      #           output.#{meth}_invoked.should == true
      #           output.session_end_invoked.should == true
      #         end
      #       }
      #     end
      
      #     commands.each do |command, meth|

      #       if RUBY_VERSION =~ /1.8/ && NOT_FOR_RUBY_18.include?(command)
      #         next
      #       end

      #       eval %{
      #         it "should raise when trying to invoke #{command} command with preceding whitespace" do
      #           input_strings = [" #{command}", "exit"]
      #           input = InputTester.new(*input_strings)
      #           output = OutputTester.new
      #           o = Class.new
      
      #           pry_tester = Pry.new(:input => input, :output => output)
      #           pry_tester.repl(o)

      #           if "#{command}" != "!"
      #             output.output_buffer.is_a?(NameError).should == true
      #           else

      #             # because entering " !" in pry doesnt cause error, it
      #             # just creates a wait prompt which the subsquent
      #             # "exit" escapes from
      #             output.output_buffer.should == ""
      #           end
      #         end
      #       }
      #     end
      #   end
    end
  end
end